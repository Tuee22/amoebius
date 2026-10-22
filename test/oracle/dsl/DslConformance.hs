{-# LANGUAGE OverloadedStrings #-}

-- Independent literals judge the finite model, its refusals, and its explicit
-- premises. A pure passing seal never substitutes for native compiler rows.
module DslConformance (conformanceRows, expectedDeclaration, frame) where

import Data.Char (isHexDigit)
import Control.Exception (IOException, try)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (sort, sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslConformanceContract
import DslExtensionContract (linkedIds, declarationWorkflows)
import DslParse
import Numeric (showHex)
import System.Directory (listDirectory)
import System.FilePath ((</>))

conformanceRows :: FilePath -> IO [Row]
conformanceRows directory = do
  controls <- readTable (directory </> "controls.tsv")
  faults <- readTable (directory </> "faults.tsv")
  four <- modelRows "four-member" linkedIds fourMemberInventory
  two <- modelRows "two-member" ["infernix", "jitml"] twoMemberInventory
  laws <- traverse (\name -> judgeLaws (Text.unpack name <> "-laws.tsv") ("L." <> name) perExtensionLaws) linkedIds
  composition <- judgeLaws "composition.tsv" "C" compositionLaws
  security <- judgeLaws "security.tsv" "S" securityLaws
  pure ([expectEqual "extensions.conformance.controls" [[name, tag] | (name, tag) <- modelControls] controls,
         expectEqual "extensions.conformance.faults" [[name, Text.intercalate "," refused] | (name, refused) <- lawFaults] faults]
    <> four <> two <> laws <> [composition, security])
 where
  judgeLaws file label laws = do
    observed <- readTable (directory </> file)
    pure (expectEqual ("extensions.conformance." <> label) [[law, "model-passed"] | law <- laws] observed)
  modelRows label members (count, cases, coverage, files) = do
    observed <- readTable (directory </> Text.unpack label <> ".tsv")
    generated <- traverse (generatedRows label members) members
    let pairs = [(key, value) | [key, value] <- maybe [] id observed]
        values = Map.fromList pairs
        exact = length pairs == length (maybe [] id observed) && Map.size values == length pairs
        memberOf key = [name | name <- members, (name <> ".") `Text.isPrefixOf` key]
        lawKeys name =
          [name <> ".law." <> law <> "." <> name <> "/" <> axis | (law, axis) <-
            [("L1", "workflow"), ("L2", "plan"), ("L3", "budget"), ("L4", "workflow"), ("L5", "evidence")]] <>
          [name <> ".law.compile." <> name <> "/evidence"] <>
          [name <> ".law." <> law <> ".security-boundary" | law <- securityLaws] <>
          [name <> ".law." <> law <> "." <> peer <> "." <> digest peer | law <- compositionLaws, peer <- members, peer /= name]
        digest = expectedDeclaration
        allKeys = ["premise." <> premise | premise <- modeledPremises] <>
          concat [[name <> "." <> field | field <- ["declaration", "suite", "verdict", "cases", "coverage", "files"]] <> lawKeys name | name <- members]
        hexDigest key = case Map.lookup key values of Just value -> Text.length value == 64 && Text.all isHexDigit value; _ -> False
        expectedPremises = ["assumed", "parent-gate-obligation", "unverified", "assumed"]
        prefix = "extensions.conformance." <> label <> "."
    pure ([check (prefix <> "complete-inventory") (exact && length members == count && sort (Map.keys values) == sort allKeys)
             "missing, duplicate or unexpected model/member/law row",
           expectEqual (prefix <> "explicit-premises") expectedPremises
             (traverse (\premise -> Map.lookup ("premise." <> premise) values) modeledPremises)] <>
      [check (prefix <> name) (all (\key -> Map.lookup key values == Just "model-passed") (lawKeys name)
          && Map.lookup (name <> ".cases") values == Just (decimal cases)
          && Map.lookup (name <> ".coverage") values == Just (decimal coverage)
          && Map.lookup (name <> ".files") values == Just (decimal files)
          && all (hexDigest . ((name <> ".") <>)) ["declaration", "suite", "verdict"]
          && Map.lookup (name <> ".declaration") values == Just (expectedDeclaration name)
          && Map.lookup (name <> ".suite") values == Just (expectedSuite members name)
          && Map.lookup (name <> ".verdict") values == Just
             (sha256Hex (frame ["amoebius-extension-verdict-v1", expectedDeclaration name, finiteCoreVersion, expectedSuite members name, "passed"]))
          && length [key | key <- Map.keys values, memberOf key == [name]] == cases + 6)
        "wrong model verdict, generated inventory or declaration binding" | name <- members] <> generated)
  generatedRows label members name = do
    let root = directory </> Text.unpack label </> Text.unpack name
    listing <- try (listDirectory root) :: IO (Either IOException [FilePath])
    contents <- traverse (\file -> readBytes (root </> file)) suiteFileNames
    pure (check ("extensions.conformance." <> label <> "." <> name <> ".generated-bytes")
      (either (const Nothing) (Just . sort) listing == Just suiteFileNames
       && contents == map (Just . snd) (expectedFiles members name)) "generated file set or bytes differ from independent literals")
  decimal = Text.pack . show

expectedDeclaration :: Text -> Text
expectedDeclaration name = sha256Hex (frame ("amoebius-extension-declaration-v1" : name : concatMap component components))
 where
  components =
    [("artifact", "plan", ["recipe", name <> "/plan", "1"]),
     ("budget", "budget", "allowance" : maybe [] id (lookup name declaredBudgets)),
     ("lift", "placement", ["layer", "in-container"]),
     ("workflow", "workflow", ["ledger", "arms", Text.pack (show (length arms))] <> arms <> ["provisioned", "0", "released", "0"]),
     ("evidence", "evidence", ["register", "pure"])]
  arms = maybe [] id (lookup name declarationWorkflows)
  component (kind, suffix, payload) = [kind, name <> "/" <> suffix] <>
    (if name == "infernix" && kind == "workflow" then ["4", "8", "16", "1"] else ["0", "0", "0", "0"]) <> payload

expectedSuite :: [Text] -> Text -> Text
expectedSuite members name = sha256Hex (frameBytes (concat [[Encoding.encodeUtf8 (Text.pack path), bytes] | (path, bytes) <- expectedFiles members name]))

expectedFiles :: [Text] -> Text -> [(FilePath, ByteString)]
expectedFiles members name = [(path, Encoding.encodeUtf8 (Text.unlines (metadata <> body path))) | path <- suiteFileNames]
 where
  metadata = ["# declaration\t" <> expectedDeclaration name, "# core\t" <> hex (Encoding.encodeUtf8 finiteCoreVersion)]
  property = [("property", law, name <> "/" <> axis, "") | (law, axis) <-
    [("L1", "workflow"), ("L2", "plan"), ("L3", "budget"), ("L4", "workflow"), ("L5", "evidence")]]
  composition = [("composition", law, peer, expectedDeclaration peer) | peer <- members, peer /= name, law <- compositionLaws]
  security = [("security", law, "security-boundary", "") | law <- securityLaws]
  compile = [("compile-fail", "compile", name <> "/evidence", "")]
  cases = [("case-" <> sha256Hex (frame [suite, law, axis, peer]), suite, law, axis, peer) | (suite, law, axis, peer) <- property <> composition <> security <> compile]
  coverage = [(law, axis, "required", "-") | (_, law, axis, _) <- property <> composition <> security] <>
    [(law, "transaction-vocabulary", "not-applicable", hex (Encoding.encodeUtf8 "transaction-vocabulary-not-declared")) | law <- ["P1", "P2", "P3", "P4", "P5", "P6"]]
  body path
    | path == "coverage-grid.tsv" = "law\taxis_hex\tstatus\treason_hex" :
      [Text.intercalate "\t" [law, hex (Encoding.encodeUtf8 axis), status, reason] | (law, axis, status, reason) <- sortOn (\(law, axis, _, _) -> (law, axis)) coverage]
    | otherwise = "case_id\tlaw\taxis_hex\tpeer_digest" :
      [Text.intercalate "\t" [identifier, law, hex (Encoding.encodeUtf8 axis), if Text.null peer then "-" else peer]
      | (identifier, suite, law, axis, peer) <- sortOn (\(identifier, _, _, _, _) -> identifier) cases,
        Text.unpack suite <> "-suite.tsv" == path]

frame :: [Text] -> ByteString
frame = frameBytes . map Encoding.encodeUtf8

frameBytes :: [ByteString] -> ByteString
frameBytes = LazyByteString.toStrict . Builder.toLazyByteString . foldMap
  (\bytes -> Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes)

hex :: ByteString -> Text
hex = Text.pack . concatMap (\byte -> let digits = showHex byte "" in if length digits == 1 then '0' : digits else digits) . ByteString.unpack

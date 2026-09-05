{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.IllegalStateCovering
import Control.Exception (SomeException, try)
import Control.Monad (forM, forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson qualified as Aeson
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.List (sort)
import Data.Maybe (isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import Data.Word (Word8)
import Dhall qualified
import IllegalStateCoveringOracle
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (proc, readCreateProcessWithExitCode)
import Test.QuickCheck
  ( Args (chatty, maxSuccess), Gen, Property, Result, checkCoverage, chooseInt
  , counterexample, cover, elements, isSuccess, property, quickCheckWithResult, stdArgs
  )

main :: IO ()
main = do
  output <- required "AMOEBIUS_ILLEGAL_STATE_OUTPUT"
  compiler <- required "AMOEBIUS_ILLEGAL_STATE_GHC"
  createDirectoryIfMissing True output
  checkCatalogue output
  checkStructural output
  checkDecode
  checkCompileRefusals output compiler
  checkProperties
  putStrLn "illegal-state-covering-spec: PASS (121 catalog rows, 43 reached, 26 Phase-27 rows, 7 structural pairs, 13 decode pairs, 5 compile-refusal pairs, 4 sampled properties, 3/3 finite arms)"

checkCatalogue :: FilePath -> IO ()
checkCatalogue output = do
  let projections = map catalogProjection catalogRows
      reached = filter isReached catalogRows
      phaseTwentySeven = filter ((== 27) . catalogOwnerPhase) catalogRows
      phaseNine = sort [(catalogEntry value, catalogSubcase value) | value <- catalogRows, catalogOwnerPhase value == 9]
  assertEqual "catalog count" expectedCatalogCount (length catalogRows)
  assertEqual "catalog digest" expectedCatalogSha256 (sha256 (TextEncoding.encodeUtf8 (Text.unlines projections)))
  assertEqual "reached count" expectedReachedCount (length reached)
  assertEqual "Phase-27 count" expectedPhaseTwentySevenCount (length phaseTwentySeven)
  assertEqual "Phase-9 two-way join" (sort expectedPhaseNineRows) phaseNine
  assert (all validDeferred catalogRows) "a deferred row has an invalid locus/owner relationship"
  TextIO.writeFile (output </> "validation-locus-ledger.tsv") $ Text.unlines
    ("# Register-1 only; Tier-2/model-runtime correspondence UNVERIFIED" : "entry\tsubcase\tlocus\towner_phase\tcase_family\tdisposition" : map ledgerRow catalogRows)
  TextIO.writeFile (output </> "catalog.inventory") (Text.unlines projections)
 where
  validDeferred value = case catalogLocus value of
    ProvisionSeal -> catalogOwnerPhase value >= 9
    RenderedArtifactOracle -> catalogOwnerPhase value >= 33
    LiveEffect -> catalogOwnerPhase value >= 41
    ExtensionAstcheck -> catalogOwnerPhase value == 34
    _ -> True
  ledgerRow value = Text.intercalate "\t"
    [catalogEntry value, catalogSubcase value, Text.pack (show (catalogLocus value)), "Phase-" <> Text.pack (show (catalogOwnerPhase value)), Text.pack (show (catalogFamily value)), disposition value]

checkStructural :: FilePath -> IO ()
checkStructural output = do
  assertEqual "structural oracle" expectedStructuralRows (map structuralRow structuralCases)
  let root = output </> "dhall"
  createDirectoryIfMissing True root
  forM_ structuralCases $ \value@(StructuralCase _ subcase token legal illegal) -> do
    TextIO.writeFile (root </> Text.unpack subcase <> "-legal.dhall") (legal <> "\n")
    TextIO.writeFile (root </> Text.unpack subcase <> "-illegal.dhall") (illegal <> "\n")
    legalResult <- typecheck legal
    illegalResult <- typecheck illegal
    assert (either (const False) (const True) legalResult) ("structural legal twin rejected: " <> Text.unpack subcase)
    case illegalResult of
      Right () -> die ("structural negative admitted at " <> Text.unpack subcase)
      Left problem -> assert (token `Text.isInfixOf` problem) ("structural negative failed at wrong locus: " <> show value)
 where
  structuralRow (StructuralCase entry subcase token _ _) = (entry, subcase, token)

checkDecode :: IO ()
checkDecode = do
  assertEqual "decode oracle" expectedDecodeRows (map decodeRow decodeCases)
  forM_ decodeCases $ \(DecodeCase _ subcase expected legal illegal) -> do
    assert (either (const False) (const True) (validateDecode legal)) ("decode legal twin rejected: " <> Text.unpack subcase)
    case validateDecode illegal of
      Left actual -> assertEqual ("decode locus " <> Text.unpack subcase) expected actual
      Right _ -> die ("decode negative admitted at " <> Text.unpack subcase)
 where
  decodeRow (DecodeCase entry subcase expected _ _) = (entry, subcase, Text.pack (show expected))

checkCompileRefusals :: FilePath -> FilePath -> IO ()
checkCompileRefusals output compiler = do
  let root = output </> "compile-refusal"
  createDirectoryIfMissing True root
  results <- forM compileCases $ \value -> do
    let legalPath = root </> Text.unpack (compileCaseName value) <> "-legal.hs"
        illegalPath = root </> Text.unpack (compileCaseName value) <> "-illegal.hs"
    TextIO.writeFile legalPath (moduleSource (compileCaseLegal value))
    TextIO.writeFile illegalPath (moduleSource (compileCaseIllegal value))
    legal <- compile compiler root legalPath
    assert (receiptExit legal == ExitSuccess) ("compile legal twin rejected: " <> showReceipt legal)
    illegal <- compile compiler root illegalPath
    assert (receiptExit illegal /= ExitSuccess) ("compile negative admitted at " <> Text.unpack (compileCaseName value))
    assert (structuredError (receiptError illegal)) ("compile negative lacked structured diagnostics: " <> Text.unpack (compileCaseName value))
    assert (compileCaseLocus value `Text.isInfixOf` receiptError illegal) ("compile negative failed at wrong type locus: " <> Text.unpack (compileCaseName value))
    pure (length (compileCaseEntries value))
  assertEqual "compile-covered row count" 6 (sum results)
 where
  moduleSource expression = Text.unlines
    [ "{-# LANGUAGE DataKinds #-}", "module Probe where"
    , "import Amoebius.Dsl.IllegalStateCovering", "probe :: ()", "probe = " <> expression
    ]
  compile compilerPath root source = do
    let arguments = ["-fno-code", "-fforce-recomp", "-fdiagnostics-as-json", "-XGHC2024", "-package", "text", "-isrc/illegal-state-covering", "-odir", root, "-hidir", root]
#ifdef ILLEGAL_STATE_GADT_MUTANT
          <> ["-DILLEGAL_STATE_GADT_MUTANT"]
#endif
          <> [source, "src/illegal-state-covering/Amoebius/Dsl/IllegalStateCovering.hs"]
    (status, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc compilerPath arguments) ""
    pure (Receipt status (Text.pack stdoutText) (Text.pack stderrText))

checkProperties :: IO ()
checkProperties = do
  results <- sequence
    [ runProperty propSmartConstructorClosure
    , runProperty propDecodeRoundTrip
    , runProperty propFoldTotal
    , runProperty propCompositionPreservesWellFormedness
    ]
  assert (all isSuccess results) "property mutant or production behavior made the sampled property suite red"
  assertEqual "exhausted Rke2Servers" [1, 3, 5] rke2ServerCounts

propSmartConstructorClosure :: Property
propSmartConstructorClosure = checkCoverage $ forAllSmart $ \family a b c ->
  cover 15 (family == ReplicaFamily) "replica" $
  cover 15 (family == RolloutFamily) "rollout" $
  cover 15 (family == HeadroomFamily) "headroom" $
  let actual = smartConstructorClosed family a b c
      expected = case family of
        ReplicaFamily -> a > 0
        RolloutFamily -> a > 0 || b > 0
        HeadroomFamily -> c > 0 && a + c <= b
   in counterexample (show (family, a, b, c)) (actual == expected)

propDecodeRoundTrip :: Property
propDecodeRoundTrip = checkCoverage $ do
  substrateCount <- chooseInt (1, 3)
  serviceCount <- chooseInt (1, 3)
  resources <- naturalList
  let value = (names "s" substrateCount, names "v" serviceCount, resources)
  pure $ cover 20 (substrateCount > 1) "multi-substrate" $ cover 20 (serviceCount >= 2) "multi-service" $ roundTrip value == value

propFoldTotal :: Property
propFoldTotal = checkCoverage $ do
  values <- naturalList
  pure $ cover 10 (null values) "boundary-empty" $ cover 10 (not (null values)) "non-empty" $ totalFold values == sum values

propCompositionPreservesWellFormedness :: Property
propCompositionPreservesWellFormedness = checkCoverage $ do
  left <- fragment "left"
  right <- fragment "right"
  let (ls, lv, lr) = left; (rs, rv, rr) = right
  pure $ cover 25 True "non-identity-distinct-composition" $ composeFragments left right == (ls <> rs, lv <> rv, lr <> rr)

forAllSmart :: (SmartFamily -> Natural -> Natural -> Natural -> Property) -> Property
forAllSmart consume = property $ do
  family <- elements [minBound .. maxBound]
  a <- natural
  b <- natural
  c <- natural
  pure (consume family a b c)

fragment :: Text -> Gen ([Text], [Text], [Natural])
fragment prefix = do
  width <- chooseInt (1, 3)
  values <- naturalList
  pure (names (prefix <> "-s") width, names (prefix <> "-v") width, values)

naturalList :: Gen [Natural]
naturalList = do
  width <- chooseInt (0, 4)
  sequence [natural | _ <- [1 .. width]]

natural :: Gen Natural
natural = fromIntegral <$> chooseInt (0, 12)

names :: Text -> Int -> [Text]
names prefix count = [prefix <> Text.pack (show index) | index <- [1 .. count]]

runProperty :: Property -> IO Result
runProperty = quickCheckWithResult stdArgs {maxSuccess = 300, chatty = False}

typecheck :: Text -> IO (Either Text ())
typecheck source = do
  result <- try (() <$ Dhall.inputExpr source) :: IO (Either SomeException ())
  pure $ case result of Left problem -> Left (Text.pack (show problem)); Right _ -> Right ()

data Receipt = Receipt ExitCode Text Text
receiptExit :: Receipt -> ExitCode
receiptExit (Receipt status _ _) = status
receiptError :: Receipt -> Text
receiptError (Receipt _ _ problem) = problem
showReceipt :: Receipt -> String
showReceipt (Receipt status out problem) = show (status, Text.take 300 out, Text.take 500 problem)

structuredError :: Text -> Bool
structuredError problem = any (isJust . (Aeson.decodeStrict' :: ByteString.ByteString -> Maybe Aeson.Value) . Char8.pack . Text.unpack) (Text.lines problem)

sha256 :: ByteString.ByteString -> Text
sha256 = Text.pack . concatMap hex . ByteString.unpack . SHA256.hash
 where
  hex :: Word8 -> String
  hex value = [digits !! fromIntegral (value `div` 16), digits !! fromIntegral (value `mod` 16)]
  digits = "0123456789abcdef"

required :: String -> IO FilePath
required name = maybe (die (name <> " is required")) pure =<< lookupEnv name

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected=" <> show expected <> "; actual=" <> show actual)

die :: String -> IO value
die message = putStrLn ("illegal-state-covering-spec: FAIL: " <> message) >> exitFailure

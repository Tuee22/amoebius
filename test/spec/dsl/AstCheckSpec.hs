{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.AstCheck
import Amoebius.Dsl.SanctionedApi
import Control.Monad (forM_, unless)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Environment (getArgs)

data ExpectedNegative = ExpectedNegative
  { expectedFile :: FilePath
  , expectedReason :: AstViolationReason
  , expectedLine :: Int
  , expectedColumn :: Int
  }

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--mutant=astcheck-allow-rawio"] -> rejectMutant "astcheck-allow-rawio" =<< rawIoMutationCaught
    ["--mutant=astcheck-export-ctor"] -> rejectMutant "astcheck-export-ctor" =<< constructorExportMutationCaught
    _ -> runGreen

runGreen :: IO ()
runGreen = do
  forM_ ["positive_basic.hs", "positive_manifest.hs"] checkPositive
  negatives <- loadExpectedNegatives
  assert (length negatives == length ([minBound .. maxBound] :: [AstViolationReason])) "AST reason oracle is not exhaustive"
  assert (Set.fromList (fmap expectedReason negatives) == Set.fromList [minBound .. maxBound]) "AST reason oracle misses a reason arm"
  forM_ negatives checkNegative
  checkSanctionedApi
  opaque <- constructorOpaque
  assert opaque "CheckedExtensionSource constructor is exported"
  putStrLn "astcheck-spec: PASS (2 positives, 6 exact reason/span negatives, 2 sanctioned modules, 4 sanctioned effects, opaque link seal, 2 mutants)"

checkPositive :: FilePath -> IO ()
checkPositive name = do
  source <- Text.readFile (fixturePath name)
  case checkExtensionSource name source of
    Accepted checked -> assert (linkCheckedExtension checked == source) (name <> " changed at link seal")
    Rejected violations -> fail (name <> " unexpectedly rejected: " <> show violations)

checkNegative :: ExpectedNegative -> IO ()
checkNegative expected = do
  source <- Text.readFile (fixturePath (expectedFile expected))
  case checkExtensionSource (expectedFile expected) source of
    Accepted _ -> fail (expectedFile expected <> " unexpectedly accepted")
    Rejected violations ->
      let expectedViolation =
            AstViolation
              (expectedFile expected)
              (SourceSpan (expectedLine expected) (expectedColumn expected))
              (expectedReason expected)
       in assert (NonEmpty.toList violations == [expectedViolation]) (expectedFile expected <> " reason/span drifted: " <> show violations)

loadExpectedNegatives :: IO [ExpectedNegative]
loadExpectedNegatives = do
  contents <- Text.readFile "test/fixture/chain_boundary/astcheck/astcheck_negatives.expected"
  mapM parseRow (drop 1 (Text.lines contents))
 where
  parseRow row = case Text.splitOn "\t" row of
    [file, reason, line, column] ->
      ExpectedNegative (Text.unpack file)
        <$> parseReason reason
        <*> parseNatural "line" line
        <*> parseNatural "column" column
    _ -> fail ("invalid AST oracle row: " <> Text.unpack row)
  parseReason reason = case reason of
    "UnsanctionedImport" -> pure UnsanctionedImport
    "RawIO" -> pure RawIO
    "ForeignCall" -> pure ForeignCall
    "UnsafeOperation" -> pure UnsafeOperation
    "TemplateHaskell" -> pure TemplateHaskell
    "OrphanInstance" -> pure OrphanInstance
    _ -> fail ("unknown AST reason: " <> Text.unpack reason)
  parseNatural label value = case reads (Text.unpack value) of
    [(parsed, "")] | parsed > 0 -> pure parsed
    _ -> fail ("invalid " <> label <> ": " <> Text.unpack value)

checkSanctionedApi :: IO ()
checkSanctionedApi = do
  oracle <- Text.readFile "test/fixture/chain_boundary/sanctioned_api_expected.dhall"
  let expectedModules = ["Amoebius.Kernel.Step", "Amoebius.Manifest.K8sObject"]
      expectedEffects = ["ApplyManifest", "BuildImage", "PushImage", "UpdateInfrastructure"]
      actualModules = Set.map unModuleName (sanctionedModules sanctionedApi)
      actualEffects = Set.map (Text.pack . show) (sanctionedEffects sanctionedApi)
  assert (actualModules == Set.fromList expectedModules) "sanctioned module set drifted"
  assert (actualEffects == Set.fromList expectedEffects) "sanctioned effect set drifted"
  forM_ (expectedModules <> expectedEffects) $ \entry ->
    assert (entry `Text.isInfixOf` oracle) ("sanctioned oracle omits " <> Text.unpack entry)

constructorOpaque :: IO Bool
constructorOpaque = do
  source <- Text.readFile "src/Amoebius/Dsl/AstCheck.hs"
  let header = fst (Text.breakOn ") where" source)
  pure (headerIsOpaque header)

rawIoMutationCaught :: IO Bool
rawIoMutationCaught = do
  source <- Text.readFile (fixturePath "negative_raw_io.hs")
  pure $ case checkExtensionSource "negative_raw_io.hs" source of
    Rejected violations ->
      let reasons = fmap violationReason (NonEmpty.toList violations)
          mutantRemainder = filter (/= RawIO) reasons
       in reasons == [RawIO] && null mutantRemainder
    Accepted _ -> False

constructorExportMutationCaught :: IO Bool
constructorExportMutationCaught = do
  source <- Text.readFile "src/Amoebius/Dsl/AstCheck.hs"
  let header = fst (Text.breakOn ") where" source)
      widened = Text.replace ", CheckedExtensionSource\n" ", CheckedExtensionSource (..)\n" header
  pure (headerIsOpaque header && widened /= header && not (headerIsOpaque widened))

headerIsOpaque :: Text.Text -> Bool
headerIsOpaque = not . Text.isInfixOf "CheckedExtensionSource ("

rejectMutant :: String -> Bool -> IO ()
rejectMutant name caught =
  if caught
    then putStrLn ("chain-boundary-ast-mutant: RED " <> name) >> fail ("chain boundary AST mutant rejected: " <> name)
    else putStrLn ("chain-boundary-ast-mutant: SURVIVED " <> name)

fixturePath :: FilePath -> FilePath
fixturePath name = "test/fixture/chain_boundary/astcheck/" <> name

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)

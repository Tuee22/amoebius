{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-10 authority. Every compiler child is
-- synchronous; the runner uses neither @pb@ nor network/hardware effects.
module Amoebius.Validation.CalculusCompositionRun.Internal
  ( AcquiredCalculusCompositionRun
  , acquireCalculusCompositionRun
  , acquireCalculusCompositionRefreshRun
  , acquiredCalculusCompositionRunCheck
  , foldAcquiredCalculusCompositionRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( createDirectory, createDirectoryIfMissing, doesDirectoryExist, getHomeDirectory
  , listDirectory, removeFile )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Pair = Pair Text Receipt Receipt Receipt deriving (Eq, Show)
data Mutant = Mutant Text Text Receipt Receipt deriving (Eq, Show)
data Matrix = Matrix
  { cleanBuild :: Receipt
  , cleanRun :: Receipt
  , mutantRows :: [Mutant]
  , compilePairs :: [Pair]
  }

data AcquiredCalculusCompositionRun = AcquiredCalculusCompositionRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredCalculusCompositionRunCheck :: AcquiredCalculusCompositionRun -> CheckResult
acquiredCalculusCompositionRunCheck (AcquiredCalculusCompositionRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredCalculusCompositionRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredCalculusCompositionRun -> value
foldAcquiredCalculusCompositionRun consume (AcquiredCalculusCompositionRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireCalculusCompositionRun, acquireCalculusCompositionRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredCalculusCompositionRun
acquireCalculusCompositionRun = acquire False
acquireCalculusCompositionRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredCalculusCompositionRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "calculus-composition-package-database"
        [observation "calculus-composition.package-db" (Text.pack path) | path <- databases]
        [finding "CALCULUS-COMPOSITION-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 10 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "calculus-composition-freshness" [observation "calculus-composition.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "calculus-composition-cleanroom" [observation "calculus-composition.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "CALCULUS-COMPOSITION-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-10/work") runRoot)]
      qualification = mergeChecks "calculus-composition-qualification" [compiler, oracle, positive, negatives, mutants, discipline]
      prerequisite = mergeChecks "calculus-composition-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom, discipline]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "calculus-composition" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "calculus-composition-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "calculus-composition-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "calculus-composition-harness" (map receiptDigest receipts)
      observerId = ids "calculus-composition-observer" [checkDigest observer]
      qualificationId = ids "calculus-composition-qualification" [checkDigest qualification]
      acquiredRunId = ids "calculus-composition-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "calculus-composition-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredCalculusCompositionRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- compileProgram root runRoot database compiler "clean" Nothing
  cr <- runBuilt root runRoot "clean" "clean-oracle" cb
  mutants <- mapM (runMutant root runRoot database compiler) mutantSpecifications
  pairs <- mapM (compilePair root runRoot database compiler) pairSpecifications
  pure (Matrix cb cr mutants pairs)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> (Text, String) -> IO Mutant
runMutant root runRoot database compiler (name, selector) = do
  let variant = "mutant-" <> Text.unpack name
  build <- compileProgram root runRoot database compiler variant (Just selector)
  run <- runBuilt root runRoot variant (name <> "-oracle") build
  pure (Mutant name (Text.pack selector) build run)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "calculus-composition-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-package", "QuickCheck", "-o", binary, oracleSource])

compilePair :: FilePath -> FilePath -> FilePath -> FilePath -> PairSpecification -> IO Pair
compilePair root runRoot database compiler (PairSpecification name legal illegal _ _ selector) = do
  legalReceipt <- compileFixture root runRoot database compiler (name <> "-legal") legal
  illegalReceipt <- compileFixture root runRoot database compiler (name <> "-illegal") illegal
  relaxedReceipt <- compileFixtureWith root runRoot database compiler (name <> "-relaxed") selector illegal
  pure (Pair name legalReceipt illegalReceipt relaxedReceipt)

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> Text -> FilePath -> IO Receipt
compileFixture root runRoot database compiler name source = do
  compileFixtureWith root runRoot database compiler name "" source

compileFixtureWith :: FilePath -> FilePath -> FilePath -> FilePath -> Text -> String -> FilePath -> IO Receipt
compileFixtureWith root runRoot database compiler name selector source = do
  let objects = runRoot </> Text.unpack name </> "objects"
  createDirectoryIfMissing True objects
  runProcess root (name <> "-compiler") compiler
    (common database objects (if null selector then Nothing else Just selector) <> ["-fno-code", source])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  , "-clear-package-db", "-global-package-db", "-package-db", database
  , "-isrc", "-isrc/calculus-composition", "-isrc/capacity-topology", "-itest/spec/calculus"
  , "-package", "text", "-package", "QuickCheck"
  , "-odir", objects, "-hidir", objects, "-stubdir", objects]
  <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot variant name build
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "calculus-composition-oracle") []
  | otherwise = pure (unavailable name)

data PairSpecification = PairSpecification Text FilePath FilePath Text Text String

pairSpecifications :: [PairSpecification]
pairSpecifications =
  [ PairSpecification
      "different-request-scope"
      "test/negative/compile_fail/calculus_composition/same_scope_composes.hs"
      "test/negative/compile_fail/calculus_composition/different_scopes_do_not_compose.hs"
      "Couldn't match type"
      "scope"
      "CALCULUS_COMPOSITION_WIDENS_SCOPE_MUTANT"
  ]

mutantSpecifications :: [(Text, String)]
mutantSpecifications =
  [ ("resource-saturation", "CALCULUS_COMPOSITION_SATURATES_RESOURCE_SUM_MUTANT")
  , ("transform-drops-index", "CALCULUS_COMPOSITION_DROPS_TRANSFORM_INDEX_MUTANT")
  ]

compilerCheck :: Matrix -> CheckResult
compilerCheck matrix = CheckResult "calculus-composition-compiler" (map (observation "calculus-composition.compiler" . receiptSummary) required)
  [finding "CALCULUS-COMPOSITION-COMPILER" (Text.unpack name) "a clean, mutant, or legal control did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = cleanBuild matrix : [build | Mutant _ _ build _ <- mutantRows matrix]
          <> [legal | Pair _ legal _ _ <- compilePairs matrix]
          <> [relaxed | Pair _ _ _ relaxed <- compilePairs matrix]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "calculus-composition-independent-oracle" [observation "calculus-composition.oracle" (receiptSummary receipt)]
  [finding "CALCULUS-COMPOSITION-ORACLE" oracleSource "the authored Haskell oracle did not report its exact clean inventory" | receiptExit receipt /= ExitSuccess || not (passLine `Text.isInfixOf` receiptStdout receipt)]
 where passLine = "PASS (25 ordered pairs, 125 triples, 3 properties, 9 checks)"

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "calculus-composition-positive-controls" [observation "calculus-composition.positive" "clean-oracle,one-legal-compile-control"]
  [finding "CALCULUS-COMPOSITION-POSITIVE" "<clean-controls>" "the clean oracle or legal compile twin failed" | receiptExit (cleanRun matrix) /= ExitSuccess || any ((/= ExitSuccess) . receiptExit) [legal | Pair _ legal _ _ <- compilePairs matrix]]

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "calculus-composition-paired-negatives"
  [observation ("calculus-composition.negative." <> name) (receiptSummary illegal) | Pair name _ illegal _ <- compilePairs matrix]
  [finding "CALCULUS-COMPOSITION-NEGATIVE" (Text.unpack name) "the different-scope twin did not fail at its pinned rigid scope mismatch" | (PairSpecification expectedName _ _ reason locus _, Pair name _ illegal _) <- zip pairSpecifications (compilePairs matrix), name /= expectedName || not (failedWith illegal reason && failedWith illegal locus)]

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "calculus-composition-mutants"
  [observation ("calculus-composition.mutant." <> name) (selector <> "|" <> receiptSummary run) | Mutant name selector _ run <- mutantRows matrix]
  ([finding "CALCULUS-COMPOSITION-MUTANT" (Text.unpack name) "the changed production subject did not compile and turn red at its assigned unchanged-oracle locus" | Mutant name _ build run <- mutantRows matrix, receiptExit build /= ExitSuccess || not (failsAt name run)]
    <> [finding "CALCULUS-COMPOSITION-MUTANT" "scope-widening" "the widened production signature did not compile the unchanged illegal twin" | Pair _ _ _ relaxed <- compilePairs matrix, receiptExit relaxed /= ExitSuccess])
 where
  failsAt name receipt =
    receiptExit receipt == ExitFailure 1
      && case name of
        "resource-saturation" -> "FAIL resource-index-additivity" `Text.isInfixOf` receiptStdout receipt
        "transform-drops-index" -> "FAIL transform-preserves-indices" `Text.isInfixOf` receiptStdout receipt
        _ -> False

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  sources <- mapM (readFile . (root </>)) productionSources
  let combined = Text.pack (concat sources)
      forbidden = ["System.IO", "Network.Socket", "unsafePerformIO", "undefined"]
      required = ["data Calculus", "data Component scope", "compose :: Component scope", "append :: Composition scope", "compositionResource", "renameComponent"]
  pure (CheckResult "calculus-composition-source-discipline"
    [observation "calculus-composition.effect-boundary" "pure-only", observation "calculus-composition.closed-model-elements" (Text.pack (show (length required)))]
    ([finding "CALCULUS-COMPOSITION-SOURCE-DISCIPLINE" "src/calculus-composition/" ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` combined]
      <> [finding "CALCULUS-COMPOSITION-MODEL-SHAPE" "src/calculus-composition/" ("missing model element: " <> token) | token <- required, not (token `Text.isInfixOf` combined)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "calculus-composition-discovery" [observation "calculus-composition.discovery.count" (Text.pack (show (length observed)))]
  [finding "CALCULUS-COMPOSITION-DISCOVERY" "<calculus-composition-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "calculus-composition-authority"
  [observation "calculus-composition.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; pure source boundary"]
  ([finding "CALCULUS-COMPOSITION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-10/work" | not (pathBelow (root </> ".build/runs/phase-10/work") runRoot)]
    <> [finding "CALCULUS-COMPOSITION-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "calculus-composition-observer" (map (observation "calculus-composition.observer.process" . receiptSummary) receipts)
  [finding "CALCULUS-COMPOSITION-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-10-claim" [pre], named "phase-10-subject" [compiler, positive], named "phase-10-command" [compiler, authority]
  ,named "phase-10-oracle" [oracle], named "phase-10-positive-controls" [positive], named "phase-10-paired-negatives" [negatives]
  ,named "phase-10-mutants" [mutants], named "phase-10-discovery" [discovery], named "phase-10-challenge" [mutants]
  ,named "phase-10-observer" [observer], named "phase-10-authority-bypass" [authority], named "phase-10-freshness" [freshness]
  ,named "phase-10-qualification" [qualification], named "phase-10-cleanroom" [cleanroom], named "phase-10-legacy-closure" [pre]
  ,CheckResult "phase-10-predecessor" [observation "phase-10.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-10-residue" [observation "phase-10.residue" "formal models, extension declarations and laws, decode, effects, runtimes, hardware, and cleanup remain later-owned"] []
  ,named "phase-10-pass-criterion" [pre]]
 where named = mergeChecks

failedWith :: Receipt -> Text -> Bool
failedWith receipt needle = receiptExit receipt == ExitFailure 1 && needle `Text.isInfixOf` receiptStderr receipt

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do
    names <- listDirectory store
    filterM doesDirectoryExist [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-10/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _) = status
receiptStdout, receiptStderr :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
receiptStderr (Receipt _ _ _ _ _ err) = err
receiptDigest :: Receipt -> Text
receiptDigest (Receipt name executable args status out err) = digestTexts [name, Text.pack executable, Text.pack (show args), Text.pack (show status), out, err]
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> failure
 where failure = if status == ExitSuccess then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap hex . ByteString.unpack . SHA256.hash where hex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
unavailable :: Text -> Receipt
unavailable name = Receipt name "<unavailable>" [] (ExitFailure 127) "" "package database or compiler construction unavailable"
unavailableMatrix :: Matrix
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") [Mutant name (Text.pack selector) (u (name <> "-compiler")) (u (name <> "-oracle")) | (name, selector) <- mutantSpecifications] [Pair name (u (name <> "-legal-compiler")) (u (name <> "-illegal-compiler")) (u (name <> "-relaxed-compiler")) | PairSpecification name _ _ _ _ _ <- pairSpecifications] where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix = [cleanBuild matrix, cleanRun matrix] <> concat [[build, run] | Mutant _ _ build run <- mutantRows matrix] <> concat [[legal, illegal, relaxed] | Pair _ legal illegal relaxed <- compilePairs matrix]

productionSources :: [FilePath]
productionSources =
  ["src/calculus-composition/Amoebius/Calculus/Composition.hs"]
sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/calculus-composition/", "test/spec/calculus/CalculusComposition", "test/negative/compile_fail/calculus_composition/"]
expectedSources :: [FilePath]
expectedSources = sort (productionSources <> [oracleSource] <> concat [[legal, illegal] | PairSpecification _ legal illegal _ _ _ <- pairSpecifications])
oracleSource :: FilePath
oracleSource = "test/spec/calculus/CalculusCompositionSpec.hs"

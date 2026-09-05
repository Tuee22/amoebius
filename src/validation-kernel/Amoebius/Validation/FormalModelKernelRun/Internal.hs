{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, source-bound Phase-11 authority. Compiler-bearing children
-- are synchronous, use the authenticated GHC directly, and never invoke @pb@,
-- a network client, JVM, container, service, or hardware boundary.
module Amoebius.Validation.FormalModelKernelRun.Internal
  ( AcquiredFormalModelKernelRun
  , acquireFormalModelKernelRun
  , acquireFormalModelKernelRefreshRun
  , acquiredFormalModelKernelRunCheck
  , foldAcquiredFormalModelKernelRun
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
  ( createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist
  , getHomeDirectory, listDirectory, removeFile )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt Receipt deriving (Eq, Show)
data Matrix = Matrix { cleanBuild :: Receipt, cleanRun :: Receipt, mutantRows :: [Mutant] }

data AcquiredFormalModelKernelRun = AcquiredFormalModelKernelRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredFormalModelKernelRunCheck :: AcquiredFormalModelKernelRun -> CheckResult
acquiredFormalModelKernelRunCheck (AcquiredFormalModelKernelRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredFormalModelKernelRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredFormalModelKernelRun -> value
foldAcquiredFormalModelKernelRun consume (AcquiredFormalModelKernelRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireFormalModelKernelRun, acquireFormalModelKernelRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredFormalModelKernelRun
acquireFormalModelKernelRun = acquire False
acquireFormalModelKernelRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredFormalModelKernelRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "formal-model-kernel-package-database"
        [observation "formal-model-kernel.package-db" (Text.pack path) | path <- databases]
        [finding "FORMAL-MODEL-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root acquired
  artifact <- artifactCheck root runRoot acquired
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 11 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck (cleanRun matrix)
      negatives = negativeCheck (cleanRun matrix)
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "formal-model-kernel-freshness"
        [observation "formal-model-kernel.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "formal-model-kernel-cleanroom"
        [artifact, CheckResult "formal-model-kernel-contained-root"
          [observation "formal-model-kernel.run-root" (Text.pack (makeRelative root runRoot))]
          [finding "FORMAL-MODEL-CLEANROOM" runRoot "generated products escaped the phase run root"
            | not (pathBelow (root </> ".build/runs/phase-11/work") runRoot)]]
      qualification = mergeChecks "formal-model-kernel-qualification"
        [compiler, oracle, positive, negatives, mutants, discovery, discipline, artifact]
      prerequisite = mergeChecks "formal-model-kernel-prerequisite"
        [ genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler
        , oracle, positive, negatives, mutants, discovery, authority, observer, freshness
        , cleanroom, discipline, artifact ]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom artifact
      result = mergeChecks "formal-model-kernel" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "formal-model-kernel-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "formal-model-kernel-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "formal-model-kernel-harness" (map receiptDigest receipts)
      observerId = ids "formal-model-kernel-observer" [checkDigest observer]
      qualificationId = ids "formal-model-kernel-qualification" [checkDigest qualification]
      acquiredRunId = ids "formal-model-kernel-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "formal-model-kernel-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredFormalModelKernelRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cleanCompiler <- compileProgram root runRoot database compiler "clean" Nothing
  cleanOracle <- runBuilt root runRoot "clean" "clean-oracle" cleanCompiler
  mutants <- mapM (runMutant root runRoot database compiler) mutantSpecifications
  pure (Matrix cleanCompiler cleanOracle mutants)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot database compiler (name, selector, locus) = do
  let variant = "mutant-" <> Text.unpack name
  build <- compileProgram root runRoot database compiler variant (Just selector)
  run <- runBuilt root runRoot variant (name <> "-oracle") build
  pure (Mutant name (Text.pack selector) locus build run)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "formal-model-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-o", binary, oracleSource])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  [ "-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  , "-clear-package-db", "-global-package-db", "-package-db", database
  , "-isrc", "-isrc/calculus-composition", "-isrc/capacity-topology"
  , "-isrc/formal-composition-model", "-itest/spec/formal"
  , "-package", "text", "-package", "containers"
  , "-odir", objects, "-hidir", objects, "-stubdir", objects ]
  <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot variant name build
  | receiptExit build == ExitSuccess = do
      let output = runRoot </> variant </> "generated"
      createDirectoryIfMissing True output
      runProcess root name (runRoot </> variant </> "formal-model-oracle") [output]
  | otherwise = pure (unavailable name)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("guard-ignored", "FORMAL_MODEL_IGNORES_GUARD_MUTANT", "FAIL[disabled-transition]")
  , ("unchanged-dropped", "FORMAL_MODEL_DROPS_UNCHANGED_MUTANT", "FAIL[renderer-unchanged]")
  , ("invariant-weakened", "FORMAL_MODEL_WEAKENS_INVARIANT_MUTANT", "FAIL[invariant-truth-table]") ]

compilerCheck :: Matrix -> CheckResult
compilerCheck matrix = CheckResult "formal-model-kernel-compiler"
  (map (observation "formal-model-kernel.compiler" . receiptSummary) required)
  [finding "FORMAL-MODEL-COMPILER" (Text.unpack name) "a clean or changed-production subject did not compile"
    | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = cleanBuild matrix : [build | Mutant _ _ _ build _ <- mutantRows matrix]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "formal-model-kernel-independent-oracle"
  [observation "formal-model-kernel.oracle" (receiptSummary receipt)]
  [finding "FORMAL-MODEL-ORACLE" oracleSource "the authored Haskell oracle did not report its exact clean inventory"
    | receiptExit receipt /= ExitSuccess || not (passLine `Text.isInfixOf` receiptStdout receipt)]
 where passLine = "PASS (8 states, 8 transitions, 25 renderer facts, 200 generated models)"

positiveCheck :: Receipt -> CheckResult
positiveCheck receipt = CheckResult "formal-model-kernel-positive-controls"
  [observation "formal-model-kernel.positive" "clean-kernel,clean-explorer,clean-renderer,phase-10-projection"]
  [finding "FORMAL-MODEL-POSITIVE" oracleSource "the clean formal-model corpus failed"
    | receiptExit receipt /= ExitSuccess]

negativeCheck :: Receipt -> CheckResult
negativeCheck receipt = CheckResult "formal-model-kernel-paired-negatives"
  [observation "formal-model-kernel.negative" "well-formed model versus one duplicate-variable model"]
  [finding "FORMAL-MODEL-NEGATIVE" oracleSource "the minimally different malformed-model pair was not observed"
    | not ("paired structural model control PASS" `Text.isInfixOf` receiptStdout receipt)]

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "formal-model-kernel-mutants"
  [observation ("formal-model-kernel.mutant." <> name) (selector <> "|" <> receiptSummary run)
    | Mutant name selector _ _ run <- mutantRows matrix]
  [finding "FORMAL-MODEL-MUTANT" (Text.unpack name)
    ("changed production subject did not turn red at " <> locus)
    | Mutant name _ locus build run <- mutantRows matrix
    , receiptExit build /= ExitSuccess || receiptExit run /= ExitFailure 1 || not (locus `Text.isInfixOf` receiptStderr run)]

sourceDisciplineCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
sourceDisciplineCheck root acquired = do
  sources <- mapM (readFile . (root </>)) productionSources
  let combined = Text.pack (concat sources)
      forbidden = ["Network.Socket", "unsafePerformIO", "tla2tools.jar", "readProcess", "System.Process"]
      required = ["data Value", "data Expr", "data Model", "interpret ::", "explore ::", "emitTLA ::", "toyModel :: Model", "compositionModel ::"]
      trackedGenerated = [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), ".tla" `isSuffixOf` path || ".cfg" `isSuffixOf` path]
  pure (CheckResult "formal-model-kernel-source-discipline"
    [ observation "formal-model-kernel.effect-boundary" "pure-model-plus-contained-file-emission"
    , observation "formal-model-kernel.closed-model-elements" (Text.pack (show (length required))) ]
    ( [finding "FORMAL-MODEL-SOURCE-DISCIPLINE" "src/Amoebius/Formal/" ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` combined]
      <> [finding "FORMAL-MODEL-SHAPE" "src/Amoebius/Formal/" ("missing model element: " <> token) | token <- required, not (token `Text.isInfixOf` combined)]
      <> [finding "FORMAL-MODEL-TRACKED-GENERATED" path "generated .tla/.cfg must not be tracked" | path <- trackedGenerated] ))

artifactCheck :: FilePath -> FilePath -> AcquiredSourceSnapshot -> IO CheckResult
artifactCheck root runRoot acquired = do
  let cleanGenerated = runRoot </> "clean/generated"
      expected = [cleanGenerated </> "ToyModel.tla", cleanGenerated </> "ToyModel.cfg", cleanGenerated </> "CalculusComposition.tla", cleanGenerated </> "CalculusComposition.cfg"]
  present <- mapM doesFileExist expected
  let trackedGenerated = [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), ".tla" `isSuffixOf` path || ".cfg" `isSuffixOf` path]
  pure (CheckResult "formal-model-kernel-generated-artifacts"
    [observation "formal-model-kernel.generated.count" (Text.pack (show (length (filter id present))))]
    ( [finding "FORMAL-MODEL-GENERATED-MISSING" (makeRelative root path) "clean oracle did not lazily emit the required projection" | (path, False) <- zip expected present]
      <> [finding "FORMAL-MODEL-GENERATED-TRACKED" path "generated projection appeared in the source snapshot" | path <- trackedGenerated] ))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "formal-model-kernel-discovery"
  [observation "formal-model-kernel.discovery.count" (Text.pack (show (length observed)))]
  [finding "FORMAL-MODEL-DISCOVERY" "<formal-model-kernel-source-set>"
    ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "formal-model-kernel-authority"
  [observation "formal-model-kernel.compiler-serialization" "one synchronous GHC child at a time; no -j; direct executable; no pb/JVM/network/hardware"]
  ( [finding "FORMAL-MODEL-RUN-ROOT" runRoot "run root escaped .build/runs/phase-11/work" | not (pathBelow (root </> ".build/runs/phase-11/work") runRoot)]
    <> [finding "FORMAL-MODEL-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority"
      | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name
      , executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline )

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "formal-model-kernel-observer"
  (map (observation "formal-model-kernel.observer.process" . receiptSummary) receipts)
  [finding "FORMAL-MODEL-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
    | receipt@(Receipt name executable _ _ _ _) <- receipts
    , executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom artifact =
  [ named "phase-11-claim" [pre], named "phase-11-subject" [compiler, positive]
  , named "phase-11-command" [compiler, authority], named "phase-11-oracle" [oracle]
  , named "phase-11-positive-controls" [positive], named "phase-11-paired-negatives" [negatives]
  , named "phase-11-mutants" [mutants], named "phase-11-discovery" [discovery]
  , named "phase-11-challenge" [mutants], named "phase-11-observer" [observer]
  , named "phase-11-authority-bypass" [authority], named "phase-11-freshness" [freshness]
  , named "phase-11-qualification" [qualification], named "phase-11-cleanroom" [cleanroom]
  , named "phase-11-legacy-closure" [artifact]
  , CheckResult "phase-11-predecessor" [observation "phase-11.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-11-residue" [observation "phase-11.residue" "checker algorithms, concrete protocol models, runtime fidelity, live effects, and hardware remain later-owned"] []
  , named "phase-11-pass-criterion" [pre] ]
 where named = mergeChecks

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
  let parent = root </> ".build/runs/phase-11/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem)))
    (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

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
sha256 = Text.pack . concatMap hex . ByteString.unpack . SHA256.hash
 where hex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child)
  in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
unavailable :: Text -> Receipt
unavailable name = Receipt name "<unavailable>" [] (ExitFailure 127) "" "package database or compiler construction unavailable"
unavailableMatrix :: Matrix
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle")
  [Mutant name (Text.pack selector) locus (u (name <> "-compiler")) (u (name <> "-oracle"))
    | (name, selector, locus) <- mutantSpecifications]
 where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix = [cleanBuild matrix, cleanRun matrix]
  <> concat [[build, run] | Mutant _ _ _ build run <- mutantRows matrix]

productionSources :: [FilePath]
productionSources =
  [ "src/Amoebius/Formal/Model.hs", "src/Amoebius/Formal/Interpret.hs"
  , "src/Amoebius/Formal/Explore.hs", "src/Amoebius/Formal/EmitTLA.hs"
  , "src/Amoebius/Formal/ToyModel.hs"
  , "src/formal-composition-model/Amoebius/Formal/CalculusComposition.hs" ]
expectedSources :: [FilePath]
expectedSources = sort (productionSources <> [oracleSource])
oracleSource :: FilePath
oracleSource = "test/spec/formal/RoundTripSpec.hs"

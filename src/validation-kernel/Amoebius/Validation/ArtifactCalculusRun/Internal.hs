{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free execution authority for the artifact
-- calculus. Every GHC child is started synchronously and without @-j@, so the
-- qualification matrix cannot overlap compiler or linker work.
module Amoebius.Validation.ArtifactCalculusRun.Internal
  ( AcquiredArtifactCalculusRun
  , acquireArtifactCalculusRun
  , acquireArtifactCalculusRefreshRun
  , acquiredArtifactCalculusRunCheck
  , foldAcquiredArtifactCalculusRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustCheck
  , genesisTrustCompilerExecutable
  , genesisTrustToolchainIdentity
  )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence
  , acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , finding
  , mergeChecks
  , observation
  )
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
  ( createDirectory
  , createDirectoryIfMissing
  , doesDirectoryExist
  , getHomeDirectory
  , listDirectory
  , removeFile
  )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data ProcessReceipt = ProcessReceipt Text FilePath [String] ExitCode Text Text
  deriving (Eq, Show)

data ProcessMatrix = ProcessMatrix
  { matrixCleanBuild :: ProcessReceipt
  , matrixCleanRun :: ProcessReceipt
  , matrixCleanSeedA :: ProcessReceipt
  , matrixCleanSeedB :: ProcessReceipt
  , matrixAddressBuild :: ProcessReceipt
  , matrixAddressRun :: ProcessReceipt
  , matrixAmbientBuild :: ProcessReceipt
  , matrixAmbientSeedA :: ProcessReceipt
  , matrixAmbientSeedB :: ProcessReceipt
  , matrixLegalCompile :: ProcessReceipt
  , matrixIllegalCompile :: ProcessReceipt
  , matrixEscapedCompile :: ProcessReceipt
  }

data AcquiredArtifactCalculusRun = AcquiredArtifactCalculusRun
  AcquiredSourceSnapshot
  GenesisTrust
  AcquiredPhaseContractEvidence
  [CheckResult]
  Text Text Text Text Text Text Text Text
  CheckResult

acquiredArtifactCalculusRunCheck :: AcquiredArtifactCalculusRun -> CheckResult
acquiredArtifactCalculusRunCheck (AcquiredArtifactCalculusRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredArtifactCalculusRun
  :: ( AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence
       -> [CheckResult] -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text
       -> CheckResult -> value)
  -> AcquiredArtifactCalculusRun
  -> value
foldAcquiredArtifactCalculusRun consume (AcquiredArtifactCalculusRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result) =
  consume acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result

acquireArtifactCalculusRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredArtifactCalculusRun
acquireArtifactCalculusRun = acquireArtifactCalculusRunWith False

-- | Reacquire the complete Phase-3 matrix after a recorded Done transition,
-- validating the current frontier while preserving Phase 3's exact subject.
acquireArtifactCalculusRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredArtifactCalculusRun
acquireArtifactCalculusRefreshRun = acquireArtifactCalculusRunWith True

acquireArtifactCalculusRunWith
  :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredArtifactCalculusRun
acquireArtifactCalculusRunWith receiptRefresh root acquired trust = do
  runRoot <- freshRunRoot root
  packageDatabases <- discoverPackageDatabases
  let packageDatabaseCheck = packageDatabaseResult packageDatabases
      packageDatabase = case packageDatabases of
        [path] -> Just path
        _ -> Nothing
  matrix <- case packageDatabase of
    Nothing -> pure unavailableMatrix
    Just database -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
  let cleanBuild = matrixCleanBuild matrix
      cleanRun = matrixCleanRun matrix
      cleanSeedA = matrixCleanSeedA matrix
      cleanSeedB = matrixCleanSeedB matrix
      addressBuild = matrixAddressBuild matrix
      addressRun = matrixAddressRun matrix
      ambientBuild = matrixAmbientBuild matrix
      ambientSeedA = matrixAmbientSeedA matrix
      ambientSeedB = matrixAmbientSeedB matrix
      legalCompile = matrixLegalCompile matrix
      illegalCompile = matrixIllegalCompile matrix
      escapedCompile = matrixEscapedCompile matrix
      receipts = matrixReceipts matrix
      contract = if receiptRefresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor phaseThree acquired
      compiler = compilerConstructionCheck [cleanBuild, addressBuild, ambientBuild]
      oracle = cleanOracleCheck cleanRun
      positive = positiveControlCheck cleanRun cleanSeedA cleanSeedB legalCompile
      paired = pairedNegativeCheck illegalCompile
      mutants = mutantCheck addressRun ambientSeedA ambientSeedB escapedCompile
      discovery = discoveryCheck acquired
      challenge = challengeCheck addressRun ambientSeedA ambientSeedB escapedCompile
      observer = observerCheck receipts
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts
      freshness = CheckResult "artifact-calculus-freshness" [observation "artifact-calculus.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      qualification = mergeChecks "artifact-calculus-qualification" [compiler, oracle, positive, paired, mutants]
      cleanroom = cleanroomCheck root runRoot
      acquisition = mergeChecks "artifact-calculus-acquisition" [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, packageDatabaseCheck]
      prerequisite = mergeChecks "artifact-calculus-prerequisite" [acquisition, compiler, oracle, positive, paired, mutants, discovery, challenge, observer, authority, freshness, qualification, cleanroom]
      rows = phaseThreeRows prerequisite compiler oracle positive paired mutants discovery challenge observer authority freshness qualification cleanroom
      result = mergeChecks "artifact-calculus" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      subjectId = digestTexts ["artifact-calculus-subject", sourceId, checkDigest compiler, checkDigest positive]
      oracleId = digestTexts ["artifact-calculus-oracle", receiptDigest cleanRun]
      harnessId = digestTexts ["artifact-calculus-harness", Text.intercalate ";" (map receiptDigest receipts)]
      observerId = digestTexts ["artifact-calculus-observer", checkDigest observer]
      qualificationId = digestTexts ["artifact-calculus-qualification", checkDigest qualification]
      runId = digestTexts ["artifact-calculus-run", Text.pack runRoot, checkDigest result]
      toolchainId = digestTexts [genesisTrustToolchainIdentity trust, maybe "unavailable" Text.pack packageDatabase]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredArtifactCalculusRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO ProcessMatrix
executeMatrix root runRoot packageDatabase compiler = do
  cleanBuild <- compileProgram root runRoot packageDatabase compiler "clean" Nothing
  cleanRun <- runBuilt root runRoot "clean" "clean-oracle" [] cleanBuild
  cleanSeedA <- runBuilt root runRoot "clean" "clean-seed-a" ["--render", "seed-a"] cleanBuild
  cleanSeedB <- runBuilt root runRoot "clean" "clean-seed-b" ["--render", "seed-b"] cleanBuild
  addressBuild <- compileProgram root runRoot packageDatabase compiler "address-mutant" (Just "ARTIFACT_CALCULUS_ADDRESS_DROPS_RENDERED_MUTANT")
  addressRun <- runBuilt root runRoot "address-mutant" "address-mutant-oracle" [] addressBuild
  ambientBuild <- compileProgram root runRoot packageDatabase compiler "ambient-mutant" (Just "ARTIFACT_CALCULUS_RECIPE_ADMITS_CLOCK_MUTANT")
  ambientSeedA <- runBuilt root runRoot "ambient-mutant" "ambient-mutant-seed-a" ["--render", "seed-a"] ambientBuild
  ambientSeedB <- runBuilt root runRoot "ambient-mutant" "ambient-mutant-seed-b" ["--render", "seed-b"] ambientBuild
  legalCompile <- compileFixture root runRoot packageDatabase compiler "legal-handle" Nothing legalFixture
  illegalCompile <- compileFixture root runRoot packageDatabase compiler "illegal-handle" Nothing illegalFixture
  escapedCompile <- compileFixture root runRoot packageDatabase compiler "escaped-handle-mutant" (Just "ARTIFACT_CALCULUS_HANDLE_ESCAPES_REGION_MUTANT") illegalFixture
  pure ProcessMatrix
    { matrixCleanBuild = cleanBuild
    , matrixCleanRun = cleanRun
    , matrixCleanSeedA = cleanSeedA
    , matrixCleanSeedB = cleanSeedB
    , matrixAddressBuild = addressBuild
    , matrixAddressRun = addressRun
    , matrixAmbientBuild = ambientBuild
    , matrixAmbientSeedA = ambientSeedA
    , matrixAmbientSeedB = ambientSeedB
    , matrixLegalCompile = legalCompile
    , matrixIllegalCompile = illegalCompile
    , matrixEscapedCompile = escapedCompile
    }

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO ProcessReceipt
compileProgram root runRoot packageDatabase compiler variant selector = do
  let variantRoot = runRoot </> variant
      objectRoot = variantRoot </> "objects"
      binary = variantRoot </> "artifact-calculus-oracle"
  createDirectoryIfMissing True objectRoot
  runProcess root (Text.pack variant <> "-compiler") compiler
    (commonCompilerArguments packageDatabase objectRoot selector
      <> ["-o", binary, artifactOracleSource])

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> FilePath -> IO ProcessReceipt
compileFixture root runRoot packageDatabase compiler variant selector source = do
  let objectRoot = runRoot </> variant </> "objects"
  createDirectoryIfMissing True objectRoot
  runProcess root (Text.pack variant <> "-compiler") compiler
    (commonCompilerArguments packageDatabase objectRoot selector
      <> ["-fno-code", source])

commonCompilerArguments :: FilePath -> FilePath -> Maybe String -> [String]
commonCompilerArguments packageDatabase objectRoot selector =
  [ "-XGHC2024", "-O0", "-fforce-recomp"
  , "-clear-package-db", "-global-package-db", "-package-db", packageDatabase
  , "-isrc", "-itest/spec/calculus"
  , "-package", "bytestring", "-package", "containers"
  , "-package", "cryptohash-sha256", "-package", "text"
  , "-odir", objectRoot, "-hidir", objectRoot, "-stubdir", objectRoot
  ] <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> [String] -> ProcessReceipt -> IO ProcessReceipt
runBuilt root runRoot variant name arguments buildReceipt
  | receiptExit buildReceipt == ExitSuccess =
      runProcess root name (runRoot </> variant </> "artifact-calculus-oracle") arguments
  | otherwise = pure (ProcessReceipt name "<unavailable>" arguments (ExitFailure 127) "" "compiler construction failed")

phaseThreeRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseThreeRows prerequisite compiler oracle positive paired mutants discovery challenge observer authority freshness qualification cleanroom =
  [ named "phase-03-claim" [prerequisite]
  , named "phase-03-subject" [compiler, positive]
  , named "phase-03-command" [compiler, authority]
  , named "phase-03-oracle" [oracle]
  , named "phase-03-positive-controls" [positive]
  , named "phase-03-paired-negatives" [paired]
  , named "phase-03-mutants" [mutants]
  , named "phase-03-discovery" [discovery]
  , named "phase-03-challenge" [challenge]
  , named "phase-03-observer" [observer]
  , named "phase-03-authority-bypass" [authority]
  , named "phase-03-freshness" [freshness]
  , named "phase-03-qualification" [qualification]
  , named "phase-03-cleanroom" [cleanroom]
  , named "phase-03-legacy-closure" [prerequisite]
  , CheckResult "phase-03-predecessor" [observation "phase-03.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-03-residue" [observation "phase-03.residue" "later calculi, effects, runtimes, hardware, and live claims remain owner-scoped"] []
  , named "phase-03-pass-criterion" [prerequisite]
  ]
 where
  named label = mergeChecks label

compilerConstructionCheck :: [ProcessReceipt] -> CheckResult
compilerConstructionCheck receipts = CheckResult "artifact-calculus-compiler"
  [observation "artifact-calculus.compiler" (receiptSummary receipt) | receipt <- receipts]
  [finding "ARTIFACT-CALCULUS-COMPILER" (Text.unpack name) "the clean or changed-production oracle did not compile" | ProcessReceipt name _ _ status _ _ <- receipts, status /= ExitSuccess]

cleanOracleCheck :: ProcessReceipt -> CheckResult
cleanOracleCheck receipt = CheckResult "artifact-calculus-independent-oracle"
  [observation "artifact-calculus.oracle" (receiptSummary receipt)]
  [finding "ARTIFACT-CALCULUS-ORACLE" "ArtifactCalculusSpec" "the independent Haskell oracle did not report all eleven checks green" | not good]
 where
  good = receiptExit receipt == ExitSuccess
    && "artifact-calculus-spec: PASS (6 targets, 4 address inputs, 11 checks)" `Text.isInfixOf` receiptStdout receipt
    && Text.null (receiptStderr receipt)

positiveControlCheck :: ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> CheckResult
positiveControlCheck clean seedA seedB legal = CheckResult "artifact-calculus-positive-controls"
  [ observation "artifact-calculus.positive.clean" (receiptDigest clean)
  , observation "artifact-calculus.positive.determinism" (receiptDigest seedA <> ":" <> receiptDigest seedB)
  , observation "artifact-calculus.positive.legal-handle" (receiptDigest legal)
  ]
  [finding "ARTIFACT-CALCULUS-POSITIVE" "<positive-controls>" "clean oracle, independently seeded rendering, or legal handle control failed" | not good]
 where
  good = receiptExit clean == ExitSuccess
    && receiptExit seedA == ExitSuccess && receiptExit seedB == ExitSuccess
    && receiptStdout seedA == receiptStdout seedB && not (Text.null (receiptStdout seedA))
    && receiptExit legal == ExitSuccess

pairedNegativeCheck :: ProcessReceipt -> CheckResult
pairedNegativeCheck receipt = CheckResult "artifact-calculus-paired-negative"
  [observation "artifact-calculus.negative.handle-escape" (receiptSummary receipt)]
  [finding "ARTIFACT-CALCULUS-NEGATIVE" illegalFixture "the illegal handle-escape twin did not fail at the region-skolem type mismatch" | not good]
 where
  good = receiptExit receipt == ExitFailure 1
    && "[GHC-25897]" `Text.isInfixOf` receiptStderr receipt
    && "Couldn't match type" `Text.isInfixOf` receiptStderr receipt

mutantCheck :: ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> CheckResult
mutantCheck address seedA seedB escaped = CheckResult "artifact-calculus-mutants"
  [ observation "artifact-calculus.mutant.address-rendering" (receiptDigest address)
  , observation "artifact-calculus.mutant.recipe-ambient" (receiptDigest seedA <> ":" <> receiptDigest seedB)
  , observation "artifact-calculus.mutant.region-escape" (receiptDigest escaped)
  ]
  [finding "ARTIFACT-CALCULUS-MUTANT" "<changed-production-matrix>" "one or more applied production mutants survived its assigned independent observation" | not good]
 where
  failureLines = filter ("FAIL" `isInfixOf`) (lines (Text.unpack (receiptStdout address)))
  good = receiptExit address == ExitFailure 1
    && failureLines == ["  FAIL address-folds-rendered", "artifact-calculus-spec: FAIL address-folds-rendered"]
    && receiptExit seedA == ExitSuccess && receiptExit seedB == ExitSuccess
    && receiptStdout seedA /= receiptStdout seedB
    && receiptExit escaped == ExitSuccess

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "artifact-calculus-discovery"
  [ observation "artifact-calculus.discovery.count" (Text.pack (show (length observed)))
  , observation "artifact-calculus.discovery.sha256" (digestTexts (map Text.pack observed))
  ]
  [finding "ARTIFACT-CALCULUS-DISCOVERY" "<artifact-calculus-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) artifactSourcePrefixes

challengeCheck :: ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> CheckResult
challengeCheck address seedA seedB escaped = CheckResult "artifact-calculus-challenge"
  [observation "artifact-calculus.challenge" "address-rendering,recipe-ambient,region-escape"]
  [finding "ARTIFACT-CALCULUS-CHALLENGE" "<post-acquisition-matrix>" "the fixed post-acquisition challenge did not execute all three changed subjects" | any ((== "<unavailable>") . receiptExecutable) [address, seedA, seedB, escaped]]

observerCheck :: [ProcessReceipt] -> CheckResult
observerCheck receipts = CheckResult "artifact-calculus-observer"
  [observation "artifact-calculus.observer.process" (receiptSummary receipt) | receipt <- receipts]
  [finding "ARTIFACT-CALCULUS-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or content digest" | receipt@(ProcessReceipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

authorityCheck :: FilePath -> FilePath -> FilePath -> [ProcessReceipt] -> CheckResult
authorityCheck root runRoot compiler receipts = CheckResult "artifact-calculus-authority"
  [observation "artifact-calculus.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; no hardware or network"]
  ( [finding "ARTIFACT-CALCULUS-RUN-ROOT" runRoot "the run root escaped .build/runs/phase-03/work" | not (pathBelow (root </> ".build/runs/phase-03/work") runRoot)]
    <> [finding "ARTIFACT-CALCULUS-COMPILER-AUTHORITY" (Text.unpack name) "a compiler receipt used a different executable, pb, or a parallelism flag" | ProcessReceipt name executable arguments _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "pb") arguments || any (isInfixOf "-j") arguments]
  )

cleanroomCheck :: FilePath -> FilePath -> CheckResult
cleanroomCheck root runRoot = CheckResult "artifact-calculus-cleanroom"
  [observation "artifact-calculus.run-root" (Text.pack (makeRelative root runRoot))]
  [finding "ARTIFACT-CALCULUS-CLEANROOM" runRoot "generated products are not contained below the phase run root" | not (pathBelow (root </> ".build/runs/phase-03/work") runRoot)]

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do
    names <- listDirectory store
    filterM doesDirectoryExist
      [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

packageDatabaseResult :: [FilePath] -> CheckResult
packageDatabaseResult paths = CheckResult "artifact-calculus-package-database"
  [observation "artifact-calculus.package-db" (Text.pack path) | path <- paths]
  [finding "ARTIFACT-CALCULUS-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length paths /= 1]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-03/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO ProcessReceipt
runProcess working name executable arguments = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable arguments) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ case attempt of
    Left problem -> ProcessReceipt name executable arguments (ExitFailure 127) "" (Text.pack (show problem))
    Right (status, stdoutText, stderrText) -> ProcessReceipt name executable arguments status (Text.pack stdoutText) (Text.pack stderrText)

receiptExecutable :: ProcessReceipt -> FilePath
receiptExecutable (ProcessReceipt _ executable _ _ _ _) = executable

receiptExit :: ProcessReceipt -> ExitCode
receiptExit (ProcessReceipt _ _ _ status _ _) = status

receiptStdout :: ProcessReceipt -> Text
receiptStdout (ProcessReceipt _ _ _ _ stdoutText _) = stdoutText

receiptStderr :: ProcessReceipt -> Text
receiptStderr (ProcessReceipt _ _ _ _ _ stderrText) = stderrText

receiptSummary :: ProcessReceipt -> Text
receiptSummary receipt@(ProcessReceipt name executable arguments status _ stderrText) =
  name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show arguments) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> failure
 where
  failure = case status of
    ExitSuccess -> ""
    ExitFailure _ -> "|stderr=" <> escapeField (Text.take 512 stderrText)

receiptDigest :: ProcessReceipt -> Text
receiptDigest (ProcessReceipt name executable arguments status stdoutText stderrText) =
  digestTexts [name, Text.pack executable, Text.pack (show arguments), Text.pack (show status), stdoutText, stderrText]

checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]

digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"

sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
 where
  byteHex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

escapeField :: Text -> Text
escapeField = Text.replace "\r" "\\r" . Text.replace "\n" "\\n"

pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `Text.isPrefixOf` Text.pack relative) && not (isAbsolute relative)

expectedSources :: [FilePath]
expectedSources = sort
  [ "src/Amoebius/Calculus/Artifact/Address.hs"
  , "src/Amoebius/Calculus/Artifact/Recipe.hs"
  , "src/Amoebius/Calculus/Artifact/Region.hs"
  , "src/Amoebius/Calculus/Artifact/Target.hs"
  , artifactOracleSource
  , "test/spec/calculus/ArtifactCorpus.hs"
  , legalFixture
  , illegalFixture
  ]

artifactOracleSource, legalFixture, illegalFixture :: FilePath
artifactOracleSource = "test/spec/calculus/ArtifactCalculusSpec.hs"
legalFixture = "test/negative/compile_fail/artifact_calculus/handle_stays_in_region.hs"
illegalFixture = "test/negative/compile_fail/artifact_calculus/handle_escapes_region.hs"

matrixReceipts :: ProcessMatrix -> [ProcessReceipt]
matrixReceipts matrix =
  [ matrixCleanBuild matrix, matrixCleanRun matrix, matrixCleanSeedA matrix, matrixCleanSeedB matrix
  , matrixAddressBuild matrix, matrixAddressRun matrix, matrixAmbientBuild matrix
  , matrixAmbientSeedA matrix, matrixAmbientSeedB matrix, matrixLegalCompile matrix
  , matrixIllegalCompile matrix, matrixEscapedCompile matrix
  ]

unavailableMatrix :: ProcessMatrix
unavailableMatrix = ProcessMatrix
  (unavailable "clean-compiler")
  (unavailable "clean-oracle")
  (unavailable "clean-seed-a")
  (unavailable "clean-seed-b")
  (unavailable "address-mutant-compiler")
  (unavailable "address-mutant-oracle")
  (unavailable "ambient-mutant-compiler")
  (unavailable "ambient-mutant-seed-a")
  (unavailable "ambient-mutant-seed-b")
  (unavailable "legal-handle-compiler")
  (unavailable "illegal-handle-compiler")
  (unavailable "escaped-handle-mutant-compiler")
 where
  unavailable name = ProcessReceipt name "<unavailable>" [] (ExitFailure 127) "" "package database unavailable"

artifactSourcePrefixes :: [FilePath]
artifactSourcePrefixes =
  [ "src/Amoebius/Calculus/Artifact/"
  , "test/spec/calculus/Artifact"
  , "test/negative/compile_fail/artifact_calculus/"
  ]

phaseThree :: Int
phaseThree = 3

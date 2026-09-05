{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-8 authority. Every compiler child is
-- synchronous; the runner uses neither @pb@ nor network/hardware effects.
module Amoebius.Validation.ScopeIndexRun.Internal
  ( AcquiredScopeIndexRun
  , acquireScopeIndexRun
  , acquireScopeIndexRefreshRun
  , acquiredScopeIndexRunCheck
  , foldAcquiredScopeIndexRun
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
data Pair = Pair Text Receipt Receipt deriving (Eq, Show)
data Matrix = Matrix
  { cleanBuild, cleanRun, mutantBuild, mutantRun :: Receipt
  , compilePairs :: [Pair]
  }

data AcquiredScopeIndexRun = AcquiredScopeIndexRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredScopeIndexRunCheck :: AcquiredScopeIndexRun -> CheckResult
acquiredScopeIndexRunCheck (AcquiredScopeIndexRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredScopeIndexRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredScopeIndexRun -> value
foldAcquiredScopeIndexRun consume (AcquiredScopeIndexRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireScopeIndexRun, acquireScopeIndexRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredScopeIndexRun
acquireScopeIndexRun = acquire False
acquireScopeIndexRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredScopeIndexRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "scope-index-package-database"
        [observation "scope-index.package-db" (Text.pack path) | path <- databases]
        [finding "SCOPE-INDEX-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  sourceDiscipline <- sourceDisciplineCheck root
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 8 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts sourceDiscipline
      observer = observerCheck receipts
      freshness = CheckResult "scope-index-freshness" [observation "scope-index.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "scope-index-cleanroom" [observation "scope-index.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "SCOPE-INDEX-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-08/work") runRoot)]
      qualification = mergeChecks "scope-index-qualification" [compiler, oracle, positive, negatives, mutants, sourceDiscipline]
      prerequisite = mergeChecks "scope-index-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom, sourceDiscipline]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "scope-index" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "scope-index-subject" [checkDigest compiler, checkDigest sourceDiscipline]
      oracleId = ids "scope-index-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "scope-index-harness" (map receiptDigest receipts)
      observerId = ids "scope-index-observer" [checkDigest observer]
      qualificationId = ids "scope-index-qualification" [checkDigest qualification]
      acquiredRunId = ids "scope-index-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "scope-index-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredScopeIndexRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- compileProgram root runRoot database compiler "clean" Nothing
  cr <- runBuilt root runRoot "clean" "clean-oracle" cb
  mb <- compileProgram root runRoot database compiler "mutant" (Just "SCOPE_INDEX_DROP_OWNER_EQUALITY_MUTANT")
  mr <- runBuilt root runRoot "mutant" "mutant-oracle" mb
  pairs <- mapM (compilePair root runRoot database compiler) pairSpecifications
  pure (Matrix cb cr mb mr pairs)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "scope-index-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-package", "QuickCheck", "-o", binary, oracleSource])

compilePair :: FilePath -> FilePath -> FilePath -> FilePath -> PairSpecification -> IO Pair
compilePair root runRoot database compiler (PairSpecification name legal illegal _ _) = do
  legalReceipt <- compileFixture root runRoot database compiler (name <> "-legal") legal
  illegalReceipt <- compileFixture root runRoot database compiler (name <> "-illegal") illegal
  pure (Pair name legalReceipt illegalReceipt)

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> Text -> FilePath -> IO Receipt
compileFixture root runRoot database compiler name source = do
  let objects = runRoot </> Text.unpack name </> "objects"
  createDirectoryIfMissing True objects
  runProcess root (name <> "-compiler") compiler (common database objects Nothing <> ["-fno-code", source])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  , "-clear-package-db", "-global-package-db", "-package-db", database, "-isrc", "-itest/spec/ui"
  , "-package", "text", "-package", "containers", "-odir", objects, "-hidir", objects, "-stubdir", objects]
  <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot variant name build
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "scope-index-oracle") []
  | otherwise = pure (unavailable name)

data PairSpecification = PairSpecification Text FilePath FilePath Text Text

pairSpecifications :: [PairSpecification]
pairSpecifications =
  [ pair "raw-resource-id" "raw_resource_id" "Illegal term-level use" "ResourceId"
  , pair "scope-retag" "scope_retag" "Couldn't match type" "RequestScope scope1"
  , pair "declassify" "declassify" "Variable not in scope" "declassify"
  , pair "handle-escape" "handle_escape" "Couldn't match expected type" "SomeScopedHandle"
  , pair "forge-request-scope" "forge_request_scope" "Illegal term-level use" "RequestScope"
  ]
 where
  pair name stem reason locus = PairSpecification name (base stem <> "_legal.hs") (base stem <> "_illegal.hs") reason locus
  base stem = "test/negative/compile_fail/scope_index/" <> stem

compilerCheck :: Matrix -> CheckResult
compilerCheck matrix = CheckResult "scope-index-compiler" (map (observation "scope-index.compiler" . receiptSummary) required)
  [finding "SCOPE-INDEX-COMPILER" (Text.unpack name) "a clean, mutant, or legal control did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = [cleanBuild matrix, mutantBuild matrix] <> [legal | Pair _ legal _ <- compilePairs matrix]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "scope-index-independent-oracle" [observation "scope-index.oracle" (receiptSummary receipt)]
  [finding "SCOPE-INDEX-ORACLE" oracleSource "the authored Haskell oracle did not report its exact clean inventory" | receiptExit receipt /= ExitSuccess || not (passLine `Text.isInfixOf` receiptStdout receipt)]
 where passLine = "PASS (6 owner rows, 2 swap errors, 4 flow rows, 4 diagnostics, 9 coverage classes)"

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "scope-index-positive-controls" [observation "scope-index.positive" "clean-oracle,five-legal-compile-controls"]
  [finding "SCOPE-INDEX-POSITIVE" "<clean-controls>" "the clean oracle or a legal compile twin failed" | not good]
 where good = receiptExit (cleanRun matrix) == ExitSuccess && all ((== ExitSuccess) . receiptExit) [legal | Pair _ legal _ <- compilePairs matrix]

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "scope-index-paired-negatives"
  [observation ("scope-index.negative." <> name) (receiptSummary illegal) | Pair name _ illegal <- compilePairs matrix]
  [finding "SCOPE-INDEX-NEGATIVE" (Text.unpack name) "an illegal twin did not fail at its pinned reason and locus" | (PairSpecification expectedName _ _ reason locus, Pair name _ illegal) <- zip pairSpecifications (compilePairs matrix), name /= expectedName || not (failedWith illegal reason && failedWith illegal locus)]

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "scope-index-mutants" [observation "scope-index.mutant.drop-owner-equality" (receiptSummary (mutantRun matrix))]
  [finding "SCOPE-INDEX-MUTANT" "src/Amoebius/Scope/Index.hs" "drop_owner_equality did not make both owner swaps accepted" | not killed]
 where
  killed = receiptExit (mutantBuild matrix) == ExitSuccess && receiptExit (mutantRun matrix) == ExitFailure 1
    && "expected [\"OwnerMismatch\",\"TenantMismatch\"], got [\"accepted\",\"accepted\"]" `Text.isInfixOf` receiptStdout (mutantRun matrix)

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  indexSource <- Text.pack <$> readFile (root </> "src/Amoebius/Scope/Index.hs")
  flowSource <- Text.pack <$> readFile (root </> "src/Amoebius/Scope/Flow.hs")
  let combined = indexSource <> flowSource
      privateTypes = ["Tenant", "Subject", "Membership", "Owner", "Grant", "RequestScope", "Scoped", "ScopedHandle", "SomeScopedHandle", "ResourceId", "FlowLabel", "CanFlowTo"]
      escaped name = (name <> " (..)") `Text.isInfixOf` combined
      forbidden = ["undefined", "unsafePerformIO", "System.IO", "Network.Socket"]
  pure (CheckResult "scope-index-source-discipline"
    [observation "scope-index.closed-constructor-count" (Text.pack (show (length privateTypes))), observation "scope-index.effect-boundary" "pure-only"]
    ([finding "SCOPE-INDEX-CONSTRUCTOR-ESCAPE" (Text.unpack name) "a constructor-private type was exported openly" | name <- privateTypes, escaped name]
      <> [finding "SCOPE-INDEX-SOURCE-DISCIPLINE" "src/Amoebius/Scope/" ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` combined]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "scope-index-discovery" [observation "scope-index.discovery.count" (Text.pack (show (length observed)))]
  [finding "SCOPE-INDEX-DISCOVERY" "<scope-index-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts sourceDiscipline = CheckResult "scope-index-authority"
  [observation "scope-index.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; pure source boundary"]
  ([finding "SCOPE-INDEX-RUN-ROOT" runRoot "run root escaped .build/runs/phase-08/work" | not (pathBelow (root </> ".build/runs/phase-08/work") runRoot)]
    <> [finding "SCOPE-INDEX-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings sourceDiscipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "scope-index-observer" (map (observation "scope-index.observer.process" . receiptSummary) receipts)
  [finding "SCOPE-INDEX-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-08-claim" [pre], named "phase-08-subject" [compiler, positive], named "phase-08-command" [compiler, authority]
  ,named "phase-08-oracle" [oracle], named "phase-08-positive-controls" [positive], named "phase-08-paired-negatives" [negatives]
  ,named "phase-08-mutants" [mutants], named "phase-08-discovery" [discovery], named "phase-08-challenge" [mutants]
  ,named "phase-08-observer" [observer], named "phase-08-authority-bypass" [authority], named "phase-08-freshness" [freshness]
  ,named "phase-08-qualification" [qualification], named "phase-08-cleanroom" [cleanroom], named "phase-08-legacy-closure" [pre]
  ,CheckResult "phase-08-predecessor" [observation "phase-08.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-08-residue" [observation "phase-08.residue" "persisted-value re-entry, resource indexing, composition, effects, runtimes, and hardware remain later-owned"] []
  ,named "phase-08-pass-criterion" [pre]]
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
  let parent = root </> ".build/runs/phase-08/work"
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
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") (u "mutant-compiler") (u "mutant-oracle") [Pair name (u (name <> "-legal-compiler")) (u (name <> "-illegal-compiler")) | PairSpecification name _ _ _ _ <- pairSpecifications] where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix = [cleanBuild matrix, cleanRun matrix, mutantBuild matrix, mutantRun matrix] <> concat [[legal, illegal] | Pair _ legal illegal <- compilePairs matrix]

sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/Amoebius/Scope/", "test/spec/ui/ScopeSpec.hs", "test/negative/compile_fail/scope_index/"]
expectedSources :: [FilePath]
expectedSources = sort (["src/Amoebius/Scope/Index.hs", "src/Amoebius/Scope/Flow.hs", oracleSource] <> concat [[legal, illegal] | PairSpecification _ legal illegal _ _ <- pairSpecifications])
oracleSource :: FilePath
oracleSource = "test/spec/ui/ScopeSpec.hs"

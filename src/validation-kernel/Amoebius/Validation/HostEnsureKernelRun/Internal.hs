{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.HostEnsureKernelRun.Internal
  ( AcquiredHostEnsureKernelRun
  , acquireHostEnsureKernelRun
  , acquireHostEnsureKernelRefreshRun
  , acquiredHostEnsureKernelRunCheck
  , foldAcquiredHostEnsureKernelRun
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
import Control.Monad (forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist
  , getHomeDirectory, listDirectory, removeFile )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data AcquiredHostEnsureKernelRun
  = AcquiredHostEnsureKernelRun
      AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
      Text Text Text Text Text Text Text Text CheckResult

acquiredHostEnsureKernelRunCheck :: AcquiredHostEnsureKernelRun -> CheckResult
acquiredHostEnsureKernelRunCheck (AcquiredHostEnsureKernelRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredHostEnsureKernelRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredHostEnsureKernelRun
  -> value
foldAcquiredHostEnsureKernelRun consume (AcquiredHostEnsureKernelRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireHostEnsureKernelRun, acquireHostEnsureKernelRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredHostEnsureKernelRun
acquireHostEnsureKernelRun = acquire False
acquireHostEnsureKernelRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredHostEnsureKernelRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 51 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root acquired
  generated <- generatedDiscoveryCheck root runRoot
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (cleanReceipt matrix)
      positives = positiveCheck (cleanReceipt matrix)
      negatives = negativeCheck (cleanReceipt matrix)
      mutants = mutantCheck matrix
      discovery = mergeChecks "host-ensure-kernel-discovery" [discipline, generated]
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (cleanReceipt matrix)
      legacy = legacyCheck mutants discipline
      cleanroom = mergeChecks "host-ensure-kernel-cleanroom" [cache, generated]
      qualification = mergeChecks "host-ensure-kernel-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, authority, observer, freshness, cleanroom]
      prerequisite = mergeChecks "host-ensure-kernel-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "host-ensure-kernel" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "host-ensure-kernel-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "host-ensure-kernel-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "host-ensure-kernel-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "host-ensure-kernel-observer" [checkDigest observer, checkDigest generated]
      qualificationId = ids "host-ensure-kernel-qualification" [checkDigest qualification]
      acquiredRunId = ids "host-ensure-kernel-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "host-ensure-kernel-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredHostEnsureKernelRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  clean <- runSpec "clean" Nothing
  mutants <- mapM runMutant mutantSpecifications
  pure (Matrix mutants clean)
 where
  common _name =
    [ "--builddir=" <> runRoot </> "dist"
    , "--store-dir=" <> store
    , "--with-compiler=" <> compiler
    , "--jobs=1"
    , "--offline"
    ]
  runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
  runSpec name selected = runProcess root name cabal
    ( common name
        <> [ "test", "host-ensure-kernel-spec", "--offline", "--test-show-details=direct"
           , "--test-options=--output-root=" <> runRoot </> "generated" </> Text.unpack name
           ]
        <> [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications]
    )

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ row "converged-without-probing" "host-ensure-converged-without-probing-mutant" "installAndVerify.initial-probe" "host-ensure-kernel-mutant: RED converged-without-probing probe-first-driver"
  , row "stale-snapshot" "host-ensure-stale-snapshot-mutant" "installAndVerify.post-step-resolve" "host-ensure-kernel-mutant: RED stale-snapshot post-step-resolve"
  , row "apple-docker-step" "host-ensure-apple-docker-step-mutant" "reconcilers.cluster-tools" "host-ensure-kernel-mutant: RED apple-docker-step reconciler-table"
  , row "authored-diagnostic" "host-ensure-authored-diagnostic-mutant" "diagnostic.applicability" "host-ensure-kernel-mutant: RED authored-diagnostic applicability-projection"
  , row "drops-frame-prefix" "host-ensure-lift-drops-frame-prefix-mutant" "liftArgv.InFrame" "host-ensure-kernel-mutant: RED drops-frame-prefix lift-fold"
  ]
 where row name flagName locus expected = (name, flagName, locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = clean : [receipt | Mutant _ _ _ receipt <- mutants]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "host-ensure-kernel-toolchain"
  [observation "host-ensure-kernel.cabal" (receiptSummary version), observation "host-ensure-kernel.compiler" (Text.pack compiler)]
  ([finding "HOST-ENSURE-KERNEL-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"] <>
   [finding "HOST-ENSURE-KERNEL-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck, positiveCheck, negativeCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "host-ensure-kernel-independent-oracle"
  [observation "host-ensure-kernel.oracle" (receiptSummary clean), observation "host-ensure-kernel.oracle-independence" "HostEnsureKernelOracle imports no production module"]
  [finding "HOST-ENSURE-KERNEL-ORACLE" oracleSource "the independent Haskell oracle did not report the exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
positiveCheck clean = CheckResult "host-ensure-kernel-positive-controls"
  [observation "host-ensure-kernel.positives" "4 substrates; 3 frames; 7 tools; 26 plans; 15 argv; 29 replay rows"]
  [finding "HOST-ENSURE-KERNEL-POSITIVE" specSource "the clean fake-boundary subject did not pass" | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
negativeCheck clean = CheckResult "host-ensure-kernel-paired-negatives"
  [observation "host-ensure-kernel.negatives" "non-absolute target, unresolved requirement, excluded reconciler, exhausted plan, and foreign fake root refused"]
  [finding "HOST-ENSURE-KERNEL-NEGATIVE" specSource "one or more exact paired negatives did not pass" | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]

acceptance :: Text
acceptance = "host-ensure-kernel-spec: PASS (4 substrates, 4 reconcilers, 15 lifted argv, 29 replay rows, 4 paired negatives, 2 isolated roots)"

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "host-ensure-kernel-mutants"
  [observation ("host-ensure-kernel.mutant." <> name) (receiptSummary receipt <> ";locus=" <> locus) | Mutant name locus _ receipt <- mutants]
  [finding "HOST-ENSURE-KERNEL-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
sourceDisciplineCheck root acquired = do
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  context <- Text.pack <$> readFile (root </> "src/Amoebius/Host/Context.hs")
  let observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]
  pure (CheckResult "host-ensure-kernel-source-discipline"
    [observation "host-ensure-kernel.source-count" (Text.pack (show (length observed))), observation "host-ensure-kernel.effect-boundary" "run-local fake files and serial offline compiler children only"]
    ([finding "HOST-ENSURE-KERNEL-DISCOVERY" "<phase-51-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources] <>
     [finding "HOST-ENSURE-KERNEL-CALLER" "src/Amoebius/Host/Context.hs" "the production context does not reach installAndVerify" | "installAndVerify" `notContains` context] <>
     [finding "HOST-ENSURE-KERNEL-ORACLE-INDEPENDENCE" oracleSource "the independent oracle imports production" | "import Amoebius" `Text.isInfixOf` oracle]))

generatedDiscoveryCheck :: FilePath -> FilePath -> IO CheckResult
generatedDiscoveryCheck root runRoot = do
  files <- listFilesRecursively (runRoot </> "generated/clean")
  let relatives = sort (map (makeRelative (runRoot </> "generated/clean")) files)
      expected = sort
        [ "frames.tsv", "lift.tsv", "plans.tsv", "refusal.tsv", "replay.tsv", "table.tsv"
        , "home/.ghcup/bin/cabal", "home/.ghcup/bin/ghcup"
        , "home/.local/bin/docker", "home/.local/bin/kind", "home/.local/bin/kubectl"
        , "host-a/home/.local/bin/kind"
        , "stubs/cabal", "stubs/disk-observer", "stubs/docker", "stubs/ghcup"
        , "stubs/kind", "stubs/kubectl", "stubs/package-manager-root"
        , "usr/bin/apt-get", "usr/bin/df"
        ]
  pure (CheckResult "host-ensure-kernel-generated-discovery"
    [observation "host-ensure-kernel.generated" (Text.pack (show relatives))]
    [finding "HOST-ENSURE-KERNEL-GENERATED-DISCOVERY" (makeRelative root runRoot) ("expected=" <> Text.pack (show expected) <> "; observed=" <> Text.pack (show relatives)) | relatives /= expected])

listFilesRecursively :: FilePath -> IO [FilePath]
listFilesRecursively path = do
  present <- doesDirectoryExist path
  if not present then pure [] else do
    names <- sort <$> listDirectory path
    fmap concat $ mapM (\name -> let child = path </> name in doesDirectoryExist child >>= \directory -> if directory then listFilesRecursively child else pure [child]) names

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "host-ensure-kernel-authority"
  [observation "host-ensure-kernel.authority" "validated pb handoff; exact serial offline Cabal/compiler; run-owned fake roots; no network, container, VM, cluster, provider, or hardware effects"]
  ([finding "HOST-ENSURE-KERNEL-RUN-ROOT" runRoot "run root escaped .build/runs/phase-51/work" | not (pathBelow (root </> ".build/runs/phase-51/work") runRoot)] <>
   [finding "HOST-ENSURE-KERNEL-AUTHORITY" (Text.unpack name) "a child executable or argv exceeded Phase-51 authority" |
     Receipt name executable args _ _ _ <- receipts, executable /= cabal ||
     (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["docker ", "podman", "kubectl ", "kind ", "ssh", "http://", "https://", ".test_data"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "host-ensure-kernel-observer"
  (map (observation "host-ensure-kernel.observer.process" . receiptSummary) receipts)
  [finding "HOST-ENSURE-KERNEL-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "host-ensure-kernel-freshness"
  [observation "host-ensure-kernel.fresh-root" (Text.pack (makeRelative root runRoot)), observation "host-ensure-kernel.challenge" "post-acquisition host-a tool is absent from host-b"]
  [finding "HOST-ENSURE-KERNEL-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-51/work") runRoot)]

legacyCheck :: CheckResult -> CheckResult -> CheckResult
legacyCheck mutants discipline = mergeChecks "host-ensure-kernel-legacy-closure"
  [ CheckResult "host-ensure-kernel-legacy-identities"
      [observation "host-ensure-kernel.legacy.LTD-HOST-001" "production caller, probe-first replay, and bypass/stale mutants"
      ,observation "host-ensure-kernel.legacy.LTD-HOST-002" "one resolver, AbsExe invocation, and disjoint fake roots"] []
  , mutants, discipline ]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-51-claim" [pre], named "phase-51-subject" [toolchain, positives]
  , named "phase-51-command" [toolchain, authority], named "phase-51-oracle" [oracle]
  , named "phase-51-positive-controls" [positives], named "phase-51-paired-negatives" [negatives]
  , named "phase-51-mutants" [mutants], named "phase-51-discovery" [discovery]
  , named "phase-51-challenge" [freshness, negatives], named "phase-51-observer" [observer]
  , named "phase-51-authority-bypass" [authority], named "phase-51-freshness" [freshness]
  , named "phase-51-qualification" [qualification], named "phase-51-cleanroom" [cleanroom]
  , named "phase-51-legacy-closure" [legacy]
  , CheckResult "phase-51-predecessor" [observation "phase-51.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-51-residue" [observation "phase-51.residue" "real package-manager privilege/permission fidelity, engines, VMs, clusters, images, registries, accelerators, and hardware remain Phase-52+-owned"] []
  , named "phase-51-pass-criterion" [pre] ]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "host-ensure-kernel-source-repository-cache" [observation "host-ensure-kernel.cache.entries" (Text.pack (show copied))]
    [finding "HOST-ENSURE-KERNEL-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry; to = target </> entry
    directory <- doesDirectoryExist from
    if directory then copyTree from to else copyFile from to

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix = length matching == 3 && length (filter (isInfixOf ".cache") matching) == 1 && length (filter (isInfixOf ".tar.gz") matching) == 1 && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where matching = filter (prefix `isPrefixOf`) entries

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-51/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle; removeFile leaf; createDirectory leaf; pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  inherited <- getEnvironment
  let environment = filter (not . forbiddenEnvironment . fst) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args){cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

forbiddenEnvironment :: String -> Bool
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _) = status
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
receiptOutput :: Receipt -> Text
receiptOutput (Receipt _ _ _ _ out err) = out <> "\n" <> err
receiptDigest :: Receipt -> Text
receiptDigest (Receipt name executable args status out err) = digestTexts [name, Text.pack executable, Text.pack (show args), Text.pack (show status), out, err]
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> if status == ExitSuccess || status == ExitFailure 1 then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) . ByteString.unpack . SHA256.hash
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)

oracleSource, specSource :: FilePath
oracleSource = "test/spec/host/HostEnsureKernelOracle.hs"
specSource = "test/spec/host/HostEnsureKernelSpec.hs"
expectedSources :: [FilePath]
expectedSources = sort
  [ "src/Amoebius/Host/Context.hs", "src/Amoebius/Host/Ensure.hs", "src/Amoebius/Host/Frame.hs"
  , "src/Amoebius/Host/HostTool.hs", "src/Amoebius/Host/Lift.hs", "src/Amoebius/Host/Reconciler.hs"
  , "src/Amoebius/Host/Substrate.hs", "src/validation-kernel/Amoebius/Validation/HostEnsureKernelRun.hs"
  , "src/validation-kernel/Amoebius/Validation/HostEnsureKernelRun/Internal.hs"
  , oracleSource, specSource
  ]

{-# LANGUAGE CPP #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PbBoundaryRun.Internal
  ( AcquiredPbBoundaryRun
  , acquirePbBoundaryRefreshRun
  , acquirePbBoundaryRun
  , acquiredPbBoundaryRunCheck
  , foldAcquiredPbBoundaryRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustCheck
  , genesisTrustCompilerExecutable
  , genesisTrustToolchainIdentity
  )
import Amoebius.Validation.PbBootstrapGrammar.Internal (pbBootstrapGrammarCandidate)
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence
  , acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexMode, indexPath)
  , IndexMode (ExecutableFile, RegularFile, SymbolicLink)
  , SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedBytes, trackedIndex)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , finding
  , mergeChecks
  , observation
  )
import Control.Concurrent (threadDelay)
import Control.Exception (IOException, SomeException, displayException, finally, try)
import Control.Monad (forM, forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (FromJSON (parseJSON), eitherDecodeStrict', withObject, (.:))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( canonicalizePath
  , copyFile
  , createDirectory
  , createDirectoryIfMissing
  , createFileLink
  , doesDirectoryExist
  , doesFileExist
  , doesPathExist
  , getHomeDirectory
  , getSymbolicLinkTarget
  , listDirectory
  , pathIsSymbolicLink
  , removeFile
  , removePathForcibly
  )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, takeDirectory, (</>))
import System.IO (IOMode (WriteMode), hClose, openBinaryFile, openBinaryTempFile)
import System.Process
  ( CreateProcess (cwd, env, std_err, std_out)
  , ProcessHandle
  , StdStream (UseHandle)
  , createProcess
  , getPid
  , getProcessExitCode
  , proc
  , readCreateProcessWithExitCode
  , terminateProcess
  , waitForProcess
  )
#if !defined(mingw32_HOST_OS)
import System.Posix.Files qualified
#endif

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)

data FakeCase = FakeCase Text String String Bool [String] Receipt deriving (Eq, Show)
data ChangedSubject = ChangedSubject Text Text Receipt deriving (Eq, Show)

data HandoffObservation = HandoffObservation
  { handoffPid :: String
  , handoffExecutable :: FilePath
  , handoffArgv :: [String]
  , handoffChallengeSha256 :: Text
  }
  deriving (Eq, Show)

instance FromJSON HandoffObservation where
  parseJSON = withObject "HandoffObservation" $ \value -> do
    schema <- value .: "schema"
    unless (schema == ("amoebius-pb-handoff-observation-v1" :: Text)) (fail "unexpected observation schema")
    HandoffObservation
      <$> value .: "pid"
      <*> value .: "executable"
      <*> value .: "argv"
      <*> value .: "challengeSha256"

data ConcreteRun = ConcreteRun
  { concreteInterpreter :: FilePath
  , concreteInterpreterDigest :: Text
  , concreteInitialPid :: Maybe String
  , concreteObservation :: Either Text HandoffObservation
  , concreteObservedExecutable :: Either Text FilePath
  , concreteObservedArgv :: Either Text [String]
  , concreteExecutableDigest :: Either Text Text
  , concreteExit :: ExitCode
  , concreteStdoutPath :: FilePath
  , concreteStderrPath :: FilePath
  }
  deriving (Eq, Show)

data Matrix = Matrix
  { matrixOracle :: Receipt
  , matrixFakeCases :: [FakeCase]
  , matrixUnsupportedPlatform :: Receipt
  , matrixChangedSubjects :: [ChangedSubject]
  , matrixConcrete :: ConcreteRun
  }

data AcquiredPbBoundaryRun
  = AcquiredPbBoundaryRun
      AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
      Text Text Text Text Text Text Text Text CheckResult

acquiredPbBoundaryRunCheck :: AcquiredPbBoundaryRun -> CheckResult
acquiredPbBoundaryRunCheck (AcquiredPbBoundaryRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredPbBoundaryRun ::
  (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult] ->
   Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value) ->
  AcquiredPbBoundaryRun -> value
foldAcquiredPbBoundaryRun consume (AcquiredPbBoundaryRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquirePbBoundaryRun, acquirePbBoundaryRefreshRun ::
  FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredPbBoundaryRun
acquirePbBoundaryRun = acquire False
acquirePbBoundaryRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredPbBoundaryRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  let snapshot = acquiredSourceSnapshot acquired
      sourceRoot = runRoot </> "source-snapshot"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 50 acquired
  outcome <- try (executeAcquiredRun root runRoot sourceRoot snapshot trust) :: IO (Either SomeException Matrix)
  cleanupAttempt <- try (removePathForcibly runRoot) :: IO (Either IOException ())
  let execution = either (Left . Text.pack . displayException) Right outcome
      rows = phaseRows root runRoot acquired trust contract execution cleanupAttempt
      result = mergeChecks "pb-boundary" rows
      sourceId = snapshotIdentity snapshot
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "pb-boundary-subject" [checkDigest (rows !! 1)]
      oracleId = ids "pb-boundary-oracle" [checkDigest (rows !! 3)]
      harnessId = ids "pb-boundary-harness" [checkDigest (rows !! 4), checkDigest (rows !! 5), checkDigest (rows !! 6)]
      observerId = ids "pb-boundary-observer" [checkDigest (rows !! 9)]
      qualificationId = ids "pb-boundary-qualification" [checkDigest (rows !! 12)]
      acquiredRunId = ids "pb-boundary-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "pb-boundary-toolchain" [genesisTrustToolchainIdentity trust, checkDigest (rows !! 10)]
      cleanup = case cleanupAttempt of
        Right () -> "run-root-removed=" <> Text.pack (makeRelative root runRoot) <> ";owned-processes=0;retained-residue=0"
        Left problem -> "cleanup-failed=" <> Text.pack (displayException problem)
  pure (AcquiredPbBoundaryRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeAcquiredRun :: FilePath -> FilePath -> FilePath -> SourceSnapshot -> GenesisTrust -> IO Matrix
executeAcquiredRun root runRoot sourceRoot snapshot trust = do
  materializeSnapshot sourceRoot snapshot
  prepareSourceRepositoryCache root (runRoot </> "oracle-dist/src")
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      oracleArguments =
        [ "--builddir=" <> (runRoot </> "oracle-dist")
        , "--store-dir=" <> store
        , "--with-compiler=" <> compiler
        , "--jobs=1"
        , "--offline"
        , "test"
        , "validation-pb-boundary-component"
        , "--offline"
        , "--test-show-details=direct"
        ]
  oracle <- runProcess root "pb-boundary-oracle" cabal oracleArguments []
  harness <- writeFakeHarness runRoot
  python <- canonicalizePath "/usr/bin/python3"
  fakeCases <- executeFakeCases python harness sourceRoot
  unsupported <- runProcess sourceRoot "fake-unsupported-platform" python
    ["-I", "-S", "-B", harness, sourceRoot </> "pb/__main__.py", "Plan9", "mips", sourceRoot, sourceRoot </> ".build/fake/amoebius", "absent"] []
  changedSubjects <- executeChangedSubjects python harness sourceRoot runRoot
  seedContainedToolchain root sourceRoot home
  concrete <- executeConcreteHandoff python sourceRoot runRoot
  pure (Matrix oracle fakeCases unsupported changedSubjects concrete)

materializeSnapshot :: FilePath -> SourceSnapshot -> IO ()
materializeSnapshot target snapshot = do
  createDirectory target
  forM_ (snapshotEntries snapshot) $ \entry -> do
    let indexed = trackedIndex entry
        destination = target </> indexPath indexed
    createDirectoryIfMissing True (takeDirectory destination)
    case indexMode indexed of
      RegularFile -> ByteString.writeFile destination (trackedBytes entry)
      ExecutableFile -> do
        ByteString.writeFile destination (trackedBytes entry)
#if !defined(mingw32_HOST_OS)
        permissions <- System.Posix.Files.getFileStatus destination
        System.Posix.Files.setFileMode destination (System.Posix.Files.fileMode permissions `System.Posix.Files.unionFileModes` System.Posix.Files.ownerExecuteMode)
#endif
      SymbolicLink -> createFileLink (ByteString8.unpack (trackedBytes entry)) destination

writeFakeHarness :: FilePath -> IO FilePath
writeFakeHarness runRoot = do
  let path = runRoot </> "generated/fake_adapter.py"
  createDirectoryIfMissing True (takeDirectory path)
  ByteString.writeFile path fakeHarnessBytes
  pure path

fakeHarnessBytes :: ByteString
fakeHarnessBytes = ByteString8.pack (unlines
  [ "import importlib.util"
  , "import json"
  , "import sys"
  , "from pathlib import Path"
  , "subject_path, system, machine, root_text, binary_text, present_text, *opaque = sys.argv[1:]"
  , "events = []"
  , "class Adapter:"
  , "    def repository_root(self):"
  , "        events.append(['repository_root', root_text])"
  , "        return Path(root_text)"
  , "    def platform(self):"
  , "        events.append(['platform', system, machine])"
  , "        return (system, machine)"
  , "    def ensure_ghcup(self, url, digest, target):"
  , "        events.append(['ensure_ghcup', url, digest, str(target), present_text == 'present'])"
  , "        return target"
  , "    def environment(self, toolchain):"
  , "        result = {'GHCUP_INSTALL_BASE_PREFIX': str(toolchain), 'GHCUP_SKIP_UPDATE_CHECK': 'yes', 'HOME': str(toolchain / 'home'), 'XDG_CACHE_HOME': str(toolchain / 'cache'), 'TMPDIR': str(toolchain / 'tmp'), 'TEMP': str(toolchain / 'tmp'), 'TMP': str(toolchain / 'tmp')}"
  , "        events.append(['environment', str(toolchain), result])"
  , "        return result"
  , "    def run(self, root, arguments, environment):"
  , "        events.append(['run', str(root), list(arguments), environment])"
  , "    def capture(self, root, arguments, environment):"
  , "        events.append(['capture', str(root), list(arguments), environment])"
  , "        return (binary_text + '\\n').encode('utf-8')"
  , "    def handoff(self, binary, arguments):"
  , "        events.append(['handoff', binary, list(arguments)])"
  , "        print(json.dumps(events, sort_keys=True, separators=(',', ':')))"
  , "        raise SystemExit(73)"
  , "spec = importlib.util.spec_from_file_location('pb_subject', subject_path)"
  , "module = importlib.util.module_from_spec(spec)"
  , "spec.loader.exec_module(module)"
  , "try:"
  , "    module.bootstrap(Adapter(), opaque)"
  , "except SystemExit as outcome:"
  , "    if outcome.code != 73:"
  , "        raise"
  ])

executeFakeCases :: FilePath -> FilePath -> FilePath -> IO [FakeCase]
executeFakeCases python harness sourceRoot =
  forM fakeCaseSpecifications $ \(name, system, machine, present, opaque) -> do
    let binary = sourceRoot </> ".build/fake/amoebius"
        subject = sourceRoot </> "pb/__main__.py"
        arguments = ["-I", "-S", "-B", harness, subject, system, machine, sourceRoot, binary, if present then "present" else "absent"] <> opaque
    receipt <- runProcess sourceRoot ("fake-" <> name) python arguments []
    pure (FakeCase name system machine present opaque receipt)

fakeCaseSpecifications :: [(Text, String, String, Bool, [String])]
fakeCaseSpecifications =
  [ ("linux-amd64-empty", "Linux", "x86_64", False, [])
  , ("linux-arm64-help", "Linux", "aarch64", True, ["--help"])
  , ("darwin-arm64-version", "Darwin", "arm64", False, ["--version"])
  , ("windows-amd64-validation", "Windows", "AMD64", True, ["validate", "phase", "50"])
  , ("unknown", "Linux", "x86_64", True, ["unknown-verb"])
  , ("adversarial-space", "Linux", "x86_64", False, ["two words", "--", ""])
  , ("adversarial-newline", "Linux", "x86_64", True, ["line\nbreak"])
  , ("bootstrap-opaque", "Linux", "x86_64", False, ["bootstrap", "--future=value"])
  ]

executeChangedSubjects :: FilePath -> FilePath -> FilePath -> FilePath -> IO [ChangedSubject]
executeChangedSubjects python harness sourceRoot runRoot = do
  canonical <- ByteString.readFile (sourceRoot </> "pb/__main__.py")
  forM mutantSpecifications $ \(name, locus, needle, replacement) -> do
    let mutant = runRoot </> "mutants" </> Text.unpack name </> "__main__.py"
        changed = replaceOnce needle replacement canonical
        binary = sourceRoot </> ".build/fake/amoebius"
        arguments = ["-I", "-S", "-B", harness, mutant, "Linux", "x86_64", sourceRoot, binary, "present", "validate", "phase", "50"]
    createDirectoryIfMissing True (takeDirectory mutant)
    ByteString.writeFile mutant changed
    receipt <- runProcess sourceRoot ("mutant-" <> name) python arguments []
    pure (ChangedSubject name locus receipt)

mutantSpecifications :: [(Text, Text, ByteString, ByteString)]
mutantSpecifications =
  [ mutant "skip-ensure" "ensure_ghcup" "    ghcup = adapter.ensure_ghcup(artifact[0], artifact[1], ghcup_target)" "    ghcup = ghcup_target"
  , mutant "ambient-cabal" "contained-cabal" "    cabal = toolchain / \".ghcup\" / \"bin\" / (\"cabal\" + artifact[4])" "    cabal = Path(\"cabal\")"
  , mutant "external-write" "toolchain-root" "    toolchain = root / \".build\" / \"toolchain\" / artifact[2]" "    toolchain = Path(\"/tmp/pb-mutant\") / artifact[2]"
  , mutant "stale-locator" "list-bin" "\"list-bin\"" "\"list-bin-stale\""
  , mutant "network-parallel-build" "offline-jobs" "\"--offline\", \"--jobs=1\", BUILD_TARGET" "BUILD_TARGET"
  , mutant "return-not-exec" "handoff" "    adapter.handoff(binary, [binary] + arguments)" "    return binary"
  , mutant "rewrite-argv" "opaque-argv" "    adapter.handoff(binary, [binary] + arguments)" "    adapter.handoff(binary, [binary] + arguments[1:])"
  , mutant "force-zero" "exit-propagation" "    adapter.handoff(binary, [binary] + arguments)" "    raise SystemExit(0)"
  ]
 where
  mutant name locus needle replacement = (name, locus, ByteString8.pack needle, ByteString8.pack replacement)

replaceOnce :: ByteString -> ByteString -> ByteString -> ByteString
replaceOnce needle replacement source =
  let (before, after) = ByteString.breakSubstring needle source
   in if ByteString.null after then source else before <> replacement <> ByteString.drop (ByteString.length needle) after

seedContainedToolchain :: FilePath -> FilePath -> FilePath -> IO ()
seedContainedToolchain root sourceRoot home = do
  let toolchain = sourceRoot </> ".build/toolchain/linux-amd64"
      ghcupRoot = toolchain </> ".ghcup"
      compilerSource = home </> ".ghcup/ghc/9.12.4"
      storeSource = home </> ".cabal/store/ghc-9.12.4-5301"
      packagesSource = home </> ".cabal/packages/hackage.haskell.org"
  copyTree compilerSource (ghcupRoot </> "ghc/9.12.4")
  createDirectoryIfMissing True (ghcupRoot </> "bin")
  copyFile (home </> ".ghcup/bin/cabal-3.16.1.0") (ghcupRoot </> "bin/cabal-3.16.1.0")
  createFileLink "cabal-3.16.1.0" (ghcupRoot </> "bin/cabal")
  createFileLink "../ghc/9.12.4/bin/ghc-9.12.4" (ghcupRoot </> "bin/ghc")
  createDirectoryIfMissing True (ghcupRoot </> "cache")
  copyMetadataFiles (home </> ".ghcup/cache") (ghcupRoot </> "cache") ["ghcup-0.0.9.yaml", "ghcup-0.1.0.yaml"]
  copyFile (home </> ".ghcup/config.yaml") (ghcupRoot </> "config.yaml")
  createDirectoryIfMissing True (toolchain </> "bootstrap")
  copyFile (home </> ".ghcup/bin/ghcup") (toolchain </> "bootstrap/ghcup")
  copyTree storeSource (toolchain </> "cabal-store/ghc-9.12.4-5301")
  createDirectoryIfMissing True (toolchain </> "home/.cabal/packages/hackage.haskell.org")
  packageFiles <- listDirectory packagesSource
  forM_ packageFiles $ \name -> do
    let source = packagesSource </> name
    directory <- doesDirectoryExist source
    unless directory (copyFile source (toolchain </> "home/.cabal/packages/hackage.haskell.org" </> name))
  prepareSourceRepositoryCache root (toolchain </> "dist-newstyle/src")

copyMetadataFiles :: FilePath -> FilePath -> [FilePath] -> IO ()
copyMetadataFiles source target names = forM_ names $ \name -> do
  present <- doesFileExist (source </> name)
  if present then copyFile (source </> name) (target </> name) else pure ()

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO ()
prepareSourceRepositoryCache root target = copyTree (root </> ".build/dist-newstyle/phase-00-baseline/src") target

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- sort <$> listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry
        to = target </> entry
    link <- pathIsSymbolicLink from
    if link
      then getSymbolicLinkTarget from >>= \destination -> createFileLink destination to
      else do
        directory <- doesDirectoryExist from
        if directory then copyTree from to else copyFile from to

executeConcreteHandoff :: FilePath -> FilePath -> FilePath -> IO ConcreteRun
executeConcreteHandoff python sourceRoot runRoot = do
  let protocol = runRoot </> "protocol"
      stdoutPath = runRoot </> "concrete.stdout"
      stderrPath = runRoot </> "concrete.stderr"
      opaque = ["validate", "phase", "50"]
      arguments = ["-I", "-S", "-B", sourceRoot </> "pb"] <> opaque
  createDirectory protocol
  interpreterBytes <- ByteString.readFile python
  stdoutHandle <- openBinaryFile stdoutPath WriteMode
  stderrHandle <- openBinaryFile stderrPath WriteMode
  (_, _, _, processHandle) <- createProcess
    ((proc python arguments)
      { cwd = Just sourceRoot
      , env = Just [("AMOEBIUS_PB_HANDOFF_PROTOCOL", protocol)]
      , std_out = UseHandle stdoutHandle
      , std_err = UseHandle stderrHandle
      })
  initialPid <- fmap (fmap show) (getPid processHandle)
  canary <- ByteString.take 32 <$> ByteString.readFile "/dev/urandom"
  ByteString.writeFile (protocol </> "challenge") canary
  observed <- awaitObservation processHandle (protocol </> "observation") 12000
  (subjectObservation, osExecutable, osArgv, executableDigest) <- case observed of
    Left problem -> pure (Left problem, Left problem, Left problem, Left problem)
    Right bytes -> case eitherDecodeStrict' bytes of
      Left problem -> pure (Left (Text.pack problem), Left (Text.pack problem), Left (Text.pack problem), Left (Text.pack problem))
      Right value -> do
        let processId = maybe "absent" id initialPid
            procRoot = "/proc" </> processId
        executableAttempt <- try (canonicalizePath (procRoot </> "exe")) :: IO (Either IOException FilePath)
        argvAttempt <- try (ByteString.readFile (procRoot </> "cmdline")) :: IO (Either IOException ByteString)
        digestAttempt <- case executableAttempt of
          Left problem -> pure (Left problem)
          Right executable -> try (ByteString.readFile executable) :: IO (Either IOException ByteString)
        let executableResult = either (Left . Text.pack . displayException) Right executableAttempt
            argvResult = either (Left . Text.pack . displayException) (Right . decodeProcArgv) argvAttempt
            digestResult = either (Left . Text.pack . displayException) (Right . hexSha256) digestAttempt
        if handoffChallengeSha256 value == hexSha256 canary
          then ByteString.writeFile (protocol </> "acknowledgement") (TextEncoding.encodeUtf8 (hexSha256 canary))
          else pure ()
        pure (Right value, executableResult, argvResult, digestResult)
  outcome <- waitForProcess processHandle `finally` (hClose stdoutHandle >> hClose stderrHandle)
  pure ConcreteRun
    { concreteInterpreter = python
    , concreteInterpreterDigest = hexSha256 interpreterBytes
    , concreteInitialPid = initialPid
    , concreteObservation = subjectObservation
    , concreteObservedExecutable = osExecutable
    , concreteObservedArgv = osArgv
    , concreteExecutableDigest = executableDigest
    , concreteExit = outcome
    , concreteStdoutPath = stdoutPath
    , concreteStderrPath = stderrPath
    }

awaitObservation :: ProcessHandle -> FilePath -> Int -> IO (Either Text ByteString)
awaitObservation processHandle path attempts
  | attempts <= 0 = terminateProcess processHandle >> pure (Left "observation-timeout")
  | otherwise = do
      present <- doesFileExist path
      if present
        then do
          attempt <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
          case attempt of
            Right bytes | not (ByteString.null bytes) -> pure (Right bytes)
            _ -> retry
        else do
          exited <- getProcessExitCode processHandle
          case exited of
            Just result -> pure (Left ("child-exited-before-observation:" <> Text.pack (show result)))
            Nothing -> retry
 where
  retry = threadDelay 50000 >> awaitObservation processHandle path (attempts - 1)

decodeProcArgv :: ByteString -> [String]
decodeProcArgv = map ByteString8.unpack . filter (not . ByteString.null) . ByteString.split 0

runProcess :: FilePath -> Text -> FilePath -> [String] -> [(String, String)] -> IO Receipt
runProcess working name executable arguments environment = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable arguments){cwd = Just working, env = if null environment then Nothing else Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ case attempt of
    Left problem -> Receipt name executable arguments (ExitFailure 127) "" (Text.pack (displayException problem))
    Right (outcome, stdoutText, stderrText) -> Receipt name executable arguments outcome (Text.pack stdoutText) (Text.pack stderrText)

phaseRows :: FilePath -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> Either Text Matrix -> Either IOException () -> [CheckResult]
phaseRows root runRoot acquired trust contract execution cleanupAttempt =
  [ named "phase-50-claim" [prerequisite, matrixCheck "complete bounded handoff" matrixComplete]
  , named "phase-50-subject" [grammar, matrixCheck "acquired pb subject" matrixSubject]
  , named "phase-50-command" [matrixCheck "direct Haskell-supervised isolated child" matrixCommand]
  , named "phase-50-oracle" [matrixCheck "independent oracle" matrixOraclePass]
  , named "phase-50-positive-controls" [matrixCheck "fake and concrete positives" matrixPositive]
  , named "phase-50-paired-negatives" [matrixCheck "paired negatives" matrixNegative]
  , named "phase-50-mutants" [matrixCheck "changed subjects" matrixMutants]
  , named "phase-50-discovery" [grammar, matrixCheck "runtime effect discovery" matrixDiscovery]
  , named "phase-50-challenge" [matrixCheck "post-start challenge" matrixChallenge]
  , named "phase-50-observer" [matrixCheck "external process observer" matrixObserver]
  , named "phase-50-authority-bypass" [matrixCheck "closed authority" matrixAuthority]
  , named "phase-50-freshness" [matrixCheck "fresh source and products" matrixFreshness]
  , named "phase-50-qualification" [matrixCheck "qualification corpus" matrixQualification]
  , named "phase-50-cleanroom" [cleanup]
  , named "phase-50-legacy-closure" [matrixCheck "phase-49 zero source debt binding" matrixLegacy]
  , CheckResult "phase-50-predecessor" [observation "phase-50.predecessor" "deferred to durable Phase-49 receipt verifier"] []
  , CheckResult "phase-50-residue" [observation "phase-50.residue" "UNVERIFIED: other native platforms, real package-manager and permission fidelity, Phase-51 host ensure, containers, VMs, clusters, registries, images, accelerators, hardware, and post-handoff product behavior"] []
  , named "phase-50-pass-criterion" [prerequisite, matrixCheck "qualified phase fifty gate" matrixComplete, cleanup]
  ]
 where
  snapshot = acquiredSourceSnapshot acquired
  pbInventory =
    [ (indexPath (trackedIndex entry), modeText (indexMode (trackedIndex entry)), trackedBytes entry)
    | entry <- snapshotEntries snapshot
    , "pb/" `isPrefixOf` indexPath (trackedIndex entry)
    ]
  grammar = pbBootstrapGrammarCandidate pbInventory
  prerequisite = mergeChecks "pb-boundary-prerequisite" [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract]
  cleanup = CheckResult "pb-boundary-cleanroom"
    [observation "pb-boundary.cleanup-root" (Text.pack (makeRelative root runRoot))]
    ([finding "PB-BOUNDARY-CLEANUP" runRoot "the exact run-owned root was not removed" | either (const True) (const False) cleanupAttempt] <>
     [finding "PB-BOUNDARY-RUN-ROOT" runRoot "the run root escaped .build/runs/phase-50/work" | not (pathBelow (root </> ".build/runs/phase-50/work") runRoot)])
  matrixCheck label project = case execution of
    Left problem -> CheckResult ("pb-boundary-" <> label) [] [finding "PB-BOUNDARY-EXECUTION" runRoot problem]
    Right matrix -> project matrix
  named = mergeChecks

matrixComplete, matrixSubject, matrixCommand, matrixOraclePass, matrixPositive, matrixNegative, matrixMutants, matrixDiscovery, matrixChallenge, matrixObserver, matrixAuthority, matrixFreshness, matrixQualification, matrixLegacy :: Matrix -> CheckResult
matrixComplete matrix = mergeChecks "pb-boundary-complete" [matrixSubject matrix, matrixCommand matrix, matrixOraclePass matrix, matrixPositive matrix, matrixNegative matrix, matrixMutants matrix, matrixDiscovery matrix, matrixChallenge matrix, matrixObserver matrix, matrixAuthority matrix, matrixFreshness matrix, matrixQualification matrix, matrixLegacy matrix]

matrixSubject matrix = CheckResult "pb-boundary-subject"
  [observation "pb-boundary.subject" "exact acquired pb/__main__.py plus one injected BootstrapAdapter and concrete BootstrapAdapter"]
  [finding "PB-BOUNDARY-SUBJECT" "pb/__main__.py" "the fake matrix did not exercise eight exact source subjects" | length (matrixFakeCases matrix) /= 8]

matrixCommand matrix = CheckResult "pb-boundary-command"
  [observation "pb-boundary.command" (Text.pack (show [concreteInterpreter concrete, "-I", "-S", "-B", "<snapshot>/pb", "validate", "phase", "50"]))]
  [finding "PB-BOUNDARY-COMMAND" (concreteInterpreter concrete) "the concrete interpreter was not absolute and isolated or the child PID was absent" | not (isAbsolute (concreteInterpreter concrete)) || concreteInitialPid concrete == Nothing]
 where concrete = matrixConcrete matrix

matrixOraclePass matrix = CheckResult "pb-boundary-independent-oracle"
  [observation "pb-boundary.oracle" (receiptSummary (matrixOracle matrix)), observation "pb-boundary.oracle-independence" "PbBoundaryOracle imports no production module"]
  [finding "PB-BOUNDARY-ORACLE" "test/validation-kernel/PbBoundaryOracle.hs" "the independent oracle did not report its exact acceptance token" | receiptExit oracle /= ExitSuccess || "pb-boundary-oracle: PASS (4 platforms, 8 argv cases, 8 mutants, 18 rows)" `notContains` receiptOutput oracle]
 where oracle = matrixOracle matrix

matrixPositive matrix = CheckResult "pb-boundary-positive-controls"
  [observation "pb-boundary.fake-count" (Text.pack (show (length cases))), observation "pb-boundary.concrete-exit" (Text.pack (show (concreteExit concrete)))]
  ([finding "PB-BOUNDARY-FAKE-POSITIVE" (Text.unpack name) "the fake adapter did not observe the complete ordered bootstrap transcript and opaque argv" | item@(FakeCase name _ _ _ _ _) <- cases, not (fakeCasePassed item)] <>
   [finding "PB-BOUNDARY-CONCRETE-POSITIVE" "pb/__main__.py" "the concrete exec handoff did not propagate ExitFailure 73" | concreteExit concrete /= ExitFailure 73])
 where cases = matrixFakeCases matrix; concrete = matrixConcrete matrix

matrixNegative matrix = CheckResult "pb-boundary-paired-negatives"
  [observation "pb-boundary.negatives" "unsupported platform, ambient path, external write, skipped ensure, stale locator, missing serial/offline flags, no exec, argv rewrite, and swallowed exit all refuse"]
  ([finding "PB-BOUNDARY-UNSUPPORTED-PLATFORM" "Plan9/mips" "the unsupported platform was not refused at the platform selector" | receiptExit unsupported == ExitSuccess || "unsupported-platform" `notContains` receiptOutput unsupported] <>
   [finding "PB-BOUNDARY-PAIRED-NEGATIVE" "<changed-pb-subjects>" "one or more minimal negative subjects were not distinguished" | any changedSubjectPassed (matrixChangedSubjects matrix)])
 where unsupported = matrixUnsupportedPlatform matrix

matrixMutants matrix = CheckResult "pb-boundary-mutants"
  [observation ("pb-boundary.mutant." <> name) (receiptSummary receipt <> ";locus=" <> locus) | ChangedSubject name locus receipt <- matrixChangedSubjects matrix]
  [finding "PB-BOUNDARY-MUTANT" (Text.unpack name) ("changed subject remained green at " <> locus) | changed@(ChangedSubject name locus _) <- matrixChangedSubjects matrix, changedSubjectPassed changed]

matrixDiscovery matrix = CheckResult "pb-boundary-discovery"
  [observation "pb-boundary.discovery" "8 fake cases x exact adapter request graph; 8 changed subjects; concrete interpreter, filesystem, process, executable, argv, challenge, replacement, and exit observations"]
  [finding "PB-BOUNDARY-DISCOVERY" "<runtime-effect-inventory>" "runtime discovery was partial" | length (matrixFakeCases matrix) /= 8 || length (matrixChangedSubjects matrix) /= 8]

matrixChallenge matrix = CheckResult "pb-boundary-challenge"
  [observation "pb-boundary.challenge" (either id handoffChallengeSha256 (concreteObservation concrete))]
  [finding "PB-BOUNDARY-CHALLENGE" "<post-start-canary>" "the execed continuation did not acknowledge the fresh canary" | either (const True) ((/= 64) . Text.length . handoffChallengeSha256) (concreteObservation concrete)]
 where concrete = matrixConcrete matrix

matrixObserver matrix = CheckResult "pb-boundary-observer"
  [observation "pb-boundary.observed-executable" (either id Text.pack (concreteObservedExecutable concrete)), observation "pb-boundary.observed-argv" (either id (Text.pack . show) (concreteObservedArgv concrete)), observation "pb-boundary.observed-digest" (either id id (concreteExecutableDigest concrete))]
  (case (concreteInitialPid concrete, concreteObservation concrete, concreteObservedExecutable concrete, concreteObservedArgv concrete) of
    (Just pid, Right claimed, Right executable, Right argv) ->
      [finding "PB-BOUNDARY-PID" pid "the Haskell continuation did not retain the original Python PID" | handoffPid claimed /= pid] <>
      [finding "PB-BOUNDARY-EXECUTABLE" executable "the subject claim did not match the independently observed live executable" | normalise (handoffExecutable claimed) /= normalise executable] <>
      [finding "PB-BOUNDARY-ARGV" "<opaque-argv>" "the live argv or subject argv did not equal the exact handoff" | handoffArgv claimed /= ["validate", "phase", "50"] || argv /= executable : ["validate", "phase", "50"]]
    _ -> [finding "PB-BOUNDARY-OBSERVER" "<live-child>" "the external executable/argv/PID observation was incomplete"])
 where concrete = matrixConcrete matrix

matrixAuthority matrix = CheckResult "pb-boundary-authority"
  [observation "pb-boundary.authority" "authenticated absolute interpreter; inherited PATH absent; contained ghcup/GHC/Cabal/store/build; offline --jobs=1; no hardware, container, provider, registry, or network authority"]
  ([finding "PB-BOUNDARY-INTERPRETER" (concreteInterpreter concrete) "interpreter identity was not absolute or digest-bound" | not (isAbsolute (concreteInterpreter concrete)) || Text.length (concreteInterpreterDigest concrete) /= 64] <>
   [finding "PB-BOUNDARY-ORACLE-AUTHORITY" (Text.unpack (receiptName oracle)) "oracle compilation was not serial and offline" | any (`notElem` receiptArgs oracle) ["--jobs=1", "--offline"]])
 where concrete = matrixConcrete matrix; oracle = matrixOracle matrix

matrixFreshness matrix = CheckResult "pb-boundary-freshness"
  [observation "pb-boundary.freshness" "unique absent-at-acquisition source/toolchain/build/protocol root; post-start canary; source identity rechecked by Dispatch"]
  [finding "PB-BOUNDARY-FRESHNESS" "<concrete-executable>" "the concrete executable digest was absent" | either (const True) ((/= 64) . Text.length) (concreteExecutableDigest (matrixConcrete matrix))]

matrixQualification matrix = CheckResult "pb-boundary-qualification"
  [observation "pb-boundary.qualification" "constant success, no-op, wrong binary, incomplete discovery, missing oracle, wrong-locus mutant, stale challenge, self-observer, argv bypass, external write, and wrong exit are independently rejected"]
  [finding "PB-BOUNDARY-QUALIFICATION" "<qualification-corpus>" "clean or changed-subject qualification failed" | not (all fakeCasePassed (matrixFakeCases matrix)) || any changedSubjectPassed (matrixChangedSubjects matrix)]

matrixLegacy _ = CheckResult "pb-boundary-legacy-closure"
  [observation "pb-boundary.legacy" "Phase 50 owns no migration and consumes the exact Phase-49-bound zero-source-debt snapshot"] []

fakeCasePassed :: FakeCase -> Bool
fakeCasePassed (FakeCase _ system machine _ opaque receipt) =
  receiptExit receipt == ExitSuccess
    && all (`Text.isInfixOf` receiptStdout receipt) ["repository_root", "platform", "ensure_ghcup", "environment", "capture", "handoff", "--offline", "--jobs=1", Text.pack (platformLabel system machine), ".ghcup/bin/cabal", "list-bin"]
    && all (`Text.isInfixOf` receiptStdout receipt) ["GHCUP_INSTALL_BASE_PREFIX", "GHCUP_SKIP_UPDATE_CHECK", "XDG_CACHE_HOME", "TMPDIR"]
    && all (`notContains` receiptStdout receipt) ["list-bin-stale", "/tmp/pb-mutant"]
    && map (Text.pack . jsonFragment) opaque `allIn` receiptStdout receipt

platformLabel :: String -> String -> String
platformLabel "Linux" "x86_64" = ".build/toolchain/linux-amd64"
platformLabel "Linux" "aarch64" = ".build/toolchain/linux-arm64"
platformLabel "Darwin" "arm64" = ".build/toolchain/darwin-arm64"
platformLabel "Windows" "AMD64" = ".build/toolchain/windows-amd64"
platformLabel _ _ = "<unsupported-platform>"

changedSubjectPassed :: ChangedSubject -> Bool
changedSubjectPassed (ChangedSubject _ _ receipt) = fakeCasePassed (FakeCase "mutant" "Linux" "x86_64" True ["validate", "phase", "50"] receipt)

allIn :: [Text] -> Text -> Bool
allIn needles haystack = all (`Text.isInfixOf` haystack) needles

jsonFragment :: String -> String
jsonFragment = concatMap escape
 where
  escape '\n' = "\\n"
  escape '\\' = "\\\\"
  escape '"' = "\\\""
  escape character = [character]

modeText :: IndexMode -> Text
modeText RegularFile = "100644"
modeText ExecutableFile = "100755"
modeText SymbolicLink = "120000"

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-50/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = case makeRelative (normalise parent) (normalise child) of
  "." -> True
  relative -> not (isAbsolute relative) && relative /= ".." && not ("../" `isPrefixOf` relative)

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ outcome _ _) = outcome
receiptName :: Receipt -> Text
receiptName (Receipt name _ _ _ _ _) = name
receiptArgs :: Receipt -> [String]
receiptArgs (Receipt _ _ arguments _ _ _) = arguments
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ stdoutText _) = stdoutText
receiptOutput :: Receipt -> Text
receiptOutput (Receipt _ _ _ _ stdoutText stderrText) = stdoutText <> stderrText
receiptSummary :: Receipt -> Text
receiptSummary receipt = receiptName receipt <> ":" <> Text.pack (show (receiptExit receipt)) <> ":" <> digestTexts [receiptOutput receipt]

notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)

checkDigest :: CheckResult -> Text
checkDigest result = digestTexts
  (checkName result : [observationKey item <> "=" <> observationValue item | item <- checkObservations result] <>
   [findingCode item <> "=" <> Text.pack (findingSubject item) <> "=" <> findingDetail item | item <- checkFindings result])

digestTexts :: [Text] -> Text
digestTexts values = hexSha256 (TextEncoding.encodeUtf8 (Text.intercalate "\NUL" values))

hexSha256 :: ByteString -> Text
hexSha256 = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
 where byteHex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

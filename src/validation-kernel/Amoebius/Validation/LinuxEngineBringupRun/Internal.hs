{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.LinuxEngineBringupRun.Internal
  ( AcquiredLinuxEngineBringupRun
  , acquireLinuxEngineBringupRun
  , acquireLinuxEngineBringupRefreshRun
  , acquiredLinuxEngineBringupRunCheck
  , foldAcquiredLinuxEngineBringupRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types (CheckResult (..), Finding, finding, mergeChecks, observation)
import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, displayException, finally, try)
import Control.Monad (forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.List (isPrefixOf, sort)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.Read qualified as Text (decimal)
import System.Directory
  ( copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist
  , doesFileExist, getHomeDirectory, listDirectory, removeFile )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Posix.Process (getProcessID)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data LiveObservation = LiveObservation
  { liveInstance :: Text
  , livePreflight :: Text
  , liveHandoff :: Text
  , liveFirstLedger :: Text
  , liveSecondLedger :: Text
  , liveFirstSurfaces :: Text
  , liveSecondSurfaces :: Text
  , liveFirstVersion :: Text
  , liveSecondVersion :: Text
  , liveFirstTrace :: Text
  , liveSecondTrace :: Text
  , liveExternal :: Text
  , liveProviderBefore :: Text
  , liveProviderAfter :: Text
  , liveReceipts :: [Receipt]
  }

data AcquiredLinuxEngineBringupRun
  = AcquiredLinuxEngineBringupRun
      AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
      Text Text Text Text Text Text Text Text CheckResult

acquiredLinuxEngineBringupRunCheck :: AcquiredLinuxEngineBringupRun -> CheckResult
acquiredLinuxEngineBringupRunCheck (AcquiredLinuxEngineBringupRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredLinuxEngineBringupRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredLinuxEngineBringupRun
  -> value
foldAcquiredLinuxEngineBringupRun consume (AcquiredLinuxEngineBringupRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanupEvidence result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanupEvidence result

acquireLinuxEngineBringupRun, acquireLinuxEngineBringupRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredLinuxEngineBringupRun
acquireLinuxEngineBringupRun = acquire False
acquireLinuxEngineBringupRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredLinuxEngineBringupRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 52 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  matrix <- executeQualificationMatrix root runRoot cabal compiler store
  liveResult <- try (executeLive root runRoot) :: IO (Either SomeException LiveObservation)
  discipline <- sourceDisciplineCheck acquired
  let toolchain = toolchainCheck cabal compiler store matrix
      oracle = oracleCheck matrix liveResult
      positives = positiveCheck matrix liveResult
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = mergeChecks "linux-engine-bringup-discovery" [discoveryCheck discipline liveResult, identity]
      challenge = mergeChecks "linux-engine-bringup-challenge" [challengeCheck liveResult, identity]
      identity = mergeChecks "linux-engine-bringup-client-identity" [clientIdentityCheck liveResult, handoffIdentityCheck liveResult]
      observer = mergeChecks "linux-engine-bringup-observer" [observerCheck liveResult, identity]
      authority = mergeChecks "linux-engine-bringup-authority" [authorityCheck root runRoot cabal compiler store matrix liveResult, identity]
      freshness = freshnessCheck root runRoot liveResult
      qualification = mergeChecks "linux-engine-bringup-qualification" [toolchain, negatives, mutants, identity]
      cleanroom = mergeChecks "linux-engine-bringup-cleanroom" [cache, cleanupCheck liveResult]
      legacy = mergeChecks "linux-engine-bringup-legacy-closure" [discipline, mutants]
      prerequisite = mergeChecks "linux-engine-bringup-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positives, negatives, mutants, discovery, challenge, observer, authority, freshness, qualification, cleanroom]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery challenge observer authority freshness qualification cleanroom legacy
      result = mergeChecks "linux-engine-bringup" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "linux-engine-bringup-subject" [checkDigest discipline, liveDigest liveResult]
      oracleId = ids "linux-engine-bringup-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "linux-engine-bringup-harness" (map receiptDigest (matrixReceipts matrix) <> [liveDigest liveResult])
      observerId = ids "linux-engine-bringup-observer" [checkDigest observer]
      qualificationId = ids "linux-engine-bringup-qualification" [checkDigest qualification]
      acquiredRunId = ids "linux-engine-bringup-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "linux-engine-bringup-toolchain" [genesisTrustToolchainIdentity trust, checkDigest toolchain]
      cleanupEvidence = case liveResult of
        Right live -> "instance=" <> liveInstance live <> ";deleted=true;provider-inventory-restored=" <> truth (liveProviderBefore live == liveProviderAfter live) <> ";external-residue=0"
        Left problem -> "instance=unknown;deleted=attempted;live-error=" <> Text.pack (displayException problem)
  pure (AcquiredLinuxEngineBringupRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanupEvidence result)

executeQualificationMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeQualificationMatrix root runRoot cabal compiler store = do
  clean <- runSpec "qualification-clean" Nothing
  mutants <- mapM runMutant mutantSpecifications
  pure (Matrix mutants clean)
 where
  common =
    [ "--builddir=" <> runRoot </> "dist"
    , "--store-dir=" <> store
    , "--with-compiler=" <> compiler
    , "--jobs=1", "--offline"
    ]
  runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
  runSpec name selected = runProcess root name cabal
    (common <> ["test", "linux-engine-bringup-spec", "--offline", "--test-show-details=direct"]
      <> [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications])

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ row "ephemeral-membership" "linux-engine-ephemeral-membership-mutant" "plan.persist-membership" "linux-engine-bringup-mutant: RED ephemeral-membership durable-group-read"
  , row "unrefreshed-credentials" "linux-engine-unrefreshed-credentials-mutant" "plan.refresh-credentials" "linux-engine-bringup-mutant: RED unrefreshed-credentials current-process-read"
  , row "elevated-retry" "linux-engine-elevated-retry-mutant" "daemon.unelevated-argv" "linux-engine-bringup-mutant: RED elevated-retry unelevated-session-read"
  , row "converge-without-probe" "linux-engine-converge-without-probe-mutant" "rerun.probe-set" "linux-engine-bringup-mutant: RED converge-without-probe second-pass-probes"
  , row "platform-override" "linux-engine-platform-override-mutant" "build.architecture-admission" "linux-engine-bringup-mutant: RED platform-override native-architecture"
  , row "root-client" "linux-engine-root-client-mutant" "client.unelevated-identity" "linux-engine-bringup-mutant: RED root-client unelevated-docker-client"
  ]
 where row name flagName locus expected = (name, flagName, locus, expected)

executeLive :: FilePath -> FilePath -> IO LiveObservation
executeLive root runRoot = do
  process <- show <$> getProcessID
  let instanceName = "amoebius-phase52-" <> process
      instanceId = Text.pack instanceName
      archive = runRoot </> "source.tar"
      support = runRoot </> "toolchain-support.tar"
      guestRoot = "/root/amoebius"
      guestOutput = "/var/lib/amoebius-phase52"
      passTracePath pass = "/root/phase52-pass-" <> show (pass :: Int) <> ".trace"
      -- Follow forks across the whole pass.  The earlier trace covered only the
      -- version handoff, so no Docker client call in either pass was observed
      -- by anything but the runner that issued it.
      passArgv pass =
        [ "/usr/bin/strace", "-f", "-s", show traceStringLimit
        , "-e", "trace=execve,execveat,clone,clone3,vfork,fork"
        , "-o", passTracePath pass
        , "/usr/bin/python3", "-I", "-S", "-B", guestRoot </> "pb"
        , "dev", "linux-engine-guest-pass", show pass, guestOutput
        ]
  unless (all safeInstanceCharacter instanceName && "amoebius-phase52-" `isPrefixOf` instanceName)
    (fail "phase52-unsafe-instance-name")
  incus <- requireExecutable "/usr/bin/incus"
  beforeReceipt <- require "provider-inventory-before" =<< runProcess root "provider-inventory-before" incus ["list", "--format", "csv", "-c", "n,s,t"]
  let before = receiptStdout beforeReceipt
  absent <- runProcess root "provider-owner-absence" incus ["list", instanceName, "--format", "csv", "-c", "n"]
  unless (Text.null (Text.strip (receiptStdout absent))) (fail "phase52-owner-marker-already-present")
  _ <- require "source-archive" =<< runProcess root "source-archive" "/usr/bin/tar"
    ["--exclude=.git", "--exclude=.build", "--exclude=.data", "--exclude=.test_data", "--exclude=dist-newstyle", "--exclude=node_modules", "-C", root, "-cf", archive, "."]
  supportRoot <- prepareGuestToolchainSupport root runRoot
  _ <- require "support-archive" =<< runProcess root "support-archive" "/usr/bin/tar"
    ["-C", supportRoot, "-cf", support, ".build"]
  observed <- (`finally` cleanup incus instanceName) $ do
    launch <- require "incus-launch" =<< runProcess root "incus-launch" incus
      ["launch", "images:ubuntu/24.04/cloud", instanceName, "--vm"
      , "-c", "limits.cpu=4", "-c", "limits.memory=8GiB"
      , "-c", "user.amoebius.owner=phase-52", "-d", "root,size=80GiB"]
    toolchainDevice <- require "incus-device-toolchain" =<< runProcess root "incus-device-toolchain" incus
      ["config", "device", "add", instanceName, "phase52-toolchain", "disk", "source=" <> toolchainHostRoot, "path=/phase52-host", "readonly=true"]
    ready <- waitReady root incus instanceName
    preflight <- require "guest-preflight" =<< guestShell root incus instanceName "guest-preflight" preflightScript
    unless (receiptStdout preflight == expectedPreflight) (fail ("phase52-preflight-mismatch:" <> Text.unpack (receiptStdout preflight)))
    prerequisites <- require "guest-toolchain-prerequisites" =<< guest root incus instanceName "guest-toolchain-prerequisites"
      ["/usr/bin/env", "DEBIAN_FRONTEND=noninteractive", "/usr/bin/apt-get", "update"]
    packages <- require "guest-toolchain-packages" =<< guest root incus instanceName "guest-toolchain-packages"
      ["/usr/bin/env", "DEBIAN_FRONTEND=noninteractive", "/usr/bin/apt-get", "install", "-y", "build-essential", "git", "libgmp-dev", "zlib1g-dev", "libffi-dev", "libncurses-dev", "pkg-config", "strace", "ca-certificates"]
    pushSource <- require "guest-source-push" =<< runProcess root "guest-source-push" incus ["file", "push", archive, instanceName <> "/root/source.tar"]
    pushSupport <- require "guest-support-push" =<< runProcess root "guest-support-push" incus ["file", "push", support, instanceName <> "/root/toolchain-support.tar"]
    setup <- require "guest-source-setup" =<< guestShell root incus instanceName "guest-source-setup" setupScript
    handoff <- require "guest-pb-handoff" =<< guest root incus instanceName "guest-pb-handoff"
      [ "/usr/bin/strace", "-f", "-s", show traceStringLimit, "-e", "trace=execve,execveat"
      , "-o", "/root/phase52-handoff.trace"
      , "/usr/bin/python3", "-I", "-S", "-B", guestRoot </> "pb", "--version"]
    unless ("amoebius 0.1.0.0" `Text.isInfixOf` receiptStdout handoff) (fail "phase52-pb-handoff-version-missing")
    first <- require "guest-first-pass" =<< guest root incus instanceName "guest-first-pass" (passArgv 1)
    second <- require "guest-second-pass" =<< guest root incus instanceName "guest-second-pass" (passArgv 2)
    handoffTrace <- require "guest-handoff-trace" =<< guest root incus instanceName "guest-handoff-trace" ["/usr/bin/cat", "/root/phase52-handoff.trace"]
    firstTrace <- readGuest root incus instanceName "first-trace" (passTracePath 1)
    secondTrace <- readGuest root incus instanceName "second-trace" (passTracePath 2)
    firstLedger <- readGuest root incus instanceName "first-ledger" (guestOutput </> "pass-1-ledger.tsv")
    secondLedger <- readGuest root incus instanceName "second-ledger" (guestOutput </> "pass-2-ledger.tsv")
    firstSurfaces <- readGuest root incus instanceName "first-surfaces" (guestOutput </> "pass-1-surfaces.tsv")
    secondSurfaces <- readGuest root incus instanceName "second-surfaces" (guestOutput </> "pass-2-surfaces.tsv")
    firstVersion <- readGuest root incus instanceName "first-version" (guestOutput </> "pass-1-version.txt")
    secondVersion <- readGuest root incus instanceName "second-version" (guestOutput </> "pass-2-version.txt")
    external <- require "guest-external-observer" =<< guestShell root incus instanceName "guest-external-observer" externalObserverScript
    pure LiveObservation
      { liveInstance = instanceId
      , livePreflight = receiptStdout preflight
      , liveHandoff = receiptStdout handoffTrace
      , liveFirstLedger = receiptStdout firstLedger
      , liveSecondLedger = receiptStdout secondLedger
      , liveFirstSurfaces = receiptStdout firstSurfaces
      , liveSecondSurfaces = receiptStdout secondSurfaces
      , liveFirstVersion = receiptStdout firstVersion
      , liveSecondVersion = receiptStdout secondVersion
      , liveFirstTrace = receiptStdout firstTrace
      , liveSecondTrace = receiptStdout secondTrace
      , liveExternal = receiptStdout external
      , liveProviderBefore = before
      , liveProviderAfter = Text.empty
      , liveReceipts =
          [ launch, toolchainDevice, ready, preflight, prerequisites, packages, pushSource, pushSupport
          , setup, handoff, first, second, handoffTrace, firstTrace, secondTrace, firstLedger, secondLedger
          , firstSurfaces, secondSurfaces, firstVersion, secondVersion, external
          ]
      }
  afterReceipt <- require "provider-inventory-after" =<< runProcess root "provider-inventory-after" incus ["list", "--format", "csv", "-c", "n,s,t"]
  pure observed
    { liveProviderAfter = receiptStdout afterReceipt
    , liveReceipts = liveReceipts observed <> [afterReceipt]
    }

cleanup :: FilePath -> String -> IO ()
cleanup incus instanceName = do
  _ <- runProcess "/" "incus-delete" incus ["delete", "--force", instanceName]
  pure ()

waitReady :: FilePath -> FilePath -> String -> IO Receipt
waitReady root incus instanceName = loop (60 :: Int)
 where
  loop 0 = fail "phase52-guest-agent-timeout"
  loop remaining = do
    observed <- guest root incus instanceName "guest-ready" ["/usr/bin/true"]
    if receiptExit observed == ExitSuccess then pure observed else threadDelay 2000000 >> loop (remaining - 1)

guest :: FilePath -> FilePath -> String -> Text -> [String] -> IO Receipt
guest root incus instanceName name arguments =
  runProcess root name incus (["exec", instanceName, "--mode", "non-interactive", "--"] <> arguments)
guestShell :: FilePath -> FilePath -> String -> Text -> String -> IO Receipt
guestShell root incus instanceName name script = guest root incus instanceName name ["/bin/sh", "-c", script]

readGuest :: FilePath -> FilePath -> String -> Text -> FilePath -> IO Receipt
readGuest root incus instanceName name path = require (Text.unpack name) =<< guest root incus instanceName name ["/usr/bin/cat", path]

preflightScript :: String
preflightScript = unlines
  [ "if /usr/bin/dpkg-query -W -f='${Status}' docker.io >/dev/null 2>&1; then echo 'engine-package\tpresent'; else echo 'engine-package\tabsent'; fi"
  , "if /usr/bin/getent group docker >/dev/null 2>&1; then echo 'docker-group-row\tpresent'; else echo 'docker-group-row\tabsent'; fi"
  , "if test -S /var/run/docker.sock; then echo 'daemon-socket\tpresent'; else echo 'daemon-socket\tabsent'; fi"
  , "if test -e /var/lib/docker/image; then echo 'native-image\tpresent'; else echo 'native-image\tabsent'; fi"
  ]

expectedPreflight :: Text
expectedPreflight = "engine-package\tabsent\ndocker-group-row\tabsent\ndaemon-socket\tabsent\nnative-image\tabsent\n"

setupScript :: String
setupScript = unlines
  [ "set -eu"
  , "mkdir -p /root/amoebius"
  , "tar -C /root/amoebius -xf /root/source.tar"
  , "tar -C /root/amoebius -xf /root/toolchain-support.tar"
  , "tc=/root/amoebius/.build/toolchain/linux-amd64"
  , "mkdir -p /home/matt/.ghcup/ghc /home/matt/.ghcup/bin /home/matt/.cabal"
  , "cp -a /phase52-host/.ghcup/ghc/9.12.4 /home/matt/.ghcup/ghc/9.12.4"
  , "cp /phase52-host/.ghcup/bin/cabal-3.16.1.0 /home/matt/.ghcup/bin/cabal-3.16.1.0"
  , "ln -s /phase52-host/.cabal/store /home/matt/.cabal/store"
  , "ln -s /phase52-host/.cabal/packages /home/matt/.cabal/packages"
  , "mkdir -p \"$tc/.ghcup/ghc\" \"$tc/.ghcup/bin\" \"$tc/.ghcup/db/ghc\" \"$tc/.ghcup/db/cabal\" \"$tc/cache/cabal\""
  , "ln -s /home/matt/.ghcup/ghc/9.12.4 \"$tc/.ghcup/ghc/9.12.4\""
  , "ln -s /home/matt/.ghcup/bin/cabal-3.16.1.0 \"$tc/.ghcup/bin/cabal-3.16.1.0\""
  , "ln -s cabal-3.16.1.0 \"$tc/.ghcup/bin/cabal\""
  , "for tool in ghc ghc-9.12.4 ghci ghci-9.12.4 ghc-pkg ghc-pkg-9.12.4 haddock haddock-ghc-9.12.4 hsc2hs runghc runghc-9.12.4 runhaskell; do ln -s /home/matt/.ghcup/ghc/9.12.4/bin/$tool \"$tc/.ghcup/bin/$tool\"; done"
  , "for tool in gcc cc ld ar ranlib as nm strip git pkg-config tar gzip; do ln -s /usr/bin/$tool \"$tc/.ghcup/bin/$tool\"; done"
  , "printf '9.12.4' > \"$tc/.ghcup/db/ghc/set\""
  , "printf '3.16.1.0' > \"$tc/.ghcup/db/cabal/set\""
  , "ln -s /home/matt/.cabal/store \"$tc/cabal-store\""
  , "ln -s /home/matt/.cabal/packages \"$tc/cache/cabal/packages\""
  ]

externalObserverScript :: String
externalObserverScript = unlines
  [ "set -eu"
  , "drop() { /usr/bin/setpriv --reuid=ubuntu --regid=ubuntu --init-groups \"$@\"; }"
  , "printf 'architecture\t'; uname -m"
  , "printf 'engine-architecture\t'; drop /usr/bin/docker version --format '{{.Server.Arch}}'"
  , "printf 'group-row\t'; /usr/bin/getent group docker"
  , "printf 'future-session\t'; /usr/bin/su - ubuntu -c '/usr/bin/docker info --format {{.ServerVersion}}'"
  , "printf 'current-refresh\t'; drop /usr/bin/docker info --format '{{.ServerVersion}}'"
  , "printf 'image-architecture\t'; drop /usr/bin/docker image inspect --format '{{.Architecture}}' amoebius-phase52-cpu-amd64:local"
  , "printf 'client-uid\t'; drop /usr/bin/id -u"
  , "printf 'client-groups\t'; drop /usr/bin/id -Gn"
  , "printf 'daemon-endpoint\t'; drop /usr/bin/docker context inspect --format '{{.Endpoints.docker.Host}}'"
  , "if [ -n \"${DOCKER_HOST:-}\" ]; then printf 'docker-host-env\tset\n'; else printf 'docker-host-env\t(unset)\n'; fi"
  -- The control above reached the declared endpoint.  The same client, same
  -- identity, pointed elsewhere must not: otherwise the run proves only that
  -- some daemon answered, not that the owned guest daemon did.
  , "printf 'endpoint-substitution\t'; if (DOCKER_HOST=unix:///nonexistent/phase52.sock drop /usr/bin/docker info --format '{{.ServerVersion}}' >/dev/null 2>&1); then printf 'accepted\n'; else printf 'refused\n'; fi"
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Matrix -> CheckResult
toolchainCheck cabal compiler store matrix = CheckResult "linux-engine-bringup-toolchain"
  [observation "linux-engine.compiler" (Text.pack compiler), observation "linux-engine.cabal" (Text.pack cabal)]
  [finding "LINUX-ENGINE-TOOLCHAIN" (Text.unpack name) "qualification row did not use absolute pinned compiler/store, --jobs=1, and --offline" |
    Receipt name executable args _ _ _ _ <- matrixReceipts matrix,
    executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) || "--jobs=1" `notElem` args || "--offline" `notElem` args]

oracleCheck :: Matrix -> Either SomeException LiveObservation -> CheckResult
oracleCheck matrix liveResult = CheckResult "linux-engine-bringup-independent-oracle"
  [observation "linux-engine.oracle-independence" "LinuxEngineBringupOracle imports no production module"]
  ([finding "LINUX-ENGINE-ORACLE" "test/spec/host/LinuxEngineBringupOracle.hs" "the independent qualification oracle did not accept the clean production subject" |
      receiptExit (cleanReceipt matrix) /= ExitSuccess || notContains qualificationAcceptance (receiptOutput (cleanReceipt matrix))] <>
   case liveResult of
     Left problem -> [finding "LINUX-ENGINE-LIVE" "phase-52-live" (Text.pack (displayException problem))]
     Right live ->
       [finding "LINUX-ENGINE-SURFACE-ORACLE" "phase-52-live" "post-state surfaces or two-pass version observation diverged" |
         liveFirstSurfaces live /= expectedSurfaces || liveSecondSurfaces live /= expectedSurfaces ||
         liveFirstVersion live /= "amoebius 0.1.0.0\n" || liveSecondVersion live /= liveFirstVersion live])

positiveCheck :: Matrix -> Either SomeException LiveObservation -> CheckResult
positiveCheck matrix liveResult = CheckResult "linux-engine-bringup-positive-controls"
  [observation "linux-engine.qualification" (receiptSummary (cleanReceipt matrix))]
  (case liveResult of
    Left problem -> [finding "LINUX-ENGINE-POSITIVE" "phase-52-live" (Text.pack (displayException problem))]
    Right live ->
      [finding "LINUX-ENGINE-FIRST-PASS" "phase-52-live" "the first pass did not record all probes and exactly five typed mutations" | liveFirstLedger live /= expectedFirstLedger] <>
      [finding "LINUX-ENGINE-SECOND-PASS" "phase-52-live" "the second pass did not record four probes and zero mutations" | liveSecondLedger live /= expectedSecondLedger])

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "linux-engine-bringup-paired-negatives"
  [observation "linux-engine.negatives" "four dirty-preflight members, architecture mismatch, and elevated argv are refused by the independent oracle"]
  [finding "LINUX-ENGINE-NEGATIVE" "linux-engine-bringup-spec" "the clean qualification row did not pass every paired negative" |
    receiptExit (cleanReceipt matrix) /= ExitSuccess || notContains qualificationAcceptance (receiptOutput (cleanReceipt matrix))]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "linux-engine-bringup-mutants"
  [observation ("linux-engine.mutant." <> name) (receiptSummary receipt <> ";locus=" <> locus) | Mutant name locus _ receipt <- mutants]
  [finding "LINUX-ENGINE-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: AcquiredSourceSnapshot -> IO CheckResult
sourceDisciplineCheck acquired = pure (CheckResult "linux-engine-bringup-source-discipline"
  [observation "linux-engine.source-count" (Text.pack (show (length observed)))]
  [finding "LINUX-ENGINE-DISCOVERY" "<phase-52-source-set>" ("expected=" <> Text.pack (show expectedSources) <> ";observed=" <> Text.pack (show observed)) | observed /= expectedSources])
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

discoveryCheck :: CheckResult -> Either SomeException LiveObservation -> CheckResult
discoveryCheck discipline liveResult = mergeChecks "linux-engine-bringup-discovery"
  [discipline, case liveResult of
    Left problem -> CheckResult "linux-engine-live-discovery" [] [finding "LINUX-ENGINE-LIVE-DISCOVERY" "phase-52-live" (Text.pack (displayException problem))]
    Right live -> CheckResult "linux-engine-live-discovery"
      [observation "linux-engine.live-artifacts" "preflight;handoff;two pass traces;two ledgers;two surfaces;two versions;external observer"]
      [finding "LINUX-ENGINE-LIVE-DISCOVERY" "phase-52-live" "one or more mandatory live observations are empty" |
        any Text.null [livePreflight live, liveHandoff live, liveFirstLedger live, liveSecondLedger live, liveFirstSurfaces live, liveSecondSurfaces live, liveFirstVersion live, liveSecondVersion live, liveFirstTrace live, liveSecondTrace live, liveExternal live]]]

challengeCheck :: Either SomeException LiveObservation -> CheckResult
challengeCheck liveResult = CheckResult "linux-engine-bringup-challenge"
  [observation "linux-engine.challenge" "second pass re-observes four surfaces and emits no mutation"]
  (case liveResult of
    Right live -> [finding "LINUX-ENGINE-CHALLENGE" "phase-52-live" "second pass did not prove observed fixed point" | liveSecondLedger live /= expectedSecondLedger || liveSecondSurfaces live /= liveFirstSurfaces live]
    Left problem -> [finding "LINUX-ENGINE-CHALLENGE" "phase-52-live" (Text.pack (displayException problem))])

observerCheck :: Either SomeException LiveObservation -> CheckResult
observerCheck liveResult = CheckResult "linux-engine-bringup-observer"
  (case liveResult of
    Right live ->
      [ observation "linux-engine.external.sha256" (digestTexts [liveExternal live])
      , observation "linux-engine.handoff.sha256" (digestTexts [liveHandoff live])
      ]
    Left _ -> [])
  (case liveResult of
    Left problem -> [finding "LINUX-ENGINE-OBSERVER" "phase-52-live" (Text.pack (displayException problem))]
    Right live ->
      [finding "LINUX-ENGINE-OBSERVER" "phase-52-live" "external process/group/architecture observer did not prove the live boundary" |
        not (all (`Text.isInfixOf` liveExternal live) expectedExternalRows) ||
        not ("execve(" `Text.isInfixOf` liveHandoff live) || not ("/amoebius" `Text.isInfixOf` liveHandoff live)] <>
      [finding "LINUX-ENGINE-CLIENT-ROOT" "phase-52-live" "the observed Docker client identity was root or lacked engine group membership" |
        externalRow "client-uid" (liveExternal live) == Just "0" ||
        maybe True (notElem "docker" . Text.words) (externalRow "client-groups" (liveExternal live))])

-- | strace truncates recorded strings, and the executable a handoff becomes is
-- named by a long path.  A default-width trace would therefore record a prefix
-- that no longer identifies what ran, which is the one thing the trace is for.
traceStringLimit :: Int
traceStringLimit = 512

-- | One process in a follow-forks trace: what it ran, and who spawned it.
data TracedProcess = TracedProcess
  { tracedPid :: Int
  , tracedParent :: Maybe Int
  , tracedExecs :: [[Text]]
  }

-- | Reconstruct process lineage from a trace the guest wrote, so the identity a
-- Docker client call carried is observed rather than reported.  A call is
-- admitted only where its own lineage already dropped to the guest user;
-- root reaches the daemon through the same socket, so nothing else separates an
-- unelevated client from an elevated one after the fact.
clientIdentityCheck :: Either SomeException LiveObservation -> CheckResult
clientIdentityCheck liveResult = case liveResult of
  Left problem -> CheckResult "linux-engine-bringup-client-identity" []
    [finding "LINUX-ENGINE-CLIENT-IDENTITY" "phase-52-live" (Text.pack (displayException problem))]
  Right live ->
    let firstPass = parseTrace (liveFirstTrace live)
        secondPass = parseTrace (liveSecondTrace live)
        offenders = secondPassMutations secondPass
     in CheckResult "linux-engine-bringup-client-identity"
          [ observation "linux-engine.trace.pass-1.docker-clients" (Text.pack (show (length (dockerClients firstPass))))
          , observation "linux-engine.trace.pass-2.docker-clients" (Text.pack (show (length (dockerClients secondPass))))
          , observation "linux-engine.trace.pass-2.mutating-executables" (Text.intercalate "," offenders)
          ]
          ( passIdentityFindings "pass-1" firstPass
              <> passIdentityFindings "pass-2" secondPass
              <> [ finding "LINUX-ENGINE-SECOND-PASS-MUTATION" "phase-52-live"
                     ("the second pass ran a mutating executable: " <> Text.intercalate "," offenders)
                 | not (null offenders)
                 ]
          )

-- | The bootstrap must replace itself, not spawn a helper.  Read from the
-- guest's own trace: exactly one process ever became the binary, and it is the
-- process that was the interpreter a moment earlier.
handoffIdentityCheck :: Either SomeException LiveObservation -> CheckResult
handoffIdentityCheck liveResult = case liveResult of
  Left problem -> CheckResult "linux-engine-bringup-handoff-identity" []
    [finding "LINUX-ENGINE-HANDOFF-IDENTITY" "phase-52-live" (Text.pack (displayException problem))]
  Right live ->
    let traced = parseTrace (liveHandoff live)
        replacements =
          [ process
          | process <- traced
          , any (maybe False ("/amoebius" `Text.isSuffixOf`) . listToMaybe) (tracedExecs process)
          ]
        inPlace process =
          any (maybe False ("/python3" `Text.isSuffixOf`) . listToMaybe) (tracedExecs process)
     in CheckResult "linux-engine-bringup-handoff-identity"
          [observation "linux-engine.handoff.replacements" (Text.pack (show (length replacements)))]
          ( [ finding "LINUX-ENGINE-HANDOFF-IDENTITY" "phase-52-live"
                ("the guest trace shows " <> Text.pack (show (length replacements)) <> " processes becoming the binary; exactly one must")
            | length replacements /= 1
            ]
              <> [ finding "LINUX-ENGINE-HANDOFF-SPAWNED" "phase-52-live"
                     "the binary was started as a separate process rather than replacing the bootstrap interpreter"
                 | process <- replacements, not (inPlace process)
                 ]
          )

passIdentityFindings :: Text -> [TracedProcess] -> [Finding]
passIdentityFindings label traced =
  [ finding "LINUX-ENGINE-ROOT-CLIENT" "phase-52-live"
      (label <> ": a Docker client ran without a lineage that dropped to the guest user: " <> Text.unwords argv)
  | (pid, argv) <- dockerClients traced, not (droppedPrivilege traced pid)
  ]
    <> [ finding "LINUX-ENGINE-ELEVATED-CLIENT" "phase-52-live" (label <> ": the pass executed an elevation helper")
       | any (\process -> any (elem elevationHelper . take 1) (tracedExecs process)) traced
       ]
    <> [ finding "LINUX-ENGINE-UNOBSERVED-PASS" "phase-52-live" (label <> ": the pass trace recorded no Docker client call")
       | null (dockerClients traced)
       ]
    <> [ finding "LINUX-ENGINE-CLIENT-DISCOVERY" "phase-52-live"
           (label <> ": observed Docker client roles " <> Text.intercalate "," observed
              <> " do not match the expected " <> Text.intercalate "," expected)
       | let observed = dockerSubcommands traced
       , let expected = expectedDockerSubcommands label
       , observed /= expected
       ]

-- | Which Docker client roles each pass may exercise.  The first pass reaches
-- the engine, reads the two architectures, builds and runs; the second may only
-- re-read, because building or versioning again would be a mutation.
expectedDockerSubcommands :: Text -> [Text]
expectedDockerSubcommands label
  | label == "pass-1" = ["build", "image", "info", "run", "version"]
  | otherwise = ["image", "info", "run"]

-- | The distinct client roles a trace actually contains, as the subcommand each
-- invocation carried.
dockerSubcommands :: [TracedProcess] -> [Text]
dockerSubcommands traced = foldr insertOrdered [] [role | (_, argv) <- dockerClients traced, role <- take 1 (drop 2 argv)]
 where
  insertOrdered role seen = if role `elem` seen then seen else sort (role : seen)

-- | Executables whose presence in the second pass would contradict the fixed
-- point the phase claims: an install, a group write, a daemon restart.
secondPassMutations :: [TracedProcess] -> [Text]
secondPassMutations traced = sort
  [ executable
  | process <- traced, argv <- tracedExecs process, executable : _ <- [argv]
  , executable `elem` mutatingExecutables
  ]
    <> ["docker build" | (_, argv) <- dockerClients traced, "build" `elem` argv]

mutatingExecutables :: [Text]
mutatingExecutables = ["/usr/bin/apt-get", "/usr/sbin/usermod", "/usr/bin/systemctl", "/usr/bin/dpkg"]

elevationHelper :: Text
elevationHelper = "/usr/bin/sudo"

dockerClients :: [TracedProcess] -> [(Int, [Text])]
dockerClients traced =
  [ (tracedPid process, argv)
  | process <- traced, argv <- tracedExecs process, dockerExecutable : _ <- [argv], dockerExecutable == dockerClientExecutable
  ]

dockerClientExecutable :: Text
dockerClientExecutable = "/usr/bin/docker"

-- | A process is unelevated when it, or an ancestor, replaced itself with a
-- credential-dropping executable naming the guest user.  @setpriv@ drops in
-- place, @su@ drops in a child, so the answer is a property of the lineage.
droppedPrivilege :: [TracedProcess] -> Int -> Bool
droppedPrivilege traced = go (64 :: Int)
 where
  go budget pid
    | budget <= 0 = False
    | otherwise = case [process | process <- traced, tracedPid process == pid] of
        [] -> False
        process : _ ->
          any credentialDrop (tracedExecs process)
            || maybe False (go (budget - 1)) (tracedParent process)
  credentialDrop argv = case argv of
    "/usr/bin/setpriv" : rest -> "--reuid=ubuntu" `elem` rest
    "/usr/bin/su" : rest -> "ubuntu" `elem` rest
    _ -> False

parseTrace :: Text -> [TracedProcess]
parseTrace body =
  [ TracedProcess pid (lookup pid parents) [argv | (owner, argv) <- execs, owner == pid]
  | pid <- pids
  ]
 where
  entries = [(pid, rest) | line <- Text.lines body, Just (pid, rest) <- [splitTracePid line]]
  parents = [(child, pid) | (pid, rest) <- entries, isSpawn rest, Just child <- [traceResult rest], child > 0]
  execs = [(pid, argv) | (pid, rest) <- entries, isExec rest, execEntered rest, argv <- [quotedFields rest], not (null argv)]
  pids = foldr insertUnique [] ([pid | (pid, _) <- entries] <> [child | (child, _) <- parents])
  insertUnique pid seen = if pid `elem` seen then seen else pid : seen
  isExec rest = "execve(" `Text.isPrefixOf` rest || "execveat(" `Text.isPrefixOf` rest
  -- Under @-f@ the call is usually split: the line carrying the argument vector
  -- ends in @<unfinished ...>@ and the result arrives on a later line that no
  -- longer names the executable.  Reading only completed lines would therefore
  -- miss almost every process the trace was taken to observe.
  execEntered rest = traceResult rest == Just 0 || "<unfinished ...>" `Text.isSuffixOf` Text.stripEnd rest
  isSpawn rest = any (`Text.isInfixOf` Text.takeWhile (/= '=') rest) ["clone", "fork"]

splitTracePid :: Text -> Maybe (Int, Text)
splitTracePid line = case Text.decimal (Text.stripStart line) of
  Right (pid, rest) -> Just (pid, Text.stripStart rest)
  Left _ -> Nothing

traceResult :: Text -> Maybe Int
traceResult rest = case Text.breakOnEnd "= " rest of
  (_, tail') -> case Text.decimal (Text.stripStart tail') of
    Right (value, _) -> Just value
    Left _ -> Nothing

-- | Every double-quoted field on a trace line, in order: the executed path
-- first, then the argument vector strace recorded for it.  A backslash escapes
-- the character after it, so a quote inside an argument does not end the field
-- and shift every field after it.
quotedFields :: Text -> [Text]
quotedFields = go
 where
  go text = case Text.break (== '"') text of
    (_, rest)
      | Text.null rest -> []
      | otherwise -> let (field, remainder) = readField (Text.drop 1 rest) Text.empty in field : go remainder
  readField text acc = case Text.uncons text of
    Nothing -> (acc, Text.empty)
    Just ('"', remainder) -> (acc, remainder)
    Just ('\\', remainder) -> case Text.uncons remainder of
      Nothing -> (acc, Text.empty)
      Just (escaped, rest) -> readField rest (Text.snoc acc escaped)
    Just (character, remainder) -> readField remainder (Text.snoc acc character)

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Matrix -> Either SomeException LiveObservation -> CheckResult
authorityCheck root runRoot cabal compiler store matrix liveResult = CheckResult "linux-engine-bringup-authority"
  [observation "linux-engine.authority" "unique phase-52 owner marker; exact Incus guest; read-only toolchain mounts; no sudo Docker argv; no cluster/registry/provider-cloud effects"]
  ([finding "LINUX-ENGINE-RUN-ROOT" runRoot "run root escaped phase-52 work" | not (pathBelow (root </> ".build/runs/phase-52/work") runRoot)] <>
   [finding "LINUX-ENGINE-AUTHORITY" (Text.unpack name) "qualification process exceeded exact serialized compiler authority" |
     Receipt name executable args _ _ _ _ <- matrixReceipts matrix, executable /= cabal || ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args] <>
   case liveResult of
     Right live -> [finding "LINUX-ENGINE-SUDO-BYPASS" "phase-52-live" "an observed guest command wrapped Docker in sudo" | "sudo /usr/bin/docker" `Text.isInfixOf` Text.unlines (map receiptOutput (liveReceipts live))]
     Left _ -> [])

freshnessCheck :: FilePath -> FilePath -> Either SomeException LiveObservation -> CheckResult
freshnessCheck root runRoot liveResult = CheckResult "linux-engine-bringup-freshness"
  [observation "linux-engine.fresh-root" (Text.pack (makeRelative root runRoot))]
  ([finding "LINUX-ENGINE-FRESHNESS" runRoot "run root escaped or live owner did not use the unique phase prefix" | not (pathBelow (root </> ".build/runs/phase-52/work") runRoot)] <>
   case liveResult of Right live -> [finding "LINUX-ENGINE-FRESHNESS" (Text.unpack (liveInstance live)) "live instance identity is not unique and phase-owned" | not ("amoebius-phase52-" `Text.isPrefixOf` liveInstance live)]; Left _ -> [])

cleanupCheck :: Either SomeException LiveObservation -> CheckResult
cleanupCheck liveResult = CheckResult "linux-engine-bringup-cleanup"
  [observation "linux-engine.cleanup" "exact owner instance deleted on success and failure"]
  (case liveResult of
    Right live -> [finding "LINUX-ENGINE-RESIDUE" (Text.unpack (liveInstance live)) "provider inventory differs after exact-owner teardown" | liveProviderBefore live /= liveProviderAfter live]
    Left problem -> [finding "LINUX-ENGINE-CLEANUP-UNVERIFIED" "phase-52-live" (Text.pack (displayException problem))])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery challenge observer authority freshness qualification cleanroom legacy =
  [ named "phase-52-claim" [pre], named "phase-52-subject" [positives]
  , named "phase-52-command" [toolchain, authority], named "phase-52-oracle" [oracle]
  , named "phase-52-positive-controls" [positives], named "phase-52-paired-negatives" [negatives]
  , named "phase-52-mutants" [mutants], named "phase-52-discovery" [discovery]
  , named "phase-52-challenge" [challenge], named "phase-52-observer" [observer]
  , named "phase-52-authority-bypass" [authority], named "phase-52-freshness" [freshness]
  , named "phase-52-qualification" [qualification], named "phase-52-cleanroom" [cleanroom]
  , named "phase-52-legacy-closure" [legacy]
  , CheckResult "phase-52-predecessor" [observation "phase-52.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-52-residue" [observation "phase-52.residue" "Apple/Windows engine parity, kind, registry, full published recipe, accelerators, and platform services remain Phase-53+-owned"] []
  , named "phase-52-pass-criterion" [pre]
  ]

expectedSources :: [FilePath]
expectedSources = sort
  [ "app/amoebius/Main.hs", "src/Amoebius/Host/LinuxEngine.hs"
  , "src/validation-kernel/Amoebius/Validation/LinuxEngineBringupRun.hs"
  , "src/validation-kernel/Amoebius/Validation/LinuxEngineBringupRun/Internal.hs"
  , "test/spec/host/LinuxEngineBringupOracle.hs", "test/spec/host/LinuxEngineBringupSpec.hs"
  ]

-- | What the guest must say about itself once the run has converged.  These are
-- authored against the declared boundary rather than derived from whatever the
-- run happened to observe.
expectedExternalRows :: [Text]
expectedExternalRows =
  [ "architecture\tx86_64"
  , "engine-architecture\tamd64"
  , "group-row\tdocker:"
  , "image-architecture\tamd64"
  , "daemon-endpoint\tunix:///var/run/docker.sock"
  , "docker-host-env\t(unset)"
  , "endpoint-substitution\trefused"
  ]

externalRow :: Text -> Text -> Maybe Text
externalRow name body = case [value | line <- Text.lines body, Just value <- [Text.stripPrefix (name <> "\t") line]] of
  value : _ -> Just (Text.strip value)
  [] -> Nothing

expectedFirstLedger, expectedSecondLedger, expectedSurfaces, qualificationAcceptance :: Text
expectedFirstLedger = Text.unlines
  ["probe\tEnginePackage", "probe\tDockerGroup", "probe\tDaemonSocket", "probe\tNativeImage"
  ,"mutation\tInstallEngine", "mutation\tPersistDockerGroupMembership", "mutation\tStartDockerDaemon", "mutation\tRefreshCurrentCredentials", "mutation\tBuildNativeImage"]
expectedSecondLedger = Text.unlines ["probe\tEnginePackage", "probe\tDockerGroup", "probe\tDaemonSocket", "probe\tNativeImage"]
expectedSurfaces = Text.unlines ["EnginePackage\tpresent", "DockerGroup\tpresent", "DaemonSocket\tpresent", "NativeImage\tpresent"]
qualificationAcceptance = "linux-engine-bringup-spec: PASS (4 pristine surfaces, 5 mutations, 2 ledgers, 4 dirty negatives, 1 architecture negative, 8 architecture triples, 2 unelevated probes, 1 unelevated client, 1 image reference)"

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ receipt) = receipt
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = clean : [receipt | Mutant _ _ _ receipt <- mutants]

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess root name executable arguments = do
  (status, stdout, stderr) <- readCreateProcessWithExitCode (proc executable arguments) {cwd = Just root} ""
  let output = Text.pack stdout <> Text.pack stderr
  pure (Receipt name executable arguments status (Text.pack stdout) (Text.pack stderr) (digestTexts [name, Text.pack executable, Text.pack (show arguments), Text.pack (show status), output]))

require :: String -> Receipt -> IO Receipt
require label receipt
  | receiptExit receipt == ExitSuccess = pure receipt
  | otherwise = fail ("phase52-command-failed:" <> label <> ":" <> Text.unpack (receiptOutput receipt))

requireExecutable :: FilePath -> IO FilePath
requireExecutable path = doesFileExist path >>= \present -> if present then pure path else fail ("phase52-executable-absent:" <> path)

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _ _) = status
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ stdout _ _) = stdout
receiptDigest :: Receipt -> Text
receiptDigest (Receipt _ _ _ _ _ _ digest) = digest
receiptOutput :: Receipt -> Text
receiptOutput (Receipt _ _ _ _ stdout stderr _) = stdout <> stderr
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ _ _) = Text.intercalate "|"
  [name, Text.pack executable, "argv=" <> Text.pack (show args), "exit=" <> Text.pack (show status), "sha256=" <> receiptDigest receipt]

liveDigest :: Either SomeException LiveObservation -> Text
liveDigest liveResult = case liveResult of
  Left problem -> digestTexts ["live-error", Text.pack (displayException problem)]
  Right live -> digestTexts ([liveInstance live, livePreflight live, liveHandoff live, liveFirstLedger live, liveSecondLedger live, liveFirstSurfaces live, liveSecondSurfaces live, liveFirstVersion live, liveSecondVersion live, liveFirstTrace live, liveSecondTrace live, liveExternal live, liveProviderBefore live, liveProviderAfter live] <> map receiptDigest (liveReceipts live))

-- | The Phase-0 acquisition is the only authenticated copy of the foreign
-- source repositories.  Phase 50 reads the same tree, so a later phase that
-- invented its own path would be trusting something nothing authenticated.
sourceAcquisitionCache :: FilePath
sourceAcquisitionCache = ".build/dist-newstyle/phase-00-baseline/src"

-- | The minimal toolchain input the guest's bootstrap needs: the authenticated
-- ghcup binary with its metadata, a cabal configuration naming the guest's own
-- paths, and the acquired source repositories.  The compiler and the package
-- store reach the guest through the read-only host mount, so nothing here
-- copies either.
prepareGuestToolchainSupport :: FilePath -> FilePath -> IO FilePath
prepareGuestToolchainSupport root runRoot = do
  home <- getHomeDirectory
  let supportRoot = runRoot </> "guest-support"
      toolchain = supportRoot </> guestToolchainRelative
  createDirectoryIfMissing True (toolchain </> "bootstrap")
  createDirectoryIfMissing True (toolchain </> ".ghcup/cache")
  createDirectoryIfMissing True (toolchain </> "cache/cabal")
  copyFile (home </> ".ghcup/bin/ghcup") (toolchain </> "bootstrap/ghcup")
  forM_ ["ghcup-0.0.9.yaml", "ghcup-0.1.0.yaml"] $ \name -> do
    present <- doesFileExist (home </> ".ghcup/cache" </> name)
    if present then copyFile (home </> ".ghcup/cache" </> name) (toolchain </> ".ghcup/cache" </> name) else pure ()
  configPresent <- doesFileExist (home </> ".ghcup/config.yaml")
  if configPresent then copyFile (home </> ".ghcup/config.yaml") (toolchain </> ".ghcup/config.yaml") else pure ()
  configured <- ByteString.readFile (toolchainHostRoot </> ".cabal/config")
  ByteString.writeFile (toolchain </> "cache/cabal/config") (guestCabalConfig configured)
  copyDirectoryRecursive (root </> sourceAcquisitionCache) (toolchain </> "dist-newstyle/src")
  pure supportRoot

-- | The host account whose authenticated compiler and package store the guest
-- reads through its read-only mount.  One name, because the mount and the cabal
-- configuration derived from it must not disagree about which account that is.
toolchainHostRoot :: FilePath
toolchainHostRoot = "/home/matt"

-- | The guest resolves against the same configuration that produced the store
-- it is handed.  A different configuration yields different unit identities, at
-- which point the store holds nothing the plan asks for and every dependency is
-- rebuilt from source.  Only the writable locations move, and the parallelism
-- line is dropped because a build here is serial.
guestCabalConfig :: ByteString.ByteString -> ByteString.ByteString
guestCabalConfig =
  TextEncoding.encodeUtf8 . Text.unlines . concatMap rewrite . Text.lines . TextEncoding.decodeUtf8
 where
  rewrite line
    | "jobs:" `Text.isPrefixOf` line = []
    | "build-summary:" `Text.isPrefixOf` line = ["build-summary: " <> guestPath "cache/cabal/logs/build.log"]
    | "logs-dir:" `Text.isPrefixOf` line = ["logs-dir: " <> guestPath "cache/cabal/logs"]
    | "installdir:" `Text.isPrefixOf` line = ["installdir: " <> guestPath "cache/cabal/bin"]
    | otherwise = [line]
  guestPath leaf = Text.pack (guestToolchainRoot </> leaf)

guestToolchainRelative :: FilePath
guestToolchainRelative = ".build/toolchain/linux-amd64"

guestToolchainRoot :: FilePath
guestToolchainRoot = "/root/amoebius" </> guestToolchainRelative

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> sourceAcquisitionCache
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if not present then pure (CheckResult "linux-engine-source-cache" [] [finding "LINUX-ENGINE-CACHE" (makeRelative root source) "authenticated source repository cache is absent"])
  else do
    copyDirectoryRecursive source target
    names <- sort <$> listDirectory target
    pure (CheckResult "linux-engine-source-cache" [observation "linux-engine.cache.entries" (Text.pack (show names))]
      [finding "LINUX-ENGINE-CACHE" (makeRelative root target) "source repository cache is incomplete" | not (any ("infernix-" `isPrefixOf`) names && any ("jitML-" `isPrefixOf`) names)])

copyDirectoryRecursive :: FilePath -> FilePath -> IO ()
copyDirectoryRecursive source target = do
  createDirectoryIfMissing True target
  names <- listDirectory source
  forM_ names $ \name -> do
    let from = source </> name; to = target </> name
    directory <- doesDirectoryExist from
    if directory then copyDirectoryRecursive from to else copyFile from to

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-52/work"
  createDirectoryIfMissing True parent
  (path, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile path
  createDirectory path
  pure path

named :: Text -> [CheckResult] -> CheckResult
named name checks = (mergeChecks name checks) {checkName = name}

checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]

digestTexts :: [Text] -> Text
digestTexts = hex . SHA256.hash . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"

hex :: ByteString.ByteString -> Text
hex bytes = Text.pack (concatMap byteHex (ByteString.unpack bytes))
 where
  byteHex byte = let digits = "0123456789abcdef"; value = fromIntegral byte :: Int in [digits !! (value `div` 16), digits !! (value `mod` 16)]

notContains :: Text -> Text -> Bool
notContains needle value = not (needle `Text.isInfixOf` value)

pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)

safeInstanceCharacter :: Char -> Bool
safeInstanceCharacter character = character >= '0' && character <= '9' || character >= 'a' && character <= 'z' || character == '-'

truth :: Bool -> Text
truth True = "true"
truth False = "false"

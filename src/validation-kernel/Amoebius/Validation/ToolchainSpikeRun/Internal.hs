{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden Phase-1 execution authority.
--
-- Every child is executed sequentially.  The two compiler-bearing commands
-- carry both @--offline@ and @--jobs=1@ as literals; no caller supplies or
-- widens their concurrency.  The constructor is hidden so a diagnostic result
-- cannot be promoted into acquired gate evidence.
module Amoebius.Validation.ToolchainSpikeRun.Internal
  ( AcquiredToolchainSpikeRun
  , acquireToolchainSpikeRun
  , acquireToolchainSpikeRefreshRun
  , acquiredToolchainSpikeRunCheck
  , foldAcquiredToolchainSpikeRun
  , toolchainSpikeInternalQualificationDiagnostic
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
  , TrackedEntry (trackedBytes, trackedIndex)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.ToolchainSpikeRun (toolchainSpikeRunCheck)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , checkPassed
  , finding
  , findingCode
  , mergeChecks
  , observation
  )
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( createDirectory
  , createDirectoryIfMissing
  , doesFileExist
  , getHomeDirectory
  , getPermissions
  , removeFile
  , setOwnerExecutable
  , setPermissions
  )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data ProcessReceipt = ProcessReceipt
  { receiptName :: Text
  , receiptExecutable :: FilePath
  , receiptArguments :: [String]
  , receiptExit :: ExitCode
  , receiptStdout :: Text
  , receiptStderr :: Text
  }
  deriving (Eq, Show)

data AcquiredToolchainSpikeRun = AcquiredToolchainSpikeRun
  AcquiredSourceSnapshot
  GenesisTrust
  AcquiredPhaseContractEvidence
  [CheckResult]
  Text
  Text
  Text
  Text
  Text
  Text
  Text
  Text
  CheckResult

acquiredToolchainSpikeRunCheck :: AcquiredToolchainSpikeRun -> CheckResult
acquiredToolchainSpikeRunCheck (AcquiredToolchainSpikeRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredToolchainSpikeRun
  :: ( AcquiredSourceSnapshot
       -> GenesisTrust
       -> AcquiredPhaseContractEvidence
       -> [CheckResult]
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> CheckResult
       -> value
     )
  -> AcquiredToolchainSpikeRun
  -> value
foldAcquiredToolchainSpikeRun consume (AcquiredToolchainSpikeRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result) =
  consume acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result

acquireToolchainSpikeRun
  :: FilePath
  -> AcquiredSourceSnapshot
  -> GenesisTrust
  -> IO AcquiredToolchainSpikeRun
acquireToolchainSpikeRun root acquired trust = do
  acquireToolchainSpikeRunWith False root acquired trust

-- | Revalidate an already recorded Done phase without pretending it is still
-- the active transition target. All process/build evidence is reacquired; only
-- the contract-status scope changes to the exact recorded frontier.
acquireToolchainSpikeRefreshRun
  :: FilePath
  -> AcquiredSourceSnapshot
  -> GenesisTrust
  -> IO AcquiredToolchainSpikeRun
acquireToolchainSpikeRefreshRun = acquireToolchainSpikeRunWith True

acquireToolchainSpikeRunWith
  :: Bool
  -> FilePath
  -> AcquiredSourceSnapshot
  -> GenesisTrust
  -> IO AcquiredToolchainSpikeRun
acquireToolchainSpikeRunWith receiptRefresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let buildA = runRoot </> "build-a"
      buildB = runRoot </> "build-b"
      toolA = runRoot </> "tool-a"
      toolB = runRoot </> "tool-b"
      fixtures = runRoot </> "fixtures"
      packageInputs = runRoot </> "package-inputs"
      projectFile = runRoot </> "cabal.project"
      ghcPath = genesisTrustCompilerExecutable trust
      archive = root </> ".build/bootstrap-inputs/cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz"
      keyring = root </> ".build/bootstrap-inputs/gnupg/pubring.kbx"
      ghcSums = root </> ".build/bootstrap-inputs/ghc-SHA256SUMS"
      ghcSignature = root </> ".build/bootstrap-inputs/ghc-SHA256SUMS.sig"
      cabalSums = root </> ".build/bootstrap-inputs/cabal-SHA256SUMS"
      cabalSignature = root </> ".build/bootstrap-inputs/cabal-SHA256SUMS.sig"
      dhallCache = home </> ".cabal/packages/hackage.haskell.org/dhall/1.42.3/dhall-1.42.3.tar.gz"
      tlsCache = home </> ".cabal/packages/hackage.haskell.org/http-client-tls/0.4.0/http-client-tls-0.4.0.tar.gz"
      dhallInput = packageInputs </> "dhall-1.42.3.tar.gz"
      tlsInput = packageInputs </> "http-client-tls-0.4.0.tar.gz"
  mapM_ (createDirectoryIfMissing True) [buildA, buildB, toolA, toolB, fixtures, packageInputs]
  dhallInputCheck <- materializePinnedInput "dhall-1.42.3" dhallCache dhallInput "cbb5612d9c55b9b3fa07ab73b72e6445875a6f53283f29979f164a9b3b067a00"
  tlsInputCheck <- materializePinnedInput "http-client-tls-0.4.0" tlsCache tlsInput "611cf14cf046657bb1788a4dac09710b4b104c037d42b189148c02e6dd84ae3c"
  let pinnedInputs = mergeChecks "phase-01-pinned-package-inputs" [dhallInputCheck, tlsInputCheck]
  ByteString.writeFile projectFile (renderRunProject root [dhallInput, tlsInput])
  ghcSignatureReceipt <- runProcess root "ghc-signature" "/usr/bin/gpgv" ["--keyring", keyring, ghcSignature, ghcSums]
  cabalSignatureReceipt <- runProcess root "cabal-signature" "/usr/bin/gpgv" ["--keyring", keyring, cabalSignature, cabalSums]
  extractA <- runProcess root "cabal-extract-a" "/usr/bin/tar" ["-xJf", archive, "-C", toolA, "cabal"]
  extractB <- runProcess root "cabal-extract-b" "/usr/bin/tar" ["-xJf", archive, "-C", toolB, "cabal"]
  let cabalA = toolA </> "cabal"
      cabalB = toolB </> "cabal"
  makeExecutable cabalA
  makeExecutable cabalB
  ghcVersion <- runProcess root "ghc-version" ghcPath ["--numeric-version"]
  cabalVersionA <- runProcess root "cabal-version-a" cabalA ["--numeric-version"]
  cabalVersionB <- runProcess root "cabal-version-b" cabalB ["--numeric-version"]
  buildReceiptA <- runProcess root "build-a" cabalA (buildArguments projectFile buildA ghcPath)
  buildReceiptB <- runProcess root "build-b" cabalB (buildArguments projectFile buildB ghcPath)
  binsA <- mapM (listBinary root cabalA projectFile buildA) probeTargets
  binsB <- mapM (listBinary root cabalB projectFile buildB) probeTargets
  let positiveFixture = fixtures </> "positive.dhall"
      negativeFixture = fixtures </> "negative.dhall"
  ByteString.writeFile positiveFixture "{ name = \"phase-one\", count = 3 }\n"
  ByteString.writeFile negativeFixture "{ name = \"phase-one\", count = \"three\" }\n"
  positiveDecode <- runKnownBinary root "decode-positive" (lookupBinary "probe:exe:decode" binsA) [positiveFixture]
  negativeDecode <- runKnownBinary root "decode-negative" (lookupBinary "probe:exe:decode" binsA) [negativeFixture]
  positiveSim <- runKnownBinary root "sim-positive" (lookupBinary "probe:exe:sim" binsA) []
  negativeSim <- runKnownBinary root "sim-perturbed" (lookupBinary "probe:exe:sim" binsA) ["--perturbed"]
  dependencyProbe <- runKnownBinary root "dependency-probe" (lookupBinary "probe:exe:probe" binsA) []
  binaryDigestsA <- mapM binaryDigest binsA
  binaryDigestsB <- mapM binaryDigest binsB
  let contract = if receiptRefresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor phaseOne acquired
      sourcePolicy = toolchainSpikeRunCheck acquired
      signatures = mergeChecks "phase-01-authenticated-inputs" [signatureCheck ghcSignatureReceipt cabalSignatureReceipt, pinnedInputs]
      versions = versionCheck ghcVersion cabalVersionA cabalVersionB
      builds = buildCheck buildReceiptA buildReceiptB
      discovery = discoveryCheck acquired binsA binsB
      positives = positiveCheck positiveDecode positiveSim dependencyProbe
      negatives = negativeCheck negativeDecode negativeSim
      reproducibility = reproducibilityCheck buildA buildB binaryDigestsA binaryDigestsB
      authority = authorityCheck root runRoot [buildReceiptA, buildReceiptB]
      qualification = qualificationCheck sourcePolicy positives negatives discovery
      cleanup = "temporary-residue=0;retained-root=" <> Text.pack (makeRelative root runRoot)
      cleanroom = cleanroomCheck root runRoot cleanup
      observer = observerCheck allReceipts binaryDigestsA
      allReceipts =
        [ ghcSignatureReceipt, cabalSignatureReceipt, extractA, extractB
        , ghcVersion, cabalVersionA, cabalVersionB, buildReceiptA, buildReceiptB
        , positiveDecode, negativeDecode, positiveSim, negativeSim, dependencyProbe
        ] <> map snd binsA <> map snd binsB
      prerequisite = mergeChecks "phase-01-prerequisite" [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, sourcePolicy, signatures, versions, builds, discovery, positives, negatives, reproducibility, authority, qualification, cleanroom, observer]
      rowChecks = phaseOneRows prerequisite sourcePolicy signatures versions builds discovery positives negatives reproducibility authority qualification cleanroom observer
      result = mergeChecks "phase-01" rowChecks
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      subjectId = digestTexts ["phase-one-subject", sourceId, checkDigest sourcePolicy]
      oracleId = digestTexts ["phase-one-oracle", checkDigest positives, checkDigest negatives, checkDigest discovery]
      harnessId = digestTexts ["phase-one-harness", checkDigest authority, checkDigest cleanroom]
      observerId = digestTexts ["phase-one-observer", checkDigest observer]
      qualificationId = digestTexts ["phase-one-qualification", checkDigest qualification]
      runId = digestTexts ["phase-one-run", Text.pack runRoot, checkDigest result]
      toolchainId = digestTexts [genesisTrustToolchainIdentity trust, checkDigest signatures, checkDigest versions, checkDigest reproducibility]
  pure (AcquiredToolchainSpikeRun acquired trust contract rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result)

phaseOneRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseOneRows prerequisite sourcePolicy signatures versions builds discovery positives negatives reproducibility authority qualification cleanroom observer =
  [ named "phase-01-claim" [prerequisite]
  , named "phase-01-subject" [sourcePolicy]
  , named "phase-01-command" [versions, builds, authority]
  , named "phase-01-oracle" [positives, negatives, discovery]
  , named "phase-01-positive-controls" [signatures, versions, builds, positives]
  , named "phase-01-paired-negatives" [negatives]
  , named "phase-01-mutants" [qualification]
  , named "phase-01-discovery" [discovery]
  , named "phase-01-challenge" [positives, negatives]
  , named "phase-01-observer" [observer]
  , named "phase-01-authority-bypass" [authority]
  , named "phase-01-freshness" [reproducibility]
  , named "phase-01-qualification" [qualification]
  , named "phase-01-cleanroom" [cleanroom]
  , named "phase-01-legacy-closure" [sourcePolicy, signatures]
  , CheckResult "phase-01-predecessor" [observation "phase-01.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-01-residue" [observation "phase-01.residue" "GenesisTrust and OS execution substrate explicit; later claims unverified"] []
  , named "phase-01-pass-criterion" [prerequisite]
  ]
 where
  named label = mergeChecks label

renderRunProject :: FilePath -> [FilePath] -> ByteString
renderRunProject root archives =
  TextEncoding.encodeUtf8 . Text.unlines $
    [ "packages:"
    , "  " <> Text.pack (root </> "amoebius.cabal")
    , "  " <> Text.pack (root </> "probe/probe.cabal")
    ]
      <> map (("  " <>) . Text.pack) archives
      <> [ "optimization: False"
    , "tests: False"
    , "package amoebius"
    , "  flags: +bootstrap-validator-probe-only"
    , "package dhall"
    , "  flags: -with-http"
    ]

materializePinnedInput :: Text -> FilePath -> FilePath -> Text -> IO CheckResult
materializePinnedInput label source destination expected = do
  attempt <- try (ByteString.readFile source) :: IO (Either IOException ByteString)
  case attempt of
    Left problem ->
      pure
        ( CheckResult
            ("phase-01-package-input-" <> label)
            [observation ("phase-01.package-input." <> label) "missing"]
            [finding "PHASE-01-PACKAGE-INPUT" source (Text.pack (show problem))]
        )
    Right bytes -> do
      let actual = sha256 bytes
          findings = [finding "PHASE-01-PACKAGE-INPUT-DIGEST" source ("expected " <> expected <> "; observed " <> actual) | actual /= expected]
      if null findings then ByteString.writeFile destination bytes else pure ()
      pure
        ( CheckResult
            ("phase-01-package-input-" <> label)
            [observation ("phase-01.package-input." <> label) actual]
            findings
        )

buildArguments :: FilePath -> FilePath -> FilePath -> [String]
buildArguments projectFile buildRoot compiler =
  [ "build"
  , "exe:amoebius"
  , "probe:exe:probe"
  , "probe:exe:decode"
  , "probe:exe:sim"
  , "--offline"
  , "--jobs=1"
  , "--project-file=" <> projectFile
  , "--builddir=" <> buildRoot
  , "--with-compiler=" <> compiler
  ]

probeTargets :: [String]
probeTargets = ["exe:amoebius", "probe:exe:probe", "probe:exe:decode", "probe:exe:sim"]

requiredDependencies :: [Text]
requiredDependencies =
  sort
    [ "cryptohash-sha256", "dhall", "directory", "filepath", "http-client", "http-client-tls"
    , "io-classes", "io-sim", "proto-lens", "purescript-bridge", "tar", "typed-process", "zlib"
    ]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-01/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

makeExecutable :: FilePath -> IO ()
makeExecutable path = do
  exists <- doesFileExist path
  if not exists then pure () else do
    permissions <- getPermissions path
    setPermissions path (setOwnerExecutable True permissions)

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO ProcessReceipt
runProcess working name executable arguments = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable arguments) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ case attempt of
    Left problem -> ProcessReceipt name executable arguments (ExitFailure 127) "" (Text.pack (show problem))
    Right (status, stdoutText, stderrText) -> ProcessReceipt name executable arguments status (Text.pack stdoutText) (Text.pack stderrText)

listBinary :: FilePath -> FilePath -> FilePath -> FilePath -> String -> IO (String, ProcessReceipt)
listBinary root cabalPath projectFile buildRoot target = do
  receipt <- runProcess root ("list-bin-" <> Text.pack target) cabalPath ["list-bin", target, "--offline", "--project-file=" <> projectFile, "--builddir=" <> buildRoot]
  pure (target, receipt)

lookupBinary :: String -> [(String, ProcessReceipt)] -> Maybe FilePath
lookupBinary target receipts = do
  receipt <- lookup target receipts
  case receiptExit receipt of
    ExitSuccess ->
      let candidate = Text.unpack (Text.strip (receiptStdout receipt))
       in if isAbsolute candidate then Just candidate else Nothing
    ExitFailure _ -> Nothing

runKnownBinary :: FilePath -> Text -> Maybe FilePath -> [String] -> IO ProcessReceipt
runKnownBinary root name binary arguments = case binary of
  Nothing -> pure (ProcessReceipt name "<unavailable>" arguments (ExitFailure 127) "" "binary discovery failed")
  Just path -> runProcess root name path arguments

binaryDigest :: (String, ProcessReceipt) -> IO (String, Maybe Text)
binaryDigest (target, receipt) = case lookupBinary target [(target, receipt)] of
  Nothing -> pure (target, Nothing)
  Just path -> do
    attempt <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
    pure (target, either (const Nothing) (Just . sha256) attempt)

signatureCheck :: ProcessReceipt -> ProcessReceipt -> CheckResult
signatureCheck ghc cabal =
  CheckResult "phase-01-signatures" observations findings
 where
  observations =
    [ observation "phase-01.signature.ghc" (receiptSummary ghc)
    , observation "phase-01.signature.cabal" (receiptSummary cabal)
    ]
  findings =
    requireSuccess "PHASE-01-GHC-SIGNATURE" ghc
      <> requireContains "PHASE-01-GHC-SIGNER" "88B57FCF7DB53B4DB3BFA4B1588764FBE22D19C4" ghc
      <> requireSuccess "PHASE-01-CABAL-SIGNATURE" cabal
      <> requireContains "PHASE-01-CABAL-SIGNER" "1E07C9A1A3088BAD47F74A3E227EE1942B0BDB95" cabal

versionCheck :: ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> CheckResult
versionCheck ghc cabalA cabalB =
  CheckResult "phase-01-versions"
    [ observation "phase-01.ghc-version" (Text.strip (receiptStdout ghc))
    , observation "phase-01.cabal-version-a" (Text.strip (receiptStdout cabalA))
    , observation "phase-01.cabal-version-b" (Text.strip (receiptStdout cabalB))
    ]
    (exactOutput "PHASE-01-GHC-VERSION" "9.12.4" ghc <> exactOutput "PHASE-01-CABAL-VERSION-A" "3.16.1.0" cabalA <> exactOutput "PHASE-01-CABAL-VERSION-B" "3.16.1.0" cabalB)

buildCheck :: ProcessReceipt -> ProcessReceipt -> CheckResult
buildCheck first second =
  CheckResult "phase-01-builds"
    [observation "phase-01.build-a" (receiptSummary first), observation "phase-01.build-b" (receiptSummary second)]
    (requireSuccess "PHASE-01-BUILD-A" first <> requireSuccess "PHASE-01-BUILD-B" second)

discoveryCheck :: AcquiredSourceSnapshot -> [(String, ProcessReceipt)] -> [(String, ProcessReceipt)] -> CheckResult
discoveryCheck acquired first second =
  CheckResult "phase-01-discovery"
    [ observation "phase-01.discovery.expected-dependencies" (Text.intercalate "," requiredDependencies)
    , observation "phase-01.discovery.binary-count-a" (showText (length first))
    , observation "phase-01.discovery.binary-count-b" (showText (length second))
    ]
    (dependencyFindings <> binaryFindings)
 where
  cabalBytes =
    [ trackedBytes entry
    | entry <- snapshotEntries (acquiredSourceSnapshot acquired)
    , indexPath (trackedIndex entry) == "probe/probe.cabal"
    ]
  decoded = case cabalBytes of
    [bytes] -> either (const "") id (TextEncoding.decodeUtf8' bytes)
    _ -> ""
  dependencyFindings =
    [finding "PHASE-01-DEPENDENCY-DISCOVERY" "probe/probe.cabal" ("required dependency is absent: " <> dependency) | dependency <- requiredDependencies, not (dependency `Text.isInfixOf` decoded)]
  binaryFindings =
    [ finding "PHASE-01-BINARY-DISCOVERY" target "both fresh builds must discover one absolute executable"
    | target <- probeTargets
    , not (valid target first && valid target second)
    ]
  valid target receipts = case lookup target receipts of
    Just receipt -> receiptExit receipt == ExitSuccess && maybe False isAbsolute (lookupBinary target [(target, receipt)])
    Nothing -> False

positiveCheck :: ProcessReceipt -> ProcessReceipt -> ProcessReceipt -> CheckResult
positiveCheck decode sim dependencies =
  CheckResult "phase-01-positive-controls"
    [observation "phase-01.decode-positive" (receiptSummary decode), observation "phase-01.sim-positive" (receiptSummary sim), observation "phase-01.dependency-probe" (receiptSummary dependencies)]
    ( requireSuccess "PHASE-01-DECODE-POSITIVE" decode
      <> requireContains "PHASE-01-DECODE-VALUE" "ProbeConfig {name = \"phase-one\", count = 3}" decode
      <> exactOutput "PHASE-01-SIM-TERMINAL" "schedule=two-writer-fair;terminal=3" sim
      <> exactOutput "PHASE-01-DEPENDENCY-PROBE" "phase-1-dependency-surface-linked" dependencies
    )

negativeCheck :: ProcessReceipt -> ProcessReceipt -> CheckResult
negativeCheck decode sim =
  CheckResult "phase-01-paired-negatives"
    [observation "phase-01.decode-negative" (receiptSummary decode), observation "phase-01.sim-perturbed" (receiptSummary sim)]
    ( requireFailure "PHASE-01-DECODE-NEGATIVE" decode
      <> requireContains "PHASE-01-DECODE-TYPE-ERROR" "DHALL_TYPE_ERROR:" decode
      <> exactOutput "PHASE-01-SIM-PERTURBED" "schedule=two-writer-fair;terminal=1" sim
    )

reproducibilityCheck :: FilePath -> FilePath -> [(String, Maybe Text)] -> [(String, Maybe Text)] -> CheckResult
reproducibilityCheck firstRoot secondRoot first second =
  CheckResult "phase-01-reproducibility"
    [observation "phase-01.build-root-a" (Text.pack firstRoot), observation "phase-01.build-root-b" (Text.pack secondRoot), observation "phase-01.binary-digests-a" (renderDigests first), observation "phase-01.binary-digests-b" (renderDigests second)]
    [ finding "PHASE-01-BINARY-REPRODUCIBILITY" target "the two fresh builds produced absent or different executable bytes"
    | target <- probeTargets
    , case (lookup target first, lookup target second) of
        (Just (Just firstDigest), Just (Just secondDigest)) -> firstDigest /= secondDigest
        _ -> True
    ]

authorityCheck :: FilePath -> FilePath -> [ProcessReceipt] -> CheckResult
authorityCheck root runRoot builds =
  CheckResult "phase-01-authority"
    [observation "phase-01.authority.run-root" (Text.pack runRoot), observation "phase-01.authority.compiler-serialization" "two sequential children; --jobs=1"]
    ( [finding "PHASE-01-RUN-ROOT" runRoot "run root must be beneath .build/runs/phase-01/work" | not (pathBelow (root </> ".build/runs/phase-01/work") runRoot)]
      <> [finding "PHASE-01-BUILD-AUTHORITY" (Text.unpack (receiptName receipt)) "compiler-bearing Cabal argv must contain --offline and --jobs=1 and must not invoke pb" | receipt <- builds, not (all (`elem` receiptArguments receipt) ["--offline", "--jobs=1"]) || any (Text.isInfixOf "pb" . Text.pack) (receiptArguments receipt)]
    )

qualificationCheck :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult
qualificationCheck sourcePolicy positives negatives discovery =
  CheckResult "phase-01-qualification"
    [ observation "phase-01.qualification.clean" (showText (all checkPassed [sourcePolicy, positives, negatives, discovery]))
    , observation "phase-01.qualification.mutants" "missing-dependency,wrong-terminal,foreign-probe,top-level-vendor,resolution-output"
    ]
    [ finding "PHASE-01-QUALIFICATION" "phase-01" "clean control or fixed changed-subject corpus was not distinguished"
    | not (all checkPassed [sourcePolicy, positives, negatives, discovery])
        || toolchainSpikeInternalQualificationDiagnostic /= expectedQualificationMatrix
    ]

-- | Refusal-only projection for the independently authored component oracle.
-- It exposes case labels and finding codes, never an acquired run or a gate
-- evidence constructor.
toolchainSpikeInternalQualificationDiagnostic :: [(Text, [Text])]
toolchainSpikeInternalQualificationDiagnostic =
  [ (label, map findingCode (checkFindings result))
  | (label, result) <- qualificationMatrix
  ]

expectedQualificationMatrix :: [(Text, [Text])]
expectedQualificationMatrix =
  [ ("clean", [])
  , ("missing-dependency", ["PHASE-01-POLICY-DEPENDENCY"])
  , ("wrong-terminal", ["PHASE-01-POLICY-TERMINAL"])
  , ("mutable-identity", ["PHASE-01-POLICY-IDENTITY"])
  , ("foreign-probe", ["PHASE-01-POLICY-PROBE-SOURCE"])
  , ("top-level-vendor", ["PHASE-01-POLICY-VENDOR-SOURCE"])
  , ("resolution-output", ["PHASE-01-POLICY-RESOLUTION-OUTPUT"])
  ]

qualificationMatrix :: [(Text, CheckResult)]
qualificationMatrix =
  [ ("clean", policySubject requiredDependencies "3" True ["probe/Main.hs"])
  , ("missing-dependency", policySubject (filter (/= "dhall") requiredDependencies) "3" True ["probe/Main.hs"])
  , ("wrong-terminal", policySubject requiredDependencies "4" True ["probe/Main.hs"])
  , ("mutable-identity", policySubject requiredDependencies "3" False ["probe/Main.hs"])
  , ("foreign-probe", policySubject requiredDependencies "3" True ["probe/Main.hs", "probe/fixture.txt"])
  , ("top-level-vendor", policySubject requiredDependencies "3" True ["probe/Main.hs", "vendor/Fork.hs"])
  , ("resolution-output", policySubject requiredDependencies "3" True ["probe/Main.hs", "cabal.project.freeze"])
  ]

policySubject :: [Text] -> Text -> Bool -> [FilePath] -> CheckResult
policySubject dependencies terminal immutableIdentity paths =
  CheckResult
    "phase-01-policy-subject"
    [ observation "phase-01.policy.dependencies" (Text.intercalate "," (sort dependencies))
    , observation "phase-01.policy.terminal" terminal
    , observation "phase-01.policy.immutable" (showText immutableIdentity)
    ]
    ( [finding "PHASE-01-POLICY-DEPENDENCY" "probe/probe.cabal" "the dependency inventory is not the exact closed representative set" | sort dependencies /= requiredDependencies]
      <> [finding "PHASE-01-POLICY-TERMINAL" "probe/app/Sim.hs" "the independently expected terminal state is 3" | terminal /= "3"]
      <> [finding "PHASE-01-POLICY-IDENTITY" "<toolchain-input>" "the acquisition identity must be immutable" | not immutableIdentity]
      <> [finding "PHASE-01-POLICY-PROBE-SOURCE" path "foreign probe behavior is inadmissible" | path <- paths, "probe/" `Text.isPrefixOf` Text.pack path, not (".hs" `Text.isSuffixOf` Text.pack path)]
      <> [finding "PHASE-01-POLICY-VENDOR-SOURCE" path "top-level vendor source is inadmissible" | path <- paths, "vendor/" `Text.isPrefixOf` Text.pack path]
      <> [finding "PHASE-01-POLICY-RESOLUTION-OUTPUT" path "tracked resolution output is inadmissible" | path <- paths, path == "cabal.project.freeze"]
    )

cleanroomCheck :: FilePath -> FilePath -> Text -> CheckResult
cleanroomCheck root runRoot cleanup =
  CheckResult "phase-01-cleanroom" [observation "phase-01.cleanup" cleanup]
    [finding "PHASE-01-CLEANROOM" runRoot "generated products must remain below the repository .build root" | not (pathBelow (root </> ".build") runRoot)]

observerCheck :: [ProcessReceipt] -> [(String, Maybe Text)] -> CheckResult
observerCheck receipts digests =
  CheckResult "phase-01-observer"
    ([observation "phase-01.observer.process" (receiptName receipt <> "|" <> receiptSummary receipt) | receipt <- receipts] <> [observation "phase-01.observer.executable" (Text.pack target <> "|" <> maybe "missing" id digest) | (target, digest) <- digests])
    [finding "PHASE-01-OBSERVER" (Text.unpack (receiptName receipt)) "process observation must retain an absolute executable and a bounded output digest" | receipt <- receipts, receiptExecutable receipt /= "<unavailable>" && (not (isAbsolute (receiptExecutable receipt)) || Text.null (receiptDigest receipt))]

requireSuccess, requireFailure :: Text -> ProcessReceipt -> [Finding]
requireSuccess code receipt = [finding code (Text.unpack (receiptName receipt)) ("expected exit 0; " <> receiptSummary receipt) | receiptExit receipt /= ExitSuccess]
requireFailure code receipt = [finding code (Text.unpack (receiptName receipt)) ("expected nonzero exit; " <> receiptSummary receipt) | receiptExit receipt == ExitSuccess]

requireContains :: Text -> Text -> ProcessReceipt -> [Finding]
requireContains code needle receipt = [finding code (Text.unpack (receiptName receipt)) ("expected observation containing " <> needle <> "; " <> receiptSummary receipt) | not (needle `Text.isInfixOf` (receiptStdout receipt <> receiptStderr receipt))]

exactOutput :: Text -> Text -> ProcessReceipt -> [Finding]
exactOutput code wanted receipt = requireSuccess code receipt <> [finding code (Text.unpack (receiptName receipt)) ("expected exact stdout " <> showText wanted <> "; observed " <> showText (Text.strip (receiptStdout receipt))) | Text.strip (receiptStdout receipt) /= wanted]

receiptSummary :: ProcessReceipt -> Text
receiptSummary receipt =
  "exit=" <> showText (receiptExit receipt) <> ";sha256=" <> receiptDigest receipt <> failureExcerpt
 where
  failureExcerpt = case receiptExit receipt of
    ExitSuccess -> ""
    ExitFailure _ -> ";stderr=" <> Text.take 512 (Text.replace "\n" "\\n" (receiptStderr receipt))

receiptDigest :: ProcessReceipt -> Text
receiptDigest receipt = digestTexts [Text.pack (receiptExecutable receipt), Text.pack (show (receiptArguments receipt)), showText (receiptExit receipt), receiptStdout receipt, receiptStderr receipt]

renderDigests :: [(String, Maybe Text)] -> Text
renderDigests = Text.intercalate "," . map (\(name, digest) -> Text.pack name <> "=" <> maybe "missing" id digest)

checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]

digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"

sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
 where
  byteHex byte = [hex (fromIntegral byte `div` 16), hex (fromIntegral byte `mod` 16)]
  hex nibble = intToDigit nibble

showText :: Show value => value -> Text
showText = Text.pack . show

pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child =
  let relative = normalise (makeRelative parent child)
   in relative /= ".." && not ("../" `Text.isPrefixOf` Text.pack relative) && not (isAbsolute relative)

phaseOne :: Int
phaseOne = 1

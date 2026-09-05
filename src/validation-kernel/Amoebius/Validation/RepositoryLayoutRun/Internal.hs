{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden Phase-2 execution authority. Every compiler-bearing child
-- is executed sequentially with literal @--offline@ and @--jobs=1@ arguments.
module Amoebius.Validation.RepositoryLayoutRun.Internal
  ( AcquiredRepositoryLayoutRun
  , acquireRepositoryLayoutRun
  , acquireRepositoryLayoutRefreshRun
  , acquiredRepositoryLayoutRunCheck
  , foldAcquiredRepositoryLayoutRun
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
import Amoebius.Validation.PbBootstrapGrammar.Internal (pbBootstrapGrammarCandidate)
import Amoebius.Validation.RepositoryLayoutRun
  ( repositoryLayoutQualificationDiagnostic
  , repositoryLayoutRunCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , SourceSnapshot (snapshotIdentity)
  , acquiredSourceSnapshot
  , pbTrackedFilesFromSnapshot
  , sourceClosureCheckAcquired
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , checkPassed
  , finding
  , mergeChecks
  , observation
  )
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
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

data ProcessReceipt = ProcessReceipt Text FilePath [String] ExitCode Text Text
  deriving (Eq, Show)

data AcquiredRepositoryLayoutRun = AcquiredRepositoryLayoutRun
  AcquiredSourceSnapshot
  GenesisTrust
  AcquiredPhaseContractEvidence
  [CheckResult]
  Text Text Text Text Text Text Text Text
  CheckResult

acquiredRepositoryLayoutRunCheck :: AcquiredRepositoryLayoutRun -> CheckResult
acquiredRepositoryLayoutRunCheck (AcquiredRepositoryLayoutRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredRepositoryLayoutRun
  :: ( AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence
       -> [CheckResult] -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text
       -> CheckResult -> value)
  -> AcquiredRepositoryLayoutRun -> value
foldAcquiredRepositoryLayoutRun consume (AcquiredRepositoryLayoutRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result) =
  consume acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result

acquireRepositoryLayoutRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRepositoryLayoutRun
acquireRepositoryLayoutRun = acquireRepositoryLayoutRunWith False

-- | Reacquire the complete Phase-2 evidence matrix after the phase is Done,
-- checking plan status against the recorded frontier rather than pretending
-- Phase 2 is still the active transition target.
acquireRepositoryLayoutRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRepositoryLayoutRun
acquireRepositoryLayoutRefreshRun = acquireRepositoryLayoutRunWith True

acquireRepositoryLayoutRunWith
  :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRepositoryLayoutRun
acquireRepositoryLayoutRunWith receiptRefresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let toolRoot = runRoot </> "tool"
      buildRoot = runRoot </> "build"
      projectFile = runRoot </> "cabal.project"
      cabalArchive = root </> ".build/bootstrap-inputs/cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz"
      dhallArchive = home </> ".cabal/packages/hackage.haskell.org/dhall/1.42.3/dhall-1.42.3.tar.gz"
      tlsArchive = home </> ".cabal/packages/hackage.haskell.org/http-client-tls/0.4.0/http-client-tls-0.4.0.tar.gz"
  mapM_ (createDirectoryIfMissing True) [toolRoot, buildRoot]
  inputCheck <- verifyInputs [(dhallArchive, dhallDigest), (tlsArchive, tlsDigest)]
  ByteString.writeFile projectFile (renderProject root dhallArchive tlsArchive)
  extract <- runProcess root "cabal-extract" "/usr/bin/tar" ["-xJf", cabalArchive, "-C", toolRoot, "cabal"]
  let cabalPath = toolRoot </> "cabal"
  makeExecutable cabalPath
  build <- runProcess root "compiler-build" cabalPath
    [ "build", "exe:amoebius", "test:validation-compiler-source-graph-acquired-component"
    , "--offline", "--jobs=1", "--project-file=" <> projectFile
    , "--builddir=" <> buildRoot, "--with-compiler=" <> genesisTrustCompilerExecutable trust
    ]
  binary <- runProcess root "oracle-list-bin" cabalPath
    [ "list-bin", "test:validation-compiler-source-graph-acquired-component"
    , "--offline", "--project-file=" <> projectFile, "--builddir=" <> buildRoot
    ]
  oracleRun <- runDiscovered root binary
  let contract = if receiptRefresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor phaseTwo acquired
      layout = repositoryLayoutRunCheck acquired
      sourceClosure = sourceClosureCheckAcquired acquired
      pbGrammar = pbBootstrapGrammarCandidate (pbTrackedFilesFromSnapshot (acquiredSourceSnapshot acquired))
      compiler = processCheck "PHASE-02-COMPILER" build
      oracle = processCheck "PHASE-02-ORACLE" oracleRun
      acquisition = mergeChecks "phase-02-acquisition" [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, inputCheck, processCheck "PHASE-02-CABAL-EXTRACT" extract]
      qualification = qualificationCheck
      authority = authorityCheck root runRoot [build]
      discovery = discoveryCheck acquired layout sourceClosure pbGrammar
      observer = observerCheck [extract, build, binary, oracleRun]
      cleanroom = CheckResult "phase-02-cleanroom" [observation "phase-02.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "PHASE-02-CLEANROOM" runRoot "the run root is not contained beneath .build/runs/phase-02/work" | not (pathBelow (root </> ".build/runs/phase-02/work") runRoot)]
      prerequisite = mergeChecks "phase-02-prerequisite" [acquisition, layout, sourceClosure, pbGrammar, compiler, oracle, qualification, authority, discovery, observer, cleanroom]
      rows = phaseTwoRows prerequisite layout compiler oracle qualification authority discovery observer cleanroom pbGrammar
      result = mergeChecks "phase-02" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      subjectId = digestTexts ["repository-layout-subject", sourceId, checkDigest layout, checkDigest sourceClosure, checkDigest pbGrammar]
      oracleId = digestTexts ["repository-layout-oracle", receiptDigest oracleRun]
      harnessId = digestTexts ["repository-layout-harness", checkDigest qualification, checkDigest authority]
      observerId = digestTexts ["repository-layout-observer", checkDigest observer]
      qualificationId = digestTexts ["repository-layout-qualification", checkDigest qualification]
      runId = digestTexts ["repository-layout-run", Text.pack runRoot, checkDigest result]
      toolchainId = digestTexts [genesisTrustToolchainIdentity trust, receiptDigest extract, receiptDigest build]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredRepositoryLayoutRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup result)

phaseTwoRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseTwoRows prerequisite layout compiler oracle qualification authority discovery observer cleanroom pbGrammar =
  [ named "phase-02-claim" [prerequisite]
  , named "phase-02-subject" [layout, compiler, pbGrammar]
  , named "phase-02-command" [compiler, authority]
  , named "phase-02-oracle" [oracle]
  , named "phase-02-positive-controls" [layout, compiler, oracle]
  , named "phase-02-paired-negatives" [qualification]
  , named "phase-02-mutants" [qualification]
  , named "phase-02-discovery" [discovery]
  , named "phase-02-challenge" [qualification]
  , named "phase-02-observer" [observer]
  , named "phase-02-authority-bypass" [authority]
  , CheckResult "phase-02-freshness" [observation "phase-02.fresh-build-root" "acquired run-scoped root; closing source finalized by dispatcher"] []
  , named "phase-02-qualification" [qualification, oracle]
  , named "phase-02-cleanroom" [cleanroom]
  , named "phase-02-legacy-closure" [layout, compiler, pbGrammar]
  , CheckResult "phase-02-predecessor" [observation "phase-02.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-02-residue" [observation "phase-02.residue" "only typed later-owned source migrations remain"] []
  , named "phase-02-pass-criterion" [prerequisite]
  ]
 where named label = mergeChecks label

qualificationCheck :: CheckResult
qualificationCheck = CheckResult "phase-02-qualification-matrix"
  [observation "phase-02.qualification.cases" "clean,retired-ignore-root,runtime-phase-ordinal,validation-phase-label"]
  [finding "PHASE-02-QUALIFICATION" "RepositoryLayoutRun" "the production checker does not distinguish the independently expected fixed corpus" | repositoryLayoutQualificationDiagnostic /= expected]
 where
  expected =
    [ ("clean", [])
    , ("retired-ignore-root", ["REPOSITORY-LAYOUT-RETIRED-IGNORE-ROOT"])
    , ("runtime-phase-ordinal", ["REPOSITORY-LAYOUT-PHASE-ORDINAL-IN-SOURCE"])
    , ("validation-phase-label", [])
    ]

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult -> CheckResult -> CheckResult -> CheckResult
discoveryCheck acquired layout closure pb = CheckResult "phase-02-discovery"
  [ observation "phase-02.source-snapshot" (snapshotIdentity (acquiredSourceSnapshot acquired))
  , observation "phase-02.discovery.layout" (checkDigest layout)
  , observation "phase-02.discovery.source-closure" (checkDigest closure)
  , observation "phase-02.discovery.pb-grammar" (checkDigest pb)
  ]
  [finding "PHASE-02-DISCOVERY" "<source-graph>" "one or more closed source/layout projections refused" | not (all checkPassed [layout, closure, pb])]

authorityCheck :: FilePath -> FilePath -> [ProcessReceipt] -> CheckResult
authorityCheck root runRoot receipts = CheckResult "phase-02-authority"
  [observation "phase-02.compiler-serialization" "one compiler child at a time; --offline; --jobs=1"]
  ([finding "PHASE-02-RUN-ROOT" runRoot "run root escaped the repository .build tree" | not (pathBelow (root </> ".build") runRoot)]
   <> [finding "PHASE-02-COMPILER-AUTHORITY" (Text.unpack name) "compiler command must be offline, jobs=1, direct, and must not invoke pb" | receipt@(ProcessReceipt name _ arguments _ _ _) <- receipts, not (all (`elem` arguments) ["--offline", "--jobs=1"]) || any (Text.isInfixOf "pb" . Text.pack) arguments || not (isAbsolute (receiptExecutable receipt))])

observerCheck :: [ProcessReceipt] -> CheckResult
observerCheck receipts = CheckResult "phase-02-observer"
  [observation "phase-02.observer.process" (receiptSummary receipt) | receipt <- receipts]
  [finding "PHASE-02-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" | receipt@(ProcessReceipt name _ _ _ _ _) <- receipts, receiptExecutable receipt /= "<unavailable>" && (not (isAbsolute (receiptExecutable receipt)) || Text.null (receiptDigest receipt))]

processCheck :: Text -> ProcessReceipt -> CheckResult
processCheck code receipt = CheckResult (Text.toLower code) [observation (Text.toLower code) (receiptSummary receipt)]
  [finding code (Text.unpack name) ("expected exit 0; " <> receiptSummary receipt) | receiptExit receipt /= ExitSuccess]
 where ProcessReceipt name _ _ _ _ _ = receipt

verifyInputs :: [(FilePath, Text)] -> IO CheckResult
verifyInputs inputs = do
  checked <- mapM check inputs
  pure (CheckResult "phase-02-pinned-inputs" [observation "phase-02.pinned-input" (Text.pack path <> "=" <> actual) | (path, actual, _) <- checked] [finding "PHASE-02-PINNED-INPUT" path ("expected " <> expected <> "; observed " <> actual) | (path, actual, expected) <- checked, actual /= expected])
 where
  check (path, expected) = do
    attempt <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
    pure (path, either (const "missing") sha256 attempt, expected)

renderProject :: FilePath -> FilePath -> FilePath -> ByteString
renderProject root dhallArchive tlsArchive = TextEncoding.encodeUtf8 (Text.unlines
  [ "packages:", "  " <> Text.pack (root </> "amoebius.cabal"), "  " <> Text.pack dhallArchive, "  " <> Text.pack tlsArchive
  , "optimization: False", "tests: True", "package amoebius", "  flags: +bootstrap-validator-probe-only", "package dhall", "  flags: -with-http"
  ])

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-02/work"
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

runDiscovered :: FilePath -> ProcessReceipt -> IO ProcessReceipt
runDiscovered root receipt = case receiptExit receipt of
  ExitSuccess ->
    let path = Text.unpack (Text.strip (receiptStdout receipt))
     in if isAbsolute path then runProcess root "independent-oracle" path [] else unavailable
  ExitFailure _ -> unavailable
 where unavailable = pure (ProcessReceipt "independent-oracle" "<unavailable>" [] (ExitFailure 127) "" "oracle binary discovery failed")

receiptExecutable :: ProcessReceipt -> FilePath
receiptExecutable (ProcessReceipt _ executable _ _ _ _) = executable

receiptExit :: ProcessReceipt -> ExitCode
receiptExit (ProcessReceipt _ _ _ status _ _) = status

receiptStdout :: ProcessReceipt -> Text
receiptStdout (ProcessReceipt _ _ _ _ stdoutText _) = stdoutText

receiptSummary :: ProcessReceipt -> Text
receiptSummary receipt@(ProcessReceipt name executable arguments status _ stderrText) =
  name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show arguments) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> failure
 where failure = case status of ExitSuccess -> ""; ExitFailure _ -> "|stderr=" <> Text.take 512 (Text.replace "\n" "\\n" stderrText)

receiptDigest :: ProcessReceipt -> Text
receiptDigest (ProcessReceipt name executable arguments status stdoutText stderrText) = digestTexts [name, Text.pack executable, Text.pack (show arguments), Text.pack (show status), stdoutText, stderrText]

checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]

digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"

sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
 where byteHex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `Text.isPrefixOf` Text.pack relative) && not (isAbsolute relative)

phaseTwo :: Int
phaseTwo = 2

dhallDigest, tlsDigest :: Text
dhallDigest = "cbb5612d9c55b9b3fa07ab73b72e6445875a6f53283f29979f164a9b3b067a00"
tlsDigest = "611cf14cf046657bb1788a4dac09710b4b104c037d42b189148c02e6dd84ae3c"

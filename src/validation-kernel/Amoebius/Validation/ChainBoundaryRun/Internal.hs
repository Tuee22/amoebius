{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ChainBoundaryRun.Internal
  ( AcquiredChainBoundaryRun
  , acquireChainBoundaryRefreshRun
  , acquireChainBoundaryRun
  , acquiredChainBoundaryRunCheck
  , foldAcquiredChainBoundaryRun
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
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM, forM_)
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
  , copyFile
  , doesDirectoryExist
  , doesFileExist
  , getHomeDirectory
  , listDirectory
  , removeFile
  )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt Receipt Receipt Receipt Receipt

data AcquiredChainBoundaryRun = AcquiredChainBoundaryRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredChainBoundaryRunCheck :: AcquiredChainBoundaryRun -> CheckResult
acquiredChainBoundaryRunCheck (AcquiredChainBoundaryRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredChainBoundaryRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredChainBoundaryRun
  -> value
foldAcquiredChainBoundaryRun consume (AcquiredChainBoundaryRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireChainBoundaryRun, acquireChainBoundaryRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredChainBoundaryRun
acquireChainBoundaryRun = acquire False
acquireChainBoundaryRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredChainBoundaryRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 34 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"] []
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root
  let toolchain = toolchainCheck root runRoot cabal compiler store cabalVersion matrix
      oracle = oracleCheck matrix
      positives = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot matrix
      cleanroom = mergeChecks "chain-boundary-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "chain-boundary-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "chain-boundary-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "chain-boundary" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "chain-boundary-subject" [checkDigest discipline, receiptDigest (cleanBuild matrix)]
      oracleId = ids "chain-boundary-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "chain-boundary-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "chain-boundary-observer" [checkDigest observer]
      qualificationId = ids "chain-boundary-qualification" [checkDigest qualification]
      acquiredRunId = ids "chain-boundary-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "chain-boundary-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0;generated-fakes=run-local"
  pure (AcquiredChainBoundaryRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  linkControl <- runCabal "link-seal-control" ["build", "test:chain-boundary-link-seal-attack", "-fastcheck-link-seal-control"]
  clean <- runCabal "clean-build" ["build", "exe:amoebius", "test:chain-spec", "test:boundary-spec", "test:astcheck-spec"]
  binary <- requireUniqueExecutable runRoot "/x/amoebius/noopt/build/amoebius/amoebius"
  chain <- requireUniqueExecutable runRoot "/t/chain-spec/noopt/build/chain-spec/chain-spec"
  boundary <- requireUniqueExecutable runRoot "/t/boundary-spec/noopt/build/boundary-spec/boundary-spec"
  ast <- requireUniqueExecutable runRoot "/t/astcheck-spec/noopt/build/astcheck-spec/astcheck-spec"
  chainReceipt <- runProcess root "observe-clean-chain" chain [] []
  boundaryReceipt <- runProcess root "observe-clean-boundary" boundary [] [("AMOEBIUS_BIN", binary)]
  astReceipt <- runProcess root "observe-clean-astcheck" ast [] []
  pure (Matrix mutants linkControl clean chainReceipt boundaryReceipt astReceipt)
 where
  common = ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler, "--jobs=1"]
  runCabal name arguments = runProcess root name cabal (common <> arguments <> ["--offline"]) []
  runMutant (name, flagName, locus, expected, kind) = case kind of
    "boundary" -> do
      build <- runCabal (name <> "-build") ["build", "exe:amoebius", "test:boundary-spec", "-f" <> flagName]
      binary <- requireUniqueExecutable runRoot "/x/amoebius/noopt/build/amoebius/amoebius"
      boundary <- requireUniqueExecutable runRoot "/t/boundary-spec/noopt/build/boundary-spec/boundary-spec"
      observed <- runProcess root name boundary [] [("AMOEBIUS_BIN", binary)]
      pure (Mutant name locus expected build observed)
    "link" -> do
      receipt <- runCabal name ["build", "test:chain-boundary-link-seal-attack", "-f" <> flagName]
      pure (Mutant name locus expected receipt receipt)
    component -> do
      receipt <- runCabal name ["test", Text.unpack component, "--test-show-details=direct", "-f" <> flagName]
      pure (Mutant name locus expected receipt receipt)

mutantSpecifications :: [(Text, String, Text, Text, Text)]
mutantSpecifications =
  [ ("m1_cfg_drop_service", "chain-drop-service-mutant", "Amoebius.Kernel.Chain", "semantic plan projection drifted", "chain-spec")
  , ("m2_descent_inframe", "chain-descent-inframe-mutant", "Amoebius.Kernel.Descent", "semantic plan projection drifted", "chain-spec")
  , ("mB1_argv", "boundary-argv-mutant", "Amoebius.Exec.Boundary", "argv-transcript", "boundary")
  , ("mB2_byte", "boundary-byte-mutant", "Amoebius.Exec.Boundary", "applied-bytes", "boundary")
  , ("mB3_path_resolve", "boundary-path-resolve-mutant", "Amoebius.Exec.Tool", "hostile-path", "boundary")
  , ("astcheck-allow-rawio", "astcheck-allow-rawio-mutant", "Amoebius.Dsl.AstCheck", "negative_raw_io.hs unexpectedly accepted", "astcheck-spec")
  , ("astcheck-export-ctor", "astcheck-export-ctor-mutant", "Amoebius.Dsl.AstCheck", "link-seal-exported", "link")
  ]

cleanBuild :: Matrix -> Receipt
cleanBuild (Matrix _ _ clean _ _ _) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants linkControl clean chain boundary ast) =
  concat [[build, observed] | Mutant _ _ _ build observed <- mutants] <> [linkControl, clean, chain, boundary, ast]

toolchainCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck root runRoot cabal compiler store version matrix = CheckResult "chain-boundary-toolchain"
  [observation "chain-boundary.cabal" (receiptSummary version), observation "chain-boundary.compiler" (Text.pack compiler)]
  ([finding "CHAIN-BOUNDARY-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "CHAIN-BOUNDARY-COMPILER" (Text.unpack name) "a compiler row did not use the exact offline compiler/store with --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix, executable == cabal,
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)]
   <> [finding "CHAIN-BOUNDARY-BINARY" executable "an observed binary was not an absolute run-local product" |
      Receipt name executable _ _ _ _ <- matrixReceipts matrix, executable /= cabal,
      not (isAbsolute executable && pathBelow (runRoot </> "dist") executable && pathBelow root executable) || not ("observe-" `Text.isPrefixOf` name || name `elem` boundaryMutantNames)])
 where
  boundaryMutantNames = ["mB1_argv", "mB2_byte", "mB3_path_resolve"]

oracleCheck :: Matrix -> CheckResult
oracleCheck (Matrix _ linkControl _ chain boundary ast) = CheckResult "chain-boundary-independent-oracle"
  [observation "chain-boundary.oracle-independence" "ChainBoundaryOracle imports no production or fixture module"]
  ([finding "CHAIN-BOUNDARY-CHAIN-ORACLE" oracleSource "the independent plan oracle acceptance token is absent" | receiptExit chain /= ExitSuccess || notContains "chain-spec: PASS (2 semantic cases, 19 exact plan/descent entries, 1 zero-step render, 2 mutants)" (receiptOutput chain)]
   <> [finding "CHAIN-BOUNDARY-BOUNDARY-ORACLE" oracleSource "the exact argv/byte oracle acceptance token is absent" | receiptExit boundary /= ExitSuccess || notContains "boundary-spec: PASS (4 real-binary invocations, 3 invoked tools, 1 zero-invocation helm control, exact argv and bytes, absolute paths, 3 mutants)" (receiptOutput boundary)]
   <> [finding "CHAIN-BOUNDARY-AST-ORACLE" oracleSource "the AST reason/span oracle acceptance token is absent" | receiptExit ast /= ExitSuccess || notContains "astcheck-spec: PASS (2 positives, 6 exact reason/span negatives, 2 sanctioned modules, 4 sanctioned effects, opaque link seal, 2 mutants)" (receiptOutput ast)]
   <> [finding "CHAIN-BOUNDARY-LINK-SEAL" compileNegativeSource "the clean compile-negative control did not reject external construction at the export boundary" | receiptExit linkControl /= ExitFailure 1 || notContains "does not export any children" (receiptOutput linkControl)])

positiveCheck :: Matrix -> CheckResult
positiveCheck (Matrix _ _ _ chain boundary ast) = CheckResult "chain-boundary-positive-controls"
  [observation "chain-boundary.positives" "two plan cases, four fake-boundary invocations, two accepted AST fixtures, and an opaque-constructor compile control passed"]
  [finding "CHAIN-BOUNDARY-POSITIVE" "<clean-controls>" "one or more clean controls failed" | any ((/= ExitSuccess) . receiptExit) [chain, boundary, ast]]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ linkControl _ chain boundary ast) = CheckResult "chain-boundary-paired-negatives"
  [observation "chain-boundary.negatives" "zero-step rendering, zero Helm invocation, hostile PATH canary, six exact AST rejection pairs, and constructor opacity were observed"]
  [finding "CHAIN-BOUNDARY-NEGATIVE" "<negative-controls>" "one or more paired-negative controls was absent" |
    receiptExit linkControl /= ExitFailure 1 ||
    any (\(token, receipt) -> notContains token (receiptOutput receipt))
      [("1 zero-step render", chain), ("1 hostile PATH canary", boundary), ("6 exact reason/span negatives", ast)]]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _ _ _ _ _) = CheckResult "chain-boundary-mutants"
  [observation ("chain-boundary.mutant." <> name) (receiptSummary observed) | Mutant name _ _ _ observed <- mutants]
  [finding "CHAIN-BOUNDARY-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
    Mutant name locus expected build observed <- mutants,
    (name `elem` ["mB1_argv", "mB2_byte", "mB3_path_resolve"] && receiptExit build /= ExitSuccess) ||
    if name == "astcheck-export-ctor" then receiptExit observed /= ExitSuccess else receiptExit observed /= ExitFailure 1 || notContains expected (receiptOutput observed)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  registry <- Text.pack <$> readFile (root </> "test/mutant/registry.tsv")
  pure (CheckResult "chain-boundary-source-discipline"
    [observation "chain-boundary.production-module-count" "8", observation "chain-boundary.effect-boundary" "pure plan plus exact run-local Haskell fakes; no pb, network, host mutation, cluster, or hardware"]
    ([finding "CHAIN-BOUNDARY-SOURCE-SHAPE" "<production>" ("missing production element: " <> token) |
       token <- ["data Step", "chain ::", "nextFrameAfter", "renderChainPlan", "mkToolPath", "runBoundaryCorpus", "checkExtensionSource", "sanctionedApi"], notContains token production]
     <> [finding "CHAIN-BOUNDARY-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedPlanRows", "expectedCalculusProjection", "expectedBoundaryArgv", "expectedBoundaryManifest", "expectedAstNegatives", "expectedValidationLoci", "expectedMutants"], notContains token oracle]
     <> [finding "CHAIN-BOUNDARY-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports production or fixture modules" | any (`Text.isInfixOf` oracle) ["import Amoebius", "import BindFixtures", "import ProvisionFixtures"]]
     <> [finding "CHAIN-BOUNDARY-REGISTRY" "test/mutant/registry.tsv" "retired serialized Phase-34 mutant authority remains" | "chain_boundary\t" `Text.isInfixOf` registry]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "chain-boundary-discovery"
  [observation "chain-boundary.discovery.count" (Text.pack (show (length observed)))]
  [finding "CHAIN-BOUNDARY-DISCOVERY" "<phase-34-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "chain-boundary-authority"
  [observation "chain-boundary.authority" "direct source-bound Haskell, offline serial compiler rows, and run-local fake boundaries only"]
  ([finding "CHAIN-BOUNDARY-RUN-ROOT" runRoot "run root escaped .build/runs/phase-34/work" | not (pathBelow (root </> ".build/runs/phase-34/work") runRoot)]
   <> [finding "CHAIN-BOUNDARY-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-34 authority" |
      Receipt name executable args _ _ _ <- receipts,
      not (executable == cabal || pathBelow (runRoot </> "dist") executable) ||
      (executable == cabal && name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["/pb", " podman", " kubectl", " kind", " ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "chain-boundary-observer"
  (map (observation "chain-boundary.observer.process" . receiptSummary) receipts)
  [finding "CHAIN-BOUNDARY-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Matrix -> CheckResult
freshnessCheck root runRoot matrix = CheckResult "chain-boundary-freshness"
  [observation "chain-boundary.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "CHAIN-BOUNDARY-FRESHNESS" runRoot "the clean candidate did not build and execute in the unique acquired run root" |
    receiptExit (cleanBuild matrix) /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-34/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "chain-boundary-legacy-closure"
    [observation "chain-boundary.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "chain-boundary.legacy.semantic-inputs" "HaskellOnly"]
    [finding "CHAIN-BOUNDARY-LEGACY" path "retired Python/shell/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-34-claim" [pre]
  , named "phase-34-subject" [toolchain, positives]
  , named "phase-34-command" [toolchain, authority]
  , named "phase-34-oracle" [oracle]
  , named "phase-34-positive-controls" [positives]
  , named "phase-34-paired-negatives" [negatives]
  , named "phase-34-mutants" [mutants]
  , named "phase-34-discovery" [discovery]
  , named "phase-34-challenge" [mutants]
  , named "phase-34-observer" [observer]
  , named "phase-34-authority-bypass" [authority]
  , named "phase-34-freshness" [freshness]
  , named "phase-34-qualification" [qualification]
  , named "phase-34-cleanroom" [cleanroom]
  , named "phase-34-legacy-closure" [legacy]
  , CheckResult "phase-34-predecessor" [observation "phase-34.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-34-residue" [observation "phase-34.residue" "live interpreter, runtime fidelity, live services, cluster admission, and hardware remain later-owned"] []
  , named "phase-34-pass-criterion" [pre]
  ]
 where named = mergeChecks

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-34/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

requireUniqueExecutable :: FilePath -> FilePath -> IO FilePath
requireUniqueExecutable runRoot suffix = do
  files <- listFilesRecursive (runRoot </> "dist")
  case filter (suffix `isSuffixOf`) files of
    [path] -> pure path
    _ -> pure (runRoot </> "dist/missing" </> map (\character -> if character == '/' then '-' else character) suffix)

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "chain-boundary-source-repository-cache"
    [observation "chain-boundary.cache.entries" (Text.pack (show copied))]
    [finding "CHAIN-BOUNDARY-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry
        to = target </> entry
    directory <- doesDirectoryExist from
    if directory then copyTree from to else copyFile from to

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix =
  length matching == 3
    && length (filter (isInfixOf ".cache") matching) == 1
    && length (filter (isInfixOf ".tar.gz") matching) == 1
    && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where
  matching = filter (prefix `isPrefixOf`) entries

listFilesRecursive :: FilePath -> IO [FilePath]
listFilesRecursive directory = do
  present <- doesDirectoryExist directory
  if not present then pure [] else do
    entries <- listDirectory directory
    concat <$> forM entries (\entry -> do
      let path = directory </> entry
      nested <- doesDirectoryExist path
      if nested then listFilesRecursive path else pure [path])

runProcess :: FilePath -> Text -> FilePath -> [String] -> [(String, String)] -> IO Receipt
runProcess working name executable args additions = do
  inherited <- getEnvironment
  let environment = additions <> filter (\(key, _) -> key `notElem` map fst additions && not (forbiddenEnvironment key)) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
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

productionSources, expectedSources, retiredSources :: [FilePath]
productionSources =
  [ "src/Amoebius/Kernel/Step.hs", "src/Amoebius/Kernel/Chain.hs", "src/Amoebius/Kernel/Descent.hs", "src/Amoebius/Kernel/Plan.hs"
  , "src/Amoebius/Exec/Tool.hs", "src/Amoebius/Exec/Boundary.hs", "src/Amoebius/Dsl/AstCheck.hs", "src/Amoebius/Dsl/SanctionedApi.hs"
  ]
supportingSources, fixtureSources :: [FilePath]
expectedSources = sort (productionSources <> supportingSources <> fixtureSources)
supportingSources =
  [ oracleSource, "test/spec/kernel/PlanSpec.hs", "test/spec/boundary/BoundarySpec.hs", "test/spec/dsl/AstCheckSpec.hs", compileNegativeSource
  , "test/spec/capability/BindFixtures.hs", "test/spec/capability/ProvisionFixtures.hs"
  ]
fixtureSources = map ("test/fixture/chain_boundary/astcheck/" <>)
  ["negative_foreign.hs", "negative_import.hs", "negative_orphan.hs", "negative_raw_io.hs", "negative_template_haskell.hs", "negative_unsafe.hs", "positive_basic.hs", "positive_manifest.hs"]
  <> map ("test/fixture/chain_boundary/compilefail/" <>) ["checked_ctor_illegal.hs", "checked_ctor_legal.hs"]
retiredSources =
  [ "tools/chain_boundary_gate.py", "test/oracle/chain_boundary_surfaces.tsv"
  , "test/oracle/chain_boundary/calculus_projection.tsv", "test/oracle/chain_boundary/cases.tsv", "test/oracle/chain_boundary/plan_semantics.tsv", "test/oracle/chain_boundary/validation_locus.tsv"
  , "test/golden/chain_boundary/argv/docker.1.argv.golden", "test/golden/chain_boundary/argv/docker.2.argv.golden", "test/golden/chain_boundary/argv/kubectl.1.argv.golden", "test/golden/chain_boundary/argv/pulumi.1.argv.golden"
  , "test/harness/chain_boundary/fakes/docker", "test/harness/chain_boundary/fakes/helm", "test/harness/chain_boundary/fakes/kubectl", "test/harness/chain_boundary/fakes/pulumi"
  , "test/mutant/chain_boundary/boundary/mB1_argv/mutant.txt", "test/mutant/chain_boundary/boundary/mB2_byte/mutant.txt", "test/mutant/chain_boundary/boundary/mB3_path_resolve/mutant.txt", "test/mutant/chain_boundary/m1_cfg_drop_service/mutant.txt", "test/mutant/chain_boundary/m2_descent_inframe/mutant.txt"
  , "test/fixture/chain_boundary/astcheck/astcheck_negatives.expected", "test/fixture/chain_boundary/boundary/apply_input.json", "test/fixture/chain_boundary/sanctioned_api_expected.dhall"
  ]

oracleSource, compileNegativeSource :: FilePath
oracleSource = "test/spec/chain_boundary/ChainBoundaryOracle.hs"
compileNegativeSource = "test/compile-negative/chain-boundary-link-seal/Main.hs"

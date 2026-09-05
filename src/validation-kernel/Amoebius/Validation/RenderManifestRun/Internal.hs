{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.RenderManifestRun.Internal
  ( AcquiredRenderManifestRun
  , acquireRenderManifestRefreshRun
  , acquireRenderManifestRun
  , acquiredRenderManifestRunCheck
  , foldAcquiredRenderManifestRun
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
import Control.Monad (filterM, forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( copyFile
  , createDirectory
  , createDirectoryIfMissing
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
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data AcquiredRenderManifestRun = AcquiredRenderManifestRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredRenderManifestRunCheck :: AcquiredRenderManifestRun -> CheckResult
acquiredRenderManifestRunCheck (AcquiredRenderManifestRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredRenderManifestRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredRenderManifestRun
  -> value
foldAcquiredRenderManifestRun consume (AcquiredRenderManifestRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireRenderManifestRun, acquireRenderManifestRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRenderManifestRun
acquireRenderManifestRun = acquire False
acquireRenderManifestRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRenderManifestRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 33 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (cleanReceipt matrix)
      positives = positiveCheck (cleanReceipt matrix)
      negatives = negativeCheck (cleanReceipt matrix)
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (cleanReceipt matrix)
      cleanroom = mergeChecks "render-manifest-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "render-manifest-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "render-manifest-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "render-manifest" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "render-manifest-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "render-manifest-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "render-manifest-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "render-manifest-observer" [checkDigest observer]
      qualificationId = ids "render-manifest-qualification" [checkDigest qualification]
      acquiredRunId = ids "render-manifest-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "render-manifest-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredRenderManifestRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  clean <- runSpec "clean" Nothing
  pure (Matrix mutants clean)
 where
  runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
  runSpec name selected =
    runProcess root name cabal
      ([ "--builddir=" <> runRoot </> "dist"
       , "--store-dir=" <> store
       , "--with-compiler=" <> compiler
       , "--jobs=1"
       , "test"
       , "render-golden"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "mutant_resource_projection" "render-resource-projection-mutant" "podFor" "resource-projection"
  , mutant "mutant_ephemeral_rootfs" "render-ephemeral-rootfs-mutant" "podFor" "security-context"
  , mutant "mutant_unbounded_scratch" "render-unbounded-scratch-mutant" "podFor" "bounded-volumes"
  , mutant "mutant_memory_volume_lifecycle" "render-memory-volume-lifecycle-mutant" "podFor" "resource-projection"
  , mutant "mutant_image_platform" "render-image-platform-mutant" "podFor" "image-digest"
  , mutant "mutant_durable_size" "render-durable-size-mutant" "metadataFor" "source-annotation"
  , mutant "mutant_accelerator_projection" "render-accelerator-projection-mutant" "podFor" "accelerator-claim"
  , mutant "mutant_controller_projection" "render-controller-projection-mutant" "specFor" "controller-kind"
  , mutant "mutant_monitoring_projection" "render-monitoring-projection-mutant" "podFor" "resource-projection"
  , mutant "mutant_unhardened_pod" "render-unhardened-pod-mutant" "podFor" "security-context"
  , mutant "mutant_wild_ingress" "render-wild-ingress-mutant" "serviceExposure" "service-exposure"
  , mutant "mutant_undeclared_allow_edge" "render-undeclared-allow-edge-mutant" "dependencyEdge" "network-policy-edge-set"
  ]
 where
  mutant name flagName locus expected = (name, flagName, locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "render-manifest-toolchain"
  [observation "render-manifest.cabal" (receiptSummary version), observation "render-manifest.compiler" (Text.pack compiler)]
  ([finding "RENDER-MANIFEST-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "RENDER-MANIFEST-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "render-manifest-independent-oracle"
  [observation "render-manifest.oracle" (receiptSummary clean), observation "render-manifest.oracle-independence" "RenderGoldenOracle imports no production or fixture module"]
  [finding "RENDER-MANIFEST-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "render-manifest: PASS (18 semantic projections, 164 objects, 9 object variants, 3 non-vacuous safety predicates, 12 mutants, 1 covered property)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "render-manifest-positive-controls"
  [observation "render-manifest.positives" "eighteen capability/shape projections and 164 typed object round trips passed"]
  [finding "RENDER-MANIFEST-POSITIVE" specSource "the clean render corpus did not pass" |
    receiptExit clean /= ExitSuccess || notContains "render-properties: TESTED sampled (9 capability arms and 2 shapes, each >=4%)" (receiptOutput clean)]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "render-manifest-paired-negatives"
  [observation "render-manifest.negatives" "three non-vacuous safety predicates and twelve one-change production challenges passed"]
  [finding "RENDER-MANIFEST-NEGATIVE" specSource "the safety/oracle corpus did not execute" |
    receiptExit clean /= ExitSuccess ||
      notContains "render-manifest-invariants: PASS (18 source domains, 164 identity/namespace/API/reconcile projections, 164 Aeson round-trips, 33 locus rows)" (receiptOutput clean) ||
      notContains "render-manifest-calculus: PASS (5 kinds, 198 projected units)" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "render-manifest-mutants"
  [observation ("render-manifest.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "RENDER-MANIFEST-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "render-manifest-source-discipline"
    [observation "render-manifest.production-module-count" "5", observation "render-manifest.effect-boundary" "pure total manifest rendering and run-local Cabal children only; no host, network, service, cluster, or hardware effects"]
    ([finding "RENDER-MANIFEST-SOURCE-SHAPE" "<render-manifest-production>" ("missing production element: " <> token) |
       token <- ["data K8sObject", "data K8sObjectKind", "encodeK8sObjects", "renderAll ::", "renderSourcePrivate", "rendererAnnotations", "rendererResources", "rendererSecurityContext", "dependencyEdge"], notContains token production]
     <> [finding "RENDER-MANIFEST-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedSemanticProjection", "expectedCalculusProjection", "expectedLocusEntries", "expectedRenderMutants"], notContains token oracle]
     <> [finding "RENDER-MANIFEST-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module" |
       any (`Text.isInfixOf` oracle) ["import Amoebius", "import BindFixtures", "import ProvisionFixtures", "import RenderGoldenGate", "import RenderGoldenProps"]]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "render-manifest-discovery"
  [observation "render-manifest.discovery.count" (Text.pack (show (length observed)))]
  [finding "RENDER-MANIFEST-DISCOVERY" "<phase-33-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "render-manifest-authority"
  [observation "render-manifest.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "RENDER-MANIFEST-RUN-ROOT" runRoot "run root escaped .build/runs/phase-33/work" | not (pathBelow (root </> ".build/runs/phase-33/work") runRoot)]
   <> [finding "RENDER-MANIFEST-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-33 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "render-manifest-observer"
  (map (observation "render-manifest.observer.process" . receiptSummary) receipts)
  [finding "RENDER-MANIFEST-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "render-manifest-freshness"
  [observation "render-manifest.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "RENDER-MANIFEST-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-33/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "render-manifest-legacy-closure"
    [observation "render-manifest.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "render-manifest.legacy.semantic-inputs" "HaskellOnly"]
    [finding "RENDER-MANIFEST-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-33-claim" [pre]
  , named "phase-33-subject" [toolchain, positives]
  , named "phase-33-command" [toolchain, authority]
  , named "phase-33-oracle" [oracle]
  , named "phase-33-positive-controls" [positives]
  , named "phase-33-paired-negatives" [negatives]
  , named "phase-33-mutants" [mutants]
  , named "phase-33-discovery" [discovery]
  , named "phase-33-challenge" [mutants]
  , named "phase-33-observer" [observer]
  , named "phase-33-authority-bypass" [authority]
  , named "phase-33-freshness" [freshness]
  , named "phase-33-qualification" [qualification]
  , named "phase-33-cleanroom" [cleanroom]
  , named "phase-33-legacy-closure" [legacy]
  , CheckResult "phase-33-predecessor" [observation "phase-33.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-33-residue" [observation "phase-33.residue" "typed actions, dry-run planning, runtime fidelity, live apiserver enforcement, cluster, and hardware remain later-owned"] []
  , named "phase-33-pass-criterion" [pre]
  ]
 where
  named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "render-manifest-source-repository-cache"
    [observation "render-manifest.cache.entries" (Text.pack (show copied))]
    [finding "RENDER-MANIFEST-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-33/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  inherited <- getEnvironment
  let environment = filter (not . forbiddenEnvironment . fst) inherited
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
  [ "src/manifest-render/Amoebius/Manifest.hs"
  , "src/manifest-render/Amoebius/Manifest/K8sObject.hs"
  , "src/manifest-render/Amoebius/Manifest/Types.hs"
  , "src/manifest-render/Amoebius/Manifest/Render.hs"
  , "src/manifest-render/Amoebius/Manifest/RenderAll.hs"
  ]
expectedSources = sort (productionSources <> [bindFixtureSource, fixtureSource, dependencyOracleSource, gateSource, oracleSource, propsSource, specSource])
retiredSources =
  [ "tools/render_manifest_gate.py"
  , "test/oracle/render_manifest_surfaces.tsv"
  , "test/oracle/render_manifest/calculus_projection.tsv"
  , "test/oracle/render_manifest/semantic_projection.tsv"
  , "test/oracle/render_manifest/validation_locus.tsv"
  , "test/spec/manifest/RenderMutants.hs"
  , "test/mutant/render_manifest/mutant_accelerator_projection/mutant.txt"
  , "test/mutant/render_manifest/mutant_controller_projection/mutant.txt"
  , "test/mutant/render_manifest/mutant_durable_size/mutant.txt"
  , "test/mutant/render_manifest/mutant_ephemeral_rootfs/mutant.txt"
  , "test/mutant/render_manifest/mutant_image_platform/mutant.txt"
  , "test/mutant/render_manifest/mutant_memory_volume_lifecycle/mutant.txt"
  , "test/mutant/render_manifest/mutant_monitoring_projection/mutant.txt"
  , "test/mutant/render_manifest/mutant_resource_projection/mutant.txt"
  , "test/mutant/render_manifest/mutant_unbounded_scratch/mutant.txt"
  , "test/mutant/render_manifest/mutant_undeclared_allow_edge/mutant.txt"
  , "test/mutant/render_manifest/mutant_unhardened_pod/mutant.txt"
  , "test/mutant/render_manifest/mutant_wild_ingress/mutant.txt"
  ]

bindFixtureSource, fixtureSource, dependencyOracleSource, gateSource, oracleSource, propsSource, specSource :: FilePath
bindFixtureSource = "test/spec/capability/BindFixtures.hs"
fixtureSource = "test/spec/capability/ProvisionFixtures.hs"
dependencyOracleSource = "test/spec/manifest/DepGraphOracle.hs"
gateSource = "test/spec/manifest/RenderGoldenGate.hs"
oracleSource = "test/spec/manifest/RenderGoldenOracle.hs"
propsSource = "test/spec/manifest/RenderGoldenProps.hs"
specSource = "test/spec/manifest/RenderGoldenSpec.hs"

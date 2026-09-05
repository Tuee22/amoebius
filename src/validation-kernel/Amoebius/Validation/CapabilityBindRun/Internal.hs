{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CapabilityBindRun.Internal
  ( AcquiredCapabilityBindRun
  , acquireCapabilityBindRefreshRun
  , acquireCapabilityBindRun
  , acquiredCapabilityBindRunCheck
  , foldAcquiredCapabilityBindRun
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

data AcquiredCapabilityBindRun = AcquiredCapabilityBindRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredCapabilityBindRunCheck :: AcquiredCapabilityBindRun -> CheckResult
acquiredCapabilityBindRunCheck (AcquiredCapabilityBindRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredCapabilityBindRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredCapabilityBindRun
  -> value
foldAcquiredCapabilityBindRun consume (AcquiredCapabilityBindRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireCapabilityBindRun, acquireCapabilityBindRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredCapabilityBindRun
acquireCapabilityBindRun = acquire False
acquireCapabilityBindRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredCapabilityBindRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 30 acquired
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
      cleanroom = mergeChecks "capability-bind-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "capability-bind-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "capability-bind-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "capability-bind" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "capability-bind-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "capability-bind-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "capability-bind-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "capability-bind-observer" [checkDigest observer]
      qualificationId = ids "capability-bind-qualification" [checkDigest qualification]
      acquiredRunId = ids "capability-bind-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "capability-bind-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredCapabilityBindRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
       , "capability-bind-spec"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "copy-shape-tag" "providerGraph" "shape structural projection drifted"
  , mutant "catchall-arm" "capabilityArm" "capability arm drifted"
  , mutant "shared-app-import" "renderCapabilityNeedSurface" "app surface projection drifted"
  , mutant "provisioned-value-in-bound-deployment" "boundDeploymentIsUnprovisioned" "bound deployment crossed provision boundary"
  ]
 where
  mutant name locus expected = (name, "capability-bind-" <> Text.unpack name <> "-mutant", locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "capability-bind-toolchain"
  [observation "capability-bind.cabal" (receiptSummary version), observation "capability-bind.compiler" (Text.pack compiler)]
  ([finding "CAPABILITY-BIND-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "CAPABILITY-BIND-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "capability-bind-independent-oracle"
  [observation "capability-bind.oracle" (receiptSummary clean), observation "capability-bind.oracle-independence" "CapabilityBindOracle imports no production or fixture module"]
  [finding "CAPABILITY-BIND-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "PASS (9 arms, 18 shapes, 7 paired negatives, 1 property, 4 changed-production mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "capability-bind-positive-controls"
  [observation "capability-bind.positives" "nine capability arms bind under two shapes and retain exact app-surface identities"]
  [finding "CAPABILITY-BIND-POSITIVE" specSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "capability-bind-paired-negatives"
  [observation "capability-bind.negatives" "seven minimally different pairs cover Dhall foreclosure, provider, coverage, cycle, and shadowing boundaries"]
  [finding "CAPABILITY-BIND-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "7 paired negatives" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "capability-bind-mutants"
  [observation ("capability-bind.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "CAPABILITY-BIND-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "capability-bind-source-discipline"
    [observation "capability-bind.production-module-count" "4", observation "capability-bind.effect-boundary" "pure bind/Dhall semantics and run-local Cabal children only; no host, network, service, cluster, or hardware effects"]
    ([finding "CAPABILITY-BIND-SOURCE-SHAPE" "<capability-bind-production>" ("missing production element: " <> token) |
       token <- ["renderCapabilityNeedSurface", "renderCapabilityArmDhallType", "bind ::", "boundDeploymentIsUnprovisioned", "phase30MutationTargets"], notContains token production]
     <> [finding "CAPABILITY-BIND-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedRows", "expectedNegatives", "mutantSpecs", "expectedCalculusProjection"], notContains token oracle]
     <> [finding "CAPABILITY-BIND-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module" |
       any (`Text.isInfixOf` oracle) ["import Amoebius", "import BindFixtures", "import BindGate"]]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "capability-bind-discovery"
  [observation "capability-bind.discovery.count" (Text.pack (show (length observed)))]
  [finding "CAPABILITY-BIND-DISCOVERY" "<phase-30-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "capability-bind-authority"
  [observation "capability-bind.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "CAPABILITY-BIND-RUN-ROOT" runRoot "run root escaped .build/runs/phase-30/work" | not (pathBelow (root </> ".build/runs/phase-30/work") runRoot)]
   <> [finding "CAPABILITY-BIND-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-30 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "capability-bind-observer"
  (map (observation "capability-bind.observer.process" . receiptSummary) receipts)
  [finding "CAPABILITY-BIND-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "capability-bind-freshness"
  [observation "capability-bind.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "CAPABILITY-BIND-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-30/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "capability-bind-legacy-closure"
    [observation "capability-bind.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "capability-bind.legacy.semantic-inputs" "HaskellOnly"]
    [finding "CAPABILITY-BIND-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-30-claim" [pre]
  , named "phase-30-subject" [toolchain, positives]
  , named "phase-30-command" [toolchain, authority]
  , named "phase-30-oracle" [oracle]
  , named "phase-30-positive-controls" [positives]
  , named "phase-30-paired-negatives" [negatives]
  , named "phase-30-mutants" [mutants]
  , named "phase-30-discovery" [discovery]
  , named "phase-30-challenge" [mutants]
  , named "phase-30-observer" [observer]
  , named "phase-30-authority-bypass" [authority]
  , named "phase-30-freshness" [freshness]
  , named "phase-30-qualification" [qualification]
  , named "phase-30-cleanroom" [cleanroom]
  , named "phase-30-legacy-closure" [legacy]
  , CheckResult "phase-30-predecessor" [observation "phase-30.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-30-residue" [observation "phase-30.residue" "provision seal, availability relation, rendering, effects, runtime fidelity, live services, cluster, and hardware remain later-owned"] []
  , named "phase-30-pass-criterion" [pre]
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
  pure (CheckResult "capability-bind-source-repository-cache"
    [observation "capability-bind.cache.entries" (Text.pack (show copied))]
    [finding "CAPABILITY-BIND-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-30/work"
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
  [ "src/capability-bind/Amoebius/Capability/Binding.hs"
  , "src/capability-bind/Amoebius/Capability/Phase30Mutation.hs"
  , "src/capability-bind/Amoebius/Capability/Types.hs"
  , "src/capability-bind/Amoebius/Dsl/Error.hs"
  ]
expectedSources = sort (productionSources <> [fixtureSource, gateSource, oracleSource, propsSource, shapeSource, specSource])
retiredSources =
  [ "tools/capability_bind_gate.py"
  , "test/oracle/capability_bind_surfaces.tsv"
  , "test/oracle/capability_bind/arm_cases.tsv"
  , "test/oracle/capability_bind/bound_shape_semantics.tsv"
  , "test/oracle/capability_bind/calculus_projection.tsv"
  , "test/oracle/capability_bind/dhall_typecheck_cases.tsv"
  , "test/oracle/capability_bind/gadt_decode_cases.tsv"
  , "test/oracle/capability_bind/validation_locus.tsv"
  , "test/spec/capability/BindMutants.hs"
  , "test/mutant/capability_bind/mutant_catchall_arm/mutant.txt"
  , "test/mutant/capability_bind/mutant_copy_shape_tag/mutant.txt"
  , "test/mutant/capability_bind/mutant_provisioned_value_in_bound_deployment/mutant.txt"
  , "test/mutant/capability_bind/mutant_shared_app_import/mutant.txt"
  ]

fixtureSource, gateSource, oracleSource, propsSource, shapeSource, specSource :: FilePath
fixtureSource = "test/spec/capability/BindFixtures.hs"
gateSource = "test/spec/capability/BindGate.hs"
oracleSource = "test/spec/capability/CapabilityBindOracle.hs"
propsSource = "test/spec/capability/BindProps.hs"
shapeSource = "test/spec/capability/ShapeOracle.hs"
specSource = "test/spec/capability/CapabilityBindSpec.hs"

{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ImageRecipeRun.Internal
  ( AcquiredImageRecipeRun
  , acquireImageRecipeRefreshRun
  , acquireImageRecipeRun
  , acquiredImageRecipeRunCheck
  , foldAcquiredImageRecipeRun
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

data AcquiredImageRecipeRun = AcquiredImageRecipeRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredImageRecipeRunCheck :: AcquiredImageRecipeRun -> CheckResult
acquiredImageRecipeRunCheck (AcquiredImageRecipeRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredImageRecipeRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredImageRecipeRun
  -> value
foldAcquiredImageRecipeRun consume (AcquiredImageRecipeRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireImageRecipeRun, acquireImageRecipeRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredImageRecipeRun
acquireImageRecipeRun = acquire False
acquireImageRecipeRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredImageRecipeRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 35 acquired
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
      cleanroom = mergeChecks "image-recipe-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "image-recipe-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "image-recipe-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "image-recipe" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "image-recipe-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "image-recipe-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "image-recipe-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "image-recipe-observer" [checkDigest observer]
      qualificationId = ids "image-recipe-qualification" [checkDigest qualification]
      acquiredRunId = ids "image-recipe-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "image-recipe-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredImageRecipeRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
       , "image-recipe-spec"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "recipe-buildx-subcommand" "image-recipe-buildx-subcommand-mutant" "BuildArgv.buildSubcommand" "build invocation is not a plain docker build"
  , mutant "recipe-second-platform" "image-recipe-second-platform-mutant" "BuildArgv.platformOverride" "build invocation carries a platform override"
  , mutant "recipe-authored-base-digest" "image-recipe-authored-base-digest-mutant" "RenderDockerfile.renderBaseFrom" "rendered recipe carries an authored base digest"
  ]
 where
  mutant name flagName locus expected = (name, flagName, locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "image-recipe-toolchain"
  [observation "image-recipe.cabal" (receiptSummary version), observation "image-recipe.compiler" (Text.pack compiler)]
  ([finding "IMAGE-RECIPE-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "IMAGE-RECIPE-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "image-recipe-independent-oracle"
  [observation "image-recipe.oracle" (receiptSummary clean), observation "image-recipe.oracle-independence" "ImageRecipeOracle imports no production or fixture module"]
  [finding "IMAGE-RECIPE-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "image-recipe-spec: PASS (4 exact build invocations, 44 argv tokens, 2 architecture refusals, 3 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "image-recipe-positive-controls"
  [observation "image-recipe.positives" "twenty-two ordered steps, four exact native build vectors, two mismatch refusals, and two deterministic renders passed"]
  [finding "IMAGE-RECIPE-POSITIVE" specSource "the clean recipe corpus did not pass" |
    receiptExit clean /= ExitSuccess || notContains "image-recipe-invariants: PASS (3 stages, 22 semantic step projections, 1 dynamic base, 0 authored base digests, 2 deterministic renders)" (receiptOutput clean)]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "image-recipe-paired-negatives"
  [observation "image-recipe.negatives" "bare engine paths and two cross-architecture requests refused; three production mutations were paired separately"]
  [finding "IMAGE-RECIPE-NEGATIVE" specSource "the recipe calculus and paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess ||
      notContains "image-recipe-calculus: PASS (5 kinds, 77 projected units)" (receiptOutput clean) ||
      notContains "2 architecture refusals" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "image-recipe-mutants"
  [observation ("image-recipe.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "IMAGE-RECIPE-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "image-recipe-source-discipline"
    [observation "image-recipe.production-module-count" "5", observation "image-recipe.effect-boundary" "pure typed catalog, total Dockerfile rendering, pure argv construction, and run-local Cabal children only; no engine, network, service, cluster, or hardware effects"]
    ([finding "IMAGE-RECIPE-SOURCE-SHAPE" "<image-recipe-production>" ("missing production element: " <> token) |
       token <- ["data BakeStep", "canonicalBakeCatalog :: BakeCatalog", "newtype BaseChannel", "buildImageInvocation", "renderDockerfile"], notContains token production]
     <> [finding "IMAGE-RECIPE-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["recipeRows", "buildCaseRows", "argvRows", "calculusProjection", "mutantLoci", "validationLoci"], notContains token oracle]
     <> [finding "IMAGE-RECIPE-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module" |
       "import Amoebius" `Text.isInfixOf` oracle]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "image-recipe-discovery"
  [observation "image-recipe.discovery.count" (Text.pack (show (length observed)))]
  [finding "IMAGE-RECIPE-DISCOVERY" "<phase-35-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "image-recipe-authority"
  [observation "image-recipe.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "IMAGE-RECIPE-RUN-ROOT" runRoot "run root escaped .build/runs/phase-35/work" | not (pathBelow (root </> ".build/runs/phase-35/work") runRoot)]
   <> [finding "IMAGE-RECIPE-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-35 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "image-recipe-observer"
  (map (observation "image-recipe.observer.process" . receiptSummary) receipts)
  [finding "IMAGE-RECIPE-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "image-recipe-freshness"
  [observation "image-recipe.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "IMAGE-RECIPE-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-35/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "image-recipe-legacy-closure"
    [observation "image-recipe.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "image-recipe.legacy.semantic-inputs" "HaskellOnly"]
    [finding "IMAGE-RECIPE-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-35-claim" [pre]
  , named "phase-35-subject" [toolchain, positives]
  , named "phase-35-command" [toolchain, authority]
  , named "phase-35-oracle" [oracle]
  , named "phase-35-positive-controls" [positives]
  , named "phase-35-paired-negatives" [negatives]
  , named "phase-35-mutants" [mutants]
  , named "phase-35-discovery" [discovery]
  , named "phase-35-challenge" [mutants]
  , named "phase-35-observer" [observer]
  , named "phase-35-authority-bypass" [authority]
  , named "phase-35-freshness" [freshness]
  , named "phase-35-qualification" [qualification]
  , named "phase-35-cleanroom" [cleanroom]
  , named "phase-35-legacy-closure" [legacy]
  , CheckResult "phase-35-predecessor" [observation "phase-35.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-35-residue" [observation "phase-35.residue" "base resolution, engine execution, image build, registry publication, runtime probes, cluster behavior, and hardware remain later-owned"] []
  , named "phase-35-pass-criterion" [pre]
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
  pure (CheckResult "image-recipe-source-repository-cache"
    [observation "image-recipe.cache.entries" (Text.pack (show copied))]
    [finding "IMAGE-RECIPE-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-35/work"
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
  [ "src/Amoebius/Image/BakeInventory.hs"
  , "src/Amoebius/Image/CanonicalBakeCatalog.hs"
  , "src/Amoebius/Image/BaseChannel.hs"
  , "src/Amoebius/Image/BuildArgv.hs"
  , "src/Amoebius/Image/RenderDockerfile.hs"
  ]
expectedSources = sort (productionSources <> [oracleSource, specSource])
retiredSources =
  [ "dhall/amoebius/BakeCatalog.dhall"
  , "tools/amoebius_image_recipe_gate.py"
  , "test/oracle/amoebius_image_recipe_surfaces.tsv"
  , "test/oracle/amoebius_image_recipe/build_argv.tsv"
  , "test/oracle/amoebius_image_recipe/build_cases.tsv"
  , "test/oracle/amoebius_image_recipe/calculus_projection.tsv"
  , "test/oracle/amoebius_image_recipe/recipe_semantics.tsv"
  , "test/oracle/amoebius_image_recipe/validation_locus.tsv"
  , "test/mutant/amoebius_image_recipe/recipe-authored-base-digest/mutant.txt"
  , "test/mutant/amoebius_image_recipe/recipe-buildx-subcommand/mutant.txt"
  , "test/mutant/amoebius_image_recipe/recipe-second-platform/mutant.txt"
  ]

oracleSource, specSource :: FilePath
oracleSource = "test/spec/image/ImageRecipeOracle.hs"
specSource = "test/spec/image/ImageRecipeSpec.hs"

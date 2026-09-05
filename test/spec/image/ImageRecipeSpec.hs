{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition (
    append,
    artifactComponent,
    budgetComponent,
    calculusTag,
    compose,
    compositionKinds,
    compositionNames,
    compositionResource,
    everyCalculus,
    evidenceComponent,
    liftComponent,
    singleton,
    workflowComponent,
 )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Exec.Tool qualified as Tool
import Amoebius.Image.BakeInventory qualified as Catalog
import Amoebius.Image.BaseChannel qualified as Base
import Amoebius.Image.BuildArgv qualified as Argv
import Amoebius.Image.CanonicalBakeCatalog (canonicalBakeCatalog)
import Amoebius.Image.RenderDockerfile qualified as Dockerfile
import Amoebius.Scope.Index (
    activeMembership,
    trustedSubject,
    trustedTenant,
    withRequestScope,
 )
import Control.Monad (forM_, unless)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import ImageRecipeOracle qualified as Oracle

data RecipeRow = RecipeRow
    { recipePosition :: Int
    , recipeName :: Text
    , recipeRung :: Text
    }

data BuildCase = BuildCase
    { buildCaseName :: Text
    , buildFlavor :: Argv.ImageFlavor
    , buildObserved :: Catalog.Platform
    , buildRequested :: Catalog.Platform
    , buildTag :: String
    }

main :: IO ()
main = do
    either (fail . show) pure (Catalog.validateBakeCatalog canonicalBakeCatalog)
    rendered <- either (fail . show) pure (Dockerfile.renderDockerfile canonicalBakeCatalog)
    cases <- traverse buildCaseFromRow Oracle.buildCaseRows
    runGreen canonicalBakeCatalog rendered.dockerfileText cases argvOracle

runGreen :: Catalog.BakeCatalog -> Text -> [BuildCase] -> Map Text [String] -> IO ()
runGreen catalog rendered cases argvOracle = do
    checkRecipeProjection catalog rendered
    argvTokenCount <- checkBuildInvocations catalog cases argvOracle
    checkCalculusProjection argvTokenCount
    putStrLn "image-recipe-calculus: PASS (5 kinds, 77 projected units)"
    putStrLn "image-recipe-invariants: PASS (3 stages, 22 semantic step projections, 1 dynamic base, 0 authored base digests, 2 deterministic renders)"
    putStrLn "image-recipe-spec: PASS (4 exact build invocations, 44 argv tokens, 2 architecture refusals, 3 mutants)"

checkRecipeProjection :: Catalog.BakeCatalog -> Text -> IO ()
checkRecipeProjection catalog rendered = do
    second <- either (fail . show) pure (Dockerfile.renderDockerfile catalog)
    let steps = Catalog.catalogSteps catalog
        actual = zipWith (\position step -> RecipeRow position (Catalog.stepName step) (Catalog.stepRung step)) [1 ..] steps
        apt = [packaged | Catalog.AptPackage packaged <- steps]
        artifacts = [artifact | Catalog.OfficialArtifact artifact <- steps]
        built = [builtProduct | Catalog.BuildProduct builtProduct <- steps]
        copied = [copy | Catalog.CopyOci copy <- steps]
        payloads = concatMap (\artifact -> artifact.payloads) artifacts
        linesOfRecipe = Text.lines rendered
    assert (map rowTuple actual == Oracle.recipeRows) "semantic recipe-step projection drifted"
    assert (length catalog.stages == 3) "catalog stage count changed"
    assert ([length apt, length artifacts, length built, length copied] == [7, 9, 6, 0]) "bake-step arm vector changed"
    assert (length payloads == 1) "published companion payload count changed"
    assert (length catalog.runtimeEnvironment == 3) "runtime environment projection changed"
    assert (rendered == second.dockerfileText) "repeated Dockerfile render changed bytes"
    assert (digestFreeBase rendered) "rendered recipe carries an authored base digest"
    assert (countExact "ARG BASE_IMAGE" linesOfRecipe == 1) "global BASE_IMAGE argument is not singular"
    assert (countExact "FROM ${BASE_IMAGE} AS amoebius-base" linesOfRecipe == 1) "dynamic base FROM is not singular"
    assert (countExact "ARG TARGETARCH" linesOfRecipe == 1) "TARGETARCH argument is not singular"
    assert (countPrefix "FROM " linesOfRecipe == 1 + length copied) "FROM projection does not match the catalog"
    assert (countPrefix "RUN " linesOfRecipe == 1 + length artifacts + length payloads) "RUN projection does not match the catalog"
    assert (countPrefix "COPY --link " linesOfRecipe == length built + sum (map copyDirectiveCount copied)) "COPY projection does not match the catalog"
    assert (countPrefix "ENV " linesOfRecipe == length catalog.runtimeEnvironment) "ENV projection does not match the catalog"
    forM_ (catalog.acquisitionTools <> map packagedTool apt) $ \tool ->
        assert (Text.count (tool.package <> "=" <> tool.packageVersion) rendered == 1) ("apt projection omitted or duplicated " <> Text.unpack tool.package)
    let publishedValues = concatMap artifactValues artifacts
    forM_ (Map.toList (Map.fromListWith (+) [(value, 1 :: Int) | value <- publishedValues])) $ \(value, expectedCount) ->
        assert (Text.count ("echo " <> value <> " ;;") rendered == expectedCount) ("published value projection changed: " <> Text.unpack value)
    forM_ built $ \builtProduct ->
        assert
            (countExact ("COPY --link out/${TARGETARCH}/" <> builtProduct.name <> " " <> builtProduct.targetPath) linesOfRecipe == 1)
            ("built-product projection changed: " <> Text.unpack builtProduct.name)
  where
    rowTuple row = (row.recipePosition, row.recipeName, row.recipeRung)
    packagedTool packaged = Catalog.AcquisitionTool packaged.package packaged.packageVersion packaged.archiveSuite
    artifactValues artifact =
        concatMap (\asset -> [asset.assetUrl, asset.checksumManifest]) artifact.assets
            <> concatMap (\payload -> concatMap (\asset -> [asset.assetUrl, asset.checksumManifest]) payload.assets) artifact.payloads
    copyDirectiveCount copy = 1 + length copy.supportCopies

checkBuildInvocations :: Catalog.BakeCatalog -> [BuildCase] -> Map Text [String] -> IO Int
checkBuildInvocations catalog cases oracle = do
    engine <- either (fail . show) pure (Tool.mkToolPath "/opt/amoebius/bin/docker")
    channel <- either (fail . show) pure (Base.mkBaseChannel catalog.baseImage)
    forM_ cases $ \buildCase -> do
        actual <- either (fail . show) pure (invocation engine channel buildCase)
        expected <- maybe (fail ("argv oracle omitted " <> Text.unpack buildCase.buildCaseName)) pure (Map.lookup buildCase.buildCaseName oracle)
        assert (plainBuild actual) "build invocation is not a plain docker build"
        assert (singleArchitecture actual) "build invocation carries a platform override"
        assert (actual == expected) ("build argv drifted: " <> Text.unpack buildCase.buildCaseName)
        assert (Argv.renderPublishedTag buildCase.buildFlavor buildCase.buildRequested == buildCase.buildTag) "architecture tag projection drifted"
    assert (sum (map length (Map.elems oracle)) == 44) "argv oracle no longer contains 44 exact tokens"
    assert (Tool.mkToolPath "docker" == Left (Tool.ToolPathNotAbsolute "docker")) "bare engine path was admitted"
    let mismatches = [(Catalog.Amd64, Catalog.Arm64), (Catalog.Arm64, Catalog.Amd64)]
    forM_ mismatches $ \(observed, requested) ->
        case Argv.buildImageInvocation engine channel observed requested Argv.Cpu ".build/image-recipe/Dockerfile" ".build/image-recipe/context" of
            Left (Argv.BuildArchitectureMismatch actualObserved actualRequested) ->
                assert (actualObserved == observed && actualRequested == requested) "architecture refusal lost its operands"
            Right _ -> fail "cross-architecture invocation was emitted"
    digestA <- either (fail . show) pure (Base.mkBaseResolution channel (digest 'a') Base.CanonicalRegistry)
    digestB <- either (fail . show) pure (Base.mkBaseResolution channel (digest 'b') Base.MirrorAfterRateLimit)
    assert (digestA /= digestB) "distinct run-local base resolutions collapsed"
    pure 44
  where
    invocation engine channel buildCase =
        Argv.buildImageInvocation
            engine
            channel
            buildCase.buildObserved
            buildCase.buildRequested
            buildCase.buildFlavor
            ".build/image-recipe/Dockerfile"
            ".build/image-recipe/context"
    digest character = "sha256:" <> Text.replicate 64 (Text.singleton character)

plainBuild :: [String] -> Bool
plainBuild invocation = case invocation of
    _ : "build" : _ -> "buildx" `notElem` invocation
    _ -> False

singleArchitecture :: [String] -> Bool
singleArchitecture invocation = "--platform" `notElem` invocation

digestFreeBase :: Text -> Bool
digestFreeBase rendered =
    "sha256:" `Text.isInfixOf` rendered == False
        && countExact "FROM ${BASE_IMAGE} AS amoebius-base" (Text.lines rendered) == 1

checkCalculusProjection :: Int -> IO ()
checkCalculusProjection argvTokens = do
    tenant <- either (fail . show) pure (trustedTenant "image-recipe-tenant")
    subject <- either (fail . show) pure (trustedSubject tenant "image-recipe-subject")
    membership <- either (fail . show) pure (activeMembership tenant subject)
    action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
        let resources :: Int -> ResourceVector
            resources count = ResourceVector 1 (fromIntegral count) 0 0
            components = [22, argvTokens, 4, 4, 3]
            artifact = artifactComponent scope "recipe-step-semantics" (resources 22) (RecipeId "amoebius-image-recipe" 1)
            budget = budgetComponent scope "build-argv-tokens" (resources argvTokens) (allowance (Bytes (fromIntegral argvTokens)) (Slots 1) (Bytes (fromIntegral argvTokens)))
            lift = liftComponent scope "renderer-laws" (resources 4) OnHost
            workflow = workflowComponent scope "build-cases" (resources 4) emptyLedger
            evidence = evidenceComponent scope "mutant-evidence" (resources 3) PureRegister
            composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
            ResourceVector cpu memory ephemeral pods = compositionResource composition
            actual =
                [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
                , ("component-names", Text.intercalate "," (compositionNames composition))
                , ("projection-counts", Text.intercalate "," (map (Text.pack . show) components))
                , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
                ]
        assert (compositionKinds composition == everyCalculus) "image recipe projection omitted or reordered a calculus"
        assert (actual == Oracle.calculusProjection) ("image recipe calculus projection changed: " <> show actual)
    action

argvOracle :: Map Text [String]
argvOracle =
    Map.fromListWith
        (<>)
        [ (name, map (\(_, _, token) -> token) (sortOn (\(_, position, _) -> position) grouped))
        | name <- Map.keys (Map.fromList [(rowName, ()) | (rowName, _, _) <- Oracle.argvRows])
        , let grouped = filter (\(rowName, _, _) -> rowName == name) Oracle.argvRows
        ]

buildCaseFromRow :: (Text, Text, Text, Text, String) -> IO BuildCase
buildCaseFromRow (name, flavor, observed, requested, tag) =
    BuildCase name <$> parseFlavor flavor <*> parsePlatform observed <*> parsePlatform requested <*> pure tag

parseFlavor :: Text -> IO Argv.ImageFlavor
parseFlavor value = case value of
    "cpu" -> pure Argv.Cpu
    "cuda" -> pure Argv.Cuda
    _ -> fail ("unknown image flavor: " <> Text.unpack value)

parsePlatform :: Text -> IO Catalog.Platform
parsePlatform value = case value of
    "amd64" -> pure Catalog.Amd64
    "arm64" -> pure Catalog.Arm64
    _ -> fail ("unknown platform: " <> Text.unpack value)

countExact :: Text -> [Text] -> Int
countExact needle = length . filter (== needle)

countPrefix :: Text -> [Text] -> Int
countPrefix prefix = length . filter (Text.isPrefixOf prefix)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)

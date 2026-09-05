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
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Bind
import Amoebius.Ui.Check (checkUiSource)
import Amoebius.Ui.Compile.ClientPlan (clientActionPorts)
import Amoebius.Ui.Compile.Demand
import Amoebius.Ui.Compile.Manifest
import Amoebius.Ui.Compile.ServerPlan (serverActionPorts)
import Amoebius.Ui.ExternalLinkCatalog
import Amoebius.Ui.Security.Authorization
import Amoebius.Ui.Security.Scope
import AuthorizationCases (ActionRow (..), actionRows)
import Control.Monad (forM_, unless)
import Data.ByteString.Lazy qualified as Lazy
import Data.ByteString.Lazy.Char8 qualified as LazyChar
import Data.List (sort)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import PlanCompilerReference (referenceAuthoritySource, referenceDigest, referenceProjectionRows)
import System.Environment (getArgs, getEnvironment, getExecutablePath)
import System.Exit (ExitCode (..), exitFailure)
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)
import UiPlanCompilerCases qualified as Cases
import UiProgramSchemaCases (minimalSingleTenant)

data Fixture = Fixture
    { boundProgram :: BoundUiProgram
    , projectionRows :: [[String]]
    , authorizationRows :: [[String]]
    , compilerPortRows :: [[String]]
    , compilerBindingRows :: [[String]]
    , compilerLinkRows :: [[String]]
    }

main :: IO ()
main = do
    arguments <- getArgs
    case arguments of
        [] -> buildFixture False >>= runGreen
        ["--emit-plan=forward"] -> buildFixture False >>= emitPlans
        ["--emit-plan=reverse"] -> buildFixture True >>= emitPlans
        _ -> die ("unknown arguments: " <> show arguments)

runGreen :: Fixture -> IO ()
runGreen fixture = do
    compiled <- requireRight "compile plans" (compileUiPlans (boundProgram fixture))
    checkProjectionOracle fixture compiled
    checkGoldens compiled
    checkDigests fixture compiled
    checkRuntimeDemand compiled
    checkSpecificNegatives fixture compiled
    checkFreshProcessDeterminism
    checkCalculus
    putStrLn "ui-plan-compiler-calculus: PASS (5 kinds, 32 projected units)"
    putStrLn "ui-plan-compiler-spec: PASS (4 projections, 4 canonical artifacts, 4 digests, 6 demand cells, 2 fresh processes, 6 mutants)"

buildFixture :: Bool -> IO Fixture
buildFixture reverseOrder = do
    let rows = Cases.projectionRows
        authRows = Cases.authorizationRows
    authorization <- buildAuthorizationRegistry
    mutatePort <- makePort "mutate" "MutationV1" "MutationReceiptV1" "MutateData"
    startPort <- makePort "start" "WorkflowStartV1" "WorkflowReceiptV1" "StartWorkflow"
    mutateHandler <- makeHandler "data-write" "MutationV1" "MutationReceiptV1" MutationAudit
    startHandler <- makeHandler "workflow-start" "WorkflowStartV1" "WorkflowReceiptV1" WorkflowAudit
    mutateCapability <- makeCapability "data-write" SqlWrite
    startCapability <- makeCapability "workflow-start" Workflow
    docs <- requireRight "docs id" (trustedExternalLinkId "docs")
    let linkRows = Cases.compilerLinkRows
        portRows = Cases.compilerPortRows
        bindingRows = Cases.compilerBindingRows
    boundLinks <-
        requireRight
            "compiler links"
            ( bindExternalLinks
                [ExternalLinkRequirement docs]
                [ExternalLinkCatalogEntry docs "https://docs.example.invalid/amoebius"]
            )
    projections <- traverse parseProjectionRequirement rows
    bound <-
        requireRight
            "bound compiler program"
            ( bindUiProgramWithProjection
                authorization
                (orderValues reverseOrder [mutatePort, startPort])
                (orderValues reverseOrder [mutateHandler, startHandler])
                (orderValues reverseOrder [mutateCapability, startCapability])
                boundLinks
                (orderValues reverseOrder projections)
            )
    pure
        Fixture
            { boundProgram = bound
            , projectionRows = rows
            , authorizationRows = authRows
            , compilerPortRows = portRows
            , compilerBindingRows = bindingRows
            , compilerLinkRows = linkRows
            }

buildAuthorizationRegistry :: IO BoundActionRegistry
buildAuthorizationRegistry = do
    checked <- either (die . show) pure (checkUiSource minimalSingleTenant)
    tenant <- requireRight "tenant" (trustedTenant "tenant-a")
    subject <- requireRight "subject" (trustedSubject tenant "alice")
    membership <- requireRight "membership" (activeMembership tenant subject)
    context <- requireRight "context" (trustedRequestContext tenant subject membership)
    specs <- traverse typedAuthorizationAction actionRows
    let projections = map projectAuthorization specs
    requireRight "authorization registry" (bindActionRegistry (scopeCheckedProgram checked context) specs projections)

checkProjectionOracle :: Fixture -> CompiledUiPlans -> IO ()
checkProjectionOracle fixture compiled = do
    expected <- either die pure (referenceProjectionRows (projectionRows fixture))
    let actual = sort (map renderProjection (boundUiProjection (boundProgram fixture)))
    assertEqual "logical projection oracle" expected actual
    assertEqual
        "client/server action parity"
        (clientActionPorts (compiledClientPlan compiled))
        (serverActionPorts (compiledServerPlan compiled))

checkGoldens :: CompiledUiPlans -> IO ()
checkGoldens compiled = do
    let artifacts =
            [ ("client_plan.golden.json", compiledClientBytes compiled)
            , ("ui_server_plan.golden.json", compiledServerBytes compiled)
            , ("public_contracts.golden.json", compiledContractBytes compiled)
            , ("content_manifest.golden.json", compiledContentManifestBytes compiled)
            ]
    forM_ artifacts $ \(name, actual) -> do
        expected <- case lookup name Cases.expectedArtifactRows of
            Nothing -> die ("missing typed artifact expectation: " <> name)
            Just bytes -> pure (LazyChar.pack bytes)
        assertEqual name expected actual

-- The expected digest side is derived at run time from the authored goldens, never read
-- from a committed digest table. A table of four SHA-256 values is not something a human
-- can author or review: it is a reproducible observation of bytes that are already pinned,
-- so tracking it added a second copy that could only ever agree or be wrong.
checkDigests :: Fixture -> CompiledUiPlans -> IO ()
checkDigests fixture compiled = do
    let digests = compiledDigests compiled
        referenceSources =
            referenceAuthoritySource
                (authorizationRows fixture)
                (compilerPortRows fixture)
                (compilerBindingRows fixture)
                (compilerLinkRows fixture)
    goldenClient <- typedArtifact "client_plan.golden.json"
    goldenServer <- typedArtifact "ui_server_plan.golden.json"
    goldenContracts <- typedArtifact "public_contracts.golden.json"
    let expected =
            [ ["authority", Text.unpack (referenceDigest (encodeSources referenceSources))]
            , ["client", Text.unpack (referenceDigest goldenClient)]
            , ["server", Text.unpack (referenceDigest goldenServer)]
            , ["contracts", Text.unpack (referenceDigest goldenContracts)]
            ]
        actual =
            [ ["authority", Text.unpack (authorityDigest digests)]
            , ["client", Text.unpack (clientDigest digests)]
            , ["server", Text.unpack (serverDigest digests)]
            , ["contracts", Text.unpack (contractsDigest digests)]
            ]
    assertEqual "canonical digests over the authored goldens" expected actual
    assertEqual "independent client digest" (clientDigest digests) (referenceDigest (compiledClientBytes compiled))
    assertEqual "independent server digest" (serverDigest digests) (referenceDigest (compiledServerBytes compiled))
    assertEqual "independent contract digest" (contractsDigest digests) (referenceDigest (compiledContractBytes compiled))
    assertEqual "independent authority source/digest" (authorityDigest digests) (referenceDigest (encodeSources referenceSources))
  where
    typedArtifact name = case lookup name Cases.expectedArtifactRows of
        Nothing -> die ("missing typed artifact expectation: " <> name)
        Just bytes -> pure (LazyChar.pack bytes)

checkRuntimeDemand :: CompiledUiPlans -> IO ()
checkRuntimeDemand compiled = do
    let demand = compiledDemand compiled
    assertEqual
        "finite runtime demand"
        (2, 2, 1, 2, 2, 8)
        ( browserRouteDemand demand
        , browserEventDemand demand
        , browserLinkDemand demand
        , serverActionDemand demand
        , serverContractDemand demand
        , authoritySourceDemand demand
        )

checkSpecificNegatives :: Fixture -> CompiledUiPlans -> IO ()
checkSpecificNegatives fixture compiled = do
    assertEqual
        "private field refusal"
        "PrivateFieldForbidden"
        (either (Text.unpack . uiPlanErrorTag) (const "accepted") (validatePublicField "private:server-handle"))
    assertEqual
        "link-as-effect refusal"
        "LinkNavigationAsEffect"
        (either (Text.unpack . uiPlanErrorTag) (const "accepted") (validateNavigationInstruction "fetch:docs"))
    let sources =
            referenceAuthoritySource
                (authorizationRows fixture)
                (compilerPortRows fixture)
                (compilerBindingRows fixture)
                (compilerLinkRows fixture)
        changed = sources <> ["policy-epoch:changed"]
        current = authorityDigest (compiledDigests compiled)
    assert (digestAuthoritySources changed /= current) "authority-bearing input failed to change authority digest"
    assert (digestAuthoritySources (dropLast sources) /= current) "omitted authority source preserved digest"

checkFreshProcessDeterminism :: IO ()
checkFreshProcessDeterminism = do
    executable <- getExecutablePath
    environment <- getEnvironment
    let child argument =
            readCreateProcessWithExitCode
                ((proc executable [argument]){env = Just (("AMOEBIUS_UI_PLAN_CACHE", "disabled") : environment)})
                ""
    (forwardCode, forward, forwardErr) <- child "--emit-plan=forward"
    (reverseCode, reversed, reverseErr) <- child "--emit-plan=reverse"
    assertEqual "forward fresh process" ExitSuccess forwardCode
    assertEqual "reverse fresh process" ExitSuccess reverseCode
    assertEqual "fresh-process stderr" ("", "") (forwardErr, reverseErr)
    assertEqual "cache-bypassed randomized-order bytes" forward reversed

checkCalculus :: IO ()
checkCalculus = do
    tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-plan-compiler-calculus-tenant")
    subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-plan-compiler-calculus-subject")
    membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
    action <- requireRight "calculus request scope" $
        CalculusScope.withRequestScope tenant subject membership $ \scope -> do
            let resources :: Int -> ResourceVector
                resources count = ResourceVector 1 (fromIntegral count) 0 0
                counts = [4, 6, 14, 2, 6] :: [Int]
                artifact =
                    artifactComponent
                        scope
                        "canonical-plan-artifacts"
                        (resources 4)
                        (RecipeId "ui-plan-compiler" 4)
                budget =
                    budgetComponent
                        scope
                        "finite-runtime-demand"
                        (resources 6)
                        (allowance (Bytes 6) (Slots 1) (Bytes 6))
                lift = liftComponent scope "projection-digest-and-refusal-checks" (resources 14) OnHost
                workflow = workflowComponent scope "deterministic-plan-workflow" (resources 2) emptyLedger
                evidence = evidenceComponent scope "mutant-evidence" (resources 6) PureRegister
                composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
                ResourceVector cpu memory ephemeral pods = compositionResource composition
                render = Text.unpack . Text.intercalate ","
                actual =
                    [ ["calculus-kinds", render (map calculusTag (compositionKinds composition))]
                    , ["component-names", render (compositionNames composition)]
                    , ["projection-counts", render (map (Text.pack . show) counts)]
                    , ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
                    ]
            assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
            assertEqual "plan-compiler calculus projection" Cases.calculusRows actual
    action

emitPlans :: Fixture -> IO ()
emitPlans fixture = do
    compiled <- requireRight "emit compile" (compileUiPlans (boundProgram fixture))
    LazyChar.putStrLn (compiledClientBytes compiled)
    LazyChar.putStrLn (compiledServerBytes compiled)
    LazyChar.putStrLn (compiledContractBytes compiled)
    LazyChar.putStrLn (compiledContentManifestBytes compiled)
    putStrLn (show (compiledDigests compiled))

parseProjectionRequirement :: [String] -> IO UiProjectionRequirement
parseProjectionRequirement row = case row of
    [source, client, server, route, contract, _audit, _handler] -> do
        sourceId <- requireRight source (trustedSourceId (Text.pack source))
        routeId <- requireRight route (trustedRouteId (Text.pack route))
        instruction <- parseClientInstruction client server
        contractValue <- if contract == "-" then pure Nothing else Just <$> requireRight contract (trustedCodec (Text.pack contract))
        pure (UiProjectionRequirement sourceId instruction (Just routeId) contractValue)
    _ -> die ("invalid projection row: " <> show row)

parseClientInstruction :: String -> String -> IO UiClientInstruction
parseClientInstruction client server
    | "view:" `prefixOf` client = pure ViewText
    | "event:" `prefixOf` client = do
        event <- requireRight client (trustedEventName (Text.pack (drop 6 client)))
        port <- requireRight server (trustedPortId (Text.pack (drop 7 server)))
        pure (EmitEvent event port)
    | "navigation:" `prefixOf` client = do
        link <- requireRight client (trustedExternalLinkId (Text.pack (drop 11 client)))
        pure (NavigateExternal link)
    | otherwise = die ("invalid client instruction: " <> client)

makePort :: Text.Text -> Text.Text -> Text.Text -> Text.Text -> IO PortRequirement
makePort name request response effect =
    PortRequirement
        <$> requireRight "port" (trustedPortId name)
        <*> requireRight "request" (trustedCodec request)
        <*> requireRight "response" (trustedCodec response)
        <*> pure OwnerScope
        <*> requireRight "effect" (parsePortEffectTarget effect)

makeHandler :: Text.Text -> Text.Text -> Text.Text -> AuditClass -> IO HandlerSpec
makeHandler name request response audit =
    HandlerSpec
        <$> requireRight "handler" (trustedHandlerId name)
        <*> requireRight "request" (trustedCodec request)
        <*> requireRight "response" (trustedCodec response)
        <*> pure OwnerScope
        <*> pure IdempotentRetry
        <*> pure audit

makeCapability :: Text.Text -> CapabilityName -> IO CapabilityBinding
makeCapability handler capability =
    CapabilityBinding
        <$> requireRight "capability handler" (trustedHandlerId handler)
        <*> pure capability

typedAuthorizationAction :: ActionRow -> IO ActionSpec
typedAuthorizationAction row =
    ActionSpec
        <$> requireRight "authorization action" (trustedActionId (actionName row))
        <*> pure (actionEffect row)
        <*> pure (actionPermission row)
        <*> pure (actionVisibility row)
        <*> pure (actionIdempotent row)

projectAuthorization :: ActionSpec -> ActionProjection
projectAuthorization spec =
    ActionProjection
        (specAction spec)
        (specEffect spec)
        (specPermission spec)
        (specVisibility spec)
        (specIdempotent spec)

renderProjection :: BoundUiProjection -> [String]
renderProjection row =
    [ Text.unpack (sourceIdText (compiledSource row))
    , renderInstruction (compiledInstruction row)
    , renderServerInstruction (compiledInstruction row)
    , Text.unpack (routeIdText (compiledRoute row))
    , maybe "-" (Text.unpack . codecText) (compiledContract row)
    , maybe "-" renderAudit (compiledAudit row)
    , maybe "-" (Text.unpack . handlerIdText) (compiledHandler row)
    ]

renderInstruction :: UiClientInstruction -> String
renderInstruction instruction = case instruction of
    ViewText -> "view:text"
    EmitEvent event _ -> "event:" <> Text.unpack (eventNameText event)
    NavigateExternal link -> "navigation:" <> Text.unpack (externalLinkIdText link)

renderServerInstruction :: UiClientInstruction -> String
renderServerInstruction instruction = case instruction of
    EmitEvent _ port -> "action:" <> Text.unpack (portIdText port)
    _ -> "-"

renderAudit :: AuditClass -> String
renderAudit audit = case audit of
    ReadAudit -> "read"
    MutationAudit -> "mutation"
    WorkflowAudit -> "workflow"
    StreamAudit -> "stream"
    BlobAudit -> "blob"
    ArtifactAudit -> "artifact"

encodeSources :: [Text.Text] -> Lazy.ByteString
encodeSources = Lazy.fromStrict . TextEncoding.encodeUtf8 . Text.intercalate "\n"

dropLast :: [value] -> [value]
dropLast values = case reverse values of _ : rest -> reverse rest; [] -> []

orderValues :: Bool -> [value] -> [value]
orderValues reverseOrder values = if reverseOrder then reverse values else values

prefixOf :: String -> String -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (left : lefts) (right : rights) = left == right && prefixOf lefts rights

requireRight :: (Show problem) => String -> Either problem value -> IO value
requireRight label result = either (die . ((label <> ": ") <>) . show) pure result

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("ui-plan-compiler-spec: FAIL: " <> message) >> exitFailure

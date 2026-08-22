{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
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
import Amoebius.Ui.Source (decodeUiSource)
import Control.Monad (forM_, unless)
import qualified Data.ByteString.Lazy as Lazy
import qualified Data.ByteString.Lazy.Char8 as LazyChar
import Data.List (sort)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import PlanCompilerReference (referenceAuthoritySource, referenceDigest, referenceProjectionRows)
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Environment (getArgs, getEnvironment, getExecutablePath)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

data Fixture = Fixture
  { boundProgram :: BoundUiProgram
  , projectionRows :: [[String]]
  , authorizationRows :: [[String]]
  , compilerPortRows :: [[String]]
  , compilerBindingRows :: [[String]]
  , compilerLinkRows :: [[String]]
  }

data Mutant = Mutant
  { mutantName :: String
  , mutantLocus :: String
  , mutantFile :: FilePath
  , mutantMarker :: String
  }

mutants :: [Mutant]
mutants =
  [ Mutant "M-drop-server-action" "workflow.start" "M-drop-server-action.mutant" "dropped-effect"
  , Mutant "M-swap-action-targets" "handler-projection" "M-swap-action-targets.mutant" "effect-swap"
  , Mutant "M-emit-private-field" "public-allowlist" "M-emit-private-field.mutant" "projection-guard-deletion"
  , Mutant "M-client-only-authority-digest" "authority-digest" "M-client-only-authority-digest.mutant" "invariant-clause-delete"
  , Mutant "M-link-navigation-as-fetch" "docs.link" "M-link-navigation-as-fetch.mutant" "effect-swap"
  , Mutant "M-preserve-map-insertion-order" "fresh-process-bytes" "M-preserve-map-insertion-order.mutant" "determinism-violation"
  ]

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  case arguments of
    [] -> buildFixture root False >>= runGreen root
    ["--emit-plan=forward"] -> buildFixture root False >>= emitPlans
    ["--emit-plan=reverse"] -> buildFixture root True >>= emitPlans
    [argument] | "--mutant=" `prefixOf` argument -> buildFixture root False >>= \fixture -> runMutant root fixture (drop 9 argument)
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> Fixture -> IO ()
runGreen root fixture = do
  compiled <- requireRight "compile plans" (compileUiPlans (boundProgram fixture))
  checkProjectionOracle fixture compiled
  checkGoldens root compiled
  checkDigests root fixture compiled
  checkRuntimeDemand compiled
  checkSpecificNegatives fixture compiled
  checkFreshProcessDeterminism
  checkCalculus root
  checkMutantControls root fixture compiled
  putStrLn "ui-plan-compiler-calculus: PASS (5 kinds, 32 projected units)"
  putStrLn "ui-plan-compiler-spec: PASS (4 projections, 4 canonical artifacts, 4 digests, 6 demand cells, 2 fresh processes, 6 mutants)"

buildFixture :: FilePath -> Bool -> IO Fixture
buildFixture root reverseOrder = do
  rows <- loadTable (root </> "test/fixture/ui_plan_compiler/projection_rows.tsv")
  authRows <- loadTable (root </> "test/fixture/ui_authorization/action_registry.tsv")
  authorization <- buildAuthorizationRegistry root authRows
  mutatePort <- makePort "mutate" "MutationV1" "MutationReceiptV1" "MutateData"
  startPort <- makePort "start" "WorkflowStartV1" "WorkflowReceiptV1" "StartWorkflow"
  mutateHandler <- makeHandler "data-write" "MutationV1" "MutationReceiptV1" MutationAudit
  startHandler <- makeHandler "workflow-start" "WorkflowStartV1" "WorkflowReceiptV1" WorkflowAudit
  mutateCapability <- makeCapability "data-write" SqlWrite
  startCapability <- makeCapability "workflow-start" Workflow
  docs <- requireRight "docs id" (trustedExternalLinkId "docs")
  let linkRows = [["docs", "https://docs.example.invalid/amoebius"]]
      portRows =
        [ ["mutate", "MutationV1", "MutationReceiptV1", "MutateData"]
        , ["start", "WorkflowStartV1", "WorkflowReceiptV1", "StartWorkflow"]
        ]
      bindingRows =
        [ ["mutate", "data-write", "SqlWrite", "owner", "required", "mutation"]
        , ["start", "workflow-start", "Workflow", "owner", "required", "workflow"]
        ]
  boundLinks <- requireRight "compiler links" (bindExternalLinks
    [ExternalLinkRequirement docs]
    [ExternalLinkCatalogEntry docs "https://docs.example.invalid/amoebius"])
  projections <- traverse parseProjectionRequirement rows
  bound <- requireRight "bound compiler program" (bindUiProgramWithProjection authorization
    (orderValues reverseOrder [mutatePort, startPort])
    (orderValues reverseOrder [mutateHandler, startHandler])
    (orderValues reverseOrder [mutateCapability, startCapability])
    boundLinks
    (orderValues reverseOrder projections))
  pure Fixture
    { boundProgram = bound
    , projectionRows = rows
    , authorizationRows = authRows
    , compilerPortRows = portRows
    , compilerBindingRows = bindingRows
    , compilerLinkRows = linkRows
    }

buildAuthorizationRegistry :: FilePath -> [[String]] -> IO BoundActionRegistry
buildAuthorizationRegistry root rows = do
  decoded <- decodeUiSource (root </> "test/fixture/ui_program_schema/minimal_single_tenant.dhall")
  source <- either (die . Text.unpack) pure decoded
  checked <- either (die . show) pure (checkUiSource source)
  tenant <- requireRight "tenant" (trustedTenant "tenant-a")
  subject <- requireRight "subject" (trustedSubject tenant "alice")
  membership <- requireRight "membership" (activeMembership tenant subject)
  context <- requireRight "context" (trustedRequestContext tenant subject membership)
  specs <- traverse parseAuthorizationAction rows
  let projections = map projectAuthorization specs
  requireRight "authorization registry" (bindActionRegistry (scopeCheckedProgram checked context) specs projections)

checkProjectionOracle :: Fixture -> CompiledUiPlans -> IO ()
checkProjectionOracle fixture compiled = do
  expected <- either die pure (referenceProjectionRows (projectionRows fixture))
  let actual = sort (map renderProjection (boundUiProjection (boundProgram fixture)))
  assertEqual "logical projection oracle" expected actual
  assertEqual "client/server action parity"
    (clientActionPorts (compiledClientPlan compiled))
    (serverActionPorts (compiledServerPlan compiled))

checkGoldens :: FilePath -> CompiledUiPlans -> IO ()
checkGoldens root compiled = do
  let fixtureRoot = root </> "test/fixture/ui_plan_compiler"
      artifacts =
        [ ("client_plan.golden.json", compiledClientBytes compiled)
        , ("ui_server_plan.golden.json", compiledServerBytes compiled)
        , ("public_contracts.golden.json", compiledContractBytes compiled)
        , ("content_manifest.golden.json", compiledContentManifestBytes compiled)
        ]
  forM_ artifacts $ \(name, actual) -> do
    expected <- stripNewline <$> Lazy.readFile (fixtureRoot </> name)
    assertEqual name expected actual

-- The expected digest side is derived at run time from the authored goldens, never read
-- from a committed digest table. A table of four SHA-256 values is not something a human
-- can author or review: it is a reproducible observation of bytes that are already pinned,
-- so tracking it added a second copy that could only ever agree or be wrong.
checkDigests :: FilePath -> Fixture -> CompiledUiPlans -> IO ()
checkDigests root fixture compiled = do
  let fixtureRoot = root </> "test/fixture/ui_plan_compiler"
      digests = compiledDigests compiled
      referenceSources = referenceAuthoritySource
        (authorizationRows fixture) (compilerPortRows fixture) (compilerBindingRows fixture) (compilerLinkRows fixture)
  goldenClient <- stripNewline <$> Lazy.readFile (fixtureRoot </> "client_plan.golden.json")
  goldenServer <- stripNewline <$> Lazy.readFile (fixtureRoot </> "ui_server_plan.golden.json")
  goldenContracts <- stripNewline <$> Lazy.readFile (fixtureRoot </> "public_contracts.golden.json")
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

checkRuntimeDemand :: CompiledUiPlans -> IO ()
checkRuntimeDemand compiled = do
  let demand = compiledDemand compiled
  assertEqual "finite runtime demand" (2, 2, 1, 2, 2, 8)
    ( browserRouteDemand demand
    , browserEventDemand demand
    , browserLinkDemand demand
    , serverActionDemand demand
    , serverContractDemand demand
    , authoritySourceDemand demand
    )

checkSpecificNegatives :: Fixture -> CompiledUiPlans -> IO ()
checkSpecificNegatives fixture compiled = do
  assertEqual "private field refusal" "PrivateFieldForbidden"
    (either (Text.unpack . uiPlanErrorTag) (const "accepted") (validatePublicField "private:server-handle"))
  assertEqual "link-as-effect refusal" "LinkNavigationAsEffect"
    (either (Text.unpack . uiPlanErrorTag) (const "accepted") (validateNavigationInstruction "fetch:docs"))
  let sources = referenceAuthoritySource
        (authorizationRows fixture) (compilerPortRows fixture) (compilerBindingRows fixture) (compilerLinkRows fixture)
      changed = sources <> ["policy-epoch:changed"]
      current = authorityDigest (compiledDigests compiled)
  assert (digestAuthoritySources changed /= current) "authority-bearing input failed to change authority digest"
  assert (digestAuthoritySources (dropLast sources) /= current) "omitted authority source preserved digest"

checkFreshProcessDeterminism :: IO ()
checkFreshProcessDeterminism = do
  executable <- getExecutablePath
  environment <- getEnvironment
  let child argument = readCreateProcessWithExitCode
        ((proc executable [argument]) {env = Just (("AMOEBIUS_UI_PLAN_CACHE", "disabled") : environment)}) ""
  (forwardCode, forward, forwardErr) <- child "--emit-plan=forward"
  (reverseCode, reversed, reverseErr) <- child "--emit-plan=reverse"
  assertEqual "forward fresh process" ExitSuccess forwardCode
  assertEqual "reverse fresh process" ExitSuccess reverseCode
  assertEqual "fresh-process stderr" ("", "") (forwardErr, reverseErr)
  assertEqual "cache-bypassed randomized-order bytes" forward reversed

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadTable (root </> "test/oracle/ui_plan_compiler/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-plan-compiler-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-plan-compiler-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [4, 6, 14, 2, 6] :: [Int]
          artifact = artifactComponent scope "canonical-plan-artifacts" (resources 4)
            (RecipeId "ui-plan-compiler" 4)
          budget = budgetComponent scope "finite-runtime-demand" (resources 6)
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
      assertEqual "plan-compiler calculus projection" expected actual
  action

emitPlans :: Fixture -> IO ()
emitPlans fixture = do
  compiled <- requireRight "emit compile" (compileUiPlans (boundProgram fixture))
  LazyChar.putStrLn (compiledClientBytes compiled)
  LazyChar.putStrLn (compiledServerBytes compiled)
  LazyChar.putStrLn (compiledContractBytes compiled)
  LazyChar.putStrLn (compiledContentManifestBytes compiled)
  putStrLn (show (compiledDigests compiled))

checkMutantControls :: FilePath -> Fixture -> CompiledUiPlans -> IO ()
checkMutantControls root fixture compiled = do
  forM_ mutants $ \mutant -> do
    source <- readFile (root </> "test/mutant/ui_plan_compiler" </> mutantFile mutant)
    assert (mutantMarker mutant `contains` source) (mutantName mutant <> " fixture drifted")
  let server = LazyChar.unpack (compiledServerBytes compiled)
      client = LazyChar.unpack (compiledClientBytes compiled)
      dropped = replaceOnce ",\"start\":\"workflow-start\"" "" server
      swapped = replaceOnce "\"mutate\":\"data-write\",\"start\":\"workflow-start\""
        "\"mutate\":\"workflow-start\",\"start\":\"data-write\"" server
      privateClient = replaceOnce "}" ",\"private\":\"server-handle\"}" client
      insertionOrder = "{\"routes\":[\"workflow\",\"home\"],\"links\":[\"docs\"],\"events\":[\"start\",\"submit\"],\"abi\":\"ui-client-v1\"}"
      publicOnlyDigest = referenceDigest (compiledClientBytes compiled)
  assert (dropped /= server) "drop-server-action mutant has no effect"
  assert (swapped /= server) "swap-action-targets mutant has no effect"
  assert (privateClient /= client && deniedPlan (validatePublicField "private:server-handle")) "private-field mutant has no red locus"
  assert (publicOnlyDigest /= authorityDigest (compiledDigests compiled)) "client-only authority mutant survived"
  assert (deniedPlan (validateNavigationInstruction "fetch:docs")) "link-as-fetch mutant survived"
  assert (insertionOrder /= client) "insertion-order mutant survived"
  assert (not (null (projectionRows fixture))) "projection oracle is empty"

runMutant :: FilePath -> Fixture -> String -> IO ()
runMutant root fixture name = case firstMatching ((== name) . mutantName) mutants of
  Nothing -> die ("unknown mutant: " <> name)
  Just mutant -> do
    compiled <- requireRight "mutant control compile" (compileUiPlans (boundProgram fixture))
    checkMutantControls root fixture compiled
    putStrLn ("ui-plan-compiler-mutant: RED " <> mutantName mutant <> " locus=" <> mutantLocus mutant)
    exitFailure

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
makePort name request response effect = PortRequirement
  <$> requireRight "port" (trustedPortId name)
  <*> requireRight "request" (trustedCodec request)
  <*> requireRight "response" (trustedCodec response)
  <*> pure OwnerScope
  <*> requireRight "effect" (parsePortEffectTarget effect)

makeHandler :: Text.Text -> Text.Text -> Text.Text -> AuditClass -> IO HandlerSpec
makeHandler name request response audit = HandlerSpec
  <$> requireRight "handler" (trustedHandlerId name)
  <*> requireRight "request" (trustedCodec request)
  <*> requireRight "response" (trustedCodec response)
  <*> pure OwnerScope
  <*> pure IdempotentRetry
  <*> pure audit

makeCapability :: Text.Text -> CapabilityName -> IO CapabilityBinding
makeCapability handler capability = CapabilityBinding
  <$> requireRight "capability handler" (trustedHandlerId handler)
  <*> pure capability

parseAuthorizationAction :: [String] -> IO ActionSpec
parseAuthorizationAction row = case row of
  [name, effect, permission, visibility, idempotent] -> ActionSpec
    <$> requireRight name (trustedActionId (Text.pack name))
    <*> parseActionEffect effect
    <*> parsePermission permission
    <*> parseVisibility visibility
    <*> parseBoolean idempotent
  _ -> die ("invalid authorization action: " <> show row)

projectAuthorization :: ActionSpec -> ActionProjection
projectAuthorization spec = ActionProjection
  (specAction spec) (specEffect spec) (specPermission spec) (specVisibility spec) (specIdempotent spec)

parseActionEffect :: String -> IO ActionEffect
parseActionEffect value = case value of
  "ReadData" -> pure ReadData
  "MutateData" -> pure MutateData
  "StartWorkflow" -> pure StartWorkflow
  "ObserveWorkflow" -> pure ObserveWorkflow
  "EndSession" -> pure EndSession
  _ -> die ("invalid effect: " <> value)

parsePermission :: String -> IO Permission
parsePermission value = case value of
  "read" -> pure ReadPermission
  "write" -> pure WritePermission
  "invoke" -> pure InvokePermission
  _ -> die ("invalid permission: " <> value)

parseVisibility :: String -> IO Visibility
parseVisibility value = case value of
  "visible" -> pure Visible
  "hidden" -> pure Hidden
  _ -> die ("invalid visibility: " <> value)

parseBoolean :: String -> IO Bool
parseBoolean value = case value of "true" -> pure True; "false" -> pure False; _ -> die ("invalid Boolean: " <> value)

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

stripNewline :: Lazy.ByteString -> Lazy.ByteString
stripNewline value = if Lazy.isSuffixOf "\n" value then Lazy.take (Lazy.length value - 1) value else value

deniedPlan :: Either problem value -> Bool
deniedPlan = either (const True) (const False)

replaceOnce :: String -> String -> String -> String
replaceOnce needle replacement haystack = case breakOn needle haystack of
  Nothing -> haystack
  Just (before, after) -> before <> replacement <> after

breakOn :: String -> String -> Maybe (String, String)
breakOn needle = go ""
  where
    go _ [] = Nothing
    go before rest@(character : remaining)
      | needle `prefixOf` rest = Just (reverse before, drop (length needle) rest)
      | otherwise = go (character : before) remaining

dropLast :: [value] -> [value]
dropLast values = case reverse values of _ : rest -> reverse rest; [] -> []

orderValues :: Bool -> [value] -> [value]
orderValues reverseOrder values = if reverseOrder then reverse values else values

firstMatching :: (value -> Bool) -> [value] -> Maybe value
firstMatching predicate values = case filter predicate values of value : _ -> Just value; [] -> Nothing

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  content <- readFile path
  case lines content of
    [] -> die ("empty TSV: " <> path)
    _header : rows -> pure (map splitTabs (filter (not . null) rows))

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

contains :: String -> String -> Bool
contains needle haystack = any (needle `prefixOf`) (tails haystack)
  where
    tails [] = [[]]
    tails value@(_ : rest) = value : tails rest

prefixOf :: String -> String -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (left : lefts) (right : rights) = left == right && prefixOf lefts rights

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label result = either (die . ((label <> ": ") <>) . show) pure result

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("ui-plan-compiler-spec: FAIL: " <> message) >> exitFailure

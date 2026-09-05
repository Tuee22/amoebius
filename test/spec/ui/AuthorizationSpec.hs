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
import Amoebius.Ui.Check (checkUiSource)
import Amoebius.Ui.Security.Authorization
import Amoebius.Ui.Security.Scope
import AuthorizationCases
import AuthorizationOracle
import Control.Monad (forM_, unless)
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Test.QuickCheck (
    Args (..),
    Property,
    checkCoverage,
    counterexample,
    cover,
    elements,
    forAll,
    isSuccess,
    property,
    quickCheckWithResult,
    stdArgs,
 )
import Test.QuickCheck.Random (mkQCGen)
import UiProgramSchemaCases (minimalSingleTenant)

data Fixture = Fixture
    { registry :: BoundActionRegistry
    , scopedProgram :: ScopedUiProgram
    , actionSpecs :: [ActionSpec]
    , ownContext :: RequestContext
    , ownOwner :: Owner
    , foreignOwner :: Owner
    , targetResource :: ResourceId
    , currentEpochs :: AuthorityEpochs
    , staleEpochs :: AuthorityEpochs
    , currentSnapshot :: AuthoritySnapshot
    }

data CoverageClass
    = AbsentPolicyClass
    | WrongScopeClass
    | WrongPermissionClass
    | StaleEpochClass
    | ReadDataClass
    | MutateDataClass
    | StartWorkflowClass
    | ObserveWorkflowClass
    | EndSessionClass
    deriving stock (Bounded, Enum, Eq, Show)

main :: IO ()
main = do
    fixture <- buildFixture
    checkRegistryOracle fixture
    checkParityErrors fixture
    checkAuthorizationMatrix fixture
    checkStaleEpochs fixture
    checkCoverageProperties fixture
    checkCalculus
    checkOracleClosure
    putStrLn "ui-authorization-calculus: PASS (5 kinds, 30 projected units)"
    putStrLn "ui-authorization-spec: PASS (5 actions, 6 matrix rows, 4 parity errors, 4 stale epochs, 9 coverage classes, 2 production mutants)"

buildFixture :: IO Fixture
buildFixture = do
    specs <- traverse actionSpec actionRows
    checked <- requireRight "typed UI source" (checkUiSource minimalSingleTenant)
    tenantA <- requireRight "tenant A" (trustedTenant "tenant-a")
    tenantB <- requireRight "tenant B" (trustedTenant "tenant-b")
    alice <- requireRight "alice" (trustedSubject tenantA "alice")
    carol <- requireRight "carol" (trustedSubject tenantB "carol")
    membership <- requireRight "membership" (activeMembership tenantA alice)
    context <- requireRight "request context" (trustedRequestContext tenantA alice membership)
    resource <- requireRight "resource" (trustedResourceId "record-1")
    epochs <- requireRight "authority epochs" (authorityEpochs 4 7 9 12)
    stale <- requireRight "stale authority epochs" (authorityEpochs 3 7 9 12)
    let scoped = scopeCheckedProgram checked context
        projections = map projectSpec specs
    bound <- requireRight "bound registry" (bindActionRegistry scoped specs projections)
    let policy = Map.fromList [(specAction spec, specPermission spec) | spec <- specs]
    pure
        Fixture
            { registry = bound
            , scopedProgram = scoped
            , actionSpecs = specs
            , ownContext = context
            , ownOwner = subjectOwner tenantA alice
            , foreignOwner = subjectOwner tenantB carol
            , targetResource = resource
            , currentEpochs = epochs
            , staleEpochs = stale
            , currentSnapshot = authoritySnapshot epochs policy
            }

checkRegistryOracle :: Fixture -> IO ()
checkRegistryOracle fixture = do
    let client = sort (map renderProjection (clientProjection (registry fixture)))
        server = sort (map renderProjection (serverProjection (registry fixture)))
    assertEqual "independent client projection" (sort registryOracle) client
    assertEqual "single-source server projection" (sort registryOracle) server
    assertEqual "client/server exact parity" client server
    assertEqual "closed effect-arm coverage" [minBound .. maxBound] (sort (map specEffect (actionSpecs fixture)))

checkParityErrors :: Fixture -> IO ()
checkParityErrors fixture = do
    assertEqual "typed parity oracle" parityOracle parityRows
    let specs = actionSpecs fixture
        projections = map projectSpec specs
    extraId <- requireRight "extra action" (trustedActionId "extra-action")
    let extraProjection = ActionProjection extraId ReadData ReadPermission Visible True
        mutations =
            [ ("missing-action", bindWith fixture specs (dropLast projections))
            , ("extra-action", bindWith fixture specs (projections <> [extraProjection]))
            , ("duplicate-action", bindWith fixture (specs <> take 1 specs) projections)
            , ("permission-swap", bindWith fixture specs (map swapPermission projections))
            ]
    forM_ parityOracle $ \(caseName, expectedTag) -> case lookup caseName mutations of
        Nothing -> die ("missing parity mutation: " <> Text.unpack caseName)
        Just result -> assertEqual (Text.unpack caseName) expectedTag (either authorizationErrorTag (const "accepted") result)

checkAuthorizationMatrix :: Fixture -> IO ()
checkAuthorizationMatrix fixture = do
    assertEqual "decision corpus names" (map fst decisionOracle) (map decisionName decisionRows)
    forM_ decisionRows $ \row -> do
        expected <- maybe (die ("missing decision oracle: " <> Text.unpack (decisionName row))) pure (lookup (decisionName row) decisionOracle)
        assertEqual (label row <> " case expectation") expected (decisionAllowed row)
        action <- actionNamed fixture (decisionAction row)
        let snapshot = snapshotFor fixture (decisionPolicyPresent row) action
            owner = if decisionOwnScope row then ownOwner fixture else foreignOwner fixture
            presented = if decisionCurrentEpoch row then currentEpochs fixture else staleEpochs fixture
            result = authorize (registry fixture) snapshot presented (ownContext fixture) owner (targetResource fixture) action (decisionPermission row)
            actual = either (const False) (const True) result
            trace = either (const []) interpretAuthorized result
        assertEqual (label row <> " production decision") expected actual
        unless actual (assertEqual (label row <> " denied trace") ([] :: [EffectEvent]) trace)
        case result of
            Right authorized -> checkWitness (decisionAction row) authorized
            Left _ -> pure ()
  where
    label = Text.unpack . decisionName

checkStaleEpochs :: Fixture -> IO ()
checkStaleEpochs fixture = do
    assertEqual "epoch corpus oracle" epochOracle [(epochName row, epochError row) | row <- epochRows]
    action <- actionNamed fixture "end-session"
    forM_ epochRows $ \row -> do
        fresh <- epochsWith (epochName row) (epochCurrent row)
        stale <- epochsWith (epochName row) (epochPresented row)
        let snapshot = authoritySnapshot fresh (Map.singleton action InvokePermission)
            result = authorize (registry fixture) snapshot stale (ownContext fixture) (ownOwner fixture) (targetResource fixture) action InvokePermission
        assertEqual (Text.unpack (epochName row) <> " stale tag") (epochError row) (either authorizationErrorTag (const "accepted") result)
        assertEqual (Text.unpack (epochName row) <> " stale trace") ([] :: [EffectEvent]) (either (const []) interpretAuthorized result)

checkCoverageProperties :: Fixture -> IO ()
checkCoverageProperties fixture = do
    let classes = [minBound .. maxBound] :: [CoverageClass]
        args = stdArgs{maxSuccess = 500, replay = Just (mkQCGen 180018, 0), chatty = False}
    result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty fixture classes)
    assert (isSuccess result) "authorization generated coverage failed"

checkCalculus :: IO ()
checkCalculus = do
    tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-authorization-calculus-tenant")
    subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-authorization-calculus-subject")
    membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
    action <- requireRight "calculus scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
        let resources count = ResourceVector 1 count 0 0
            counts = [5, 6, 8, 9, 2] :: [Int]
            artifact = artifactComponent scope "action-registry" (resources 5) (RecipeId "ui-authorization" 5)
            budget = budgetComponent scope "authorization-decisions" (resources 6) (allowance (Bytes 6) (Slots 1) (Bytes 6))
            lift = liftComponent scope "parity-and-epoch-refusals" (resources 8) OnHost
            workflow = workflowComponent scope "generated-coverage-workflow" (resources 9) emptyLedger
            evidence = evidenceComponent scope "mutant-evidence" (resources 2) PureRegister
            composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
            ResourceVector cpu memory ephemeral pods = compositionResource composition
            actual =
                [ ["calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition))]
                , ["component-names", Text.intercalate "," (compositionNames composition)]
                , ["projection-counts", Text.intercalate "," (map (Text.pack . show) counts)]
                , ["resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
                ]
        assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
        assertEqual "authorization calculus projection" calculusOracle actual
    action

checkOracleClosure :: IO ()
checkOracleClosure = do
    assertEqual "validation locus cardinality" 30 (length validationLoci)
    assertEqual "production mutant cardinality" 2 (length mutantOracle)

coverageProperty :: Fixture -> [CoverageClass] -> CoverageClass -> Property
coverageProperty fixture classes selected = checkCoverage $ foldr (\coverageClass -> cover 5 (selected == coverageClass) (show coverageClass)) (counterexample (show selected) (property (exerciseClass fixture selected))) classes

exerciseClass :: Fixture -> CoverageClass -> Bool
exerciseClass fixture coverageClass = case coverageClass of
    AbsentPolicyClass -> denied (attempt fixture "read-data" Map.empty ReadPermission (ownOwner fixture) (currentEpochs fixture))
    WrongScopeClass -> denied (attempt fixture "read-data" fullPolicy ReadPermission (foreignOwner fixture) (currentEpochs fixture))
    WrongPermissionClass -> denied (attempt fixture "mutate-data" fullPolicy ReadPermission (ownOwner fixture) (currentEpochs fixture))
    StaleEpochClass -> denied (attempt fixture "end-session" fullPolicy InvokePermission (ownOwner fixture) (staleEpochs fixture))
    ReadDataClass -> emits ReadData "read-data"
    MutateDataClass -> emits MutateData "mutate-data"
    StartWorkflowClass -> emits StartWorkflow "start-workflow"
    ObserveWorkflowClass -> emits ObserveWorkflow "observe-workflow"
    EndSessionClass -> emits EndSession "end-session"
  where
    fullPolicy = Map.fromList [(specAction spec, specPermission spec) | spec <- actionSpecs fixture]
    denied = either (const True) (const False)
    emits effect name = case attempt fixture name fullPolicy (permissionForEffect effect) (ownOwner fixture) (currentEpochs fixture) of
        Left _ -> False
        Right authorized -> case interpretAuthorized authorized of
            [EffectEvent _ actual] -> actual == effect
            _ -> False

attempt :: Fixture -> Text -> Map.Map ActionId Permission -> Permission -> Owner -> AuthorityEpochs -> Either AuthorizationError AuthorizedAction
attempt fixture name policy requested owner presented = case findAction fixture name of
    Nothing -> Left (InvalidActionId name)
    Just action -> authorize (registry fixture) (authoritySnapshot (currentEpochs fixture) policy) presented (ownContext fixture) owner (targetResource fixture) action requested

actionSpec :: ActionRow -> IO ActionSpec
actionSpec row = ActionSpec <$> requireRight "action id" (trustedActionId (actionName row)) <*> pure (actionEffect row) <*> pure (actionPermission row) <*> pure (actionVisibility row) <*> pure (actionIdempotent row)

bindWith :: Fixture -> [ActionSpec] -> [ActionProjection] -> Either AuthorizationError BoundActionRegistry
bindWith fixture specs = bindActionRegistry (scopedProgram fixture) specs

projectSpec :: ActionSpec -> ActionProjection
projectSpec spec = ActionProjection (specAction spec) (specEffect spec) (specPermission spec) (specVisibility spec) (specIdempotent spec)

swapPermission :: ActionProjection -> ActionProjection
swapPermission projection
    | actionIdText (projectionAction projection) == "read-data" = projection{projectionPermission = WritePermission}
    | actionIdText (projectionAction projection) == "mutate-data" = projection{projectionPermission = ReadPermission}
    | otherwise = projection

renderProjection :: ActionProjection -> [Text]
renderProjection projection = [actionIdText (projectionAction projection), Text.pack (show (projectionEffect projection)), renderPermission (projectionPermission projection), renderVisibility (projectionVisibility projection), if projectionIdempotent projection then "true" else "false"]

renderPermission :: Permission -> Text
renderPermission permission = case permission of
    ReadPermission -> "read"
    WritePermission -> "write"
    InvokePermission -> "invoke"

renderVisibility :: Visibility -> Text
renderVisibility visibility = case visibility of
    Visible -> "visible"
    Hidden -> "hidden"

permissionForEffect :: ActionEffect -> Permission
permissionForEffect effect = case effect of
    ReadData -> ReadPermission
    MutateData -> WritePermission
    StartWorkflow -> InvokePermission
    ObserveWorkflow -> ReadPermission
    EndSession -> InvokePermission

checkWitness :: Text -> AuthorizedAction -> IO ()
checkWitness name authorized
    | name `elem` ["read-data", "observe-workflow"] = assert (present (canRead authorized)) (Text.unpack name <> " lacks CanRead")
    | name `elem` ["start-workflow", "end-session"] = assert (present (canInvoke authorized)) (Text.unpack name <> " lacks CanInvoke")
    | otherwise = pure ()

snapshotFor :: Fixture -> Bool -> ActionId -> AuthoritySnapshot
snapshotFor fixture policyPresent action
    | policyPresent = currentSnapshot fixture
    | otherwise = authoritySnapshot (currentEpochs fixture) (Map.delete action fullPolicy)
  where
    fullPolicy = Map.fromList [(specAction spec, specPermission spec) | spec <- actionSpecs fixture]

epochsWith :: Text -> Int -> IO AuthorityEpochs
epochsWith source value = requireRight (Text.unpack source <> " epochs") $ case source of
    "policy" -> authorityEpochs value 7 9 12
    "membership" -> authorityEpochs 4 value 9 12
    "grant" -> authorityEpochs 4 7 value 12
    "scope" -> authorityEpochs 4 7 9 value
    _ -> Left (InvalidAuthorityEpoch (-1))

actionNamed :: Fixture -> Text -> IO ActionId
actionNamed fixture name = maybe (die ("missing fixture action: " <> Text.unpack name)) pure (findAction fixture name)

findAction :: Fixture -> Text -> Maybe ActionId
findAction fixture name = specAction <$> firstMatching ((== name) . actionIdText . specAction) (actionSpecs fixture)

firstMatching :: (value -> Bool) -> [value] -> Maybe value
firstMatching predicate values = case filter predicate values of
    value : _ -> Just value
    [] -> Nothing

dropLast :: [value] -> [value]
dropLast values = case reverse values of
    _ : rest -> reverse rest
    [] -> []

present :: Maybe value -> Bool
present value = case value of
    Just _ -> True
    Nothing -> False

requireRight :: (Show problem) => String -> Either problem value -> IO value
requireRight label result = either (die . ((label <> ": ") <>) . show) pure result

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("ui-authorization-spec: FAIL: " <> message) >> fail message

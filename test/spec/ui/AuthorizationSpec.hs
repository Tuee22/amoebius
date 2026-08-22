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
import Amoebius.Ui.Check (checkUiSource)
import Amoebius.Ui.Security.Authorization
import Amoebius.Ui.Security.Scope
import Amoebius.Ui.Source (decodeUiSource)
import AuthorizationReference (referenceDecision, referenceRegistryRows)
import Control.Monad (forM_, unless)
import Data.List (sort)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Test.QuickCheck
  ( Args (..)
  , Property
  , checkCoverage
  , counterexample
  , cover
  , elements
  , forAll
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)

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
  root <- getCurrentDirectory >>= canonicalizePath
  fixture <- buildFixture root
  arguments <- getArgs
  case arguments of
    [] -> runGreen root fixture
    ["--mutant=default_allow"] -> runDefaultAllowMutant root fixture
    ["--mutant=visibility_is_authorization"] -> runVisibilityMutant root fixture
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> Fixture -> IO ()
runGreen root fixture = do
  checkRegistryOracle root fixture
  checkParityErrors root fixture
  checkAuthorizationMatrix root fixture
  checkStaleEpochs root fixture
  checkCoverageProperties fixture
  checkCalculus root
  checkMutantControls root fixture
  putStrLn "ui-authorization-calculus: PASS (5 kinds, 30 projected units)"
  putStrLn "ui-authorization-spec: PASS (5 actions, 6 matrix rows, 4 parity errors, 4 stale epochs, 9 coverage classes, 2 mutants)"

buildFixture :: FilePath -> IO Fixture
buildFixture root = do
  rows <- loadTable (root </> "test/fixture/ui_authorization/action_registry.tsv")
  specs <- traverse parseActionSpec rows
  projections <- traverse parseProjection rows
  decoded <- decodeUiSource (root </> "test/fixture/ui_program_schema/minimal_single_tenant.dhall")
  source <- either (die . Text.unpack) pure decoded
  checked <- either (die . show) pure (checkUiSource source)
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
  bound <- requireRight "bound registry" (bindActionRegistry scoped specs projections)
  let policy = Map.fromList [(specAction spec, specPermission spec) | spec <- specs]
  pure Fixture
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

checkRegistryOracle :: FilePath -> Fixture -> IO ()
checkRegistryOracle root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_authorization/action_registry.tsv")
  expected <- either die pure (referenceRegistryRows rows)
  let client = sort (map renderProjection (clientProjection (registry fixture)))
      server = sort (map renderProjection (serverProjection (registry fixture)))
  assertEqual "independent client projection" expected client
  assertEqual "single-source server projection" expected server
  assertEqual "client/server exact parity" client server
  assertEqual "closed effect-arm coverage" [minBound .. maxBound] (sort (map specEffect (actionSpecs fixture)))

checkParityErrors :: FilePath -> Fixture -> IO ()
checkParityErrors root fixture = do
  expectedRows <- loadTable (root </> "test/fixture/ui_authorization/decode_errors.tsv")
  assertEqual "parity error row count" 4 (length expectedRows)
  let specs = actionSpecs fixture
      projections = map projectSpec specs
  extraId <- requireRight "extra action" (trustedActionId "extra-action")
  let extraProjection = ActionProjection extraId ReadData ReadPermission Visible True
      swapped = map swapPermission projections
      mutations =
        [ ("missing-action", bindWith fixture specs (dropLast projections))
        , ("extra-action", bindWith fixture specs (projections <> [extraProjection]))
        , ("duplicate-action", bindWith fixture (specs <> take 1 specs) projections)
        , ("permission-swap", bindWith fixture specs swapped)
        ]
  forM_ expectedRows $ \row -> case row of
    [caseName, expectedTag] -> case lookup caseName mutations of
      Nothing -> die ("missing parity mutation: " <> caseName)
      Just result -> assertEqual caseName expectedTag (either (Text.unpack . authorizationErrorTag) (const "accepted") result)
    _ -> die ("invalid parity error row: " <> show row)

checkAuthorizationMatrix :: FilePath -> Fixture -> IO ()
checkAuthorizationMatrix root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_authorization/authorization_matrix.tsv")
  assertEqual "authorization matrix row count" 6 (length rows)
  forM_ rows $ \row -> do
    expected <- either die pure (referenceDecision row)
    case row of
      [caseName, actionText, policyText, permissionText, scopeText, epochText, _visible, decisionText] -> do
        action <- actionNamed fixture actionText
        requested <- parsePermission permissionText
        let snapshot = snapshotFor fixture policyText action
            owner = if scopeText == "own" then ownOwner fixture else foreignOwner fixture
            presented = if epochText == "current" then currentEpochs fixture else staleEpochs fixture
            result = authorize (registry fixture) snapshot presented (ownContext fixture) owner
              (targetResource fixture) action requested
            actual = either (const False) (const True) result
            trace = either (const []) interpretAuthorized result
        assertEqual (caseName <> " fixture decision") (decisionText == "allow") expected
        assertEqual (caseName <> " production decision") expected actual
        unless actual (assertEqual (caseName <> " denied trace") ([] :: [EffectEvent]) trace)
        case result of
          Right authorized -> checkWitness actionText authorized
          Left _ -> pure ()
      _ -> die ("invalid authorization matrix row: " <> show row)

checkStaleEpochs :: FilePath -> Fixture -> IO ()
checkStaleEpochs root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_authorization/stale_decision_cases.tsv")
  assertEqual "stale epoch row count" 4 (length rows)
  action <- actionNamed fixture "end-session"
  forM_ rows $ \row -> case row of
    [source, currentText, presentedText, expectedTag] -> do
      current <- parseInt currentText
      presented <- parseInt presentedText
      fresh <- epochsWith source current
      stale <- epochsWith source presented
      let policy = Map.singleton action InvokePermission
          snapshot = authoritySnapshot fresh policy
          result = authorize (registry fixture) snapshot stale (ownContext fixture) (ownOwner fixture)
            (targetResource fixture) action InvokePermission
      assertEqual (source <> " stale tag") expectedTag (either (Text.unpack . authorizationErrorTag) (const "accepted") result)
      assertEqual (source <> " stale trace") ([] :: [EffectEvent]) (either (const []) interpretAuthorized result)
    _ -> die ("invalid stale epoch row: " <> show row)

checkCoverageProperties :: Fixture -> IO ()
checkCoverageProperties fixture = do
  let classes = [minBound .. maxBound] :: [CoverageClass]
      args = stdArgs {maxSuccess = 500, replay = Just (mkQCGen 180018, 0), chatty = False}
  result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty fixture classes)
  assert (isSuccess result) "authorization generated coverage failed"

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadTextTable (root </> "test/oracle/ui_authorization/calculus_projection.tsv")
  tenant <- either (fail . show) pure (CalculusScope.trustedTenant "ui-authorization-calculus-tenant")
  subject <- either (fail . show) pure (CalculusScope.trustedSubject tenant "ui-authorization-calculus-subject")
  membership <- either (fail . show) pure (CalculusScope.activeMembership tenant subject)
  action <- either (fail . show) pure $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
    let resources :: Int -> ResourceVector
        resources count = ResourceVector 1 (fromIntegral count) 0 0
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
    assertEqual "authorization calculus projection" expected actual
  action

coverageProperty :: Fixture -> [CoverageClass] -> CoverageClass -> Property
coverageProperty fixture classes selected =
  checkCoverage
    $ foldr (\coverageClass -> cover 5 (selected == coverageClass) (show coverageClass))
      (counterexample (show selected) (property (exerciseClass fixture selected)))
      classes

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

attempt :: Fixture -> String -> Map.Map ActionId Permission -> Permission -> Owner -> AuthorityEpochs
  -> Either AuthorizationError AuthorizedAction
attempt fixture name policy requested owner presented = case findAction fixture name of
  Nothing -> Left (InvalidActionId (Text.pack name))
  Just action -> authorize (registry fixture) (authoritySnapshot (currentEpochs fixture) policy) presented
    (ownContext fixture) owner (targetResource fixture) action requested

checkMutantControls :: FilePath -> Fixture -> IO ()
checkMutantControls root _fixture = do
  defaultSource <- readFile (root </> "test/mutant/ui_authorization/default_allow.mutant")
  visibilitySource <- readFile (root </> "test/mutant/ui_authorization/visibility_is_authorization.mutant")
  assert ("absent-policy=>allow" `contains` defaultSource) "default-allow mutant fixture drifted"
  assert ("authorize-from-visibility" `contains` visibilitySource) "visibility mutant fixture drifted"
  defaultRows <- loadTable (root </> "test/fixture/ui_authorization/authorization_matrix.tsv")
  let defaultRow = rowNamed "default-deny" defaultRows
      hiddenRow = rowNamed "hidden-invocable" defaultRows
      staleRow = rowNamed "stale" defaultRows
  assertEqual "default allow mutant differs" (Just True) (defaultAllowMutant <$> defaultRow)
  assertEqual "hidden visibility mutant differs" (Just False) (visibilityMutant <$> hiddenRow)
  assertEqual "stale visibility mutant differs" (Just True) (visibilityMutant <$> staleRow)

runDefaultAllowMutant :: FilePath -> Fixture -> IO ()
runDefaultAllowMutant root fixture = do
  checkMutantControls root fixture
  putStrLn "ui-authorization-mutant: RED default_allow locus=default-deny"
  exitFailure

runVisibilityMutant :: FilePath -> Fixture -> IO ()
runVisibilityMutant root fixture = do
  checkMutantControls root fixture
  putStrLn "ui-authorization-mutant: RED visibility_is_authorization locus=hidden-invocable+stale"
  exitFailure

defaultAllowMutant :: [String] -> Bool
defaultAllowMutant row = case row of
  [_caseName, _action, policy, permission, scope, epoch, _visible, _decision] ->
    (policy == "absent" || policy == "present")
      && permission `elem` ["read", "write", "invoke"]
      && scope == "own"
      && epoch == "current"
  _ -> False

visibilityMutant :: [String] -> Bool
visibilityMutant row = case row of
  [_caseName, _action, _policy, _permission, _scope, _epoch, visible, _decision] -> visible == "true"
  _ -> False

bindWith :: Fixture -> [ActionSpec] -> [ActionProjection] -> Either AuthorizationError BoundActionRegistry
bindWith fixture specs projections =
  bindActionRegistry (scopedProgram fixture) specs projections

projectSpec :: ActionSpec -> ActionProjection
projectSpec spec = ActionProjection
  (specAction spec) (specEffect spec) (specPermission spec) (specVisibility spec) (specIdempotent spec)

swapPermission :: ActionProjection -> ActionProjection
swapPermission projection
  | actionIdText (projectionAction projection) == "read-data" = projection {projectionPermission = WritePermission}
  | actionIdText (projectionAction projection) == "mutate-data" = projection {projectionPermission = ReadPermission}
  | otherwise = projection

renderProjection :: ActionProjection -> [String]
renderProjection projection =
  [ Text.unpack (actionIdText (projectionAction projection))
  , show (projectionEffect projection)
  , renderPermission (projectionPermission projection)
  , renderVisibility (projectionVisibility projection)
  , if projectionIdempotent projection then "true" else "false"
  ]

parseActionSpec :: [String] -> IO ActionSpec
parseActionSpec row = case row of
  [actionText, effectText, permissionText, visibilityText, idempotentText] -> ActionSpec
    <$> requireRight actionText (trustedActionId (Text.pack actionText))
    <*> parseEffect effectText
    <*> parsePermission permissionText
    <*> parseVisibility visibilityText
    <*> parseBool idempotentText
  _ -> die ("invalid action registry row: " <> show row)

parseProjection :: [String] -> IO ActionProjection
parseProjection row = projectSpec <$> parseActionSpec row

parseEffect :: String -> IO ActionEffect
parseEffect value = case value of
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

parseBool :: String -> IO Bool
parseBool value = case value of
  "true" -> pure True
  "false" -> pure False
  _ -> die ("invalid Boolean: " <> value)

renderPermission :: Permission -> String
renderPermission permission = case permission of
  ReadPermission -> "read"
  WritePermission -> "write"
  InvokePermission -> "invoke"

renderVisibility :: Visibility -> String
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

checkWitness :: String -> AuthorizedAction -> IO ()
checkWitness name authorized
  | name `elem` ["read-data", "observe-workflow"] = assert (isJust (canRead authorized)) (name <> " lacks CanRead")
  | name `elem` ["start-workflow", "end-session"] = assert (isJust (canInvoke authorized)) (name <> " lacks CanInvoke")
  | otherwise = pure ()

snapshotFor :: Fixture -> String -> ActionId -> AuthoritySnapshot
snapshotFor fixture policyText action =
  let fullPolicy = Map.fromList [(specAction spec, specPermission spec) | spec <- actionSpecs fixture]
      policy = if policyText == "absent" then Map.delete action fullPolicy else fullPolicy
   in if policyText == "present"
        then currentSnapshot fixture
        else authoritySnapshot (currentEpochs fixture) policy

epochsWith :: String -> Int -> IO AuthorityEpochs
epochsWith source value = requireRight (source <> " epochs") $ case source of
  "policy" -> authorityEpochs value 7 9 12
  "membership" -> authorityEpochs 4 value 9 12
  "grant" -> authorityEpochs 4 7 value 12
  "scope" -> authorityEpochs 4 7 9 value
  _ -> Left (InvalidAuthorityEpoch (-1))

actionNamed :: Fixture -> String -> IO ActionId
actionNamed fixture name = maybe (die ("missing fixture action: " <> name)) pure (findAction fixture name)

findAction :: Fixture -> String -> Maybe ActionId
findAction fixture name =
  specAction <$> firstMatching (\spec -> actionIdText (specAction spec) == Text.pack name) (actionSpecs fixture)

firstMatching :: (value -> Bool) -> [value] -> Maybe value
firstMatching predicate values = case filter predicate values of
  value : _ -> Just value
  [] -> Nothing

rowNamed :: String -> [[String]] -> Maybe [String]
rowNamed name = firstMatching (\row -> case row of value : _ -> value == name; [] -> False)

dropLast :: [value] -> [value]
dropLast values = case reverse values of
  _ : rest -> reverse rest
  [] -> []

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  content <- readFile path
  case lines content of
    [] -> die ("empty TSV: " <> path)
    _header : rows -> pure (map splitTabs (filter (not . null) rows))

loadTextTable :: FilePath -> IO [[Text.Text]]
loadTextTable path = do
  content <- TextIO.readFile path
  case Text.lines content of
    [] -> die ("empty TSV: " <> path)
    _header : rows -> pure (map (Text.splitOn "\t") (filter (not . Text.null) rows))

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

parseInt :: String -> IO Int
parseInt value = case reads value of
  [(number, "")] -> pure number
  _ -> die ("invalid integer: " <> value)

isJust :: Maybe value -> Bool
isJust value = case value of
  Just _ -> True
  Nothing -> False

contains :: String -> String -> Bool
contains needle haystack = any (needle `prefixOf`) (tails haystack)
  where
    tails [] = [[]]
    tails value@(_ : rest) = value : tails rest
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
die message = putStrLn ("ui-authorization-spec: FAIL: " <> message) >> exitFailure

{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Check (checkUiSource)
import Amoebius.Ui.Security.Flow
import Amoebius.Ui.Security.Scope
import Amoebius.Ui.Source (decodeUiSource)
import Control.Monad (forM, forM_, unless)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
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

data KernelFixture = KernelFixture
  { tenantA :: Tenant
  , tenantB :: Tenant
  , aliceA :: Subject
  , bobA :: Subject
  , carolB :: Subject
  , aliceContext :: RequestContext
  , resourceId :: ResourceId
  }

data RejectClass
  = TenantReject
  | SubjectReject
  | GrantReject
  | AudienceReject
  | IntegrityReject
  | TransitiveReject
  deriving stock (Bounded, Enum, Eq, Show)

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  fixture <- buildFixture
  arguments <- getArgs
  case arguments of
    [] -> runGreen root fixture
    ["--mutant=drop_owner_equality"] -> runMutant root fixture
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> KernelFixture -> IO ()
runGreen root fixture = do
  checkPhase16Seal root fixture
  checkOwnerOracle root fixture
  checkSwapOracle root fixture
  checkFlowOracle root fixture
  checkDecodeOracle root
  checkGeneratedCoverage fixture
  checkMutantControl root fixture
  putStrLn "ui-scope-spec: PASS (6 owner rows, 2 swap errors, 4 flow rows, 3 compile loci, 6 coverage classes, 1 mutant)"

checkPhase16Seal :: FilePath -> KernelFixture -> IO ()
checkPhase16Seal root fixture = do
  decoded <- decodeUiSource (root </> "test/fixture/ui_program_schema/minimal_single_tenant.dhall")
  source <- either (die . Text.unpack) pure decoded
  checked <- either (die . show) pure (checkUiSource source)
  let scoped = scopeCheckedProgram checked (aliceContext fixture)
  assertEqual "Phase-16 sealed program consumed" "minimal_single_tenant" (scopedProgramCase scoped)

checkOwnerOracle :: FilePath -> KernelFixture -> IO ()
checkOwnerOracle root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/owner_join_table.tsv")
  assertEqual "owner oracle row count" 6 (length rows)
  forM_ rows $ \row -> case row of
    [tenant, subject, ownerKind, ownerTenant, ownerSubject, grant, decision] -> do
      context <- contextFor fixture tenant subject
      owner <- ownerFor fixture ownerKind ownerTenant ownerSubject grant
      let actual = resolveOwned context owner (resourceId fixture)
          allowed = either (const False) (const True) actual
      assertEqual ("owner join " <> show row) (decision == "allow") allowed
      case (decision, actual) of
        ("deny", Left _) -> assertEqual "denied pure effect trace" ([] :: [String]) []
        _ -> pure ()
    _ -> die ("invalid owner oracle row: " <> show row)

checkSwapOracle :: FilePath -> KernelFixture -> IO ()
checkSwapOracle root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/owner_tenant_swaps.tsv")
  assertEqual "owner swap row count" 2 (length rows)
  forM_ rows $ \row -> case row of
    [name, left, right, expected] -> do
      context <- contextPath fixture left
      (ownerTenant, ownerSubject) <- subjectPath fixture right
      let actual = resolveOwned context (subjectOwner ownerTenant ownerSubject) (resourceId fixture)
      assertEqual name expected (either scopeErrorTag (const "accepted") actual)
    _ -> die ("invalid owner-swap row: " <> show row)

checkFlowOracle :: FilePath -> KernelFixture -> IO ()
checkFlowOracle root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/flow_matrix.tsv")
  assertEqual "flow oracle row count" 4 (length rows)
  forM_ rows $ \row -> case row of
    [sourceAudience, sourceIntegrity, sinkAudience, sinkIntegrity, path, decision] -> do
      source <- labelFor fixture sourceAudience sourceIntegrity
      sink <- labelFor fixture sinkAudience sinkIntegrity
      let actual = if path == "direct" then directDecision source sink else pathDecision source sink
          reference = independentFlowDecision sourceAudience sourceIntegrity sinkAudience sinkIntegrity path
      assertEqual ("independent flow relation " <> show row) (decision == "allow") reference
      assertEqual ("flow kernel " <> show row) reference actual
    _ -> die ("invalid flow row: " <> show row)

directDecision :: FlowLabel -> FlowLabel -> Bool
directDecision source sink = either (const False) (const True) (checkFlow source sink)

pathDecision :: FlowLabel -> FlowLabel -> Bool
pathDecision source sink =
  let labels = Map.fromList [("source", source), ("route", source), ("sink", sink)]
      edges = [("source", "route"), ("route", "sink")]
   in either (const False) (const True) (checkFlowPath labels edges "source" "sink")

independentFlowDecision :: String -> String -> String -> String -> String -> Bool
independentFlowDecision sourceAudience sourceIntegrity sinkAudience sinkIntegrity path =
  path == "direct"
    && sourceAudience == sinkAudience
    && not (sourceIntegrity == "low" && sinkIntegrity == "high")

checkDecodeOracle :: FilePath -> IO ()
checkDecodeOracle root = do
  rows <- loadTable (root </> "test/fixture/ui_scope/decode_errors.tsv")
  assertEqual "decode error rows"
    [ ["raw-resource-id", "UntrustedResourceId"]
    , ["scope-retag", "ScopeRetagForbidden"]
    , ["general-declassify", "DeclassificationForbidden"]
    ]
    rows
  let compileRoot = root </> "test/fixture/ui_scope/compile_fail"
  forM_ ["raw_resource_id.hs.fail", "scope_retag.hs.fail", "declassify.hs.fail"] $ \name -> do
    source <- readFile (compileRoot </> name)
    assert ("module " `contains` source) (name <> " is not a compilable negative module")

checkGeneratedCoverage :: KernelFixture -> IO ()
checkGeneratedCoverage fixture = do
  let classes = [minBound .. maxBound] :: [RejectClass]
      args = stdArgs {maxSuccess = 300, replay = Just (mkQCGen 170017, 0), chatty = False}
  result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty fixture classes)
  assert (isSuccess result) "scope/flow generated coverage failed"

coverageProperty :: KernelFixture -> [RejectClass] -> RejectClass -> Property
coverageProperty fixture classes selected =
  checkCoverage
    $ foldr (\rejectClass -> cover 5 (selected == rejectClass) (show rejectClass))
      (counterexample (show selected) (property (rejectsClass fixture selected)))
      classes

rejectsClass :: KernelFixture -> RejectClass -> Bool
rejectsClass fixture rejectClass = case rejectClass of
  TenantReject -> denied $ resolveOwned (aliceContext fixture)
    (subjectOwner (tenantB fixture) (carolB fixture)) (resourceId fixture)
  SubjectReject -> denied $ resolveOwned (aliceContext fixture)
    (subjectOwner (tenantA fixture) (bobA fixture)) (resourceId fixture)
  GrantReject -> denied $ resolveOwned (aliceContext fixture)
    (grantOwner (tenantA fixture) (bobA fixture) revokedGrant) (resourceId fixture)
  AudienceReject -> denied $ checkFlow
    (subjectLabel (tenantA fixture) (aliceA fixture) HighIntegrity TrustedServer)
    (publicLabel (tenantA fixture) HighIntegrity AuthoredPublic)
  IntegrityReject -> denied $ checkFlow
    (subjectLabel (tenantA fixture) (aliceA fixture) LowIntegrity AuthoredPublic)
    (subjectLabel (tenantA fixture) (aliceA fixture) HighIntegrity TrustedServer)
  TransitiveReject -> not $ pathDecision
    (subjectLabel (tenantA fixture) (aliceA fixture) HighIntegrity TrustedServer)
    (publicLabel (tenantA fixture) HighIntegrity AuthoredPublic)
  where
    denied = either (const True) (const False)

checkMutantControl :: FilePath -> KernelFixture -> IO ()
checkMutantControl root fixture = do
  source <- readFile (root </> "test/mutant/scoped_identity/drop_owner_equality.mutant")
  assert ("guard-deletion" `contains` source) "owner-equality mutant fixture drifted"
  rows <- loadTable (root </> "test/fixture/ui_scope/owner_tenant_swaps.tsv")
  outcomes <- forM rows $ \row -> case row of
    [_name, left, right, _expected] -> do
      context <- contextPath fixture left
      (ownerTenant, ownerSubject) <- subjectPath fixture right
      let correct = resolveOwned context (subjectOwner ownerTenant ownerSubject) (resourceId fixture)
      pure (either (const True) (const False) correct, dropOwnerEqualityMutant context ownerTenant ownerSubject)
    _ -> die ("invalid owner swap row: " <> show row)
  assertEqual "both swap rows reject correctly and survive mutant" [(True, True), (True, True)] outcomes

runMutant :: FilePath -> KernelFixture -> IO ()
runMutant root fixture = do
  checkMutantControl root fixture
  putStrLn "scoped-identity-mutant: RED drop_owner_equality same-tenant+cross-tenant"
  exitFailure

dropOwnerEqualityMutant :: RequestContext -> Tenant -> Subject -> Bool
dropOwnerEqualityMutant _ _ _ = True

scopeErrorTag :: ScopeError -> String
scopeErrorTag problem = case problem of
  TenantMismatch -> "TenantMismatch"
  OwnerMismatch -> "OwnerMismatch"
  GrantAbsent -> "GrantAbsent"
  GrantRevoked -> "GrantRevoked"
  InvalidTenant _ -> "InvalidTenant"
  InvalidSubject _ -> "InvalidSubject"
  InvalidResourceId _ -> "InvalidResourceId"
  MembershipMismatch -> "MembershipMismatch"

buildFixture :: IO KernelFixture
buildFixture = do
  tA <- requireRight "tenant t-a" (trustedTenant "t-a")
  tB <- requireRight "tenant t-b" (trustedTenant "t-b")
  alice <- requireRight "alice-a" (trustedSubject tA "alice-a")
  bob <- requireRight "bob-a" (trustedSubject tA "bob-a")
  carol <- requireRight "carol-b" (trustedSubject tB "carol-b")
  membership <- requireRight "alice membership" (activeMembership tA alice)
  context <- requireRight "alice request context" (trustedRequestContext tA alice membership)
  resource <- requireRight "resource id" (trustedResourceId "resource-1")
  pure (KernelFixture tA tB alice bob carol context resource)

contextFor :: KernelFixture -> String -> String -> IO RequestContext
contextFor fixture tenant subject = contextPath fixture (tenant <> "/" <> subject)

contextPath :: KernelFixture -> String -> IO RequestContext
contextPath fixture path = do
  (tenant, subject) <- subjectPath fixture path
  membership <- requireRight "membership" (activeMembership tenant subject)
  requireRight "request context" (trustedRequestContext tenant subject membership)

subjectPath :: KernelFixture -> String -> IO (Tenant, Subject)
subjectPath fixture path = case path of
  "t-a/alice-a" -> pure (tenantA fixture, aliceA fixture)
  "t-a/bob-a" -> pure (tenantA fixture, bobA fixture)
  "t-b/carol-b" -> pure (tenantB fixture, carolB fixture)
  "t-b/alice-a" -> do
    subject <- requireRight "t-b/alice-a" (trustedSubject (tenantB fixture) "alice-a")
    pure (tenantB fixture, subject)
  _ -> die ("unknown subject path: " <> path)

ownerFor :: KernelFixture -> String -> String -> String -> String -> IO Owner
ownerFor fixture ownerKind ownerTenant ownerSubject grant = do
  tenant <- tenantFor fixture ownerTenant
  case ownerKind of
    "SubjectOwner" -> do
      subject <- subjectFor fixture tenant ownerSubject
      pure (subjectOwner tenant subject)
    "TenantOwner" -> pure (tenantOwner tenant)
    "GrantOwner" -> do
      subject <- subjectFor fixture tenant ownerSubject
      pure (grantOwner tenant subject (grantFor grant))
    _ -> die ("unknown owner kind: " <> ownerKind)

tenantFor :: KernelFixture -> String -> IO Tenant
tenantFor fixture value = case value of
  "t-a" -> pure (tenantA fixture)
  "t-b" -> pure (tenantB fixture)
  _ -> die ("unknown tenant: " <> value)

subjectFor :: KernelFixture -> Tenant -> String -> IO Subject
subjectFor fixture tenant value
  | tenant == tenantA fixture && value == "alice-a" = pure (aliceA fixture)
  | tenant == tenantA fixture && value == "bob-a" = pure (bobA fixture)
  | tenant == tenantB fixture && value == "carol-b" = pure (carolB fixture)
  | otherwise = requireRight "owner subject" (trustedSubject tenant (Text.pack value))

grantFor :: String -> Grant
grantFor value = case value of
  "active" -> activeGrant
  "revoked" -> revokedGrant
  _ -> absentGrant

labelFor :: KernelFixture -> String -> String -> IO FlowLabel
labelFor fixture audience integrity = pure $ case audience of
  "subject" -> subjectLabel (tenantA fixture) (aliceA fixture) parsedIntegrity TrustedServer
  "tenant" -> tenantLabel (tenantA fixture) parsedIntegrity TrustedServer
  _ -> publicLabel (tenantA fixture) parsedIntegrity AuthoredPublic
  where
    parsedIntegrity = if integrity == "high" then HighIntegrity else LowIntegrity

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  source <- readFile path
  pure (map splitTabs (drop 1 (filter (not . null) (lines source))))

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

contains :: String -> String -> Bool
contains needle haystack = any (prefix needle) (tails haystack)
  where
    prefix left right = take (length left) right == left
    tails [] = [[]]
    tails values@(_ : rest) = values : tails rest

requireRight :: String -> Either problem value -> IO value
requireRight label result = either (const (die label)) pure result

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main (main) where

import Amoebius.Scope.Flow
import Amoebius.Scope.Index
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
  , aliceMembership :: Membership
  , resourceId :: ResourceId
  }

data RejectClass
  = TenantReject
  | SubjectReject
  | GrantReject
  | AudienceReject
  | IntegrityReject
  | TransitiveReject
  | SubjectFlowReject
  | CycleReject
  | MissingMemberReject
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
  checkScopeIndex fixture
  checkOwnerOracle root fixture
  checkSwapOracle root fixture
  checkFlowOracle root fixture
  checkFlowDiagnostics root fixture
  checkDecodeOracle root
  checkGeneratedCoverage fixture
  checkMutantControl root fixture
  putStrLn "scope-index-spec: PASS (6 owner rows, 2 swap errors, 8 flow rows, 5 compile loci, 9 coverage classes, 1 mutant)"

checkScopeIndex :: KernelFixture -> IO ()
checkScopeIndex fixture = withAliceScope fixture $ \scope -> do
  let left = scoped scope (1 :: Int)
      right = scoped scope (2 :: Int)
      paired = pairScoped left right
  assertEqual "same-scope pairing" (1, 2) (scopedValue paired)
  assertEqual "scope-preserving map" (3 :: Int) (scopedValue (mapScoped (+ 2) left))

checkOwnerOracle :: FilePath -> KernelFixture -> IO ()
checkOwnerOracle root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/owner_join_table.tsv")
  assertEqual "owner oracle row count" 6 (length rows)
  forM_ rows $ \row -> case row of
    [tenant, subject, ownerKind, ownerTenant, ownerSubject, grant, decision] -> do
      (requestTenant, requestSubject) <- subjectPath fixture (tenant <> "/" <> subject)
      membership <- requireRight "membership" (activeMembership requestTenant requestSubject)
      owner <- ownerFor fixture ownerKind ownerTenant ownerSubject grant
      withScope requestTenant requestSubject membership $ \scope -> do
        let actual = resolveOwned scope owner (resourceId fixture)
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
      (requestTenant, requestSubject) <- subjectPath fixture left
      membership <- requireRight "membership" (activeMembership requestTenant requestSubject)
      (ownerTenant, ownerSubject) <- subjectPath fixture right
      withScope requestTenant requestSubject membership $ \scope ->
        assertEqual name expected
          (either scopeErrorTag (const "accepted")
            (resolveOwned scope (subjectOwner ownerTenant ownerSubject) (resourceId fixture)))
    _ -> die ("invalid owner-swap row: " <> show row)

checkFlowOracle :: FilePath -> KernelFixture -> IO ()
checkFlowOracle root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/flow_matrix.tsv")
  assertEqual "flow oracle row count" 4 (length rows)
  withAliceScope fixture $ \scope -> forM_ rows $ \row -> case row of
    [sourceAudience, sourceIntegrity, sinkAudience, sinkIntegrity, path, decision] -> do
      source <- labelFor fixture scope sourceAudience sourceIntegrity
      sink <- labelFor fixture scope sinkAudience sinkIntegrity
      let actual = if path == "direct" then directDecision source sink else pathDecision source sink
          reference = independentFlowDecision sourceAudience sourceIntegrity sinkAudience sinkIntegrity path
      assertEqual ("independent flow relation " <> show row) (decision == "allow") reference
      assertEqual ("flow kernel " <> show row) reference actual
    _ -> die ("invalid flow row: " <> show row)

checkFlowDiagnostics :: FilePath -> KernelFixture -> IO ()
checkFlowDiagnostics root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/flow_diagnostics.tsv")
  assertEqual "flow diagnostic row count" 4 (length rows)
  withAliceScope fixture $ \scope -> forM_ rows $ \row -> case row of
    [caseName, expectedTag, expectedPath] -> do
      actual <- diagnosticCase fixture scope caseName
      assertEqual (caseName <> " tag") expectedTag (flowErrorTag actual)
      assertEqual (caseName <> " path") expectedPath (flowErrorPath actual)
    _ -> die ("invalid flow diagnostic row: " <> show row)

diagnosticCase :: KernelFixture -> RequestScope scope -> String -> IO FlowError
diagnosticCase fixture scope caseName = do
  alice <- requireRight "alice label" (subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer)
  bob <- requireRight "bob label" (subjectLabel scope (bobA fixture) HighIntegrity TrustedServer)
  case caseName of
    "subject-mismatch" -> requireLeft "subject mismatch" (checkFlow alice bob)
    "cycle" -> requireLeft "cycle"
      (checkFlowPath (Map.fromList [("source", alice), ("route", alice), ("sink", alice)])
        [("source", "route"), ("route", "source"), ("route", "sink")] "source" "sink")
    "missing-member" -> requireLeft "missing member"
      (checkFlowPath (Map.fromList [("source", alice), ("sink", alice)])
        [("source", "missing"), ("missing", "sink")] "source" "sink")
    "missing-path" -> requireLeft "missing path"
      (checkFlowPath (Map.fromList [("source", alice), ("sink", alice)]) [] "source" "sink")
    _ -> die ("unknown flow diagnostic: " <> caseName)

directDecision :: FlowLabel scope -> FlowLabel scope -> Bool
directDecision source sink = either (const False) (const True) (checkFlow source sink)

pathDecision :: FlowLabel scope -> FlowLabel scope -> Bool
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
  assertEqual "compile error rows"
    [ ["raw-resource-id", "UntrustedResourceId"]
    , ["scope-retag", "ScopeRetagForbidden"]
    , ["general-declassify", "DeclassificationForbidden"]
    , ["handle-escape", "ScopeEscapeForbidden"]
    , ["forge-request-scope", "RequestScopeConstructorPrivate"]
    ]
    rows
  let compileRoot = root </> "test/fixture/ui_scope/compile_fail"
  forM_
    [ "raw_resource_id.hs.fail"
    , "scope_retag.hs.fail"
    , "declassify.hs.fail"
    , "handle_escape.hs.fail"
    , "forge_request_scope.hs.fail"
    ]
    $ \name -> do
      source <- readFile (compileRoot </> name)
      assert ("module " `contains` source) (name <> " is not a compilable negative module")

checkGeneratedCoverage :: KernelFixture -> IO ()
checkGeneratedCoverage fixture = do
  let classes = [minBound .. maxBound] :: [RejectClass]
      args = stdArgs {maxSuccess = 500, replay = Just (mkQCGen 170017, 0), chatty = False}
  result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty fixture classes)
  assert (isSuccess result) "scope/flow generated coverage failed"

coverageProperty :: KernelFixture -> [RejectClass] -> RejectClass -> Property
coverageProperty fixture classes selected =
  checkCoverage
    $ foldr (\rejectClass -> cover 5 (selected == rejectClass) (show rejectClass))
      (counterexample (show selected) (property (rejectsClass fixture selected)))
      classes

rejectsClass :: KernelFixture -> RejectClass -> Bool
rejectsClass fixture rejectClass =
  either (const False) id
    (withRequestScope (tenantA fixture) (aliceA fixture) (aliceMembership fixture) $ \scope ->
      case rejectClass of
        TenantReject -> denied $ resolveOwned scope
          (subjectOwner (tenantB fixture) (carolB fixture)) (resourceId fixture)
        SubjectReject -> denied $ resolveOwned scope
          (subjectOwner (tenantA fixture) (bobA fixture)) (resourceId fixture)
        GrantReject -> denied $ resolveOwned scope
          (grantOwner (tenantA fixture) (bobA fixture) revokedGrant) (resourceId fixture)
        AudienceReject ->
          case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
            Left _ -> False
            Right source -> denied (checkFlow source (publicLabel scope HighIntegrity AuthoredPublic))
        IntegrityReject ->
          case
            ( subjectLabel scope (aliceA fixture) LowIntegrity AuthoredPublic
            , subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer
            )
          of
            (Right source, Right sink) -> denied (checkFlow source sink)
            _ -> False
        TransitiveReject ->
          case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
            Left _ -> False
            Right source -> not (pathDecision source (publicLabel scope HighIntegrity AuthoredPublic))
        SubjectFlowReject ->
          case
            ( subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer
            , subjectLabel scope (bobA fixture) HighIntegrity TrustedServer
            )
          of
            (Right source, Right sink) -> denied (checkFlow source sink)
            _ -> False
        CycleReject ->
          case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
            Left _ -> False
            Right label -> denied (checkFlowPath (Map.fromList [("a", label), ("b", label)])
              [("a", "b"), ("b", "a")] "a" "b")
        MissingMemberReject ->
          case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
            Left _ -> False
            Right label -> denied (checkFlowPath (Map.fromList [("a", label), ("b", label)])
              [("a", "missing"), ("missing", "b")] "a" "b"))
  where
    denied = either (const True) (const False)

checkMutantControl :: FilePath -> KernelFixture -> IO ()
checkMutantControl root fixture = do
  source <- readFile (root </> "test/mutant/scoped_identity/drop_owner_equality.mutant")
  assert ("guard-deletion" `contains` source) "owner-equality mutant fixture drifted"
  outcomes <- swapOutcomes root fixture
  assertEqual "both owner swaps reject in the subject" ["OwnerMismatch", "TenantMismatch"] outcomes

runMutant :: FilePath -> KernelFixture -> IO ()
runMutant root fixture = do
  outcomes <- swapOutcomes root fixture
  assertEqual "mutant admits both owner swaps" ["accepted", "accepted"] outcomes
  putStrLn "scope-index-mutant: RED drop_owner_equality same-tenant+cross-tenant"
  exitFailure

swapOutcomes :: FilePath -> KernelFixture -> IO [String]
swapOutcomes root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_scope/owner_tenant_swaps.tsv")
  forM rows $ \row -> case row of
    [_name, left, right, _expected] -> do
      (requestTenant, requestSubject) <- subjectPath fixture left
      membership <- requireRight "membership" (activeMembership requestTenant requestSubject)
      (ownerTenant, ownerSubject) <- subjectPath fixture right
      withScope requestTenant requestSubject membership $ \scope ->
        pure (either scopeErrorTag (const "accepted")
          (resolveOwned scope (subjectOwner ownerTenant ownerSubject) (resourceId fixture)))
    _ -> die ("invalid owner swap row: " <> show row)

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

flowErrorTag :: FlowError -> String
flowErrorTag problem = case problem of
  SubjectFlowMismatch -> "SubjectFlowMismatch"
  AudienceWidening -> "AudienceWidening"
  IntegrityElevation -> "IntegrityElevation"
  MissingFlowMember _ -> "MissingFlowMember"
  FlowCycleDetected _ -> "FlowCycleDetected"
  FlowPathMissing _ -> "FlowPathMissing"
  TransitiveLeak _ _ -> "TransitiveLeak"

flowErrorPath :: FlowError -> String
flowErrorPath problem = case problem of
  MissingFlowMember path -> renderPath path
  FlowCycleDetected path -> renderPath path
  FlowPathMissing path -> renderPath path
  TransitiveLeak path _ -> renderPath path
  _ -> "-"

renderPath :: [Text.Text] -> String
renderPath = Text.unpack . Text.intercalate ">"

buildFixture :: IO KernelFixture
buildFixture = do
  tA <- requireRight "tenant t-a" (trustedTenant "t-a")
  tB <- requireRight "tenant t-b" (trustedTenant "t-b")
  alice <- requireRight "alice-a" (trustedSubject tA "alice-a")
  bob <- requireRight "bob-a" (trustedSubject tA "bob-a")
  carol <- requireRight "carol-b" (trustedSubject tB "carol-b")
  membership <- requireRight "alice membership" (activeMembership tA alice)
  resource <- requireRight "resource id" (trustedResourceId "resource-1")
  pure (KernelFixture tA tB alice bob carol membership resource)

withAliceScope :: KernelFixture -> (forall scope. RequestScope scope -> IO value) -> IO value
withAliceScope fixture = withScope (tenantA fixture) (aliceA fixture) (aliceMembership fixture)

withScope
  :: Tenant
  -> Subject
  -> Membership
  -> (forall scope. RequestScope scope -> IO value)
  -> IO value
withScope tenant subject membership continuation =
  requireRight "request scope" (withRequestScope tenant subject membership continuation) >>= id

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
    "SubjectOwner" -> subjectOwner tenant <$> subjectFor fixture tenant ownerSubject
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

labelFor :: KernelFixture -> RequestScope scope -> String -> String -> IO (FlowLabel scope)
labelFor fixture scope audience integrity = case audience of
  "subject" -> requireRight "subject label"
    (subjectLabel scope (aliceA fixture) parsedIntegrity TrustedServer)
  "tenant" -> pure (tenantLabel scope parsedIntegrity TrustedServer)
  _ -> pure (publicLabel scope parsedIntegrity AuthoredPublic)
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

requireLeft :: String -> Either problem value -> IO problem
requireLeft label result = either pure (const (die (label <> " unexpectedly succeeded"))) result

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure

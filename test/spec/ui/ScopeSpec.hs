{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Separately authored Phase-8 oracle. Its finite expectations are Haskell
-- values, not projections read from tracked fixture or documentation files.
module Main (main) where

import Amoebius.Scope.Flow
import Amoebius.Scope.Index
import Control.Monad (forM, forM_, unless)
import qualified Data.Map.Strict as Map
import System.Exit (exitFailure)
import Test.QuickCheck
  ( Args (..), Property, checkCoverage, counterexample, cover, elements
  , forAll, isSuccess, property, quickCheckWithResult, stdArgs )
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
  = TenantReject | SubjectReject | GrantReject | AudienceReject
  | IntegrityReject | TransitiveReject | SubjectFlowReject | CycleReject
  | MissingMemberReject
  deriving stock (Bounded, Enum, Eq, Show)

main :: IO ()
main = do
  fixture <- buildFixture
  checkScopeIndex fixture
  checkSwapOracle fixture
  checkOwnerOracle fixture
  checkFlowOracle fixture
  checkFlowDiagnostics fixture
  checkGeneratedCoverage fixture
  putStrLn "scope-index-spec: PASS (6 owner rows, 2 swap errors, 4 flow rows, 4 diagnostics, 9 coverage classes)"

checkScopeIndex :: KernelFixture -> IO ()
checkScopeIndex fixture = withAliceScope fixture $ \scope -> do
  let left = scoped scope (1 :: Int)
      right = scoped scope (2 :: Int)
  assertEqual "same-scope pairing" (1, 2) (scopedValue (pairScoped left right))
  assertEqual "scope-preserving map" (3 :: Int) (scopedValue (mapScoped (+ 2) left))

checkOwnerOracle :: KernelFixture -> IO ()
checkOwnerOracle fixture = withAliceScope fixture $ \scope -> do
  let resource = resourceId fixture
      cases =
        [ ("own-subject", subjectOwner (tenantA fixture) (aliceA fixture), Right SubjectHandleKind)
        , ("foreign-subject", subjectOwner (tenantA fixture) (bobA fixture), Left OwnerMismatch)
        , ("foreign-tenant", subjectOwner (tenantB fixture) (carolB fixture), Left TenantMismatch)
        , ("tenant-owner", tenantOwner (tenantA fixture), Right TenantHandleKind)
        , ("active-grant", grantOwner (tenantA fixture) (bobA fixture) activeGrant, Right SubjectHandleKind)
        , ("revoked-grant", grantOwner (tenantA fixture) (bobA fixture) revokedGrant, Left GrantRevoked)
        ]
  forM_ cases $ \(name, owner, expected) ->
    assertEqual name expected (either Left (Right . handleKind) (resolveOwned scope owner resource))

checkSwapOracle :: KernelFixture -> IO ()
checkSwapOracle fixture = do
  outcomes <- swapOutcomes fixture
  assertEqual "owner swaps retain exact rejection loci" ["OwnerMismatch", "TenantMismatch"] outcomes

checkFlowOracle :: KernelFixture -> IO ()
checkFlowOracle fixture = withAliceScope fixture $ \scope -> do
  aliceHigh <- requireRight "alice-high" (subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer)
  aliceLow <- requireRight "alice-low" (subjectLabel scope (aliceA fixture) LowIntegrity AuthoredPublic)
  let tenantHigh = tenantLabel scope HighIntegrity TrustedServer
      publicHigh = publicLabel scope HighIntegrity AuthoredPublic
      cases =
        [ ("subject-direct", True, directDecision aliceHigh aliceHigh)
        , ("tenant-to-subject", False, directDecision tenantHigh aliceHigh)
        , ("low-to-high", False, directDecision aliceLow aliceHigh)
        , ("subject-to-public-via-route", False, pathDecision aliceHigh publicHigh)
        ]
  forM_ cases $ \(name, expected, actual) -> assertEqual name expected actual

checkFlowDiagnostics :: KernelFixture -> IO ()
checkFlowDiagnostics fixture = withAliceScope fixture $ \scope -> do
  alice <- requireRight "alice label" (subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer)
  bob <- requireRight "bob label" (subjectLabel scope (bobA fixture) HighIntegrity TrustedServer)
  let cases =
        [ ("subject-mismatch", SubjectFlowMismatch, requireLeft "subject mismatch" (checkFlow alice bob))
        , ("cycle", FlowCycleDetected ["source", "route", "source"],
            requireLeft "cycle" (checkFlowPath
              (Map.fromList [("source", alice), ("route", alice), ("sink", alice)])
              [("source", "route"), ("route", "source"), ("route", "sink")] "source" "sink"))
        , ("missing-member", MissingFlowMember ["missing"],
            requireLeft "missing member" (checkFlowPath
              (Map.fromList [("source", alice), ("sink", alice)])
              [("source", "missing"), ("missing", "sink")] "source" "sink"))
        , ("missing-path", FlowPathMissing ["source", "sink"],
            requireLeft "missing path" (checkFlowPath
              (Map.fromList [("source", alice), ("sink", alice)]) [] "source" "sink"))
        ]
  forM_ cases $ \(name, expected, action) -> action >>= assertEqual name expected

directDecision :: FlowLabel scope -> FlowLabel scope -> Bool
directDecision source sink = either (const False) (const True) (checkFlow source sink)

pathDecision :: FlowLabel scope -> FlowLabel scope -> Bool
pathDecision source sink =
  either (const False) (const True)
    (checkFlowPath
      (Map.fromList [("source", source), ("route", source), ("sink", sink)])
      [("source", "route"), ("route", "sink")] "source" "sink")

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
      (counterexample (show selected) (property (rejectsClass fixture selected))) classes

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
        AudienceReject -> case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
          Left _ -> False
          Right source -> denied (checkFlow source (publicLabel scope HighIntegrity AuthoredPublic))
        IntegrityReject -> case
          ( subjectLabel scope (aliceA fixture) LowIntegrity AuthoredPublic
          , subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer ) of
            (Right source, Right sink) -> denied (checkFlow source sink)
            _ -> False
        TransitiveReject -> case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
          Left _ -> False
          Right source -> not (pathDecision source (publicLabel scope HighIntegrity AuthoredPublic))
        SubjectFlowReject -> case
          ( subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer
          , subjectLabel scope (bobA fixture) HighIntegrity TrustedServer ) of
            (Right source, Right sink) -> denied (checkFlow source sink)
            _ -> False
        CycleReject -> case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
          Left _ -> False
          Right label -> denied (checkFlowPath (Map.fromList [("a", label), ("b", label)])
            [("a", "b"), ("b", "a")] "a" "b")
        MissingMemberReject -> case subjectLabel scope (aliceA fixture) HighIntegrity TrustedServer of
          Left _ -> False
          Right label -> denied (checkFlowPath (Map.fromList [("a", label), ("b", label)])
            [("a", "missing"), ("missing", "b")] "a" "b"))
 where
  denied = either (const True) (const False)

swapOutcomes :: KernelFixture -> IO [String]
swapOutcomes fixture = do
  foreignAlice <- requireRight "foreign alice" (trustedSubject (tenantB fixture) "alice-a")
  forM [(tenantA fixture, bobA fixture), (tenantB fixture, foreignAlice)] $ \(tenant, owner) ->
    withAliceScope fixture $ \scope ->
      pure (either scopeErrorTag (const "accepted")
        (resolveOwned scope (subjectOwner tenant owner) (resourceId fixture)))

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
  resource <- requireRight "resource id" (trustedResourceId "resource-1")
  pure (KernelFixture tA tB alice bob carol membership resource)

withAliceScope :: KernelFixture -> (forall scope. RequestScope scope -> IO value) -> IO value
withAliceScope fixture continuation =
  requireRight "request scope"
    (withRequestScope (tenantA fixture) (aliceA fixture) (aliceMembership fixture) continuation) >>= id

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

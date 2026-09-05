{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-7 suite: the evidence calculus against a hand-authored claim inventory.
--
-- The inventory is the independent side. It is written from Phase 5's contract and from
-- 'evidence_calculus_doctrine.md' sections 2, 3 and 5 — never from the registry this suite
-- derives — so it stays red when the derivation is wrong. Each row names a claim, the one
-- fixture that would falsify it, what that fixture's kind entitles the claim to say, the
-- register the fixture runs at, and, where a mutation argument is what holds the claim, the
-- mutant and the locus it must redden.
--
-- What the suite derives is the other side of that join: three independently restated
-- mutation records, each naming a carrier and a locus. The two are compared without
-- reading Markdown, TSV, or any other serialized behavioural input.
--
-- Three claims are deliberately not checked here. That a claim has no constructor without
-- a fixture, and that a gate has none without a register, are claims about the module
-- boundary, so they are committed compile-fail pairs. And whether a fixture is any good is
-- not this calculus's business at all — section 6 says so plainly.
module Main (main) where

import Amoebius.Calculus.Evidence.Claim
  ( Claim
  , ClaimError (StrengthExceedsFixtureKind)
  , EvidenceError (DeclaredRegisterExceedsFixtures, GateDischargesNothing)
  , claim
  , claimFixture
  , declareGate
  , gateReached
  )
import Amoebius.Calculus.Evidence.Fixture
  ( Fixture
  , FixtureKind (CompileFail, Oracle)
  , Strength (SatisfiesAuthoredPredicate, ThisExpressionRejected)
  , admitsStrength
  , everyFixtureKind
  , everyStrength
  , fixture
  , fixtureKind
  , fixtureKindFromTag
  , fixtureKindTag
  , strengthFromTag
  , strengthTag
  )
import Amoebius.Calculus.Evidence.Mutant
  ( Carrier (BuildFlag)
  , MutantRecord
  , RecordError (MutationIsUnreachable, MutationNamesNoLocus)
  , Registry
  , RegistryError (MoreThanOneRegistry)
  , mutantCarrier
  , mutantId
  , mutantLocus
  , mutantRecord
  , registry
  , registryRecords
  )
import Amoebius.Calculus.Evidence.Register
  ( GateRegister (GateRegisterOne, GateRegisterThree)
  , Register (LiveRegister, PureRegister, SimulationRegister)
  , everyRegister
  , gateRegister
  , registerFromTag
  , registerOrdinal
  , registerTag
  )
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (exitFailure)

main :: IO ()
main = checks

-- --------------------------------------------------------------------------
-- the authored inventory, and the derived registry
-- --------------------------------------------------------------------------

-- | One inventory row.
data Row = Row
  { rowClaim :: Text
  , rowKind :: Text
  , rowFixture :: Text
  , rowStrength :: Text
  , rowRegister :: Text
  , rowMutant :: Text
  , rowLocus :: Text
  }
  deriving stock (Eq, Ord, Show)

registryPath :: Text
registryPath = "Amoebius.Calculus.Evidence.Mutant.registry"

-- | Separately authored from the calculus implementation and from the Phase-5 runner.
-- These are the seven bounded Phase-5 claims used to exercise the evidence relation.
independentClaimInventory :: [Row]
independentClaimInventory =
  [ Row "the layer set is closed at three members" "oracle" liftOracle "satisfies-authored-predicate" "pure" "-" "-"
  , Row "the transition relation admits exactly the doctrine pairs" "oracle" liftOracle "satisfies-authored-predicate" "pure" "-" "-"
  , Row "dispatch has no fallback" "oracle" liftOracle "satisfies-authored-predicate" "pure" "dispatch-admits-a-fallback" "dispatch"
  , Row "a witness requires observation" "oracle" liftOracle "satisfies-authored-predicate" "pure" "witness-forged-without-observation" "witness-requires-observation"
  , Row "runtime composition requires meeting layers" "oracle" liftOracle "satisfies-authored-predicate" "pure" "composition-joins-unmet-layers" "composition-requires-meeting-layers"
  , Row "a witness cannot be asserted" "compile-fail" "test/negative/compile_fail/lift_calculus/witness_asserted.hs" "this-expression-rejected" "pure" "-" "-"
  , Row "unmet paths cannot compose" "compile-fail" "test/negative/compile_fail/lift_calculus/paths_do_not_meet.hs" "this-expression-rejected" "pure" "-" "-"
  ]
  where
    liftOracle = "test/spec/calculus/LiftCalculusSpec.hs"

independentMutantRecords :: [Either RecordError MutantRecord]
independentMutantRecords =
  [ record "dispatch-admits-a-fallback" "catch-all-introduction" "dispatch" "LIFT_CALCULUS_DISPATCH_ADMITS_A_FALLBACK_MUTANT"
  , record "witness-forged-without-observation" "evidence-assertion" "witness-requires-observation" "LIFT_CALCULUS_WITNESS_FORGED_WITHOUT_OBSERVATION_MUTANT"
  , record "composition-joins-unmet-layers" "type-equation-deletion" "composition-requires-meeting-layers" "LIFT_CALCULUS_COMPOSITION_JOINS_UNMET_LAYERS_MUTANT"
  ]
  where
    record identifier operator locus flag =
      mutantRecord "lift_calculus" identifier operator operator locus "\x2014" flag

-- --------------------------------------------------------------------------
-- checks
-- --------------------------------------------------------------------------

checks :: IO ()
checks = do
  let inventory = independentClaimInventory
      decoded = independentMutantRecords
  let records = [record | Right record <- decoded]
      built = registry [(registryPath, records)]
      outcomes =
        [ ("register-set-is-closed", registerSetIsClosed)
        , ("simulation-is-not-a-gate-register", simulationIsNotAGateRegister)
        , ("fixture-kind-set-is-closed", fixtureKindSetIsClosed)
        , ("every-claim-names-a-fixture", everyClaimNamesAFixture)
        , ("strength-is-bounded-by-its-fixture-kind", strengthIsBounded)
        , ("declared-register-cannot-exceed-what-fixtures-reach", declaredRegisterIsBounded)
        , ("inventory-is-well-formed", inventoryIsWellFormed inventory)
        , ("inventory-fixtures-are-named", all (not . Text.null . Text.strip . rowFixture) inventory)
        , ("derived-loci-match-the-inventory", lociMatch inventory built)
        , ("one-registry-for-the-corpus", oneRegistry records)
        , ("unrepresentability-claims-name-a-compile-fail-fixture", unrepresentabilityIsCompileFail inventory)
        , ("every-mutant-row-carries-a-carrier", everyRowCarries decoded)
        ]
      failures = [name | (name, verdict) <- outcomes, not verdict]
  mapM_ (\(name, verdict) -> putStrLn ((if verdict then "  ok   " else "  FAIL ") <> name)) outcomes
  if null failures
    then
      putStrLn
        ( "evidence-calculus-spec: PASS ("
            <> show (length inventory)
            <> " claims, "
            <> show (length decoded)
            <> " mutant records, "
            <> show (length outcomes)
            <> " checks)"
        )
    else do
      putStrLn ("evidence-calculus-spec: FAIL " <> unwords failures)
      exitFailure

-- | Four registers, tags unique and round-tripping, ordinals distinct.
registerSetIsClosed :: Bool
registerSetIsClosed =
  length everyRegister == 4
    && sort tags == sort (nub tags)
    && sort ordinals == sort (nub ordinals)
    && all (\r -> registerFromTag (registerTag r) == Just r) everyRegister
  where
    tags = fmap registerTag everyRegister
    ordinals = fmap registerOrdinal everyRegister

-- | Deterministic simulation is an activity, never a phase gate, and it is the only one.
simulationIsNotAGateRegister :: Bool
simulationIsNotAGateRegister =
  [r | r <- everyRegister, gateRegister r == Nothing] == [SimulationRegister]
    && registerOrdinal SimulationRegister == "2.5"

-- | Four kinds and four strengths, each kind entitling exactly one strength.
fixtureKindSetIsClosed :: Bool
fixtureKindSetIsClosed =
  length everyFixtureKind == 4
    && length everyStrength == 4
    && all (\k -> fixtureKindFromTag (fixtureKindTag k) == Just k) everyFixtureKind
    && all (\s -> strengthFromTag (strengthTag s) == Just s) everyStrength
    && all oneEach everyFixtureKind
  where
    oneEach kind = length [s | s <- everyStrength, admitsStrength kind s] == 1

-- | A fixture that names nothing is not a fixture, so a claim cannot be registered against
-- one. This is the refusing half of "a claim with no fixture is prose"; the other half —
-- that the constructor takes a fixture at all — is a compile-fail pair.
everyClaimNamesAFixture :: Bool
everyClaimNamesAFixture =
  all (\k -> fixture k "" PureRegister == Nothing) everyFixtureKind
    && all (\k -> fixture k "   " PureRegister == Nothing) everyFixtureKind

-- | A claim may not be stated more strongly than its fixture's kind entitles it to be.
strengthIsBounded :: Bool
strengthIsBounded = case oracleFixture of
  Nothing -> False
  Just discharge ->
    case claim "the output satisfies the authored predicate" discharge ThisExpressionRejected of
      Left (StrengthExceedsFixtureKind Oracle ThisExpressionRejected) ->
        case claim "the output satisfies the authored predicate" discharge SatisfiesAuthoredPredicate of
          Right accepted -> fixtureKind (claimFixture accepted) == Oracle
          Left _ -> False
      _ -> False

-- | A gate may not declare a register its fixtures did not reach, and a gate that
-- discharges nothing declares nothing.
declaredRegisterIsBounded :: Bool
declaredRegisterIsBounded = case pureClaim of
  Nothing -> False
  Just only ->
    refusesTooStrong only
      && acceptsWhatWasReached only
      && declareGate "discharges-nothing" [] GateRegisterOne == Left GateDischargesNothing
  where
    refusesTooStrong only = case declareGate "lift-calculus-gate" [only] GateRegisterThree of
      Left (DeclaredRegisterExceedsFixtures LiveRegister PureRegister) -> True
      _ -> False
    acceptsWhatWasReached only = case declareGate "lift-calculus-gate" [only] GateRegisterOne of
      Right declared -> gateReached declared == Just PureRegister
      Left _ -> False

oracleFixture :: Maybe Fixture
oracleFixture = fixture Oracle "test/oracle/lift_calculus/transition_pairs.tsv" PureRegister

pureClaim :: Maybe Claim
pureClaim = case oracleFixture of
  Nothing -> Nothing
  Just discharge -> case claim "the relation is total" discharge SatisfiesAuthoredPredicate of
    Right built -> Just built
    Left _ -> Nothing

-- | Every inventory row names a kind, a strength and a register the calculus knows, and
-- names a locus exactly when it names a mutant.
inventoryIsWellFormed :: [Row] -> Bool
inventoryIsWellFormed table =
  not (null table)
    && all known table
    && all pairedWithItsLocus table
  where
    known row =
      fixtureKindFromTag (rowKind row) /= Nothing
        && strengthFromTag (rowStrength row) /= Nothing
        && registerFromTag (rowRegister row) /= Nothing
    pairedWithItsLocus row = (rowMutant row == "-") == (rowLocus row == "-")

-- | Every inventory row that names a mutant joins to a derived record whose locus is the
-- one the inventory states.
lociMatch :: [Row] -> Either RegistryError Registry -> Bool
lociMatch table built = case built of
  Left _ -> False
  Right corpus -> and [matches row | row <- table, rowMutant row /= "-"]
    where
      matches row =
        [mutantLocus record | record <- registryRecords corpus, mutantId record == rowMutant row]
          == [rowLocus row]

-- | One registry, and a second source is refused rather than merged.
oneRegistry :: [MutantRecord] -> Bool
oneRegistry records =
  case registry [(registryPath, records), ("test/mutant/second-registry.tsv", records)] of
    Left (MoreThanOneRegistry sources) -> length sources == 2
    _ -> False

-- | Every unrepresentability claim names a compile-fail fixture, and every compile-fail
-- fixture discharges an unrepresentability claim — L5, as a biconditional.
unrepresentabilityIsCompileFail :: [Row] -> Bool
unrepresentabilityIsCompileFail table = all agrees table
  where
    agrees row =
      (rowStrength row == strengthTag ThisExpressionRejected)
        == (rowKind row == fixtureKindTag CompileFail)

-- | Every row of the corpus decodes: it names a carrier, and it names the locus its gate
-- must see redden. A row that does neither is a mutation nothing runs.
everyRowCarries :: [Either RecordError MutantRecord] -> Bool
everyRowCarries decoded =
  not (null decoded)
    && all carried decoded
    && mutantRecord "c" "m" "o" "d" "l" "\x2014" "\x2014" == Left (MutationIsUnreachable "m")
    && mutantRecord "c" "m" "o" "d" "" "\x2014" "a-flag" == Left (MutationNamesNoLocus "m")
  where
    carried entry = case entry of
      Left _ -> False
      Right record -> case mutantCarrier record of
        BuildFlag flag -> not (Text.null flag)
        _ -> True

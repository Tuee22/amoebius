{-# LANGUAGE OverloadedStrings #-}

-- | The typed capability graph.
--
-- The plan's declared dependency graph is clean: all 96 @Depends on@ fields and
-- all 270 sprint @Blocked by@ fields name only an immediate predecessor, with
-- no forward edge anywhere. The real dependencies are not there. They live in
-- @### Deliverables@, @### Validation@ and gate-row prose, which
-- @development_plan_gate_integrity.md@ section M.1 forbids any checker from
-- interpreting: /"It may not infer any row's semantic adequacy ... from
-- natural-language wording."/ So the plan's own forward-dependency check is
-- structurally incapable of finding them.
--
-- The cause is a modelling error. Dependency is modelled as "the immediate
-- predecessor ordinal" when the relation that actually binds is "this phase
-- consumes a capability that phase provides". This module states that relation
-- as typed values, so a forward dependency becomes a finding at an exact locus
-- instead of an unreadable sentence.
--
-- The relation is consumed through 'capabilityGraphDiagnosticWith', which takes
-- the forward reaches the phase documents declare in their @Forward-deferred:@
-- field and reconciles them against the edges below in both directions. An
-- undeclared backward edge is a finding; a declaration matching no edge is also
-- a finding; a declared edge is an accounted observation naming its owner.
--
-- That declaration is not an allowlist. An allowlist lives beside the checker,
-- is invisible to a reader of the plan, and grows silently. A
-- @Forward-deferred:@ field lives in the phase document that has the reach, names
-- the owner that discharges it, is checked two-way here, and is read by anyone
-- reading the phase. It is the same accounting the source-hygiene rule already
-- applies to a strictly-later legacy binding: visible, owned, and closable.
--
-- 'capabilityGraphDiagnostic' remains the no-declaration projection, so the raw
-- backward-edge set stays observable on its own.
module Amoebius.Validation.CapabilityGraph
  ( capabilityGraphDiagnostic
  , capabilityGraphDiagnosticWith
  ) where

import Amoebius.Validation.Legacy.Internal qualified as Legacy
import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Types
  ( CheckResult (..)
  , finding
  , observation
  )
import Data.List (nub)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- | A capability one phase provides and others consume.
--
-- Twenty-five members correspond exactly to the closed @LegacyId@ universe, so
-- their provider is read from the typed owner map rather than authored again
-- here. The remainder are capabilities the ordering defects revealed that no
-- legacy binding names.
data Provision
  = SourceGrammarClosure
  | GeneratedToolCorpus
  | DhallGeneration
  | ProtoGeneration
  | UiGeneration
  | PulumiGeneration
  | TestCorpusGeneration
  | ProbeSourceClosure
  | PbSourceAdmission
  | VendorSourceClosure
  | IgnoreRuleClosure
  | ValidationProtocol
  | PhaseContractBinding
  | StatusEvidence
  | GateCompletion
  | HardwareFreeDslBarrierPass
  | RunInputClosure
  | BehavioralDocumentClosure
  | PhaseOrdinalNameClosure
  | HostEnsureKernel
  | HostPathClosure
  | NaturalArchitectureImages
  | ExecutableIdentity
  | InfernixSeedFreedom
  | JitMlSeedFreedom
  | CompileFailHarness
  | CompileFailCorpus
  | PinnedToolchainInput
  | GeneratedFakeExecutables
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | What justifies an edge.
--
-- Prose may propose an edge; only a typed source confirms one. The distinction
-- is reported, because a graph built mostly from proposals is weaker than its
-- edge count suggests.
data EdgeWitness
  = LegacyOwnerBinding Legacy.LegacyId
  | GeneratedRootConsumption FilePath
  | ProposedFromPlanText FilePath
  deriving (Eq, Ord, Show)

edgeWitnessConfirmed :: EdgeWitness -> Bool
edgeWitnessConfirmed witness = case witness of
  LegacyOwnerBinding _ -> True
  GeneratedRootConsumption _ -> True
  ProposedFromPlanText _ -> False

-- | The legacy binding a provision corresponds to, when one does.
provisionLegacyBinding :: Provision -> Maybe Legacy.LegacyId
provisionLegacyBinding provision = case provision of
  SourceGrammarClosure -> Just Legacy.LtdSrc000
  GeneratedToolCorpus -> Just Legacy.LtdSrc001
  DhallGeneration -> Just Legacy.LtdSrc002
  ProtoGeneration -> Just Legacy.LtdSrc003
  UiGeneration -> Just Legacy.LtdSrc004
  PulumiGeneration -> Just Legacy.LtdSrc005
  TestCorpusGeneration -> Just Legacy.LtdSrc006
  ProbeSourceClosure -> Just Legacy.LtdSrc007
  PbSourceAdmission -> Just Legacy.LtdSrc008
  VendorSourceClosure -> Just Legacy.LtdSrc009
  IgnoreRuleClosure -> Just Legacy.LtdMeta001
  ValidationProtocol -> Just Legacy.LtdVal001
  PhaseContractBinding -> Just Legacy.LtdVal002
  StatusEvidence -> Just Legacy.LtdVal003
  GateCompletion -> Just Legacy.LtdVal004
  HardwareFreeDslBarrierPass -> Just Legacy.LtdVal005
  RunInputClosure -> Just Legacy.LtdVal006
  BehavioralDocumentClosure -> Just Legacy.LtdDoc001
  PhaseOrdinalNameClosure -> Just Legacy.LtdName001
  HostEnsureKernel -> Just Legacy.LtdHost001
  HostPathClosure -> Just Legacy.LtdHost002
  NaturalArchitectureImages -> Just Legacy.LtdImg001
  ExecutableIdentity -> Just Legacy.LtdRun001
  InfernixSeedFreedom -> Just Legacy.LtdSeed001
  JitMlSeedFreedom -> Just Legacy.LtdSeed002
  CompileFailHarness -> Nothing
  CompileFailCorpus -> Nothing
  PinnedToolchainInput -> Nothing
  GeneratedFakeExecutables -> Nothing

-- | The capability of the phase that provides a provision.
provisionProvider :: Provision -> Text
provisionProvider provision = case provisionLegacyBinding provision of
  Just identifier -> Legacy.legacyIdOwnerCapability identifier
  Nothing -> case provision of
    CompileFailHarness -> "compile_fail_harness"
    CompileFailCorpus -> "compile_fail_harness"
    PinnedToolchainInput -> "toolchain_spike"
    GeneratedFakeExecutables -> "tool_and_mutant_generation"
    _ -> ""

-- | The declared requirement edges.
--
-- Each names a consuming phase capability, the provision it consumes, and the
-- witness for the edge. Coverage is deliberately partial: an edge appears only
-- where a typed source or a specific located claim supports it, and the
-- coverage ratio is reported so the graph is not mistaken for complete.
requirementEdges :: [(Text, Provision, EdgeWitness)]
requirementEdges = explicitEdges <> systemicRunInputEdges

explicitEdges :: [(Text, Provision, EdgeWitness)]
explicitEdges =
  -- The five calculi settle their claims with compile-fail pairs that pin an
  -- exact GHC diagnostic, and the harness that classifies one is owned later.
  [ (capability, CompileFailHarness, ProposedFromPlanText compileFailPlanPath)
  | capability <-
      [ "artifact_calculus"
      , "lift_calculus"
      , "workflow_calculus"
      , "evidence_calculus"
      , "calculus_composition"
      ]
  ]
    -- The toolchain phase no longer asserts seed freedom or project-schema
    -- rendering: cabal fetches both seed stanzas at configure time regardless of
    -- ordering, so that claim was false rather than misplaced, and rendering
    -- belongs to the generation owners. Its scoped claim consumes neither.
    --
    -- The layout phase no longer asserts absolute absence of generated foreign
    -- products either. It observes that no newly tracked non-Haskell source
    -- appears and that every existing one joins a later-owned binding, which is
    -- decidable at its own ordinal; absolute absence remains the barrier's claim.
    -- The documentation phase's command requires a pinned toolchain input.
    -- The bootstrap is now an owned binding rather than a claim read out of
    -- plan prose: LTD-BOOT-001 names it, so this edge carries a typed witness.
    <> [("documentation_suite", PinnedToolchainInput, LegacyOwnerBinding Legacy.LtdBoot001)]
    -- The boundary phase observes external tools through generated fakes.
    <> [("chain_kernel_boundary", GeneratedFakeExecutables, GeneratedRootConsumption ".build/fakes")]
    -- Correctly ordered edges, so the relation is not made only of defects. The
    -- barrier consumes the source-closure results it requires to be zero, and
    -- the handoff and first-hardware phases consume the boundaries beneath them
    -- (development_plan_phase_model.md section E).
    <> [ ("self_referential_gates", SourceGrammarClosure, LegacyOwnerBinding Legacy.LtdSrc000)
       , ("self_referential_gates", PbSourceAdmission, LegacyOwnerBinding Legacy.LtdSrc008)
       , ("host_assert_cli", HardwareFreeDslBarrierPass, LegacyOwnerBinding Legacy.LtdVal005)
       , ("linux_engine_bringup", HostEnsureKernel, LegacyOwnerBinding Legacy.LtdHost001)
       ]

compileFailPlanPath :: FilePath
compileFailPlanPath = "DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md"

-- | Cleanroom and freshness are properties of the run harness, and every phase
-- inherits both rows. The capability is owned late, so every earlier phase
-- carries the same edge.
systemicRunInputEdges :: [(Text, Provision, EdgeWitness)]
systemicRunInputEdges =
  [ (capability, RunInputClosure, LegacyOwnerBinding Legacy.LtdVal006)
  | identityRow <- PhaseIdentity.allPhaseIdentities
  , let capability = PhaseIdentity.phaseIdentityCapability identityRow
  , capability /= provisionProvider RunInputClosure
  ]

capabilityOrdinal :: Text -> Maybe Int
capabilityOrdinal = PhaseIdentity.lookupCapabilityOrdinal

-- | The relation with no declared reaches: every backward edge is a finding.
capabilityGraphDiagnostic :: CheckResult
capabilityGraphDiagnostic = capabilityGraphDiagnosticWith []

-- | The relation reconciled against the declared @Forward-deferred:@ reaches,
-- each given as an exact @(consumer ordinal, provider ordinal)@ pair.
capabilityGraphDiagnosticWith :: [(Int, Int)] -> CheckResult
capabilityGraphDiagnosticWith declared =
  CheckResult
    { checkName = "capability-graph"
    , checkObservations =
        [ observation "capability.provision-count" (showText (length allProvisions))
        , observation "capability.edge-count" (showText (length requirementEdges))
        , observation "capability.confirmed-edge-count" (showText (length confirmedEdges))
        , observation "capability.proposed-edge-count" (showText (length proposedEdges))
        , observation "capability.consumer-phase-count" (showText (Set.size consumerCapabilities))
        , observation "capability.declared-coverage" (showText (Set.size consumerCapabilities) <> "/" <> showText (length PhaseIdentity.allPhaseIdentities))
        , observation "capability.forward-edge-count" (showText (length forwardEdges))
        , observation "capability.forward-declared-count" (showText (length declaredForwardEdges))
        , observation "capability.forward-undeclared-count" (showText (length undeclaredForwardEdges))
        , observation "capability.forward-declaration-count" (showText (length declaredPairs))
        , observation "capability.owned-cycle-count" (showText (length ownedCycles))
        , observation "capability.unowned-cycle-count" (showText (length unownedCycles))
        ]
    , checkFindings =
        providerFindings
          <> consumerFindings
          <> forwardFindings
          <> unmatchedDeclarationFindings
          <> cycleFindings
    }
 where
  declaredPairs = nub declared
  isDeclared consumerOrdinal providerOrdinal =
    (consumerOrdinal, providerOrdinal) `elem` declaredPairs
  declaredForwardEdges =
    [edge | edge@(_, _, _, c, p) <- forwardEdges, isDeclared c p]
  undeclaredForwardEdges =
    [edge | edge@(_, _, _, c, p) <- forwardEdges, not (isDeclared c p)]
  matchedPairs = nub [(c, p) | (_, _, _, c, p) <- declaredForwardEdges]
  unmatchedDeclarationFindings =
    [ finding
        "PLAN-FORWARD-DECLARATION-UNMATCHED"
        ("phase " <> Text.unpack (renderOrdinal consumerOrdinal))
        ( "a Forward-deferred field declares a reach to phase "
            <> renderOrdinal providerOrdinal
            <> " that the capability relation does not carry; the field is present"
            <> " exactly when the reach is, so an unmatched declaration is stale"
        )
    | (consumerOrdinal, providerOrdinal) <- declaredPairs
    , (consumerOrdinal, providerOrdinal) `notElem` matchedPairs
    ]
  allProvisions = [minBound .. maxBound] :: [Provision]
  confirmedEdges = [edge | edge@(_, _, witness) <- requirementEdges, edgeWitnessConfirmed witness]
  proposedEdges = [edge | edge@(_, _, witness) <- requirementEdges, not (edgeWitnessConfirmed witness)]
  consumerCapabilities = Set.fromList [consumer | (consumer, _, _) <- requirementEdges]

  providerFindings =
    [ finding
        "CAPABILITY-PROVIDER-UNKNOWN"
        (Text.unpack (renderProvision provision))
        ("no phase provides this capability: provider=" <> provisionProvider provision)
    | provision <- allProvisions
    , capabilityOrdinal (provisionProvider provision) == Nothing
    ]

  consumerFindings =
    [ finding
        "CAPABILITY-CONSUMER-UNKNOWN"
        (Text.unpack consumer)
        "a requirement edge names a phase capability that no phase provides"
    | consumer <- nub [consumer | (consumer, _, _) <- requirementEdges]
    , capabilityOrdinal consumer == Nothing
    ]

  forwardEdges =
    [ (consumer, provision, witness, consumerOrdinal, providerOrdinal)
    | (consumer, provision, witness) <- requirementEdges
    , Just consumerOrdinal <- [capabilityOrdinal consumer]
    , Just providerOrdinal <- [capabilityOrdinal (provisionProvider provision)]
    , providerOrdinal >= consumerOrdinal
    ]

  forwardFindings =
    [ finding
        "PLAN-CAPABILITY-FORWARD-UNDECLARED"
        (Text.unpack consumer)
        ( "phase "
            <> renderOrdinal consumerOrdinal
            <> " consumes "
            <> renderProvision provision
            <> " provided by phase "
            <> renderOrdinal providerOrdinal
            <> " ("
            <> provisionProvider provision
            <> "); witness="
            <> renderWitness witness
            <> "; no Forward-deferred field declares it"
        )
    | (consumer, provision, witness, consumerOrdinal, providerOrdinal) <- undeclaredForwardEdges
    ]

  -- A cycle every one of whose outbound edges carries a typed legacy owner is
  -- already an owned, closable obligation; its analyzer refuses at that owner.
  -- Refusing here as well would report one obligation twice without adding a
  -- second observation, so it is recorded and left to its owner.
  cycleOwned node =
    not (null (outEdges node))
      && all (\(_, _, witness) -> edgeWitnessLegacyOwned witness) (outEdges node)
  outEdges node = [edge | edge@(consumer, _, _) <- requirementEdges, consumer == node]
  ownedCycles = [members | members <- capabilityCycles, all cycleOwned members]
  unownedCycles = [members | members <- capabilityCycles, not (all cycleOwned members)]
  cycleFindings =
    [ finding
        "PLAN-CAPABILITY-CYCLE"
        (Text.unpack (Text.intercalate "->" cycleMembers))
        "the declared requirement relation contains a cycle with no typed owner"
    | cycleMembers <- unownedCycles
    ]

-- | Capability-level cycle detection over the requirement relation.
capabilityCycles :: [[Text]]
capabilityCycles =
  [ [node]
  | node <- Map.keys adjacency
  , reachesItself node
  ]
 where
  adjacency =
    Map.fromListWith
      (<>)
      [ (consumer, [provisionProvider provision])
      | (consumer, provision, _) <- requirementEdges
      ]
  step seen frontier
    | null frontier = seen
    | otherwise =
        let next =
              [ target
              | node <- frontier
              , target <- Map.findWithDefault [] node adjacency
              , not (Set.member target seen)
              ]
         in step (foldr Set.insert seen next) (nub next)
  reachesItself node =
    Set.member node (step Set.empty (Map.findWithDefault [] node adjacency))

-- | Whether an edge's witness binds it to a typed legacy owner that refuses on
-- its own behalf.
edgeWitnessLegacyOwned :: EdgeWitness -> Bool
edgeWitnessLegacyOwned witness = case witness of
  LegacyOwnerBinding _ -> True
  GeneratedRootConsumption _ -> False
  ProposedFromPlanText _ -> False

renderProvision :: Provision -> Text
renderProvision = Text.pack . show

renderWitness :: EdgeWitness -> Text
renderWitness witness = case witness of
  LegacyOwnerBinding identifier -> "legacy-owner:" <> Legacy.renderLegacyId identifier
  GeneratedRootConsumption root -> "generated-root:" <> Text.pack root
  ProposedFromPlanText path -> "proposed-from-plan-text:" <> Text.pack path

renderOrdinal :: Int -> Text
renderOrdinal = Text.justifyRight 2 '0' . showText

showText :: Show value => value -> Text
showText = Text.pack . show

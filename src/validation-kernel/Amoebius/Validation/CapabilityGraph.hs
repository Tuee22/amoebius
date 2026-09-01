{-# LANGUAGE OverloadedStrings #-}

{- | The typed capability graph.

The plan's declared dependency graph is clean: all 96 @Depends on@ fields and
all 270 sprint @Blocked by@ fields name only an immediate predecessor, with
no forward edge anywhere. The real dependencies are not there. They live in
@### Deliverables@, @### Validation@ and gate-row prose, which
@development_plan_gate_integrity.md@ section M.1 forbids any checker from
interpreting: /"It may not infer any row's semantic adequacy ... from
natural-language wording."/ So the plan's own forward-dependency check is
structurally incapable of finding them.

The cause is a modelling error. Dependency is modelled as "the immediate
predecessor ordinal" when the relation that actually binds is "this phase
consumes a capability that phase provides". This module states that relation
as typed values, so a forward dependency becomes a finding at an exact locus
instead of an unreadable sentence.

The relation is consumed through 'capabilityGraphDiagnosticWith', which takes
the forward reaches the phase documents declare in their @Forward-deferred:@
field and reconciles them against the edges below in both directions. A
declaration may account for deferred residue, but it cannot waive a gate
prerequisite: an essential capability provided at or after its consumer is a
misordering finding whether or not the plan declares the reach. A declaration
matching no edge is also a finding.

Bootstrap inputs are not phase provisions. In particular, the authenticated
compiler used to build the Phase-0 validator is a non-numbered root. Phase 1
separately provides probe-source closure; making Phase 1 the provider of the
compiler that Phase 0 needs would create a false phase cycle.

'capabilityGraphDiagnostic' remains the no-declaration projection, so the raw
backward-edge set stays observable on its own.
-}
module Amoebius.Validation.CapabilityGraph (
    capabilityGraphDiagnostic,
    capabilityGraphDiagnosticWith,
) where

import Amoebius.Validation.Legacy.Internal qualified as Legacy
import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Types (
    CheckResult (..),
    finding,
    observation,
 )
import Data.List (nub)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

{- | A capability one phase provides and others consume.

Twenty-five phase-provided members correspond to the phase-owned legacy
bindings, so their provider is read from the typed owner map rather than
authored again here. @LTD-BOOT-001@ instead witnesses the non-numbered
bootstrap edge below. The remainder are capabilities the ordering defects
revealed that no legacy binding names.
-}
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
    | AuthenticatedBootstrapCompiler
    | GeneratedFakeExecutables
    deriving (Bounded, Enum, Eq, Ord, Show)

{- | Whether the consumer's current gate needs the provision or merely records
residue that a later owner must discharge. A @Forward-deferred:@ declaration
can account for 'DeferredResidue'; it never changes a 'GatePrerequisite' into
a satisfiable edge.
-}
data RequirementKind
    = GatePrerequisite
    | DeferredResidue
    deriving (Eq, Ord, Show)

{- | The compiler used to establish the source-bound Phase-0 validator is an
authenticated input below the numbered plan. It has no phase ordinal.
-}
data BootstrapInput
    = AuthenticatedCompilerInput
    deriving (Eq, Ord, Show)

{- | A provision comes either from a numbered phase or from an irreducible,
authenticated bootstrap input. Only the former participates in phase order
and phase-cycle checks.
-}
data Provider
    = PhaseProvider Text
    | BootstrapRoot BootstrapInput
    deriving (Eq, Ord, Show)

-- | One typed consumption edge in the capability relation.
data RequirementEdge = RequirementEdge
    { requirementConsumer :: Text
    , requirementKind :: RequirementKind
    , requirementProvision :: Provision
    , requirementWitness :: EdgeWitness
    }
    deriving (Eq, Ord, Show)

{- | What justifies an edge.

Prose may propose an edge; only a typed source confirms one. The distinction
is reported, because a graph built mostly from proposals is weaker than its
edge count suggests.
-}
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
    AuthenticatedBootstrapCompiler -> Nothing
    GeneratedFakeExecutables -> Nothing

-- | The phase or bootstrap root that provides a provision.
provisionProvider :: Provision -> Provider
provisionProvider provision = case provisionLegacyBinding provision of
    Just identifier -> PhaseProvider (Legacy.legacyIdOwnerCapability identifier)
    Nothing -> case provision of
        CompileFailHarness -> PhaseProvider "compile_fail_harness"
        CompileFailCorpus -> PhaseProvider "compile_fail_harness"
        AuthenticatedBootstrapCompiler -> BootstrapRoot AuthenticatedCompilerInput
        GeneratedFakeExecutables -> PhaseProvider "tool_and_mutant_generation"
        -- A newly added provision without a provider remains fail-closed through
        -- CAPABILITY-PROVIDER-UNKNOWN below.
        _ -> PhaseProvider ""

provisionPhaseProvider :: Provision -> Maybe Text
provisionPhaseProvider provision = case provisionProvider provision of
    PhaseProvider capability -> Just capability
    BootstrapRoot _ -> Nothing

{- | The declared requirement edges.

Each names a consuming phase capability, the provision it consumes, and the
witness for the edge. Coverage is deliberately partial: an edge appears only
where a typed source or a specific located claim supports it, and the
coverage ratio is reported so the graph is not mistaken for complete.
-}
requirementEdges :: [RequirementEdge]
requirementEdges = explicitEdges <> systemicRunInputEdges

explicitEdges :: [RequirementEdge]
explicitEdges =
    -- Each early calculus owns the direct compile-negative runner and exact
    -- diagnostic oracle needed by its own gate. Phase 15 later consolidates a
    -- reusable harness; it is not a prerequisite of already ordered consumers.
    -- Likewise, Phase 34 owns its bounded run-local fake declarations. Phase 47
    -- later generalizes repository-wide tool generation and does not provide a
    -- prerequisite retroactively.
    --
    -- The toolchain phase no longer asserts seed freedom or project-schema
    -- rendering: cabal fetches both seed stanzas at configure time regardless of
    -- ordering, so that claim was false rather than misplaced, and rendering
    -- belongs to the generation owners. Its scoped claim consumes neither.
    --
    -- The layout phase no longer asserts absolute absence of generated foreign
    -- products either. It observes that no newly tracked non-Haskell source
    -- appears and that every existing one joins a later-owned binding, which is
    -- decidable at its own ordinal; absolute absence remains the barrier's claim.
    -- The documentation phase requires an authenticated compiler input. That
    -- input is a non-numbered bootstrap root, not a Phase-1 provision. Phase 1's
    -- distinct numbered output remains ProbeSourceClosure through LTD-SRC-007.
    [ RequirementEdge
        "documentation_suite"
        GatePrerequisite
        AuthenticatedBootstrapCompiler
        (LegacyOwnerBinding Legacy.LtdBoot001)
    ]
        -- Correctly ordered edges, so the relation is not made only of defects. The
        -- barrier consumes the source-closure results it requires to be zero, and
        -- the handoff and first-hardware phases consume the boundaries beneath them
        -- (development_plan_phase_model.md section E).
        <> [ RequirementEdge "self_referential_gates" GatePrerequisite SourceGrammarClosure (LegacyOwnerBinding Legacy.LtdSrc000)
           , RequirementEdge "self_referential_gates" GatePrerequisite PbSourceAdmission (LegacyOwnerBinding Legacy.LtdSrc008)
           , RequirementEdge "host_assert_cli" GatePrerequisite HardwareFreeDslBarrierPass (LegacyOwnerBinding Legacy.LtdVal005)
           , RequirementEdge "linux_engine_bringup" GatePrerequisite HostEnsureKernel (LegacyOwnerBinding Legacy.LtdHost001)
           ]

{- | Cleanroom and freshness are properties of the run harness, and every phase
inherits both rows. The capability is owned late, so every earlier phase
carries the same edge.
-}
systemicRunInputEdges :: [RequirementEdge]
systemicRunInputEdges =
    [ RequirementEdge capability GatePrerequisite RunInputClosure (LegacyOwnerBinding Legacy.LtdVal006)
    | identityRow <- PhaseIdentity.allPhaseIdentities
    , let capability = PhaseIdentity.phaseIdentityCapability identityRow
    , Just capability /= provisionPhaseProvider RunInputClosure
    ]

capabilityOrdinal :: Text -> Maybe Int
capabilityOrdinal = PhaseIdentity.lookupCapabilityOrdinal

-- | The relation with no declared reaches: every backward edge is a finding.
capabilityGraphDiagnostic :: CheckResult
capabilityGraphDiagnostic = capabilityGraphDiagnosticWith []

{- | The relation reconciled against the declared @Forward-deferred:@ reaches,
each given as an exact @(consumer ordinal, provider ordinal)@ pair.
-}
capabilityGraphDiagnosticWith :: [(Int, Int)] -> CheckResult
capabilityGraphDiagnosticWith declared =
    CheckResult
        { checkName = "capability-graph"
        , checkObservations =
            [ observation "capability.provision-count" (showText (length allProvisions))
            , observation "capability.edge-count" (showText (length requirementEdges))
            , observation "capability.confirmed-edge-count" (showText (length confirmedEdges))
            , observation "capability.proposed-edge-count" (showText (length proposedEdges))
            , observation "capability.gate-prerequisite-edge-count" (showText (length gatePrerequisiteEdges))
            , observation "capability.deferred-residue-edge-count" (showText (length deferredResidueEdges))
            , observation "capability.bootstrap-root-count" (showText (length bootstrapRootProvisions))
            , observation "capability.consumer-phase-count" (showText (Set.size consumerCapabilities))
            , observation "capability.declared-coverage" (showText (Set.size consumerCapabilities) <> "/" <> showText (length PhaseIdentity.allPhaseIdentities))
            , observation "capability.forward-edge-count" (showText (length forwardEdges))
            , observation "capability.forward-gate-prerequisite-count" (showText (length forwardGatePrerequisites))
            , observation "capability.forward-deferred-residue-count" (showText (length forwardDeferredResidue))
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
        [edge | edge@(_, _, _, _, c, p) <- forwardEdges, isDeclared c p]
    undeclaredForwardEdges =
        [edge | edge@(_, _, _, _, c, p) <- forwardEdges, not (isDeclared c p)]
    matchedPairs = nub [(c, p) | (_, _, _, _, c, p) <- declaredForwardEdges]
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
    confirmedEdges = [edge | edge <- requirementEdges, edgeWitnessConfirmed (requirementWitness edge)]
    proposedEdges = [edge | edge <- requirementEdges, not (edgeWitnessConfirmed (requirementWitness edge))]
    gatePrerequisiteEdges = [edge | edge <- requirementEdges, requirementKind edge == GatePrerequisite]
    deferredResidueEdges = [edge | edge <- requirementEdges, requirementKind edge == DeferredResidue]
    bootstrapRootProvisions =
        [ provision
        | provision <- allProvisions
        , BootstrapRoot _ <- [provisionProvider provision]
        ]
    consumerCapabilities = Set.fromList [requirementConsumer edge | edge <- requirementEdges]

    providerFindings =
        [ finding
            "CAPABILITY-PROVIDER-UNKNOWN"
            (Text.unpack (renderProvision provision))
            ("no phase provides this capability: provider=" <> providerCapability)
        | provision <- allProvisions
        , PhaseProvider providerCapability <- [provisionProvider provision]
        , capabilityOrdinal providerCapability == Nothing
        ]

    consumerFindings =
        [ finding
            "CAPABILITY-CONSUMER-UNKNOWN"
            (Text.unpack consumer)
            "a requirement edge names a phase capability that no phase provides"
        | consumer <- nub [requirementConsumer edge | edge <- requirementEdges]
        , capabilityOrdinal consumer == Nothing
        ]

    forwardEdges =
        [ (consumer, kind, provision, witness, consumerOrdinal, providerOrdinal)
        | RequirementEdge consumer kind provision witness <- requirementEdges
        , Just consumerOrdinal <- [capabilityOrdinal consumer]
        , PhaseProvider providerCapability <- [provisionProvider provision]
        , Just providerOrdinal <- [capabilityOrdinal providerCapability]
        , providerOrdinal >= consumerOrdinal
        ]
    forwardGatePrerequisites =
        [edge | edge@(_, GatePrerequisite, _, _, _, _) <- forwardEdges]
    forwardDeferredResidue =
        [edge | edge@(_, DeferredResidue, _, _, _, _) <- forwardEdges]

    forwardFindings =
        [ finding
            "PLAN-CAPABILITY-GATE-PREREQUISITE-MISORDERED"
            (Text.unpack consumer)
            ( "phase "
                <> renderOrdinal consumerOrdinal
                <> " consumes "
                <> renderProvision provision
                <> " provided by phase "
                <> renderOrdinal providerOrdinal
                <> " ("
                <> providerCapability
                <> "); witness="
                <> renderWitness witness
                <> if isDeclared consumerOrdinal providerOrdinal
                    then "; a Forward-deferred field declares the reach, but cannot waive an essential gate prerequisite"
                    else "; the essential gate prerequisite is not available before its consumer"
            )
        | (consumer, GatePrerequisite, provision, witness, consumerOrdinal, providerOrdinal) <- forwardGatePrerequisites
        , PhaseProvider providerCapability <- [provisionProvider provision]
        ]
            <> [ finding
                    "PLAN-CAPABILITY-DEFERRED-UNDECLARED"
                    (Text.unpack consumer)
                    ( "phase "
                        <> renderOrdinal consumerOrdinal
                        <> " carries deferred residue for "
                        <> renderProvision provision
                        <> " provided by phase "
                        <> renderOrdinal providerOrdinal
                        <> " ("
                        <> providerCapability
                        <> "); witness="
                        <> renderWitness witness
                        <> "; no Forward-deferred field declares it"
                    )
               | (consumer, DeferredResidue, provision, witness, consumerOrdinal, providerOrdinal) <- forwardDeferredResidue
               , not (isDeclared consumerOrdinal providerOrdinal)
               , PhaseProvider providerCapability <- [provisionProvider provision]
               ]

    -- Ownership annotates a cycle but never makes the phase topology admissible.
    -- The graph therefore reports every cycle while retaining separate owned and
    -- unowned counts as observations.
    cycleOwned node =
        not (null (outEdges node))
            && all (edgeWitnessLegacyOwned . requirementWitness) (outEdges node)
    outEdges node = [edge | edge <- requirementEdges, requirementConsumer edge == node]
    ownedCycles = [members | members <- capabilityCycles, all cycleOwned members]
    unownedCycles = [members | members <- capabilityCycles, not (all cycleOwned members)]
    cycleFindings =
        [ finding
            "PLAN-CAPABILITY-CYCLE"
            (Text.unpack (Text.intercalate "->" cycleMembers))
            ( if all cycleOwned cycleMembers
                then "the requirement relation contains a cycle with typed ownership; ownership annotates the obligation but cannot waive the ordering failure"
                else "the requirement relation contains a cycle without complete typed ownership"
            )
        | cycleMembers <- capabilityCycles
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
            [ (requirementConsumer edge, [providerCapability])
            | edge <- requirementEdges
            , PhaseProvider providerCapability <- [provisionProvider (requirementProvision edge)]
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

{- | Whether an edge carries typed legacy ownership. This annotates cycle
findings; it never suppresses one.
-}
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

showText :: (Show value) => value -> Text
showText = Text.pack . show

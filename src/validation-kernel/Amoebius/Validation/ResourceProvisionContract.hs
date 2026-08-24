{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ResourceProvisionContract
  ( resourceProvisionContractDiagnostic
  , resourceProvisionProjectionDiagnostic
  ) where

import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- The universal source-bound Haskell supervisor and ordinary generated
-- .build observations do not select this contract.  Only a phase-specific
-- subject/fake/adapter/observer/cleanup process or live/external effect does.

data ResourceField
  = OwnerMarker
  | Preflight
  | AllowedMutations
  | ForbiddenMutations
  | ExternalObserver
  | ScopedCleanup
  | ZeroOwnedResidue
  deriving (Bounded, Enum, Eq, Ord, Show)

data ResourceGapId = ResourceGapId Int ResourceField
  deriving (Eq, Ord, Show)

data ResourceDraft = ResourceDraft Int ResourceField
  deriving (Eq, Ord, Show)

data ResourceReviewMissing = ResourceReviewMissing
  deriving (Eq, Ord, Show)

data ResourceReviewCustody = ResourceReviewCustody Text
  deriving (Eq, Ord, Show)

data ResourceSlot a
  = ResourceContractGap ResourceGapId
  | ResourceDrafted a ResourceReviewMissing
  | ResourceReviewed a ResourceReviewCustody
  deriving (Eq, Ord, Show)

data ResourceProvisionContract = ResourceProvisionContract
  { resourcePhaseOrdinal :: Int
  , resourceSlots :: [ResourceSlot ResourceDraft]
  }
  deriving (Eq, Show)

resourceFields :: [ResourceField]
resourceFields = [minBound .. maxBound]

resourceRequiredPhases :: Set Int
resourceRequiredPhases =
#if defined(VALIDATION_PHASE_SEMANTIC_RESOURCE_MUTANT)
  Set.insert 48 (Set.delete 43 canonicalResourceRequiredPhases)
#else
  canonicalResourceRequiredPhases
#endif

canonicalResourceRequiredPhases :: Set Int
canonicalResourceRequiredPhases =
  Set.fromList
    [ PhaseIdentity.phaseIdentityOrdinal identityRow
    | identityRow <- PhaseIdentity.allPhaseIdentities
    , PhaseIdentity.phaseIdentityResourceProvision identityRow
        == PhaseIdentity.ResourceProvisionRequired
    ]

canonicalResourceContracts :: [ResourceProvisionContract]
canonicalResourceContracts =
  [ ResourceProvisionContract
      ordinal
      (resourceSlotsFor ordinal)
  | ordinal <- Set.toAscList resourceRequiredPhases
  ]

resourceSlotsFor :: Int -> [ResourceSlot ResourceDraft]
resourceSlotsFor ordinal = resourceFieldIdentityMutation (expectedResourceSlots ordinal)
 where
#ifdef VALIDATION_PHASE_SEMANTIC_RESOURCE_FIELD_IDENTITY_MUTANT
  resourceFieldIdentityMutation slots
    | ordinal == 1 = case slots of
        firstSlot : _secondSlot : remaining ->
          firstSlot : ResourceContractGap (ResourceGapId 1 OwnerMarker) : remaining
        _ -> slots
    | otherwise = slots
#else
  resourceFieldIdentityMutation = id
#endif

expectedResourceSlots :: Int -> [ResourceSlot ResourceDraft]
expectedResourceSlots ordinal =
  [ResourceContractGap (ResourceGapId ordinal field) | field <- resourceFields]

resourceProvisionContractDiagnostic :: CheckResult
resourceProvisionContractDiagnostic =
  CheckResult
    { checkName = "resource-provision-contract-diagnostic"
    , checkObservations =
        [ observation "resource.phase-domain-count" "96"
        , observation "resource.required-phase-count" (showText (Set.size resourceRequiredPhases))
        , observation "resource.slot-count" (showText (length allSlots))
        , observation "resource.gap-count" (showText (length resourceGaps))
        , observation "resource.draft-count" (showText (length resourceDrafts))
        , observation "resource.reviewed-count" (showText (length resourceReviews))
        ]
          <> [ observation
                 "resource.phase"
                 ( renderOrdinal ordinal
                     <> "|"
                     <> if Set.member ordinal resourceRequiredPhases
                       then "required|UNRESOLVED"
                       else "not-required|ABSENT"
                 )
             | ordinal <- [0 .. 95]
             ]
    , checkFindings =
        resourceIntegrityFindings
          <> concatMap resourceSlotFindings canonicalResourceContracts
          <> [resourcePermanentRefusal]
    }
 where
  allSlots = concatMap resourceSlots canonicalResourceContracts
  resourceGaps = [gapIdentifier | ResourceContractGap gapIdentifier <- allSlots]
  resourceDrafts = [draftIdentifier | ResourceDrafted draftIdentifier ResourceReviewMissing <- allSlots]
  resourceReviews = [custody | ResourceReviewed _ custody <- allSlots]

resourcePermanentRefusal :: Finding
resourcePermanentRefusal =
  finding
    "PLAN-RESOURCE-DIAGNOSTIC-ONLY"
    "DEVELOPMENT_PLAN/"
    "all 55 phase-specific resource-provision contracts are unresolved; no live mutation is authorized"

resourceIntegrityFindings :: [Finding]
resourceIntegrityFindings =
  concat
    [ identityIntegrityFindings
    , integrityFinding
        (resourceRequiredPhases == canonicalResourceRequiredPhases)
        "the phase-specific resource-provision set must equal the exact canonical 55-phase set"
    , integrityFinding
        ( case (Set.lookupMin resourceRequiredPhases, Set.lookupMax resourceRequiredPhases) of
            (Just lower, Just upper) -> lower >= 0 && upper <= 95
            _ -> False
        )
        "resource-provision ordinals must form a non-empty subset of the closed 0..95 domain"
    , integrityFinding
        (map resourcePhaseOrdinal canonicalResourceContracts == Set.toAscList resourceRequiredPhases)
        "resource contracts must occur exactly once in ordinal order"
    , integrityFinding
        (all ((== 7) . length . resourceSlots) canonicalResourceContracts)
        "every required phase must retain exactly seven resource fields"
    , integrityFinding
        (all resourceSlotIdentitiesAreExact canonicalResourceContracts)
        "every required phase must retain the exact ordered seven ResourceGapId identities"
    , integrityFinding
        (length allSlots == 385)
        "the unresolved reset must retain exactly 385 resource ContractGap slots"
    , integrityFinding
        (all isGap allSlots)
        "no resource slot may be Drafted or Reviewed while every resource section is UNRESOLVED"
    ]
 where
  allSlots = concatMap resourceSlots canonicalResourceContracts
  isGap slot = case slot of
    ResourceContractGap _ -> True
    ResourceDrafted _ _ -> False
    ResourceReviewed _ _ -> False

identityIntegrityFindings :: [Finding]
identityIntegrityFindings =
  [ finding
      "PLAN-RESOURCE-REGISTRY-INTEGRITY"
      "DEVELOPMENT_PLAN/"
      ("shared phase identity refused: " <> detail)
  | detail <- PhaseIdentity.phaseIdentityIntegrityProblems
  ]

resourceSlotIdentitiesAreExact :: ResourceProvisionContract -> Bool
resourceSlotIdentitiesAreExact contract =
  resourceSlots contract == expectedResourceSlots (resourcePhaseOrdinal contract)

integrityFinding :: Bool -> Text -> [Finding]
integrityFinding condition detail =
  [finding "PLAN-RESOURCE-REGISTRY-INTEGRITY" "DEVELOPMENT_PLAN/" detail | not condition]

resourceSlotFindings :: ResourceProvisionContract -> [Finding]
resourceSlotFindings contract = concatMap findingFor (resourceSlots contract)
 where
  findingFor slot = case slot of
    ResourceContractGap gapIdentifier ->
      [ finding
          "PLAN-RESOURCE-CONTRACT-GAP"
          (phaseSubject (resourcePhaseOrdinal contract))
          ("gap=" <> renderResourceGapId gapIdentifier)
      ]
    ResourceDrafted draftIdentifier ResourceReviewMissing ->
      [ finding
          "PLAN-RESOURCE-REVIEW-MISSING"
          (phaseSubject (resourcePhaseOrdinal contract))
          ("draft=" <> renderResourceDraft draftIdentifier <> " review=missing")
      ]
    ResourceReviewed _ (ResourceReviewCustody custody) ->
      [ finding
          "PLAN-RESOURCE-REVIEW-CUSTODY-UNAVAILABLE"
          (phaseSubject (resourcePhaseOrdinal contract))
          ("a reviewed resource slot is inadmissible in the reset registry: " <> custody)
      ]

-- Each projection is ordinal, exact heading (or ABSENT), and whether the
-- first blockquote carries the mandatory unresolved/no-mutation prefix.  The
-- function always refuses and exposes no resource contract value.
resourceProvisionProjectionDiagnostic :: [(Int, Text, Bool)] -> CheckResult
resourceProvisionProjectionDiagnostic supplied =
  CheckResult
    { checkName = "resource-provision-structural-projection-diagnostic"
    , checkObservations =
        [ observation "resource.join.phase-count" (showText (length supplied))
        , observation "resource.join.distinct-ordinal-count" (showText (Map.size grouped))
        ]
    , checkFindings =
        cardinalityFindings
          <> duplicateFindings
          <> missingFindings
          <> extraFindings
          <> concatMap compareProjection supplied
          <> resourceStructuralDiagnosticRefusal
    }
 where
  grouped = Map.fromListWith (<>) [(ordinal, [(heading, blocker)]) | (ordinal, heading, blocker) <- supplied]
  cardinalityFindings =
    [ finding
        "PLAN-RESOURCE-JOIN-CARDINALITY"
        "DEVELOPMENT_PLAN/"
        ("expected exactly 96 phase resource projections; observed " <> showText (length supplied))
    | length supplied /= 96
    ]
  duplicateFindings =
    [ finding
        "PLAN-RESOURCE-JOIN-DUPLICATE"
        "DEVELOPMENT_PLAN/"
        ("phase=" <> renderOrdinal ordinal <> " has " <> showText (length rows) <> " projections")
    | (ordinal, rows) <- Map.toAscList grouped
    , length rows /= 1
    ]
  missingFindings =
    [ finding
        "PLAN-RESOURCE-JOIN-MISSING"
        (phaseSubject ordinal)
        ("phase=" <> renderOrdinal ordinal <> " resource projection is absent")
    | ordinal <- [0 .. 95]
    , Map.notMember ordinal grouped
    ]
  extraFindings =
    [ finding
        "PLAN-RESOURCE-JOIN-EXTRA"
        "DEVELOPMENT_PLAN/"
        ("phase=" <> showText ordinal <> " lies outside the canonical 0..95 domain")
    | (ordinal, _, _) <- supplied
    , ordinal < 0 || ordinal > 95
    ]

resourceStructuralDiagnosticRefusal :: [Finding]
#ifdef VALIDATION_PHASE_SEMANTIC_RESOURCE_DIAGNOSTIC_REMOVAL_MUTANT
resourceStructuralDiagnosticRefusal = []
#else
resourceStructuralDiagnosticRefusal =
  [ finding
      "PLAN-RESOURCE-JOIN-DIAGNOSTIC-ONLY"
      "DEVELOPMENT_PLAN/"
      "Markdown headings cannot authorize mutation or populate the Haskell ResourceProvisionContract"
  ]
#endif

compareProjection :: (Int, Text, Bool) -> [Finding]
compareProjection (ordinal, actualHeading, actualBlocker)
  | ordinal < 0 || ordinal > 95 = []
  | otherwise =
      mismatch "heading" expectedHeading actualHeading
        <> mismatch "unresolved-blocker" expectedBlocker actualBlocker
 where
  required = Set.member ordinal resourceRequiredPhases
  expectedHeading = if required then "Resource provision — UNRESOLVED" else "ABSENT"
  expectedBlocker = required
  mismatch :: (Eq value, Show value) => Text -> value -> value -> [Finding]
  mismatch fieldName wanted observed =
    [ finding
        "PLAN-RESOURCE-JOIN-MISMATCH"
        (phaseSubject ordinal)
        ( "phase="
            <> renderOrdinal ordinal
            <> " field="
            <> fieldName
            <> " expected="
            <> showText wanted
            <> " actual="
            <> showText observed
        )
    | wanted /= observed
    ]

renderResourceGapId :: ResourceGapId -> Text
renderResourceGapId (ResourceGapId ordinal field) =
  "phase-" <> renderOrdinal ordinal <> "-" <> resourceFieldSlug field

renderResourceDraft :: ResourceDraft -> Text
renderResourceDraft (ResourceDraft ordinal field) =
  "phase-" <> renderOrdinal ordinal <> "-" <> resourceFieldSlug field

resourceFieldSlug :: ResourceField -> Text
resourceFieldSlug field = case field of
  OwnerMarker -> "owner-marker"
  Preflight -> "preflight"
  AllowedMutations -> "allowed-mutations"
  ForbiddenMutations -> "forbidden-mutations"
  ExternalObserver -> "external-observer"
  ScopedCleanup -> "scoped-cleanup"
  ZeroOwnedResidue -> "zero-owned-residue"

phaseSubject :: Int -> FilePath
phaseSubject ordinal =
  case PhaseIdentity.lookupPhaseIdentity ordinal of
    Just identityRow -> PhaseIdentity.phaseIdentityPath identityRow
    Nothing ->
      "DEVELOPMENT_PLAN/<missing-phase-identity-"
        <> Text.unpack (renderOrdinal ordinal)
        <> ">"

renderOrdinal :: Int -> Text
renderOrdinal ordinal = Text.justifyRight 2 '0' (showText ordinal)

showText :: Show value => value -> Text
showText = Text.pack . show

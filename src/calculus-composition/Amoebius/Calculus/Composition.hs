{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Index-preserving composition over the five core calculi.
--
-- A component carries one value from exactly one calculus, the request-scope phantom
-- minted by 'RequestScope', and the base resource vector it consumes.  Constructors are
-- private: a caller can introduce a component only while holding the request scope that
-- indexes it.  'compose' accepts one scope variable for both arguments, so components
-- minted by different requests cannot be combined.
--
-- The resource index uses 'Natural' arithmetic through 'addResources'.  It is therefore
-- an exact sum rather than a machine-word or policy saturation.  Transforming a label
-- preserves both indices, and appending compositions is associative because it appends
-- the authored component sequence and derives the resource fold from that sequence.
module Amoebius.Calculus.Composition
  ( Calculus (..)
  , everyCalculus
  , calculusTag
  , Component
  , artifactComponent
  , budgetComponent
  , liftComponent
  , workflowComponent
  , evidenceComponent
  , componentCalculus
  , componentName
  , componentResource
  , componentDescriptor
  , componentIdentityFields
  , renameComponent
  , Composition
  , emptyComposition
  , singleton
  , compose
  , append
  , compositionKinds
  , compositionNames
  , compositionResource
  ) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId, recipeName, recipeRevision)
import Amoebius.Calculus.Budget.Grant
  ( Allowance
  , Bytes (Bytes)
  , Slots (Slots)
  , allowanceCeiling
  , allowanceConcurrency
  , allowancePerItem
  )
import Amoebius.Calculus.Evidence.Register (Register, registerTag)
import Amoebius.Calculus.Lift.Layer (Layer, layerTag)
import Amoebius.Calculus.Workflow.Arm
  ( Condition (Condition)
  , Discharge (..)
  , Resource (Resource)
  , armTag
  )
import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Ledger
  ( ledgerArms
  , ledgerProvisioned
  , ledgerReleased
  )
import Amoebius.Capacity.Types
  ( ResourceVector (..)
  , addResources
  , zeroResources
  )
import Amoebius.Scope.Index (RequestScope)
import Data.Text (Text)
import Data.Text qualified as Text

-- | The closed set this phase composes.  Adding a sixth calculus makes the tag fold and
-- every exhaustive oracle consumer fail to compile until the new pairing surface is
-- stated.
data Calculus
  = ArtifactCalculus
  | BudgetCalculus
  | LiftCalculus
  | WorkflowCalculus
  | EvidenceCalculus
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyCalculus :: [Calculus]
everyCalculus = [minBound .. maxBound]

calculusTag :: Calculus -> Text
calculusTag calculus = case calculus of
  ArtifactCalculus -> "artifact"
  BudgetCalculus -> "budget"
  LiftCalculus -> "lift"
  WorkflowCalculus -> "workflow"
  EvidenceCalculus -> "evidence"

-- | One indexed declaration component.  The payload types come from the five owning
-- calculi; this module combines their values without inventing replacement vocabulary.
data Component scope
  = ArtifactComponent Text ResourceVector RecipeId
  | BudgetComponent Text ResourceVector Allowance
  | LiftComponent Text ResourceVector Layer
  | WorkflowComponent Text ResourceVector Ledger
  | EvidenceComponent Text ResourceVector Register
  deriving stock (Eq, Show)

artifactComponent :: RequestScope scope -> Text -> ResourceVector -> RecipeId -> Component scope
artifactComponent _scope = ArtifactComponent

budgetComponent :: RequestScope scope -> Text -> ResourceVector -> Allowance -> Component scope
budgetComponent _scope = BudgetComponent

liftComponent :: RequestScope scope -> Text -> ResourceVector -> Layer -> Component scope
liftComponent _scope = LiftComponent

workflowComponent :: RequestScope scope -> Text -> ResourceVector -> Ledger -> Component scope
workflowComponent _scope = WorkflowComponent

evidenceComponent :: RequestScope scope -> Text -> ResourceVector -> Register -> Component scope
evidenceComponent _scope = EvidenceComponent

componentCalculus :: Component scope -> Calculus
componentCalculus component = case component of
  ArtifactComponent {} -> ArtifactCalculus
  BudgetComponent {} -> BudgetCalculus
  LiftComponent {} -> LiftCalculus
  WorkflowComponent {} -> WorkflowCalculus
  EvidenceComponent {} -> EvidenceCalculus

componentName :: Component scope -> Text
componentName component = case component of
  ArtifactComponent name _ _ -> name
  BudgetComponent name _ _ -> name
  LiftComponent name _ _ -> name
  WorkflowComponent name _ _ -> name
  EvidenceComponent name _ _ -> name

componentResource :: Component scope -> ResourceVector
componentResource component = case component of
  ArtifactComponent _ resources _ -> resources
  BudgetComponent _ resources _ -> resources
  LiftComponent _ resources _ -> resources
  WorkflowComponent _ resources _ -> resources
  EvidenceComponent _ resources _ -> resources

-- | A readable projection of the real calculus payload, used only for diagnostics.  It
-- makes preservation of the payload observable without exposing this module's private
-- constructors.
componentDescriptor :: Component scope -> Text
componentDescriptor component = case component of
  ArtifactComponent _ _ value -> Text.pack (show value)
  BudgetComponent _ _ value -> Text.pack (show value)
  LiftComponent _ _ value -> Text.pack (show value)
  WorkflowComponent _ _ value -> Text.pack (show value)
  EvidenceComponent _ _ value -> Text.pack (show value)

-- | Canonical semantic fields for content identity.  Unlike 'componentDescriptor', this
-- projection never uses 'Show': every closed constructor is mapped to its authored tag,
-- every numeric field is rendered canonically, and variable-length ledger sections carry
-- their counts.  A caller must frame each field separately.
componentIdentityFields :: Component scope -> [Text]
componentIdentityFields component = case component of
  ArtifactComponent _ _ recipe ->
    ["recipe", recipeName recipe, decimal (recipeRevision recipe)]
  BudgetComponent _ _ bound ->
    [ "allowance"
    , bytesText (allowanceCeiling bound)
    , slotsText (allowanceConcurrency bound)
    , bytesText (allowancePerItem bound)
    ]
  LiftComponent _ _ layer -> ["layer", layerTag layer]
  WorkflowComponent _ _ ledger ->
    ["ledger", "arms", count (ledgerArms ledger)]
      <> fmap armTag (ledgerArms ledger)
      <> ["provisioned", count (ledgerProvisioned ledger)]
      <> fmap resourceText (ledgerProvisioned ledger)
      <> ["released", count (ledgerReleased ledger)]
      <> concatMap releasedFields (ledgerReleased ledger)
  EvidenceComponent _ _ register -> ["register", registerTag register]
 where
  bytesText (Bytes value) = decimal value
  slotsText (Slots value) = decimal value
  count = decimal . length
  resourceText (Resource value) = value
  releasedFields (resource, discharge) = resourceText resource : dischargeFields discharge
  dischargeFields discharge = case discharge of
    ToreDown -> ["tore-down"]
    TransferredTo (Condition condition) -> ["transferred", condition]
  decimal :: Show value => value -> Text
  decimal = Text.pack . show

-- | Change presentation metadata while retaining the calculus payload and both indices.
renameComponent :: Text -> Component scope -> Component scope
renameComponent name component = case component of
  ArtifactComponent _ resources value -> ArtifactComponent name (kept resources) value
  BudgetComponent _ resources value -> BudgetComponent name (kept resources) value
  LiftComponent _ resources value -> LiftComponent name (kept resources) value
  WorkflowComponent _ resources value -> WorkflowComponent name (kept resources) value
  EvidenceComponent _ resources value -> EvidenceComponent name (kept resources) value
 where
#ifdef CALCULUS_COMPOSITION_DROPS_TRANSFORM_INDEX_MUTANT
  kept _resources = zeroResources
#else
  kept resources = resources
#endif

-- | An ordered composition at one request scope.  The constructor is private, so callers
-- cannot retag a component or insert an unindexed value into the sequence.
newtype Composition scope = Composition [Component scope]
  deriving stock (Eq, Show)

emptyComposition :: RequestScope scope -> Composition scope
emptyComposition _scope = Composition []

singleton :: Component scope -> Composition scope
singleton component = Composition [component]

#ifdef CALCULUS_COMPOSITION_WIDENS_SCOPE_MUTANT
-- The seeded hole: the right component's request index is discarded and rebuilt at the
-- left index.  The committed negative fixture compiles only in this configuration.
compose :: Component leftScope -> Component rightScope -> Composition leftScope
compose left right = Composition [left, retag right]

retag :: Component from -> Component to
retag component = case component of
  ArtifactComponent name resources value -> ArtifactComponent name resources value
  BudgetComponent name resources value -> BudgetComponent name resources value
  LiftComponent name resources value -> LiftComponent name resources value
  WorkflowComponent name resources value -> WorkflowComponent name resources value
  EvidenceComponent name resources value -> EvidenceComponent name resources value
#else
compose :: Component scope -> Component scope -> Composition scope
compose left right = Composition [left, right]
#endif

append :: Composition scope -> Composition scope -> Composition scope
append (Composition left) (Composition right) = Composition (left <> right)

compositionKinds :: Composition scope -> [Calculus]
compositionKinds (Composition components) = fmap componentCalculus components

compositionNames :: Composition scope -> [Text]
compositionNames (Composition components) = fmap componentName components

compositionResource :: Composition scope -> ResourceVector
compositionResource (Composition components) =
  foldl' addIndex zeroResources (fmap componentResource components)

addIndex :: ResourceVector -> ResourceVector -> ResourceVector
#ifdef CALCULUS_COMPOSITION_SATURATES_RESOURCE_SUM_MUTANT
addIndex left right =
  ResourceVector
    { resourceCpu = min 8 (resourceCpu left + resourceCpu right)
    , resourceMemory = min 80 (resourceMemory left + resourceMemory right)
    , resourceEphemeralStorage = min 800 (resourceEphemeralStorage left + resourceEphemeralStorage right)
    , resourcePodSlots = min 8 (resourcePodSlots left + resourcePodSlots right)
    }
#else
addIndex = addResources
#endif

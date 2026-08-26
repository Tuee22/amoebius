-- | A formal-model projection of the Phase-10 calculus composition value.
--
-- The formal kernel does not invent a second composition algebra.  It consumes the
-- ordered calculus sequence and exact resource fold already computed by
-- @calculus-composition@, then reifies that snapshot as a one-state 'Model'.  Later
-- checkers can therefore reason about the same composition boundary without copying
-- its scope or resource rules into the formal EDSL.
module Amoebius.Formal.CalculusComposition
  ( compositionModel
  ) where

import Amoebius.Calculus.Composition
  ( Composition
  , calculusTag
  , compositionKinds
  , compositionResource
  )
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Formal.Model
import Data.Text qualified as Text

-- | Reify one already-validated composition as a closed, one-state model.
compositionModel :: Composition scope -> Model
compositionModel composition = Model
  { modelName = "CalculusComposition"
  , modelConstants =
      [ ("Calculi", SetValue (map (AtomValue . Text.unpack . calculusTag) kinds))
      ]
  , modelVariables = ["componentCount", "cpu", "memory", "ephemeral", "pods"]
  , modelInit =
      [ ("componentCount", integer (fromIntegral (length kinds)))
      , ("cpu", natural (resourceCpu resources))
      , ("memory", natural (resourceMemory resources))
      , ("ephemeral", natural (resourceEphemeralStorage resources))
      , ("pods", natural (resourcePodSlots resources))
      ]
  , modelActions = []
  , modelInvariants =
      [ NamedExpr "CompositionProjectionExact" (And
          [ Equal (Ref "componentCount") (integer (fromIntegral (length kinds)))
          , Equal (Ref "cpu") (natural (resourceCpu resources))
          , Equal (Ref "memory") (natural (resourceMemory resources))
          , Equal (Ref "ephemeral") (natural (resourceEphemeralStorage resources))
          , Equal (Ref "pods") (natural (resourcePodSlots resources))
          ])
      , NamedExpr "CompositionIndicesNonNegative" (And
          [ ArithmeticComparison GreaterThanOrEqual (Ref name) (integer 0)
          | name <- ["componentCount", "cpu", "memory", "ephemeral", "pods"]
          ])
      ]
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = []
  , modelProperties = []
  , modelCheckDeadlock = False
  }
 where
  kinds = compositionKinds composition
  resources = compositionResource composition
  integer = Literal . IntValue
  natural = integer . fromIntegral

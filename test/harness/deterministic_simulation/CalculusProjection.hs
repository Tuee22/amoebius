{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module CalculusProjection
  ( CalculusProjection (..)
  , referenceCalculusProjection
  , referenceCalculusModel
  ) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (..))
import Amoebius.Calculus.Budget.Grant (Bytes (..), Slots (..), allowance)
import Amoebius.Calculus.Composition
  ( Composition
  , append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Formal.CalculusComposition (compositionModel)
import Amoebius.Formal.Model (Model)
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Data.Bifunctor (first)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

-- | Package-neutral semantic facts projected from the real Phase-11 composition.
-- Keeping this adapter in its own component avoids confusing the focused Phase-11
-- packages with the older copies of capacity and scope modules still exposed by
-- @dsl-core@.
data CalculusProjection = CalculusProjection
  { projectionOrder :: [Text]
  , projectionNames :: [Text]
  , projectionResources :: Text
  }
  deriving stock (Eq, Show)

referenceCalculusProjection :: Either String CalculusProjection
referenceCalculusProjection = withReferenceComposition $ \composition ->
  CalculusProjection
    { projectionOrder = map calculusTag (compositionKinds composition)
    , projectionNames = compositionNames composition
    , projectionResources = renderResources (compositionResource composition)
    }

referenceCalculusModel :: Either String Model
referenceCalculusModel = withReferenceComposition compositionModel

withReferenceComposition :: (forall scope. Composition scope -> result) -> Either String result
withReferenceComposition continuation = do
  tenant <- first show (trustedTenant "phase-17-tenant")
  subject <- first show (trustedSubject tenant "phase-17-subject")
  membership <- first show (activeMembership tenant subject)
  first show $ withRequestScope tenant subject membership $ \scope ->
    let composition =
          append
            ( append
                ( append
                    ( append
                        (singleton (artifactComponent scope "artifact" (resources 1) (RecipeId "artifact" 1)))
                        (singleton (budgetComponent scope "budget" (resources 2) (allowance (Bytes 4096) (Slots 4) (Bytes 1024))))
                    )
                    (singleton (liftComponent scope "lift" (resources 3) OnHost))
                )
                (singleton (workflowComponent scope "workflow" (resources 4) emptyLedger))
            )
            (singleton (evidenceComponent scope "evidence" (resources 5) PureRegister))
     in continuation composition

resources :: Natural -> ResourceVector
resources value = ResourceVector value (value * 10) (value * 100) value

renderResources :: ResourceVector -> Text
renderResources value =
  Text.intercalate
    ","
    ( map
        (Text.pack . show)
        [ resourceCpu value
        , resourceMemory value
        , resourceEphemeralStorage value
        , resourcePodSlots value
        ]
    )

{-# LANGUAGE OverloadedStrings #-}

module DifferentScopesDoNotCompose where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( Calculus
  , artifactComponent
  , budgetComponent
  , compose
  , compositionKinds
  )
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )

differentScopeKinds :: Either String [Calculus]
differentScopeKinds = do
  tenant <- firstShow (trustedTenant "tenant")
  subject <- firstShow (trustedSubject tenant "subject")
  membership <- firstShow (activeMembership tenant subject)
  nested <-
    firstShow
      ( withRequestScope tenant subject membership $ \leftScope ->
          withRequestScope tenant subject membership $ \rightScope ->
            compositionKinds
              ( compose
                  (artifactComponent leftScope "artifact" (ResourceVector 1 1 1 1) (RecipeId "recipe" 1))
                  (budgetComponent rightScope "budget" (ResourceVector 2 2 2 2) (allowance (Bytes 2) (Slots 1) (Bytes 1)))
              )
      )
  firstShow nested

firstShow :: Show problem => Either problem value -> Either String value
firstShow outcome = case outcome of
  Left problem -> Left (show problem)
  Right value -> Right value

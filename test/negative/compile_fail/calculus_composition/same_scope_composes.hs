{-# LANGUAGE OverloadedStrings #-}

module SameScopeComposes where

import Amoebius.Test.ScopeFixture qualified as FixtureAuthority
import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( Calculus
  , artifactComponent
  , budgetComponent
  , compose
  , compositionKinds
  )
import Amoebius.Capacity.Vector (ResourceVector (ResourceVector))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  )

sameScopeKinds :: Either String [Calculus]
sameScopeKinds = do
  tenant <- firstShow (trustedTenant "tenant")
  subject <- firstShow (trustedSubject tenant "subject")
  membership <- firstShow (activeMembership tenant subject)
  firstShow
    ( FixtureAuthority.withFixtureScope tenant subject membership $ \scope ->
        compositionKinds
          ( compose
              (artifactComponent scope "artifact" (ResourceVector 1 1 1 1) (RecipeId "recipe" 1))
              (budgetComponent scope "budget" (ResourceVector 2 2 2 2) (allowance (Bytes 2) (Slots 1) (Bytes 1)))
          )
    )

firstShow :: Show problem => Either problem value -> Either String value
firstShow outcome = case outcome of
  Left problem -> Left (show problem)
  Right value -> Right value

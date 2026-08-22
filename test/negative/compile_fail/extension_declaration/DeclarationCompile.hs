{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( artifactComponent
  , budgetComponent
  , evidenceComponent
  , liftComponent
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (zeroResources)
import Amoebius.Extension.Declaration (DeclarationError, ExtensionDeclaration, declareExtension)
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )

main :: IO ()
main = case program of
  Left problem -> fail problem
  Right _ -> putStrLn acceptanceToken

acceptanceToken :: String
#ifdef EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT
acceptanceToken = "extension-declaration-mutant: RED optional-component RequiredComponents"
#elif defined(EXTENSION_DECLARATION_DROPS_SCOPE_INDEX_MUTANT)
acceptanceToken = "extension-declaration-mutant: RED drop-scope-index ScopeIndexPreserved"
#else
acceptanceToken = "extension-declaration-compile: PASS legal five-component same-scope twin"
#endif

program :: Either String ()
program = do
  tenant <- firstShow (trustedTenant "compile-tenant")
  subject <- firstShow (trustedSubject tenant "compile-subject")
  membership <- firstShow (activeMembership tenant subject)
#if defined(EXTENSION_DECLARATION_DROPS_SCOPE_INDEX_MUTANT) || defined(EXTENSION_DECLARATION_TEST_CROSS_SCOPE)
  nestedScopes <- firstShow $ withRequestScope tenant subject membership $ \leftScope ->
    withRequestScope tenant subject membership $ \rightScope ->
      () <$ crossScopeDeclaration leftScope rightScope
  nestedDeclaration <- firstShow nestedScopes
  firstShow nestedDeclaration
#else
  nested <- firstShow $ withRequestScope tenant subject membership $ \scope ->
    () <$ declaration scope
  firstShow nested
#endif

declaration :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
declaration scope =
#if defined(EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT) || defined(EXTENSION_DECLARATION_TEST_OPTIONAL_COMPONENT)
  declareExtension "compile" artifact budget lift workflow
#else
  declareExtension "compile" artifact budget lift workflow evidence
#endif
 where
  artifact = artifactComponent scope "artifact" zeroResources (RecipeId "recipe" 1)
  budget = budgetComponent scope "budget" zeroResources (allowance (Bytes 1) (Slots 1) (Bytes 1))
  lift = liftComponent scope "lift" zeroResources OnHost
  workflow = workflowComponent scope "workflow" zeroResources emptyLedger
  evidence = evidenceComponent scope "evidence" zeroResources PureRegister

#if defined(EXTENSION_DECLARATION_DROPS_SCOPE_INDEX_MUTANT) || defined(EXTENSION_DECLARATION_TEST_CROSS_SCOPE)
crossScopeDeclaration
  :: RequestScope left
  -> RequestScope right
  -> Either DeclarationError (ExtensionDeclaration left)
crossScopeDeclaration left right =
  declareExtension
    "cross-scope"
    (artifactComponent left "artifact" zeroResources (RecipeId "recipe" 1))
    (budgetComponent right "budget" zeroResources (allowance (Bytes 1) (Slots 1) (Bytes 1)))
    (liftComponent left "lift" zeroResources OnHost)
    (workflowComponent right "workflow" zeroResources emptyLedger)
    (evidenceComponent left "evidence" zeroResources PureRegister)
#endif

firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result

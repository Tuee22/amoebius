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
acceptanceToken = "extension-declaration-compile: PASS legal five-component same-scope twin"

program :: Either String ()
program = do
  tenant <- firstShow (trustedTenant "compile-tenant")
  subject <- firstShow (trustedSubject tenant "compile-subject")
  membership <- firstShow (activeMembership tenant subject)
  nested <- firstShow $ withRequestScope tenant subject membership $ \scope ->
    () <$ declaration scope
  firstShow nested

declaration :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
declaration scope =
  declareExtension "compile" artifact budget lift workflow evidence
 where
  artifact = artifactComponent scope "artifact" zeroResources (RecipeId "recipe" 1)
  budget = budgetComponent scope "budget" zeroResources (allowance (Bytes 1) (Slots 1) (Bytes 1))
  lift = liftComponent scope "lift" zeroResources OnHost
  workflow = workflowComponent scope "workflow" zeroResources emptyLedger
  evidence = evidenceComponent scope "evidence" zeroResources PureRegister


firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result

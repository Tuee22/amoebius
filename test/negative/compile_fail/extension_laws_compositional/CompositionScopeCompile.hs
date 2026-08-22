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
import Amoebius.Extension.Declaration
  ( DeclarationError
  , ExtensionDeclaration
  , declareExtension
  )
import Amoebius.Extension.Laws.Compositional
  ( CompositeDeclaration
  , composeComposites
  , compositePartNames
  , singletonComposite
  )
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Data.Text (Text)

main :: IO ()
main = case program of
  Left problem -> fail problem
  Right _ -> putStrLn "extension-laws-compositional-compile: PASS same-request pair"

program :: Either String ()
program = do
  tenant <- firstShow (trustedTenant "composition-compile-tenant")
  subject <- firstShow (trustedSubject tenant "composition-compile-subject")
  membership <- firstShow (activeMembership tenant subject)
#ifdef EXTENSION_LAWS_COMPOSITIONAL_TEST_CROSS_SCOPE
  nested <- firstShow $ withRequestScope tenant subject membership $ \leftScope ->
    withRequestScope tenant subject membership $ \rightScope ->
      () <$ crossScopeComposite leftScope rightScope
  inner <- firstShow nested
  firstShow inner
#else
  nested <- firstShow $ withRequestScope tenant subject membership $ \scope -> do
    left <- declaration "left" scope
    right <- declaration "right" scope
    pure (() <$ nonEmpty (composeComposites (singletonComposite left) (singletonComposite right)))
  result <- firstShow nested
  firstShow result
#endif

declaration :: Text -> RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
declaration name scope =
  declareExtension
    name
    (artifactComponent scope (name <> "-artifact") zeroResources (RecipeId (name <> "-recipe") 1))
    (budgetComponent scope (name <> "-budget") zeroResources (allowance (Bytes 1) (Slots 1) (Bytes 1)))
    (liftComponent scope (name <> "-lift") zeroResources OnHost)
    (workflowComponent scope (name <> "-workflow") zeroResources emptyLedger)
    (evidenceComponent scope (name <> "-evidence") zeroResources PureRegister)

nonEmpty :: CompositeDeclaration scope -> Either String (CompositeDeclaration scope)
nonEmpty composite = case compositePartNames composite of
  [] -> Left "composition unexpectedly empty"
  _names -> Right composite

#ifdef EXTENSION_LAWS_COMPOSITIONAL_TEST_CROSS_SCOPE
crossScopeComposite
  :: RequestScope left
  -> RequestScope right
  -> Either DeclarationError (CompositeDeclaration left)
crossScopeComposite leftScope rightScope = do
  left <- declaration "left" leftScope
  right <- declaration "right" rightScope
  pure (composeComposites (singletonComposite left) (singletonComposite right))
#endif

firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result

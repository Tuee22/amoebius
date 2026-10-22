{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | The product consumes the calculi here: an admitted binding instantiates
-- its actual five-component declaration and its workflow ledger. No resource
-- lifecycle is asserted before the child-cluster owner supplies that workflow.
module Amoebius.Extension.Calculi
  ( DeclarationBuilder, CalculusRefusal (..), declarationBuilder, instantiateDeclaration
  , declarationRows, mergeExtensions
  ) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( artifactComponent, budgetComponent, liftComponent, workflowComponent, evidenceComponent
  , calculusTag )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (InContainer))
import Amoebius.Calculus.Workflow.Arm (Evidence)
import Amoebius.Calculus.Workflow.Run
  ( Workflow, andThen, build, deploy, observe, runWorkflow )
import Amoebius.Capacity.Vector (ResourceVector, zeroResources)
import Amoebius.Extension.Config
import Amoebius.Extension.Declaration
  ( ExtensionDeclaration, DeclarationError, DeclaredComponent (..)
  , declareExtension, declarationComponents, declarationDigest )
import Amoebius.Extension.Graph (mergeExtensions)
import Amoebius.Scope.Attested (RequestScope)
import Amoebius.Vocabulary (ExtensionId, extensionIdText)
import Data.Text (Text)
import Data.Text qualified as Text

data CalculusRefusal
  = DeclarationConfigurationMismatch
  | DeclarationRefused DeclarationError
  deriving (Eq, Show)

newtype DeclarationBuilder = DeclarationBuilder
  (forall kind (scope :: kind). RequestScope scope -> ExtensionParameters -> ResourceVector
    -> Either CalculusRefusal (ExtensionDeclaration scope))

declarationBuilder :: ExtensionId -> ConfigSchema -> DeclarationBuilder
declarationBuilder identifier schema = DeclarationBuilder $ \scope parameters resources ->
  if parameterSchema parameters /= schema then Left DeclarationConfigurationMismatch else
    let name = extensionIdText identifier
        (_, ledger) = runWorkflow (declarationWorkflow schema)
        budget = maybe 0 id (cacheBudget parameters)
        concurrency = maybe 0 id (cacheConcurrency parameters)
        temporary = maybe budget id (cacheTemporary parameters)
        granted = allowance (Bytes (fromIntegral budget)) (Slots (fromIntegral concurrency)) (Bytes (fromIntegral temporary))
     in either (Left . DeclarationRefused) Right $ declareExtension name
          (artifactComponent scope (name <> "/plan") zeroResources (RecipeId (name <> "/plan") 1))
          (budgetComponent scope (name <> "/budget") zeroResources granted)
          (liftComponent scope (name <> "/placement") zeroResources InContainer)
          (workflowComponent scope (name <> "/workflow") resources ledger)
          (evidenceComponent scope (name <> "/evidence") zeroResources PureRegister)

instantiateDeclaration
  :: DeclarationBuilder -> RequestScope scope -> ExtensionParameters -> ResourceVector
  -> Either CalculusRefusal (ExtensionDeclaration scope)
instantiateDeclaration (DeclarationBuilder instantiate) = instantiate

-- These are pure deployment-plan arms, not live readback. Phase 7 supplies
-- provision/transfer/teardown obligations when a child actually owns resources.
declarationWorkflow :: ConfigSchema -> Workflow '[] '[] Evidence
declarationWorkflow schema = case schema of
  BuildCacheConfig -> andThen build (\_ -> observe)
  CoordinationConfig -> andThen deploy (\_ -> observe)
  InferenceConfig -> andThen build (\_ -> andThen deploy (\_ -> observe))
  TrainingConfig -> andThen build (\_ -> andThen deploy (\_ -> observe))

declarationRows :: ExtensionDeclaration scope -> [(Text, Text)]
declarationRows declaration = ("digest", declarationDigest declaration) : concat
  [ [(base <> ".name", declaredName component),
     (base <> ".resource", Text.pack (show (declaredResource component))),
     (base <> ".descriptor", declaredDescriptor component)]
      <> [(base <> ".field." <> Text.pack (show index), value)
         | (index, value) <- zip [1 :: Int ..] (declaredIdentityFields component)]
  | component <- declarationComponents declaration
  , let base = calculusTag (declaredCalculus component)
  ]

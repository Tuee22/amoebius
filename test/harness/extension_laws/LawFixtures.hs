{-# LANGUAGE OverloadedStrings #-}

module LawFixtures
  ( infernixDeclaration
  , jitmlDeclaration
  , lawfulOperation
  , lawfulRender
  ) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( artifactComponent
  , budgetComponent
  , evidenceComponent
  , liftComponent
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (..))
import Amoebius.Calculus.Lift.Layer (Layer (..))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Extension.Declaration
  ( DeclarationError
  , ExtensionDeclaration
  , declareExtension
  )
import Amoebius.Extension.Laws.PerExtension
  ( OperationOutcome (OperationReturned)
  )
import Amoebius.Scope.Index (RequestScope)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text.Encoding qualified as Encoding

infernixDeclaration :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
infernixDeclaration scope =
  declareExtension
    "infernix"
    (artifactComponent scope "infernix-image" (ResourceVector 2 1024 20 1) (RecipeId "infernix-image" 3))
    (budgetComponent scope "inference-budget" (ResourceVector 1 512 5 1) (allowance (Bytes 4096) (Slots 2) (Bytes 2048)))
    (liftComponent scope "inference-layer" (ResourceVector 0 0 0 0) InContainer)
    (workflowComponent scope "inference-workflow" (ResourceVector 1 256 1 1) emptyLedger)
    (evidenceComponent scope "inference-evidence" (ResourceVector 0 0 0 0) SimulationRegister)

jitmlDeclaration :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
jitmlDeclaration scope =
  declareExtension
    "jitml"
    (artifactComponent scope "jitml-model" (ResourceVector 4 2048 40 1) (RecipeId "jitml-model" 5))
    (budgetComponent scope "training-budget" (ResourceVector 2 1024 10 1) (allowance (Bytes 8192) (Slots 3) (Bytes 4096)))
    (liftComponent scope "training-layer" (ResourceVector 0 0 0 0) InFrame)
    (workflowComponent scope "training-workflow" (ResourceVector 1 512 2 1) emptyLedger)
    (evidenceComponent scope "training-evidence" (ResourceVector 0 0 0 0) BoundaryRegister)

-- Total over Text: a refusal is a value, and no input escapes.
lawfulOperation :: Text -> Text -> OperationOutcome
lawfulOperation extension input = OperationReturned (extension <> ":" <> input)

-- Pure rendering. Independently seeded harness processes receive the same declared input
-- and this function has no seed, clock, environment, directory, or unordered traversal to
-- observe.
lawfulRender :: Text -> Text -> ByteString
lawfulRender extension input = Encoding.encodeUtf8 (extension <> ":artifact:" <> input)

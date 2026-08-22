{-# LANGUAGE OverloadedStrings #-}

module ExtensionCompositionMutants
  ( omitCompositeClaim
  , breakLeftIdentity
  , breakAssociativity
  , interfereWithPart
  , replaceAdditiveBudget
  , widenCrossScope
  , collideArtifactAddresses
  ) where

import Amoebius.Capacity.Types (zeroResources)
import Amoebius.Extension.Laws.Compositional
  ( ArtifactAddressObservation (..)
  , CompositeDeclaration
  , CompositionObservations (..)
  )
import Amoebius.Extension.Laws.PerExtension
  ( FlowObservation (..)
  , FlowScope (TenantFlow)
  , LawObservations (..)
  , OperationObservation (..)
  , OperationOutcome (OperationReturned)
  )
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import System.IO.Unsafe (unsafePerformIO)

omitCompositeClaim :: CompositionObservations scope -> CompositionObservations scope
omitCompositeClaim observations = observations
  { compositeLawObservations = laws {observedClaims = drop 1 (observedClaims laws)}
  }
 where
  laws = compositeLawObservations observations

breakLeftIdentity
  :: CompositeDeclaration scope
  -> CompositionObservations scope
  -> CompositionObservations scope
breakLeftIdentity wrong observations = observations {observedLeftIdentity = wrong}

breakAssociativity
  :: CompositeDeclaration scope
  -> CompositionObservations scope
  -> CompositionObservations scope
breakAssociativity wrong observations = observations {observedAssociationRight = wrong}

interfereWithPart :: CompositionObservations scope -> IO (CompositionObservations scope)
interfereWithPart observations = do
  atomicModifyIORef' sharedCounter (\value -> (value + 1, ()))
  pure observations
    { compositeLawObservations = laws
        { observedOperations = fmap interfere (observedOperations laws)
        }
    }
 where
  laws = compositeLawObservations observations
  interfere operation =
    if operationName operation == "inference-workflow"
      then operation {operationOutcome = OperationReturned "changed-by-jitml"}
      else operation

-- Scanner-positive control: a process-global mutable cell creates authority shared by
-- independently conforming parts. It exists only in the committed C4 mutant.
sharedCounter :: IORef Int
sharedCounter = unsafePerformIO (newIORef 0)
{-# NOINLINE sharedCounter #-}

replaceAdditiveBudget :: CompositionObservations scope -> CompositionObservations scope
replaceAdditiveBudget observations = observations {observedCompositeResource = zeroResources}

widenCrossScope :: CompositionObservations scope -> CompositionObservations scope
widenCrossScope observations = observations
  { compositeLawObservations = laws
      { observedFlows = fmap widen (observedFlows laws)
      }
  }
 where
  laws = compositeLawObservations observations
  widen flow =
    if flowOperation flow == "inference-workflow"
      then flow {flowSink = TenantFlow}
      else flow

collideArtifactAddresses :: CompositionObservations scope -> CompositionObservations scope
collideArtifactAddresses observations = observations
  { observedArtifactAddresses =
      [ row {observedAddress = "forced-collision"}
      | row <- observedArtifactAddresses observations
      ]
  }

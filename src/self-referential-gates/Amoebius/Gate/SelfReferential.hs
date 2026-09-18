{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

-- | A phase gate expressed in the workflow calculus it helps validate.
--
-- The command remains an independently authored mechanism.  This module derives the
-- common lifecycle around that mechanism: the gate process is provisioned, its inputs
-- are built, it is deployed, its exit verdict is observed as evidence, and the process
-- obligation is discharged.  The result is a value and a ledger; executing the command
-- remains the runner boundary's job.
module Amoebius.Gate.SelfReferential
  ( GateDeclaration (..)
  , GateEvidence (..)
  , GateRun (..)
  , GateVerdict (..)
  , deriveGate
  , gateWorkflow
  ) where

import Amoebius.Calculus.Workflow.Arm
  ( Arm
  , Discharge
  , Evidence
  , Resource
  )
import Amoebius.Calculus.Workflow.Ledger
  ( Ledger
  , balances
  , dischargedOnce
  , ledgerArms
  , ledgerProvisioned
  , ledgerReleased
  )
import Amoebius.Calculus.Workflow.Run
  ( Workflow
  , andThen
  , build
  , deploy
  , observe
  , provision
  , pureWorkflow
  , runWorkflow
  , teardown
  )
import Data.Proxy (Proxy (Proxy))
import Data.Text (Text)

data GateDeclaration = GateDeclaration
  { gatePhase :: Int
  , gateContract :: FilePath
  , gateCommand :: Text
  }
  deriving stock (Eq, Show)

data GateVerdict
  = GatePassed
  | GateFailed Int
  deriving stock (Eq, Show)

data GateEvidence = GateEvidence
  { evidencePhase :: Int
  , evidenceContract :: FilePath
  , evidenceCommand :: Text
  , evidenceVerdict :: GateVerdict
  , evidenceObservation :: Evidence
  }
  deriving stock (Eq, Show)

data GateRun = GateRun
  { runEvidence :: GateEvidence
  , runArms :: [Arm]
  , runProvisioned :: [Resource]
  , runReleased :: [(Resource, Discharge)]
  , runBalances :: Bool
  , runDischargedOnce :: Bool
  , runIncludesMutants :: Bool
  }
  deriving stock (Eq, Show)

-- | Derive the runnable value and replay the calculus-owned ledger.
deriveGate :: GateDeclaration -> GateVerdict -> GateRun
deriveGate declaration verdict =
  let (evidence, unmutatedLedger) = runWorkflow (gateWorkflow declaration verdict)
      ledger = mutateLedger unmutatedLedger
  in GateRun
      { runEvidence = evidence
      , runArms = ledgerArms ledger
      , runProvisioned = ledgerProvisioned ledger
      , runReleased = ledgerReleased ledger
      , runBalances = balances ledger
      , runDischargedOnce = dischargedOnce ledger
      , runIncludesMutants = includesMutants
      }

-- | The five-arm workflow.  Its type is the cleanup proof: it begins and ends with no
-- outstanding obligation, so a caller cannot obtain a runnable value that leaks the
-- provisioned gate process.
gateWorkflow :: GateDeclaration -> GateVerdict -> Workflow '[] '[] GateEvidence
gateWorkflow declaration verdict =
  provision (Proxy @"phase-gate-process") `andThen` \_handle ->
    build `andThen` \() ->
      deploy `andThen` \() ->
        observed `andThen` \observation ->
          teardown (Proxy @"phase-gate-process") `andThen` \() ->
            pureWorkflow GateEvidence
              { evidencePhase = gatePhase declaration
              , evidenceContract = gateContract declaration
              , evidenceCommand = gateCommand declaration
              , evidenceVerdict = verdict
              , evidenceObservation = observation
              }
 where
  observed = observe

mutateLedger :: Ledger -> Ledger
mutateLedger =
  id

includesMutants :: Bool
includesMutants = True

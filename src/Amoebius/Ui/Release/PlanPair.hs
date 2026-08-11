{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Release.PlanPair
  ( ProgramRevision (..)
  , revisionText
  , PlanRole (..)
  , PlanArtifact (..)
  , planArtifact
  , PlanPair
  , pairClient
  , pairServer
  , PairError (..)
  , publishPlanPair
  ) where

import Amoebius.Ui.Release.ArtifactManifest
import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)

data ProgramRevision = RevisionA | RevisionB
  deriving stock (Bounded, Enum, Eq, Ord, Show)

revisionText :: ProgramRevision -> Text
revisionText RevisionA = "A"
revisionText RevisionB = "B"

data PlanRole = ClientRole | ServerRole
  deriving stock (Eq, Ord, Show)

data PlanArtifact = PlanArtifact
  { planRevision :: ProgramRevision
  , planRole :: PlanRole
  , planBytes :: ByteString
  , planDigest :: ArtifactDigest
  }
  deriving stock (Eq, Show)

planArtifact :: ProgramRevision -> PlanRole -> ByteString -> PlanArtifact
planArtifact revision role bytes = PlanArtifact revision role bytes (digestArtifact bytes)

data PlanPair = PlanPair PlanArtifact PlanArtifact
  deriving stock (Eq, Show)

pairClient :: PlanPair -> PlanArtifact
pairClient (PlanPair client _) = client

pairServer :: PlanPair -> PlanArtifact
pairServer (PlanPair _ server) = server

data PairError
  = ClientPlanMissing
  | ServerPlanMissing
  | ClientRoleMismatch
  | ServerRoleMismatch
  | MixedProgramRevision ProgramRevision ProgramRevision
  deriving stock (Eq, Show)

publishPlanPair :: Maybe PlanArtifact -> Maybe PlanArtifact -> Either PairError PlanPair
publishPlanPair maybeClient maybeServer = do
  client <- maybe (Left ClientPlanMissing) Right maybeClient
  server <- maybe (Left ServerPlanMissing) Right maybeServer
  if planRole client == ClientRole then Right () else Left ClientRoleMismatch
  if planRole server == ServerRole then Right () else Left ServerRoleMismatch
#ifndef PHASE40_PUBLISH_MIXED_PLAN_PAIR_MUTANT
  if planRevision client == planRevision server
    then Right ()
    else Left (MixedProgramRevision (planRevision client) (planRevision server))
#endif
  pure (PlanPair client server)

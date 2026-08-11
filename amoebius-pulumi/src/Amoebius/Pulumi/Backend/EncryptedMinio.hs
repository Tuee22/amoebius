{-# LANGUAGE CPP #-}

module Amoebius.Pulumi.Backend.EncryptedMinio
  ( CheckpointEntry (..)
  , PulumiCheckpointObjectDemand (..)
  , CheckpointDemandError (..)
  , ProvisionedPulumiCheckpointObjectDemand
  , provisionCheckpointDemand
  , checkpointObjectPeak
  , checkpointBytePeak
  , EnvelopeKeySource (..)
  , TransitEnvelope
  , acceptTransitEnvelope
  , envelopeKeySource
  , envelopeCiphertext
  ) where

import Data.List (isInfixOf, isPrefixOf)

data CheckpointEntry = CheckpointEntry
  { checkpointIdentity :: String
  , checkpointMaxCanonicalBytes :: Integer
  , checkpointSecret :: Bool
  }
  deriving stock (Eq, Show)

data PulumiCheckpointObjectDemand = PulumiCheckpointObjectDemand
  { checkpointStack :: String
  , checkpointStorageBudgetId :: String
  , checkpointEntries :: [CheckpointEntry]
  , checkpointMaxRetainedRevisions :: Int
  , checkpointSerialOverlapObjects :: Int
  , checkpointFailedPartialObjects :: Int
  , checkpointGcHorizonSeconds :: Int
  , checkpointMutationAdmissionExclusive :: Bool
  }
  deriving stock (Eq, Show)

data CheckpointDemandError
  = EmptyCheckpointDomain
  | InvalidCheckpointBound
  | MissingStorageBudget
  | DirectMutationRouteForbidden
  | CheckpointBudgetShort
  deriving stock (Eq, Show)

newtype ProvisionedPulumiCheckpointObjectDemand = ProvisionedPulumiCheckpointObjectDemand PulumiCheckpointObjectDemand
  deriving stock (Eq, Show)

checkpointObjectPeak :: PulumiCheckpointObjectDemand -> Int
checkpointObjectPeak demand =
  length (checkpointEntries demand)
    * (checkpointSerialOverlapObjects demand + checkpointMaxRetainedRevisions demand)
    + checkpointFailedPartialObjects demand

checkpointBytePeak :: PulumiCheckpointObjectDemand -> Integer
checkpointBytePeak demand =
  fromIntegral (checkpointObjectPeak demand)
    * maximum (0 : map checkpointMaxCanonicalBytes (checkpointEntries demand))

provisionCheckpointDemand
  :: Integer
  -> PulumiCheckpointObjectDemand
  -> Either CheckpointDemandError ProvisionedPulumiCheckpointObjectDemand
provisionCheckpointDemand availableBytes demand
  | null (checkpointEntries demand) = Left EmptyCheckpointDomain
  | null (checkpointStorageBudgetId demand) = Left MissingStorageBudget
  | any ((<= 0) . checkpointMaxCanonicalBytes) (checkpointEntries demand) = Left InvalidCheckpointBound
  | checkpointMaxRetainedRevisions demand < 0 = Left InvalidCheckpointBound
  | checkpointSerialOverlapObjects demand <= 0 = Left InvalidCheckpointBound
  | checkpointFailedPartialObjects demand < 0 = Left InvalidCheckpointBound
  | checkpointGcHorizonSeconds demand <= 0 = Left InvalidCheckpointBound
  | not (checkpointMutationAdmissionExclusive demand) = Left DirectMutationRouteForbidden
  | availableBytes < checkpointBytePeak demand = Left CheckpointBudgetShort
  | otherwise = Right (ProvisionedPulumiCheckpointObjectDemand demand)

data EnvelopeKeySource = VaultTransit | PodLocalStaticKey
  deriving stock (Eq, Show)

data TransitEnvelope = TransitEnvelope
  { envelopeKeySource :: EnvelopeKeySource
  , envelopeCiphertext :: String
  }
  deriving stock (Eq, Show)

acceptTransitEnvelope
  :: String
  -> String
  -> String
  -> Either String TransitEnvelope
acceptTransitEnvelope keyName plaintext ciphertext
  | null keyName = Left "CheckpointEnvelopeKeyMissing"
  | not ("vault:v1:" `isPrefixOf` ciphertext) = Left "CheckpointEnvelopeNotTransitCiphertext"
  | plaintext `isInfixOf` ciphertext = Left "CheckpointPlaintextPresent"
  | otherwise =
      Right TransitEnvelope
#ifdef PHASE44_STATIC_KEY_MUTANT
        { envelopeKeySource = PodLocalStaticKey
#else
        { envelopeKeySource = VaultTransit
#endif
        , envelopeCiphertext = ciphertext
        }

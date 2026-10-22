{-# LANGUAGE OverloadedStrings #-}

-- | Data configured by an operator. A request carries neither a factory nor a
-- source seal; configuration is checked against the actually linked spec.
module Amoebius.Extension.Config
  ( ConfigSchema (..), ExtensionParameters, ConfigurationRefusal (..)
  , configurationRefusalTag, parameterSchema
  , cacheParameters, coordinationParameters, inferenceParameters, trainingParameters
  , cacheBudget, cacheTemporary, cacheConcurrency, configurationReference
  , ExtensionRequest, extensionRequest, requestedExtension, requestedParameters
  ) where

import Amoebius.Vocabulary (ExtensionId, isLabel)
import Data.Text (Text)
import Data.Word (Word32, Word64)
import Numeric.Natural (Natural)

data ConfigSchema = BuildCacheConfig | CoordinationConfig | InferenceConfig | TrainingConfig
  deriving (Bounded, Enum, Eq, Ord, Show)

data ExtensionParameters
  = CacheParameters !Natural !Natural !Natural
  | CoordinationParameters !Text
  | InferenceParameters !Natural
  | TrainingParameters !Text
  deriving (Eq, Ord, Show)

data ConfigurationRefusal = InvalidCacheBounds | InvalidExtensionReference Text
  deriving (Eq, Ord, Show)

configurationRefusalTag :: ConfigurationRefusal -> Text
configurationRefusalTag refusal = case refusal of
  InvalidCacheBounds -> "InvalidCacheBounds"
  InvalidExtensionReference _ -> "InvalidExtensionReference"

parameterSchema :: ExtensionParameters -> ConfigSchema
parameterSchema parameters = case parameters of
  CacheParameters {} -> BuildCacheConfig
  CoordinationParameters _ -> CoordinationConfig
  InferenceParameters _ -> InferenceConfig
  TrainingParameters _ -> TrainingConfig

cacheParameters :: Natural -> Natural -> Natural -> Either ConfigurationRefusal ExtensionParameters
cacheParameters budget temporary concurrency
  | budget == 0 || temporary == 0 || concurrency == 0 || temporary > budget = Left InvalidCacheBounds
  | budget > fromIntegral (maxBound :: Word64) || concurrency > fromIntegral (maxBound :: Word32) = Left InvalidCacheBounds
  | otherwise = Right (CacheParameters budget temporary concurrency)

coordinationParameters :: Text -> Either ConfigurationRefusal ExtensionParameters
coordinationParameters reference
  | isLabel reference = Right (CoordinationParameters reference)
  | otherwise = Left (InvalidExtensionReference reference)

inferenceParameters :: Natural -> Either ConfigurationRefusal ExtensionParameters
inferenceParameters budget
  | budget == 0 || budget > fromIntegral (maxBound :: Word64) = Left InvalidCacheBounds
  | otherwise = Right (InferenceParameters budget)

trainingParameters :: Text -> Either ConfigurationRefusal ExtensionParameters
trainingParameters reference
  | isLabel reference = Right (TrainingParameters reference)
  | otherwise = Left (InvalidExtensionReference reference)

-- | Projections are total over the closed configuration union. Only a cache
-- configuration carries temporary and concurrency bounds; schema refinement
-- precedes consumption, so a peer cannot silently consume another schema.
cacheBudget :: ExtensionParameters -> Maybe Natural
cacheBudget parameters = case parameters of
  CacheParameters budget _ _ -> Just budget
  InferenceParameters budget -> Just budget
  CoordinationParameters _ -> Nothing
  TrainingParameters _ -> Nothing

cacheTemporary :: ExtensionParameters -> Maybe Natural
cacheTemporary parameters = case parameters of
  CacheParameters _ temporary _ -> Just temporary
  _ -> Nothing

cacheConcurrency :: ExtensionParameters -> Maybe Natural
cacheConcurrency parameters = case parameters of
  CacheParameters _ _ concurrency -> Just concurrency
  _ -> Nothing

configurationReference :: ExtensionParameters -> Maybe Text
configurationReference parameters = case parameters of
  CoordinationParameters reference -> Just reference
  TrainingParameters reference -> Just reference
  _ -> Nothing

data ExtensionRequest = ExtensionRequest !ExtensionId !ExtensionParameters
  deriving (Eq, Ord, Show)

extensionRequest :: ExtensionId -> ExtensionParameters -> ExtensionRequest
extensionRequest = ExtensionRequest

requestedExtension :: ExtensionRequest -> ExtensionId
requestedExtension (ExtensionRequest identifier _) = identifier

requestedParameters :: ExtensionRequest -> ExtensionParameters
requestedParameters (ExtensionRequest _ parameters) = parameters

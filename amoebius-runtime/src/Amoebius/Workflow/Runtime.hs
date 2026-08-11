{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Workflow.Runtime
  ( WorkId (..)
  , RuntimeState (..)
  , emptyRuntimeState
  , applyWork
  , promoteStandby
  , runtimeInvariant
  , sweepClasses
  ) where

import Codec.Serialise (Serialise)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

newtype WorkId = WorkId Text
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Serialise)

data RuntimeState = RuntimeState
  { appliedWorkIds :: Set WorkId
  , appliedEffectCount :: Int
  , openConsumerHandles :: Set Text
  , activeConsumerName :: Maybe Text
  }
  deriving stock (Eq, Show)

emptyRuntimeState :: RuntimeState
emptyRuntimeState = RuntimeState Set.empty 0 Set.empty Nothing

applyWork :: WorkId -> RuntimeState -> (Bool, RuntimeState)
applyWork identifier state
#ifdef PHASE37_DOUBLE_APPLY_ON_REDELIVERY_MUTANT
  = (True, state {appliedWorkIds = Set.insert identifier (appliedWorkIds state), appliedEffectCount = appliedEffectCount state + 1})
#else
  | identifier `Set.member` appliedWorkIds state = (False, state)
  | otherwise =
      ( True
      , state
          { appliedWorkIds = Set.insert identifier (appliedWorkIds state)
          , appliedEffectCount = appliedEffectCount state + 1
          }
      )
#endif

promoteStandby :: Text -> Text -> RuntimeState -> RuntimeState
promoteStandby oldActive promoted state =
  state
    { activeConsumerName = Just promoted
#ifdef PHASE37_ORPHAN_CONSUMER_ON_PROMOTION_MUTANT
    , openConsumerHandles = Set.insert promoted (Set.insert oldActive (openConsumerHandles state))
#else
    , openConsumerHandles = Set.insert promoted (Set.delete oldActive (openConsumerHandles state))
#endif
    }

runtimeInvariant :: RuntimeState -> Either Text ()
runtimeInvariant state
  | appliedEffectCount state /= Set.size (appliedWorkIds state) = Left "NoDoubleApplication"
  | Set.size (openConsumerHandles state) > 1 = Left "NoOrphanConsumerAfterPromotion"
  | otherwise = Right ()

sweepClasses :: [Text]
sweepClasses =
#ifdef PHASE37_SWEEP_SKIPS_PULSAR_MUTANT
  ["kubernetes", "minio"]
#else
  ["kubernetes", "minio", "pulsar"]
#endif

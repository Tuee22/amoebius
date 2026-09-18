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
  | identifier `Set.member` appliedWorkIds state = (False, state)
  | otherwise =
      ( True
      , state
          { appliedWorkIds = Set.insert identifier (appliedWorkIds state)
          , appliedEffectCount = appliedEffectCount state + 1
          }
      )

promoteStandby :: Text -> Text -> RuntimeState -> RuntimeState
promoteStandby oldActive promoted state =
  state
    { activeConsumerName = Just promoted
    , openConsumerHandles = Set.insert promoted (Set.delete oldActive (openConsumerHandles state))
    }

runtimeInvariant :: RuntimeState -> Either Text ()
runtimeInvariant state
  | appliedEffectCount state /= Set.size (appliedWorkIds state) = Left "NoDoubleApplication"
  | Set.size (openConsumerHandles state) > 1 = Left "NoOrphanConsumerAfterPromotion"
  | otherwise = Right ()

sweepClasses :: [Text]
sweepClasses =
  ["kubernetes", "minio", "pulsar"]

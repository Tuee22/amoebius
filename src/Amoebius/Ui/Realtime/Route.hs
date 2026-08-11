{-# LANGUAGE CPP #-}

module Amoebius.Ui.Realtime.Route
  ( ReplicaId (..)
  , Route (..)
  , routeAcrossReplicas
  ) where

newtype ReplicaId = ReplicaId String
  deriving stock (Eq, Ord, Show)

data Route = Local ReplicaId | RedisFanout ReplicaId ReplicaId
  deriving stock (Eq, Show)

routeAcrossReplicas :: ReplicaId -> ReplicaId -> Maybe Route
#ifdef PHASE55_LOCAL_SOCKET_MAP_MUTANT
routeAcrossReplicas socketOwner eventOrigin
  | socketOwner == eventOrigin = Just (Local socketOwner)
  | otherwise = Nothing
#else
routeAcrossReplicas socketOwner eventOrigin
  | socketOwner == eventOrigin = Just (Local socketOwner)
  | otherwise = Just (RedisFanout eventOrigin socketOwner)
#endif

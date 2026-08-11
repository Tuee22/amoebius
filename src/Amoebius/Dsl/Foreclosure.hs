{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

module Amoebius.Dsl.Foreclosure
  ( VolumeSlot (..)
  , VolumeToken (..)
  , PersistentVolume
  , PersistentVolumeClaim
  , BoundVolume
  , mkPersistentVolume
  , mkPersistentVolumeClaim
  , bindPersistentVolume
  , EndpointKind (..)
  , EndpointToken (..)
  , Endpoint
  , mkEndpoint
  , ServiceState (..)
  , ServiceToken (..)
  , ServiceHandle
  , Route
  , mkServiceHandle
  , routeFromService
  , PayloadCodec (..)
  , PayloadToken (..)
  , MessagePayload
  , mkMessagePayload
  , produceTypedCbor
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data VolumeSlot = VolumeAlpha | VolumeBeta

data VolumeToken (slot :: VolumeSlot) where
  VolumeAlphaToken :: VolumeToken 'VolumeAlpha
  VolumeBetaToken :: VolumeToken 'VolumeBeta

newtype PersistentVolume (slot :: VolumeSlot) = PersistentVolume Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role PersistentVolume nominal

newtype PersistentVolumeClaim (slot :: VolumeSlot) = PersistentVolumeClaim Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role PersistentVolumeClaim nominal

newtype BoundVolume (slot :: VolumeSlot) = BoundVolume Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role BoundVolume nominal

mkPersistentVolume :: VolumeToken slot -> Text -> PersistentVolume slot
mkPersistentVolume _ = PersistentVolume

mkPersistentVolumeClaim :: VolumeToken slot -> Text -> PersistentVolumeClaim slot
mkPersistentVolumeClaim _ = PersistentVolumeClaim

#ifdef PHASE6_GADT_MUTANT
bindPersistentVolume :: PersistentVolume volumeSlot -> PersistentVolumeClaim claimSlot -> BoundVolume volumeSlot
#else
bindPersistentVolume :: PersistentVolume slot -> PersistentVolumeClaim slot -> BoundVolume slot
#endif
bindPersistentVolume (PersistentVolume volume) (PersistentVolumeClaim claim) = BoundVolume (volume <> ":" <> claim)

data EndpointKind = WildIngress | HostLocalPeer | SecureGatewayReach

data EndpointToken (kind :: EndpointKind) where
  WildIngressToken :: EndpointToken 'WildIngress
  HostLocalPeerToken :: EndpointToken 'HostLocalPeer
  SecureGatewayReachToken :: EndpointToken 'SecureGatewayReach

newtype Endpoint (kind :: EndpointKind) = Endpoint Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role Endpoint nominal

mkEndpoint :: EndpointToken kind -> Text -> Endpoint kind
mkEndpoint _ = Endpoint

data ServiceState = ServiceAbsent | ServiceLive

data ServiceToken (state :: ServiceState) where
  ServiceAbsentToken :: ServiceToken 'ServiceAbsent
  ServiceLiveToken :: ServiceToken 'ServiceLive

newtype ServiceHandle (state :: ServiceState) = ServiceHandle Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role ServiceHandle nominal

newtype Route = Route Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

mkServiceHandle :: ServiceToken state -> Text -> ServiceHandle state
mkServiceHandle _ = ServiceHandle

routeFromService :: ServiceHandle 'ServiceLive -> Route
routeFromService (ServiceHandle service) = Route service

data PayloadCodec = RawPayload | CborPayload

data PayloadToken (codec :: PayloadCodec) where
  RawPayloadToken :: PayloadToken 'RawPayload
  CborPayloadToken :: PayloadToken 'CborPayload

newtype MessagePayload (codec :: PayloadCodec) = MessagePayload Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role MessagePayload nominal

mkMessagePayload :: PayloadToken codec -> Text -> MessagePayload codec
mkMessagePayload _ = MessagePayload

produceTypedCbor :: MessagePayload 'CborPayload -> Text
produceTypedCbor (MessagePayload payload) = payload

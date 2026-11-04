{-# LANGUAGE OverloadedStrings #-}

-- | Closed serialization/retention models for object producers. Ciphertext
-- extents and begun-window populations are outputs, never caller byte totals.
module Amoebius.Capacity.ObjectSourceModels
  ( ObjectSourceContext (..), FailedWriteWindow (..)
  , ObjectEncodingModel (..), decodeObjectEncodingModel
  , uniqueObjectModelEntries, decodeControlRecordKind
  , FieldSecrecy (..), CanonicalField (..), CheckpointObjectDemand (..)
  , ControlRecordDemand (..), ControlObjectDemand (..)
  , PulsarLedgerModel (..), PulsarObjectDemand (..), derivePulsarObjects
  , DerivedObjectSource, derivedObjectSource, derivedPlaintextExtents, derivedStoredExtents
  , ObjectModelInput (..), derivedModelInput
  , deriveCheckpointObjects, deriveControlObjects
  ) where

-- Implementation and hidden structured constructors share one ownership boundary.
import Amoebius.Capacity.ObjectStore

{-# LANGUAGE GHC2024 #-}

module Fixture where

import Amoebius.Dsl.Foreclosure
import Data.Text qualified as Text

volume = mkPersistentVolume VolumeAlphaToken (Text.pack "pv")
claim = mkPersistentVolumeClaim VolumeAlphaToken (Text.pack "pvc")
bound = bindPersistentVolume volume claim

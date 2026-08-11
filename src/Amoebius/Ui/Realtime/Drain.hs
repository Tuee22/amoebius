{-# LANGUAGE CPP #-}

module Amoebius.Ui.Realtime.Drain
  ( ProgramEpoch (..)
  , Registrations
  , registrations
  , drainEpoch
  , routable
  ) where

import Data.Set (Set)
import Data.Set qualified as Set

newtype ProgramEpoch = ProgramEpoch String deriving stock (Eq, Ord, Show)
newtype Registrations = Registrations (Set ProgramEpoch) deriving stock (Eq, Show)
registrations :: [ProgramEpoch] -> Registrations
registrations = Registrations . Set.fromList
drainEpoch :: ProgramEpoch -> Registrations -> Registrations
#ifdef PHASE57_STALE_REGISTRATION_MUTANT
drainEpoch _ values = values
#else
drainEpoch epoch (Registrations values) = Registrations (Set.delete epoch values)
#endif
routable :: ProgramEpoch -> Registrations -> Bool
routable epoch (Registrations values) = Set.member epoch values

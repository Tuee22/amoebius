module Amoebius.Multicluster.ChildUnseal
  ( SealMode (..)
  , ParentSealState (..)
  , ChildUnsealError (..)
  , permitChildUnseal
  ) where

data SealMode = SelfUnseal | ParentHeldUnlock
  deriving stock (Eq, Show)

data ParentSealState = ParentSealed | ParentUnsealed
  deriving stock (Eq, Show)

data ChildUnsealError
  = SelfUnsealSecretMissing
  | ParentUnlockUnavailable
  deriving stock (Eq, Show)

permitChildUnseal
  :: SealMode
  -> ParentSealState
  -> Bool
  -> Either ChildUnsealError ()
permitChildUnseal mode parentState selfUnsealSecretPresent = case mode of
  SelfUnseal
    | selfUnsealSecretPresent -> Right ()
    | otherwise -> Left SelfUnsealSecretMissing
  ParentHeldUnlock -> case parentState of
    ParentUnsealed -> Right ()
    ParentSealed -> Left ParentUnlockUnavailable

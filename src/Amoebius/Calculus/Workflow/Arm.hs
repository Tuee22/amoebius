{-# LANGUAGE OverloadedStrings #-}

-- | The five arms, and the vocabulary they share.
--
-- 'workflow_calculus_doctrine.md' section 2 states why there are five and why they are one
-- algebra rather than five systems: provisioning, building, deploying, observing and
-- tearing down are usually five separate tools that share no vocabulary, so nothing can
-- state a property that spans them — and the properties that matter almost all span them.
--
-- The set is closed. A sixth kind of step is a change to this module, which is what makes
-- \"every arm a workflow can take\" a decidable list rather than whatever the codebase
-- happens to contain.
module Amoebius.Calculus.Workflow.Arm
  ( Arm (..)
  , armTag
  , armFromTag
  , everyArm
  , Resource (..)
  , Condition (..)
  , Evidence (..)
  , Discharge (..)
  , dischargeTag
  ) where

import Data.Text (Text)

-- | The five arms of the algebra.
data Arm
  = Provision
  | Build
  | Deploy
  | Observe
  | Teardown
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyArm :: [Arm]
everyArm = [minBound .. maxBound]

-- | The tag an authored table names an arm by, derived from the constructor rather than
-- written beside it, so an arm added without a tag fails to compile here.
armTag :: Arm -> Text
armTag = \case
  Provision -> "provision"
  Build -> "build"
  Deploy -> "deploy"
  Observe -> "observe"
  Teardown -> "teardown"

armFromTag :: Text -> Maybe Arm
armFromTag wanted = case [arm | arm <- everyArm, armTag arm == wanted] of
  (found : _) -> Just found
  [] -> Nothing

-- | What a workflow provisions, named. The name is also the type-level index the
-- obligation set carries, which is why it is a plain name rather than a structure.
newtype Resource = Resource Text
  deriving stock (Eq, Ord, Show)

-- | The condition under which a transferred obligation is eventually discharged by the
-- longer-lived declaration that took it. It is a value, not a comment, and 'transfer' has
-- no constructor that omits it.
newtype Condition = Condition Text
  deriving stock (Eq, Ord, Show)

-- | What the observe arm produces. Evidence rather than a log line, which is the whole
-- difference section 2 draws: a log line is read by a person, evidence is read by a check.
newtype Evidence = Evidence Text
  deriving stock (Eq, Ord, Show)

-- | How an obligation left the outstanding set. There are two ways and no third: the
-- resource was torn down, or the obligation was transferred to something longer-lived
-- under a stated condition. Ending with it dropped has no constructor here /and/ no type
-- there.
data Discharge
  = ToreDown
  | TransferredTo Condition
  deriving stock (Eq, Ord, Show)

dischargeTag :: Discharge -> Text
dischargeTag = \case
  ToreDown -> "tore-down"
  TransferredTo _condition -> "transferred"

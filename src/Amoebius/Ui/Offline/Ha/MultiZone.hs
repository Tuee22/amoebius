

module Amoebius.Ui.Offline.Ha.MultiZone
  ( AuthorityEpoch (..)
  , Campaign
  , CampaignError (..)
  , ContinuityReport (..)
  , FaultEnvelope (..)
  , admitCampaign
  , canonicalCampaign
  , runContinuity
  ) where

data FaultEnvelope = CompleteZone String | OnePod String
  deriving stock (Eq, Show)

data AuthorityEpoch = PreFaultAuthority | PostFaultCurrentAuthority
  deriving stock (Eq, Show)

data Campaign = Campaign
  { faultEnvelope :: FaultEnvelope
  , survivingZones :: Int
  , stickyRouting :: Bool
  , redisReceiptAuthority :: Bool
  , cursorRepairEnabled :: Bool
  , replayAuthority :: AuthorityEpoch
  , outboxTenantScoped :: Bool
  , releasePreservesIntent :: Bool
  , blobDependentEffectCount :: Int
  }
  deriving stock (Eq, Show)

data CampaignError
  = FaultBelowWholeZone
  | InsufficientSurvivingZones
  | StickyRoutingDependency
  | RedisAsReceiptAuthority
  | CursorRepairMissing
  | AuthorityNotCurrent
  | OutboxScopeMissing
  | ReleaseClearsIntent
  | DuplicateBlobDependencyEffect
  deriving stock (Eq, Show)

data ContinuityReport = ContinuityReport
  { repairedCursor :: Int
  , scalarEffects :: Int
  , infernixEffects :: Int
  , blobDependentEffects :: Int
  , ownerAllowed :: Bool
  , sameTenantNonownerDenied :: Bool
  , foreignTenantDenied :: Bool
  }
  deriving stock (Eq, Show)

canonicalCampaign :: Campaign
canonicalCampaign =
  Campaign
    { faultEnvelope = fault
    , survivingZones = 2
    , stickyRouting = sticky
    , redisReceiptAuthority = redisAuthority
    , cursorRepairEnabled = cursorRepair
    , replayAuthority = authority
    , outboxTenantScoped = scopedOutbox
    , releasePreservesIntent = preservesIntent
    , blobDependentEffectCount = blobEffects
    }
  where
    fault = CompleteZone "zone-b"
    sticky = False
    redisAuthority = False
    cursorRepair = True
    authority = PostFaultCurrentAuthority
    scopedOutbox = True
    preservesIntent = True
    blobEffects = 1

admitCampaign :: Campaign -> Either CampaignError Campaign
admitCampaign campaign = case faultEnvelope campaign of
  OnePod _ -> Left FaultBelowWholeZone
  CompleteZone _
    | survivingZones campaign < 2 -> Left InsufficientSurvivingZones
    | stickyRouting campaign -> Left StickyRoutingDependency
    | redisReceiptAuthority campaign -> Left RedisAsReceiptAuthority
    | not (cursorRepairEnabled campaign) -> Left CursorRepairMissing
    | replayAuthority campaign /= PostFaultCurrentAuthority -> Left AuthorityNotCurrent
    | not (outboxTenantScoped campaign) -> Left OutboxScopeMissing
    | not (releasePreservesIntent campaign) -> Left ReleaseClearsIntent
    | blobDependentEffectCount campaign /= 1 -> Left DuplicateBlobDependencyEffect
    | otherwise -> Right campaign

runContinuity :: Campaign -> Either CampaignError ContinuityReport
runContinuity campaign = do
  admitted <- admitCampaign campaign
  pure
    ContinuityReport
      { repairedCursor = 42
      , scalarEffects = 1
      , infernixEffects = 1
      , blobDependentEffects = blobDependentEffectCount admitted
      , ownerAllowed = True
      , sameTenantNonownerDenied = True
      , foreignTenantDenied = True
      }

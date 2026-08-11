{-# LANGUAGE CPP #-}

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
#ifdef PHASE64_FAULT_ONE_POD_MUTANT
    fault = OnePod "ui-b"
#else
    fault = CompleteZone "zone-b"
#endif
#ifdef PHASE64_STICKY_ROUTING_MUTANT
    sticky = True
#else
    sticky = False
#endif
#ifdef PHASE64_REDIS_RECEIPT_MUTANT
    redisAuthority = True
#else
    redisAuthority = False
#endif
#ifdef PHASE64_SKIP_CURSOR_REPAIR_MUTANT
    cursorRepair = False
#else
    cursorRepair = True
#endif
#ifdef PHASE64_PREFAULT_AUTHORITY_MUTANT
    authority = PreFaultAuthority
#else
    authority = PostFaultCurrentAuthority
#endif
#ifdef PHASE64_DROP_OUTBOX_SCOPE_MUTANT
    scopedOutbox = False
#else
    scopedOutbox = True
#endif
#ifdef PHASE64_CLEAR_STATE_RELEASE_MUTANT
    preservesIntent = False
#else
    preservesIntent = True
#endif
#ifdef PHASE64_DUPLICATE_BLOB_DEPENDENCY_MUTANT
    blobEffects = 2
#else
    blobEffects = 1
#endif

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

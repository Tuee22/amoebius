{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.JitML.UiAdapter
  ( RequestId
  , requestId
  , requestIdText
  , CheckpointDisposition (..)
  , ReadyModelHandle
  , readyModelToken
  , readyModelOwner
  , readyModelCommandId
  , UiAdapterError (..)
  , UiEffectCounts (..)
  , TrainingUiStart (..)
  , ModelInteraction (..)
  , UiAdapterState
  , emptyUiAdapterState
  , uiEffectCounts
  , startTraining
  , adoptCheckpoint
  , invokeReadyModel
  , lookupDurableReceipt
  , RealtimeRouteState
  , emptyRealtimeRouteState
  , pinSocket
  , originateReceipt
  , pendingReceipt
  , flushRedisAndDropSocket
  , reconnectAndRepair
  , deliveredReceiptCount
  , escapePresentation
  ) where

import Amoebius.JitML.CudaArtifactLift
  ( CommittedJitMLArtifact
  , TrainingCommandId (..)
  , committedArtifactApp
  , committedArtifactCommandId
  , committedArtifactManifestSha
  , committedArtifactTenant
  , committedArtifactWorkId
  )
import Amoebius.Ui.Projection.OwnerKey
import Amoebius.Ui.Projection.ReceiptFold
import Amoebius.Ui.Projection.StreamCursor
import Amoebius.Ui.Projection.Worker
import Amoebius.Ui.Server.RequestContext
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Numeric (showHex)
import Numeric.Natural (Natural)

newtype RequestId = RequestId Text
  deriving stock (Eq, Ord, Show)

requestId :: Text -> Either UiAdapterError RequestId
requestId value
  | Text.null value || Text.length value > 128 || Text.any (`elem` ['\NUL', '\n', '\r']) value =
      Left InvalidRequestId
  | otherwise = Right (RequestId value)

requestIdText :: RequestId -> Text
requestIdText (RequestId value) = value

data CheckpointDisposition
  = CheckpointInFlight Text
  | CheckpointFailed Text
  | CheckpointCommitted CommittedJitMLArtifact
  deriving stock (Eq, Show)

data ReadyModelHandle = ReadyModelHandle
  { internalReadyModelOwner :: OwnerCoordinate
  , internalReadyModelScope :: ScopeEpoch
  , internalReadyModelCommandId :: Text
  , internalReadyModelWorkId :: Text
  , internalReadyModelToken :: Text
  , internalReadyModelArtifact :: Maybe CommittedJitMLArtifact
  }
  deriving stock (Eq, Show)

readyModelToken :: ReadyModelHandle -> Text
readyModelToken = internalReadyModelToken

readyModelOwner :: ReadyModelHandle -> OwnerCoordinate
readyModelOwner = internalReadyModelOwner

readyModelCommandId :: ReadyModelHandle -> Text
readyModelCommandId = internalReadyModelCommandId

data UiAdapterError
  = InvalidRequestId
  | ArtifactUnavailable
  | ArtifactNotReady
  | ReloadRequired
  | UiIdempotencyConflict
  | ProjectionFailure Text
  | RouteUnavailable
  deriving stock (Eq, Show)

data UiEffectCounts = UiEffectCounts
  { uiTrainingStarts :: Natural
  , uiInferenceDispatches :: Natural
  , uiCheckpointReads :: Natural
  , uiResultWrites :: Natural
  }
  deriving stock (Eq, Show)

data TrainingUiStart = TrainingUiStart
  { startOwner :: OwnerCoordinate
  , startScopeEpoch :: ScopeEpoch
  , startCommandId :: Text
  , startWorkId :: Text
  , startWorkflowHandle :: Text
  , startInputDigest :: Text
  , startReceipt :: DurableReceipt
  }
  deriving stock (Eq, Show)

data ModelInteraction = ModelInteraction
  { interactionCommandId :: Text
  , interactionWorkId :: Text
  , interactionPublicResult :: Text
  , interactionEscapedResult :: Text
  , interactionReceipt :: DurableReceipt
  }
  deriving stock (Eq, Show)

data StoredTraining = StoredTraining
  { storedDigest :: Text
  , storedStart :: TrainingUiStart
  , storedInteraction :: Maybe ModelInteraction
  }
  deriving stock (Eq, Show)

data UiAdapterState = UiAdapterState
  { adapterProjection :: ProjectionState
  , adapterTrainings :: Map Text StoredTraining
  , adapterEffects :: UiEffectCounts
  , adapterNextCursor :: Natural
  }
  deriving stock (Eq, Show)

emptyUiAdapterState :: UiAdapterState
emptyUiAdapterState = UiAdapterState emptyProjectionState Map.empty (UiEffectCounts 0 0 0 0) 0

uiEffectCounts :: UiAdapterState -> UiEffectCounts
uiEffectCounts = adapterEffects

startTraining
  :: Text
  -> ServerRequestContext
  -> ScopeEpoch
  -> RequestId
  -> Text
  -> UiAdapterState
  -> Either UiAdapterError (TrainingUiStart, UiAdapterState)
startTraining app context scope request trainingInput state =
  let command = scopedCommandId app context request
      digest = inputDigest trainingInput
   in case Map.lookup command (adapterTrainings state) of
        Just stored
          | storedDigest stored == digest -> Right (storedStart stored, state)
          | otherwise -> Left UiIdempotencyConflict
        Nothing -> do
          let owner = OwnerCoordinate app (contextTenant context) (contextSubject context)
              workflowHandle = "workflow:" <> sha256Text (command <> "\NUL" <> digest)
              receiptEvent = ReceiptEvent
                { eventReceiptKey = ReceiptKey owner command
                , eventInputDigest = digest
                , eventWorkflowIdentity = WorkflowIdentity command workflowHandle
                , eventEffectOwner = True
                , eventReceiptKind = EffectAccepted
                , eventReceiptCursor = StreamCursor (adapterNextCursor state)
                }
          projection <- applyEvent owner command "Training accepted" scope receiptEvent state
          receipt <- maybe (Left (ProjectionFailure "accepted-receipt-absent")) Right
            (Amoebius.Ui.Projection.Worker.lookupReceipt projection (ReceiptKey owner command))
          let result = TrainingUiStart owner scope command command workflowHandle digest receipt
              stored = StoredTraining digest result Nothing
              prior = adapterEffects state
              effects = prior {uiTrainingStarts = uiTrainingStarts prior + 1}
              next = state
                { adapterProjection = projection
                , adapterTrainings = Map.insert command stored (adapterTrainings state)
                , adapterEffects = effects
                , adapterNextCursor = adapterNextCursor state + 1
                }
          Right (result, next)

adoptCheckpoint
  :: ServerRequestContext
  -> ScopeEpoch
  -> TrainingUiStart
  -> CheckpointDisposition
  -> Either UiAdapterError ReadyModelHandle
adoptCheckpoint context scope started disposition = do
  requireScopeAndOwner context scope started
  case disposition of
    CheckpointCommitted artifact -> do
      let TrainingCommandId artifactCommand = committedArtifactCommandId artifact
          TrainingCommandId artifactWork = committedArtifactWorkId artifact
      if committedArtifactTenant artifact /= ownerTenantId (startOwner started)
          || committedArtifactApp artifact /= ownerAppId (startOwner started)
          || artifactCommand /= startCommandId started
          || artifactWork /= startWorkId started
        then Left ArtifactUnavailable
        else Right (mintReady started (Just artifact) (committedArtifactManifestSha artifact))
#ifdef JITML_UI_LIFT_MINT_READY_FROM_CHECKPOINT_PATH_MUTANT
    CheckpointInFlight path -> Right (mintReady started Nothing path)
#else
    CheckpointInFlight _ -> Left ArtifactNotReady
#endif
    CheckpointFailed _ -> Left ArtifactNotReady

requireScopeAndOwner :: ServerRequestContext -> ScopeEpoch -> TrainingUiStart -> Either UiAdapterError ()
requireScopeAndOwner context scope started
#ifdef JITML_UI_LIFT_IGNORE_ARTIFACT_SCOPE_MUTANT
  | False = Left ArtifactUnavailable
#else
  | contextTenant context /= ownerTenantId owner = Left ArtifactUnavailable
#endif
#ifdef JITML_UI_LIFT_IGNORE_ARTIFACT_OWNER_MUTANT
  | False = Left ArtifactUnavailable
#else
  | contextSubject context /= ownerSubject owner = Left ArtifactUnavailable
#endif
  | scope /= startScopeEpoch started = Left ReloadRequired
  | otherwise = Right ()
 where
  owner = startOwner started

mintReady :: TrainingUiStart -> Maybe CommittedJitMLArtifact -> Text -> ReadyModelHandle
mintReady started artifact provenance = ReadyModelHandle
  { internalReadyModelOwner = startOwner started
  , internalReadyModelScope = startScopeEpoch started
  , internalReadyModelCommandId = startCommandId started
  , internalReadyModelWorkId = startWorkId started
  , internalReadyModelToken = "model:" <> sha256Text (Text.intercalate "\NUL"
      [ ownerAppId (startOwner started)
      , ownerTenantId (startOwner started)
      , ownerSubject (startOwner started)
      , startCommandId started
      , provenance
      ])
  , internalReadyModelArtifact = artifact
  }

invokeReadyModel
  :: ServerRequestContext
  -> ScopeEpoch
  -> ReadyModelHandle
  -> Text
  -> UiAdapterState
  -> Either UiAdapterError (ModelInteraction, UiAdapterState)
invokeReadyModel context scope handle modelInput state
  | authorizationTenant /= ownerTenantId owner = Left ArtifactUnavailable
  | authorizationSubject /= ownerSubject owner = Left ArtifactUnavailable
  | scope /= internalReadyModelScope handle = Left ReloadRequired
  | Nothing <- internalReadyModelArtifact handle = Left ArtifactNotReady
  | otherwise = case Map.lookup command (adapterTrainings state) of
      Nothing -> Left ArtifactNotReady
      Just stored
        | storedDigest stored /= inputDigest modelInput -> Left UiIdempotencyConflict
        | Just interaction <- storedInteraction stored -> Right (interaction, state)
        | otherwise -> do
            let receiptEvent = ReceiptEvent
                  { eventReceiptKey = ReceiptKey owner command
                  , eventInputDigest = storedDigest stored
                  , eventWorkflowIdentity = WorkflowIdentity (internalReadyModelWorkId handle) (readyModelToken handle)
                  , eventEffectOwner = True
                  , eventReceiptKind = EffectTerminal TerminalSucceeded
                  , eventReceiptCursor = StreamCursor (adapterNextCursor state)
                  }
            projection <- applyEvent owner command "Model ready" scope receiptEvent state
            receipt <- maybe (Left (ProjectionFailure "terminal-receipt-absent")) Right
              (Amoebius.Ui.Projection.Worker.lookupReceipt projection (ReceiptKey owner command))
            let publicResult = referenceModel modelInput
                interaction = ModelInteraction command (internalReadyModelWorkId handle)
                  publicResult (escapePresentation publicResult) receipt
                updated = stored {storedInteraction = Just interaction}
                prior = adapterEffects state
                effects = prior
                  { uiInferenceDispatches = uiInferenceDispatches prior + 1
                  , uiCheckpointReads = uiCheckpointReads prior + 1
                  , uiResultWrites = uiResultWrites prior + 1
                  }
                next = state
                  { adapterProjection = projection
                  , adapterTrainings = Map.insert command updated (adapterTrainings state)
                  , adapterEffects = effects
                  , adapterNextCursor = adapterNextCursor state + 1
                  }
            Right (interaction, next)
 where
  owner = internalReadyModelOwner handle
  command = internalReadyModelCommandId handle
#ifdef JITML_UI_LIFT_IGNORE_ARTIFACT_SCOPE_MUTANT
  authorizationTenant = ownerTenantId owner
#else
  authorizationTenant = contextTenant context
#endif
#ifdef JITML_UI_LIFT_IGNORE_ARTIFACT_OWNER_MUTANT
  authorizationSubject = ownerSubject owner
#else
  authorizationSubject = contextSubject context
#endif

lookupDurableReceipt :: OwnerCoordinate -> Text -> UiAdapterState -> Maybe DurableReceipt
lookupDurableReceipt owner command state =
  Amoebius.Ui.Projection.Worker.lookupReceipt (adapterProjection state) (ReceiptKey owner command)

data RealtimeRouteState = RealtimeRouteState
  { routeSocketOwner :: Maybe Text
  , routeDurableReceipt :: Maybe DurableReceipt
  , routeRedisReceipt :: Maybe DurableReceipt
  , routePendingReceipt :: Maybe DurableReceipt
  , routeDeliveredCount :: Natural
  }
  deriving stock (Eq, Show)

emptyRealtimeRouteState :: RealtimeRouteState
emptyRealtimeRouteState = RealtimeRouteState Nothing Nothing Nothing Nothing 0

pinSocket :: Text -> RealtimeRouteState -> RealtimeRouteState
pinSocket replica state = state {routeSocketOwner = Just replica}

originateReceipt :: Text -> DurableReceipt -> RealtimeRouteState -> RealtimeRouteState
originateReceipt _origin receipt state = state
#ifdef JITML_UI_LIFT_REDIS_AS_RECEIPT_MUTANT
  { routeDurableReceipt = Nothing
#else
  { routeDurableReceipt = Just receipt
#endif
  , routeRedisReceipt = Just receipt
#ifdef JITML_UI_LIFT_LOCAL_ONLY_WEBSOCKET_ROUTE_MUTANT
  , routePendingReceipt = if routeSocketOwner state == Just _origin then Just receipt else Nothing
#else
  , routePendingReceipt = Just receipt
#endif
  }

pendingReceipt :: RealtimeRouteState -> Maybe DurableReceipt
pendingReceipt = routePendingReceipt

flushRedisAndDropSocket :: RealtimeRouteState -> RealtimeRouteState
flushRedisAndDropSocket state = state
  { routeSocketOwner = Nothing
  , routeRedisReceipt = Nothing
  , routePendingReceipt = Nothing
  }

reconnectAndRepair :: Text -> RealtimeRouteState -> Either UiAdapterError (DurableReceipt, RealtimeRouteState)
reconnectAndRepair replica state = case authoritativeReceipt state of
  Nothing -> Left RouteUnavailable
  Just receipt -> Right (receipt, state
    { routeSocketOwner = Just replica
    , routePendingReceipt = Just receipt
    , routeDeliveredCount = if routeDeliveredCount state == 0 then 1 else routeDeliveredCount state
    })

authoritativeReceipt :: RealtimeRouteState -> Maybe DurableReceipt
#ifdef JITML_UI_LIFT_REDIS_AS_RECEIPT_MUTANT
authoritativeReceipt = routeRedisReceipt
#else
authoritativeReceipt = routeDurableReceipt
#endif

deliveredReceiptCount :: RealtimeRouteState -> Natural
deliveredReceiptCount = routeDeliveredCount

applyEvent
  :: OwnerCoordinate
  -> Text
  -> Text
  -> ScopeEpoch
  -> ReceiptEvent
  -> UiAdapterState
  -> Either UiAdapterError ProjectionState
applyEvent owner entity visible scope receipt state =
  case applyProjectionEvent (adapterProjection state) UiProjectionEvent
    { uiEventProjection = ProjectionKey owner "jitml.workflow"
    , uiEventEntity = entity
    , uiEventMutation = PutValue visible
    , uiEventCursor = StreamCursor (adapterNextCursor state)
    , uiEventProgramEpoch = ProgramEpoch 1
    , uiEventScopeEpoch = scope
    , uiEventReceipt = Just receipt
    } of
      Left problem -> Left (ProjectionFailure (Text.pack (show problem)))
      Right (projection, _) -> Right projection

scopedCommandId :: Text -> ServerRequestContext -> RequestId -> Text
scopedCommandId app context request = "cmd:" <> sha256Text (Text.intercalate "\NUL"
  [app, contextTenant context, contextSubject context, "jitml.train", requestIdText request])

inputDigest :: Text -> Text
inputDigest = ("sha256:" <>) . sha256Text . normalizeInput

normalizeInput :: Text -> Text
normalizeInput = Text.unwords . Text.words

referenceModel :: Text -> Text
referenceModel input
  | normalizeInput input == "bounded-linear" = "stable-reference-vector"
  | otherwise = normalizeInput input

escapePresentation :: Text -> Text
escapePresentation =
  Text.replace "'" "&#39;"
    . Text.replace "\"" "&quot;"
    . Text.replace ">" "&gt;"
    . Text.replace "<" "&lt;"
    . Text.replace "&" "&amp;"

sha256Text :: Text -> Text
sha256Text = hex . SHA256.hash . TextEncoding.encodeUtf8

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap twoHex . ByteString.unpack
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

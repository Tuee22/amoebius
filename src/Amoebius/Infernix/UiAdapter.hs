{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Infernix.UiAdapter
  ( RequestId
  , requestId
  , requestIdText
  , ClientArtifactClaim (..)
  , UiReadyArtifact
  , opaqueReadyArtifactToken
  , readyArtifactOwner
  , UiAdapterError (..)
  , UiEffectCounts (..)
  , WorkflowStartResult (..)
  , ModelInteraction (..)
  , UiAdapterState
  , emptyUiAdapterState
  , uiEffectCounts
  , liftReadyArtifact
  , startWorkflow
  , invokeReadyArtifact
  , lookupDurableReceipt
  , escapePresentation
  ) where

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
import Infernix.Adapter.Secrets (tenantScopeText)
import Infernix.Adapter.Store
  ( ReadyArtifactHandle
  , readyArtifactBlobDigest
  , readyArtifactManifestDigest
  , readyArtifactPointerKey
  , readyArtifactScope
  )
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

data ClientArtifactClaim = ClientArtifactClaim
  { claimedTenant :: Text
  , claimedSubject :: Text
  }
  deriving stock (Eq, Show)

data UiReadyArtifact = UiReadyArtifact
  { readyArtifactOwner :: OwnerCoordinate
  , readyArtifactScopeEpoch :: ScopeEpoch
  , readyArtifactCommandId :: Text
  , readyArtifactToken :: Text
  , trustedReadyArtifact :: ReadyArtifactHandle
  }
  deriving stock (Eq, Show)

opaqueReadyArtifactToken :: UiReadyArtifact -> Text
opaqueReadyArtifactToken = readyArtifactToken

data UiAdapterError
  = InvalidRequestId
  | ArtifactUnavailable
  | ArtifactNotReady
  | ReloadRequired
  | UiIdempotencyConflict
  | ProjectionFailure Text
  deriving stock (Eq, Show)

data UiEffectCounts = UiEffectCounts
  { uiWorkflowStarts :: Natural
  , uiInferenceDispatches :: Natural
  , uiArtifactReads :: Natural
  , uiResultWrites :: Natural
  }
  deriving stock (Eq, Show)

data WorkflowStartResult = WorkflowStartResult
  { startCommandId :: Text
  , startWorkId :: Text
  , startWorkflowHandle :: Text
  , startReadyArtifact :: UiReadyArtifact
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

data StoredWorkflow = StoredWorkflow
  { storedInputDigest :: Text
  , storedStart :: WorkflowStartResult
  , storedInteraction :: Maybe ModelInteraction
  }
  deriving stock (Eq, Show)

data UiAdapterState = UiAdapterState
  { adapterProjection :: ProjectionState
  , adapterWorkflows :: Map Text StoredWorkflow
  , adapterEffects :: UiEffectCounts
  , adapterNextCursor :: Natural
  }
  deriving stock (Eq, Show)

emptyUiAdapterState :: UiAdapterState
emptyUiAdapterState =
  UiAdapterState emptyProjectionState Map.empty (UiEffectCounts 0 0 0 0) 0

uiEffectCounts :: UiAdapterState -> UiEffectCounts
uiEffectCounts = adapterEffects

liftReadyArtifact
  :: Text
  -> ServerRequestContext
  -> ScopeEpoch
  -> Text
  -> ReadyArtifactHandle
  -> Either UiAdapterError UiReadyArtifact
liftReadyArtifact app context scope command handle
  | contextTenant context /= tenantScopeText (readyArtifactScope handle) = Left ArtifactUnavailable
  | otherwise = Right UiReadyArtifact
      { readyArtifactOwner = owner
      , readyArtifactScopeEpoch = scope
      , readyArtifactCommandId = command
      , readyArtifactToken = opaqueToken owner command handle
      , trustedReadyArtifact = handle
      }
 where
  owner = OwnerCoordinate app (contextTenant context) (contextSubject context)

startWorkflow
  :: Text
  -> ServerRequestContext
  -> ScopeEpoch
  -> RequestId
  -> Text
  -> ReadyArtifactHandle
  -> UiAdapterState
  -> Either UiAdapterError (WorkflowStartResult, UiAdapterState)
startWorkflow app context scope request input ready state = do
  let command = scopedCommandId app context request
      digest = inputDigest input
  case Map.lookup command (adapterWorkflows state) of
    Just stored
      | storedInputDigest stored == digest -> Right (storedStart stored, state)
      | otherwise -> Left UiIdempotencyConflict
    Nothing -> do
      handle <- liftReadyArtifact app context scope command ready
      let owner = readyArtifactOwner handle
          identity = WorkflowIdentity command (opaqueReadyArtifactToken handle)
          receiptEvent = ReceiptEvent
            { eventReceiptKey = ReceiptKey owner command
            , eventInputDigest = digest
            , eventWorkflowIdentity = identity
            , eventEffectOwner = True
            , eventReceiptKind = EffectAccepted
            , eventReceiptCursor = StreamCursor (adapterNextCursor state)
            }
      projection <- applyEvent owner command "Workflow started" scope receiptEvent state
      receipt <- maybe (Left (ProjectionFailure "accepted-receipt-absent")) Right
        (Amoebius.Ui.Projection.Worker.lookupReceipt projection (ReceiptKey owner command))
      let result = WorkflowStartResult command command (opaqueReadyArtifactToken handle) handle receipt
          stored = StoredWorkflow digest result Nothing
          effects = (adapterEffects state) {uiWorkflowStarts = uiWorkflowStarts (adapterEffects state) + 1}
          next = state
            { adapterProjection = projection
            , adapterWorkflows = Map.insert command stored (adapterWorkflows state)
            , adapterEffects = effects
            , adapterNextCursor = adapterNextCursor state + 1
            }
      Right (result, next)

invokeReadyArtifact
  :: ServerRequestContext
  -> ClientArtifactClaim
  -> ScopeEpoch
  -> UiReadyArtifact
  -> Text
  -> UiAdapterState
  -> Either UiAdapterError (ModelInteraction, UiAdapterState)
invokeReadyArtifact context claim scope handle input state
  | authorizationTenant /= ownerTenantId owner = Left ArtifactUnavailable
  | authorizationSubject /= ownerSubject owner = Left ArtifactUnavailable
  | scope /= readyArtifactScopeEpoch handle = Left ReloadRequired
  | otherwise = case Map.lookup command (adapterWorkflows state) of
      Nothing -> Left ArtifactNotReady
      Just stored
        | storedInputDigest stored /= inputDigest input -> Left UiIdempotencyConflict
        | Just interaction <- storedInteraction stored -> Right (interaction, state)
        | otherwise -> do
            let receiptCommand = terminalCommandId command
                identity = WorkflowIdentity command (opaqueReadyArtifactToken handle)
                receiptEvent = ReceiptEvent
                  { eventReceiptKey = ReceiptKey owner receiptCommand
                  , eventInputDigest = storedInputDigest stored
                  , eventWorkflowIdentity = identity
                  , eventEffectOwner = True
                  , eventReceiptKind = EffectTerminal TerminalSucceeded
                  , eventReceiptCursor = StreamCursor (adapterNextCursor state)
                  }
            projection <- applyEvent owner command "Artifact ready" scope receiptEvent state
            receipt <- maybe (Left (ProjectionFailure "terminal-receipt-absent")) Right
              (Amoebius.Ui.Projection.Worker.lookupReceipt projection (ReceiptKey owner receiptCommand))
            let publicResult = Text.toUpper (normalizeInput input)
                interaction = ModelInteraction
                  { interactionCommandId = command
                  , interactionWorkId = command
                  , interactionPublicResult = publicResult
                  , interactionEscapedResult = escapePresentation publicResult
                  , interactionReceipt = receipt
                  }
                updatedStored = stored {storedInteraction = Just interaction}
                prior = adapterEffects state
                effects = prior
                  { uiInferenceDispatches = uiInferenceDispatches prior + 1
                  , uiArtifactReads = uiArtifactReads prior + 1
                  , uiResultWrites = uiResultWrites prior + 1
                  }
                next = state
                  { adapterProjection = projection
                  , adapterWorkflows = Map.insert command updatedStored (adapterWorkflows state)
                  , adapterEffects = effects
                  , adapterNextCursor = adapterNextCursor state + 1
                  }
            Right (interaction, next)
 where
  owner = readyArtifactOwner handle
  command = readyArtifactCommandId handle
#ifdef INFERNIX_UI_LIFT_TRUST_CLIENT_ARTIFACT_SCOPE_MUTANT
  authorizationTenant = claimedTenant claim
  authorizationSubject = claimedSubject claim
#else
  authorizationTenant = contextTenant context
  authorizationSubject = contextSubject context
  _ignoredClientClaim = claim
#endif

lookupDurableReceipt :: OwnerCoordinate -> Text -> UiAdapterState -> Maybe DurableReceipt
lookupDurableReceipt owner command state =
  Amoebius.Ui.Projection.Worker.lookupReceipt (adapterProjection state) (ReceiptKey owner command)

escapePresentation :: Text -> Text
escapePresentation =
  Text.replace "'" "&#39;"
    . Text.replace "\"" "&quot;"
    . Text.replace ">" "&gt;"
    . Text.replace "<" "&lt;"
    . Text.replace "&" "&amp;"

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
    { uiEventProjection = ProjectionKey owner "infernix.workflow"
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
  [app, contextTenant context, contextSubject context, "infernix.start", requestIdText request])

inputDigest :: Text -> Text
inputDigest = ("sha256:" <>) . sha256Text . normalizeInput

normalizeInput :: Text -> Text
normalizeInput = Text.unwords . Text.words

opaqueToken :: OwnerCoordinate -> Text -> ReadyArtifactHandle -> Text
opaqueToken owner command handle = "artifact:" <> sha256Text (Text.intercalate "\NUL"
  [ ownerAppId owner
  , ownerTenantId owner
  , ownerSubject owner
  , command
  , readyArtifactBlobDigest handle
  , readyArtifactManifestDigest handle
  , readyArtifactPointerKey handle
  ])

sha256Text :: Text -> Text
sha256Text = hex . SHA256.hash . TextEncoding.encodeUtf8

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap twoHex . ByteString.unpack
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

terminalCommandId :: Text -> Text
#ifdef INFERNIX_UI_LIFT_DROP_COMMAND_ID_FROM_TERMINAL_MUTANT
terminalCommandId _ = "unrelated-command"
#else
terminalCommandId = id
#endif

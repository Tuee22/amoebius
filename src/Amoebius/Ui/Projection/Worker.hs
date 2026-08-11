{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Projection.Worker
  ( ProjectionMutation (..)
  , UiProjectionEvent (..)
  , ProjectionRow (..)
  , ProjectionState
  , emptyProjectionState
  , ApplyResult (..)
  , applyProjectionEvent
  , lookupProjection
  , lookupReceipt
  , lookupWatermark
  , HandleSeal
  , handleSeal
  , ScopedQueryHandle
  , newScopedQueryHandle
  , queryHandleToken
  , queryHandleProjection
  , queryHandleProgramEpoch
  , queryHandleScopeEpoch
  , QueryDenial (..)
  , queryProjection
  ) where

import Amoebius.Ui.Projection.OwnerKey
import Amoebius.Ui.Projection.ReceiptFold
import Amoebius.Ui.Projection.StreamCursor
import Amoebius.Ui.Projection.Watermark
import Amoebius.Ui.Server.RequestContext
import Codec.Serialise (Serialise)
import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as ByteString
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import GHC.Generics (Generic)
import Numeric (showHex)

data ProjectionMutation = PutValue Text | Tombstone
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data UiProjectionEvent = UiProjectionEvent
  { uiEventProjection :: ProjectionKey
  , uiEventEntity :: Text
  , uiEventMutation :: ProjectionMutation
  , uiEventCursor :: StreamCursor
  , uiEventProgramEpoch :: ProgramEpoch
  , uiEventScopeEpoch :: ScopeEpoch
  , uiEventReceipt :: Maybe ReceiptEvent
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ProjectionRow = ProjectionRow
  { rowProjection :: ProjectionKey
  , rowEntity :: Text
  , rowValue :: Text
  , rowCursor :: StreamCursor
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ProjectionState = ProjectionState
  { stateRows :: Map Text ProjectionRow
  , stateReceipts :: Map Text DurableReceipt
  , stateWatermarks :: Map Text Watermark
  }
  deriving stock (Eq, Show)

emptyProjectionState :: ProjectionState
emptyProjectionState = ProjectionState Map.empty Map.empty Map.empty

data ApplyResult = Applied | RedeliveryNoOp | ReceiptConflict ReceiptFoldError
  deriving stock (Eq, Show)

applyProjectionEvent :: ProjectionState -> UiProjectionEvent -> Either CursorError (ProjectionState, ApplyResult)
applyProjectionEvent state event = do
  step <- advanceCursor previous (uiEventCursor event) (uiEventProgramEpoch event) (uiEventScopeEpoch event)
  case foldEventReceipt state event of
    Left conflict -> Right (state, ReceiptConflict conflict)
    Right receipts ->
      let rows = case uiEventMutation event of
            PutValue value -> Map.insert rowKey (ProjectionRow projection entity value (uiEventCursor event)) (stateRows state)
            Tombstone -> Map.delete rowKey (stateRows state)
          watermarks = case step of
            CursorAdvanced -> Map.insert streamKey watermark (stateWatermarks state)
            CursorRedelivery -> stateWatermarks state
          updated = ProjectionState rows receipts watermarks
       in Right (updated, case step of CursorAdvanced -> Applied; CursorRedelivery -> RedeliveryNoOp)
 where
  projection = uiEventProjection event
  entity = uiEventEntity event
  rowKey = projectionMessageKey projection entity
  streamKey = ownerStreamKey projection
  watermark = Watermark (uiEventCursor event) (uiEventProgramEpoch event) (uiEventScopeEpoch event)
  previous = do
    value <- Map.lookup streamKey (stateWatermarks state)
    pure (watermarkCursor value, watermarkProgramEpoch value, watermarkScopeEpoch value)

foldEventReceipt :: ProjectionState -> UiProjectionEvent -> Either ReceiptFoldError (Map Text DurableReceipt)
foldEventReceipt state event = case uiEventReceipt event of
  Nothing -> Right (stateReceipts state)
  Just receiptEvent -> do
    let key = receiptMessageKey (eventReceiptKey receiptEvent)
    folded <- foldReceipt (Map.lookup key (stateReceipts state)) receiptEvent
    pure $ case folded of
      Nothing -> stateReceipts state
      Just receipt -> Map.insert key receipt (stateReceipts state)

lookupProjection :: ProjectionState -> ProjectionKey -> Text -> Maybe ProjectionRow
lookupProjection state key entity = Map.lookup (projectionMessageKey key entity) (stateRows state)

lookupReceipt :: ProjectionState -> ReceiptKey -> Maybe DurableReceipt
lookupReceipt state key = Map.lookup (receiptMessageKey key) (stateReceipts state)

lookupWatermark :: ProjectionState -> ProjectionKey -> Maybe Watermark
lookupWatermark state key = Map.lookup (ownerStreamKey key) (stateWatermarks state)

data ScopedQueryHandle = ScopedQueryHandle
  { queryHandleToken :: Text
  , queryHandleNonce :: Text
  , queryHandleProjection :: ProjectionKey
  , queryHandleProgramEpoch :: ProgramEpoch
  , queryHandleScopeEpoch :: ScopeEpoch
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

newtype HandleSeal = HandleSeal ByteString.ByteString

handleSeal :: Text -> Maybe HandleSeal
handleSeal value
  | Text.length value >= 32 = Just (HandleSeal (Text.encodeUtf8 value))
  | otherwise = Nothing

newScopedQueryHandle :: HandleSeal -> Text -> ProjectionKey -> ProgramEpoch -> ScopeEpoch -> ScopedQueryHandle
newScopedQueryHandle seal nonce projection program scope =
  ScopedQueryHandle
    { queryHandleToken = handleMac seal nonce projection program scope
    , queryHandleNonce = nonce
    , queryHandleProjection = projection
    , queryHandleProgramEpoch = program
    , queryHandleScopeEpoch = scope
    }

data QueryDenial = ResourceUnavailable
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

queryProjection
  :: ServerRequestContext
  -> HandleSeal
  -> ProgramEpoch
  -> ScopeEpoch
  -> ScopedQueryHandle
  -> Text
  -> ProjectionState
  -> Either QueryDenial (Maybe ProjectionRow, Maybe Watermark)
queryProjection context seal program scope handle entity state
  | contextTenant context /= ownerTenantId owner = Left ResourceUnavailable
  | contextSubject context /= ownerSubject owner = Left ResourceUnavailable
  | queryHandleToken handle /= handleMac seal (queryHandleNonce handle) projection (queryHandleProgramEpoch handle) (queryHandleScopeEpoch handle) = Left ResourceUnavailable
  | program /= queryHandleProgramEpoch handle = Left ResourceUnavailable
  | scope /= queryHandleScopeEpoch handle = Left ResourceUnavailable
  | otherwise = Right
      ( lookupProjection state projection entity
      , lookupWatermark state projection
      )
 where
  projection = queryHandleProjection handle
  owner = projectionOwner projection

handleMac :: HandleSeal -> Text -> ProjectionKey -> ProgramEpoch -> ScopeEpoch -> Text
handleMac (HandleSeal key) nonce projection program scope =
  hex (SHA256.hmac key (Text.encodeUtf8 payload))
 where
  owner = projectionOwner projection
  payload = Text.intercalate "|"
    [ nonce
    , ownerAppId owner
    , ownerTenantId owner
    , ownerSubject owner
    , projectionId projection
    , Text.pack (show (unProgramEpoch program))
    , Text.pack (show (unScopeEpoch scope))
    ]

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap twoHex . ByteString.unpack
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

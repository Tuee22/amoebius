{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Projection.OwnerKey
  ( OwnerCoordinate (..)
  , ProjectionKey (..)
  , ReceiptKey (..)
  , projectionMessageKey
  , receiptMessageKey
  , ownerStreamKey
  , subscriptionIdentity
  ) where

import Codec.Serialise (Serialise)
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Generics (Generic)

data OwnerCoordinate = OwnerCoordinate
  { ownerAppId :: Text
  , ownerTenantId :: Text
  , ownerSubject :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Serialise)

data ProjectionKey = ProjectionKey
  { projectionOwner :: OwnerCoordinate
  , projectionId :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Serialise)

data ReceiptKey = ReceiptKey
  { receiptOwner :: OwnerCoordinate
  , receiptCommandId :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Serialise)

projectionMessageKey :: ProjectionKey -> Text -> Text
projectionMessageKey key entityId =
  joinKey
    [ ownerAppId owner
    , ownerTenantId owner
#ifndef PHASE38_DROP_OWNER_KEY_MUTANT
    , ownerSubject owner
#endif
    , projectionId key
    , entityId
    ]
 where
  owner = projectionOwner key

receiptMessageKey :: ReceiptKey -> Text
receiptMessageKey key =
  joinKey
    [ ownerAppId owner
    , ownerTenantId owner
    , ownerSubject owner
#ifdef PHASE38_DROP_RECEIPT_COMMAND_ID_MUTANT
    , "receipt"
#else
    , receiptCommandId key
#endif
    ]
 where
  owner = receiptOwner key

ownerStreamKey :: ProjectionKey -> Text
ownerStreamKey key =
  joinKey
    [ ownerAppId owner
    , ownerTenantId owner
#ifndef PHASE38_DROP_OWNER_SUBSCRIPTION_MUTANT
    , ownerSubject owner
#endif
    , projectionId key
    ]
 where
  owner = projectionOwner key

subscriptionIdentity :: ProjectionKey -> Text
subscriptionIdentity key = "ui-projection/" <> ownerStreamKey key

joinKey :: [Text] -> Text
joinKey = Text.intercalate "/" . map escape
 where
  escape = Text.replace "%" "%25" . Text.replace "/" "%2f"

{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Namespace
  ( NamespacePolicy (..)
  , deduplicationPolicyPath
  , desiredDeduplicationPolicy
  ) where

import Data.Text (Text)

data NamespacePolicy = NamespacePolicy
  { policyTenant :: Text
  , policyNamespace :: Text
  , policyDeduplicationEnabled :: Bool
  }
  deriving stock (Eq, Show)

deduplicationPolicyPath :: NamespacePolicy -> Text
deduplicationPolicyPath policy =
  "/admin/v2/namespaces/" <> policyTenant policy <> "/" <> policyNamespace policy <> "/deduplication"

desiredDeduplicationPolicy :: Text -> Text -> NamespacePolicy
desiredDeduplicationPolicy tenant namespace = NamespacePolicy tenant namespace True

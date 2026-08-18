module Amoebius.Ui.Components
  ( headingFor
  , statusFor
  ) where

import Prelude

headingFor :: String -> String
headingFor route = case route of
  "workflow" -> "Workflow"
  "choose-tenant" -> "Tenant workspace"
  _ -> "Home"

statusFor :: String -> String -> String
statusFor state challenge = case state of
  "pending" -> "Pending: " <> challenge
  "cancelled" -> "Cancelled"
  "ReloadRequired" -> "ReloadRequired"
  _ -> state

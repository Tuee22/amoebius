{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Browser.Interpreter (
    ClientPlan (..), Interaction (..), Event (..), UiState (..), Effect (..),
    TransportPlan (..), Observation (..), interpret, verifyEnvelope,
    renderTrustedText, focusAfter, challengeBody, providerRequestAllowed,
) where

import Data.Text (Text)
import Data.Text qualified as Text

data ClientPlan = ClientPlan { planDigest :: Text, currentDigest :: Text, routes :: [Text], events :: [Event] }
  deriving stock (Eq, Show)
data Event = Edit | Submit | Cancel | OpenDocs | Choose deriving stock (Bounded, Enum, Eq, Show)
data Interaction = Interaction { caseName :: Text, event :: Event, input :: Text } deriving stock (Eq, Show)
data UiState = Editing | Pending | Cancelled | Home | Ready | ReloadRequired deriving stock (Eq, Show)
data Effect = NoEffect | PortRequest Text | Navigate Text deriving stock (Eq, Show)
data TransportPlan = TransportPlan { transportMethod :: Text, transportOrigin :: Text, transportPath :: Text, transportBody :: Text } deriving stock (Eq, Show)
data Observation = Observation { visibleState :: UiState, requestedEffect :: Effect, route :: Text, atomicWrites :: Int } deriving stock (Eq, Show)

verifyEnvelope :: ClientPlan -> Either Text ()
#ifdef UI_BROWSER_ACCEPT_STALE_PLAN_MUTANT
verifyEnvelope _ = Right ()
#else
verifyEnvelope plan | planDigest plan == currentDigest plan = Right (); verifyEnvelope _ = Left "ReloadRequired"
#endif

interpret :: ClientPlan -> Interaction -> Either Text Observation
interpret plan selected = do
  verifyEnvelope plan
  if event selected `elem` events plan then Right (step (event selected)) else Left "UnknownEvent"
 where
  step Edit = Observation Editing NoEffect "home" sequentialWrites
  step Submit = Observation Pending submitEffect submitRoute 1
  step Cancel = Observation Cancelled (PortRequest "cancel") "workflow" 1
  step OpenDocs = Observation Home (Navigate "docs") "home" 1
  step Choose = Observation Ready (PortRequest "scope") "home" 1
#ifdef UI_BROWSER_DROP_EVENT_EFFECT_MUTANT
  submitEffect = NoEffect
#else
  submitEffect = PortRequest "submit"
#endif
#ifdef UI_BROWSER_SWAP_ROUTE_TARGET_MUTANT
  submitRoute = "home"
#else
  submitRoute = "workflow"
#endif
#ifdef UI_BROWSER_SEQUENTIAL_WRITES_MUTANT
  sequentialWrites = 2
#else
  sequentialWrites = 1
#endif

renderTrustedText :: Text -> Text
#ifdef UI_BROWSER_RAW_HTML_SINK_MUTANT
renderTrustedText = id
#else
renderTrustedText = Text.replace ">" "&gt;" . Text.replace "<" "&lt;" . Text.replace "&" "&amp;"
#endif

focusAfter :: Text -> Text -> Text
#ifdef UI_BROWSER_BREAK_FOCUS_RETURN_MUTANT
focusAfter "Escape" _ = "document-body"
#else
focusAfter "Escape" opener = opener
#endif
focusAfter "route" _ = "new-route-h1"
focusAfter _ _ = "modal-first-control"

challengeBody :: Text -> Text
#ifdef UI_BROWSER_HARDCODED_RESPONSE_MUTANT
challengeBody _ = "fresh-challenge"
#else
challengeBody nonce = "challenge=" <> nonce
#endif

providerRequestAllowed :: TransportPlan -> Bool
#ifdef UI_BROWSER_DIRECT_PROVIDER_FETCH_MUTANT
providerRequestAllowed request = transportOrigin request == "same-origin" || transportOrigin request == "https://provider.invalid"
#else
providerRequestAllowed request = transportOrigin request == "same-origin"
#endif

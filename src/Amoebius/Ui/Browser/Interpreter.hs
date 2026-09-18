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
verifyEnvelope plan | planDigest plan == currentDigest plan = Right (); verifyEnvelope _ = Left "ReloadRequired"

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
  submitEffect = PortRequest "submit"
  submitRoute = "workflow"
  sequentialWrites = 1

renderTrustedText :: Text -> Text
renderTrustedText = Text.replace ">" "&gt;" . Text.replace "<" "&lt;" . Text.replace "&" "&amp;"

focusAfter :: Text -> Text -> Text
focusAfter "Escape" opener = opener
focusAfter "route" _ = "new-route-h1"
focusAfter _ _ = "modal-first-control"

challengeBody :: Text -> Text
challengeBody nonce = "challenge=" <> nonce

providerRequestAllowed :: TransportPlan -> Bool
providerRequestAllowed request = transportOrigin request == "same-origin"

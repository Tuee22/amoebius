{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Server.WebSocket
  ( RegistrationInput (..)
  , RegistrationError (..)
  , validateRegistration
  ) where

import Amoebius.Ui.Realtime.Envelope (UiRealtimeEnvelope (..), envelopeComplete)
import Amoebius.Ui.Server.RequestContext
  ( ServerRequestContext
  , VerifiedCredential
  , contextTenant
  , credentialEpoch
  , credentialSessionNonce
  )
import Data.Text (Text)

data RegistrationInput = RegistrationInput
  { registrationOrigin :: Text
  , registrationSubprotocol :: Text
  , registrationNonce :: Text
  , registrationProgram :: Text
  , registrationAbi :: Text
  , registrationScope :: Text
  , registrationCoordinatorAvailable :: Bool
  , registrationEnvelope :: UiRealtimeEnvelope
  }
  deriving stock (Eq, Show)

data RegistrationError
  = RegistrationOriginDenied
  | RegistrationSubprotocolDenied
  | RegistrationNonceDenied
  | RegistrationEpochStale
  | RegistrationProgramStale
  | RegistrationAbiMismatch
  | RegistrationScopeMismatch
  | RegistrationEnvelopeIncomplete
  | RegistrationCoordinatorUnavailable
  deriving stock (Eq, Show)

validateRegistration
  :: Int
  -> Text
  -> Text
  -> VerifiedCredential
  -> ServerRequestContext
  -> RegistrationInput
  -> Either RegistrationError UiRealtimeEnvelope
validateRegistration currentEpoch currentProgram currentAbi credential context registration
  | registrationOrigin registration /= "same-origin" = Left RegistrationOriginDenied
  | registrationSubprotocol registration /= "amoebius-ui-v1" = Left RegistrationSubprotocolDenied
  | registrationNonce registration /= credentialSessionNonce credential = Left RegistrationNonceDenied
  | credentialEpoch credential /= currentEpoch = Left RegistrationEpochStale
  | registrationProgram registration /= currentProgram = Left RegistrationProgramStale
  | registrationAbi registration /= currentAbi = Left RegistrationAbiMismatch
  | registrationScope registration /= contextTenant context = Left RegistrationScopeMismatch
  | not (registrationCoordinatorAvailable registration) = Left RegistrationCoordinatorUnavailable
  | not (envelopeComplete envelope) = Left RegistrationEnvelopeIncomplete
  | envelopeProgram envelope /= currentProgram = Left RegistrationProgramStale
  | envelopeAbi envelope /= currentAbi = Left RegistrationAbiMismatch
  | envelopeScope envelope /= contextTenant context = Left RegistrationScopeMismatch
  | otherwise = Right envelope
  where
    envelope = registrationEnvelope registration

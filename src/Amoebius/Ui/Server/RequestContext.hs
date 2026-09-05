{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Server.RequestContext
  ( SigningKey
  , VerifiedCredential
  , ServerRequestContext
  , CredentialError (..)
  , signingKey
  , verifyCredential
  , signCredential
  , credentialSubject
  , credentialTenant
  , credentialPermission
  , credentialGrant
  , credentialEpoch
  , credentialSessionNonce
  , serverRequestContext
  , contextSubject
  , contextTenant
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as ByteString
import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Numeric (showHex)
import Text.Read (readMaybe)

newtype SigningKey = SigningKey ByteString.ByteString

data VerifiedCredential = VerifiedCredential
  { credentialSubject :: Text
  , credentialTenant :: Text
  , credentialPermission :: Text
  , credentialGrant :: Text
  , credentialEpoch :: Int
  , credentialSessionNonce :: Text
  }
  deriving stock (Eq, Show)

data ServerRequestContext = ServerRequestContext
  { contextSubject :: Text
  , contextTenant :: Text
  }
  deriving stock (Eq, Show)

data CredentialError
  = InvalidSigningKey
  | MalformedCredential
  | InvalidCredentialSignature
  | InvalidCredentialClaim Text
  deriving stock (Eq, Show)

signingKey :: Text -> Either CredentialError SigningKey
signingKey value
  | Text.length value >= 32 && Text.all validKeyCharacter value = Right (SigningKey (Text.encodeUtf8 value))
  | otherwise = Left InvalidSigningKey

verifyCredential :: SigningKey -> Text -> Either CredentialError VerifiedCredential
verifyCredential (SigningKey key) token = do
  (claims, signature) <- case Text.breakOnEnd "." token of
    (prefix, suffix)
      | not (Text.null prefix) && not (Text.null suffix) -> Right (Text.dropEnd 1 prefix, suffix)
    _ -> Left MalformedCredential
  let expected = hex (SHA256.hmac key (Text.encodeUtf8 claims))
  if signature /= expected
    then Left InvalidCredentialSignature
    else parseClaims claims

signCredential :: SigningKey -> Text -> Text -> Text -> Text -> Int -> Text -> Text
signCredential (SigningKey key) subject tenant permission grant epoch nonce =
  claims <> "." <> hex (SHA256.hmac key (Text.encodeUtf8 claims))
 where
  claims = Text.intercalate "|" [subject, tenant, permission, grant, Text.pack (show epoch), nonce]

serverRequestContext :: VerifiedCredential -> ServerRequestContext
serverRequestContext credential = ServerRequestContext
  { contextSubject = credentialSubject credential
  , contextTenant = credentialTenant credential
  }

parseClaims :: Text -> Either CredentialError VerifiedCredential
parseClaims claims = case Text.splitOn "|" claims of
  [subject, tenant, permission, grant, epochText, nonce] -> do
    require "subject" subject
    require "tenant" tenant
    requireOneOf "permission" ["read", "write"] permission
    requireOneOf "grant" ["active", "revoked"] grant
    require "session-nonce" nonce
    epoch <- maybe (Left (InvalidCredentialClaim "epoch")) Right (readMaybe (Text.unpack epochText))
    if epoch < 0
      then Left (InvalidCredentialClaim "epoch")
      else Right VerifiedCredential
        { credentialSubject = subject
        , credentialTenant = tenant
        , credentialPermission = permission
        , credentialGrant = grant
        , credentialEpoch = epoch
        , credentialSessionNonce = nonce
        }
  _ -> Left MalformedCredential

require :: Text -> Text -> Either CredentialError ()
require label value
  | not (Text.null value) && Text.all validClaimCharacter value = Right ()
  | otherwise = Left (InvalidCredentialClaim label)

requireOneOf :: Text -> [Text] -> Text -> Either CredentialError ()
requireOneOf label allowed value
  | value `elem` allowed = Right ()
  | otherwise = Left (InvalidCredentialClaim label)

validKeyCharacter :: Char -> Bool
validKeyCharacter character = isAlphaNum character || character `elem` ['-', '_', '.', ':']

validClaimCharacter :: Char -> Bool
validClaimCharacter character = validKeyCharacter character

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap twoHex . ByteString.unpack
  where
    twoHex byte = case showHex byte "" of
      [digit] -> ['0', digit]
      digits -> digits

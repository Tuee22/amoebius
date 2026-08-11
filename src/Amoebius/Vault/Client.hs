{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Vault.Client
  ( KubernetesIdentity (..)
  , VaultToken (..)
  , VaultTransport (..)
  , resolveSecret
  , HttpVaultAddress (..)
  , mkHttpVaultTransport
  , runVaultReadCommand
  , runVaultTransitCommand
  ) where

import Amoebius.Vault.Error
import Amoebius.Vault.SecretRef
import Control.Exception (IOException, try)
import Data.Aeson (Value (..), eitherDecodeStrict', encode, object, withObject, (.:), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Char8 qualified as ByteString8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Network.Socket
import Network.Socket.ByteString (recv, sendAll)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

data KubernetesIdentity = KubernetesIdentity
  { identityNamespace :: Text
  , identityServiceAccount :: Text
  , identityVaultRole :: Text
  }
  deriving stock (Eq, Show)

newtype VaultToken = VaultToken {unVaultToken :: ByteString}
  deriving stock (Eq, Show)

data VaultTransport m = VaultTransport
  { authenticateKubernetes :: KubernetesIdentity -> ByteString -> m (Either VaultError VaultToken)
  , readKvField :: VaultToken -> Text -> Text -> Text -> m (Either VaultError ByteString)
  , decryptTransit :: VaultToken -> Text -> ByteString -> m (Either VaultError ByteString)
  }

resolveSecret
  :: Monad m
  => VaultTransport m
  -> KubernetesIdentity
  -> ByteString
  -> SecretRef
  -> Maybe ByteString
  -> m (Either VaultError ByteString)
resolveSecret transport identity jwt reference ciphertext = do
#ifdef PHASE29_PREMINTED_TOKEN_MUTANT
  let authenticated = Right (VaultToken "login-token")
#else
  authenticated <- authenticateKubernetes transport identity jwt
#endif
  case authenticated of
    Left failure -> pure (Left failure)
    Right token ->
      foldSecretRef
        (readKvField transport token)
        (\key -> case ciphertext of
          Nothing -> pure (Left VaultDecryptDenied)
          Just encrypted -> decryptTransit transport token key encrypted)
        reference

data HttpVaultAddress = HttpVaultAddress
  { vaultHost :: String
  , vaultPort :: String
  }
  deriving stock (Eq, Show)

mkHttpVaultTransport :: HttpVaultAddress -> VaultTransport IO
mkHttpVaultTransport address =
  VaultTransport
    { authenticateKubernetes = httpLogin address
    , readKvField = httpReadKv address
    , decryptTransit = httpDecryptTransit address
    }

httpLogin :: HttpVaultAddress -> KubernetesIdentity -> ByteString -> IO (Either VaultError VaultToken)
httpLogin address identity jwt = do
  let body = LazyByteString.toStrict (encode (object ["role" .= identityVaultRole identity, "jwt" .= TextEncoding.decodeUtf8 jwt]))
  response <- httpJson address "POST" "/v1/auth/kubernetes/login" Nothing body
  pure $ do
    (status, payload) <- response
    if status == 200
      then VaultToken <$> parseJson payload parseClientToken
      else Left (loginFailure status payload)

httpReadKv :: HttpVaultAddress -> VaultToken -> Text -> Text -> Text -> IO (Either VaultError ByteString)
httpReadKv address token mount path field = do
  let requestPath = "/v1/" <> TextEncoding.encodeUtf8 mount <> "/data/" <> TextEncoding.encodeUtf8 path
  response <- httpJson address "GET" requestPath (Just token) ByteString.empty
  pure $ do
    (status, payload) <- response
    if status == 200
      then parseJson payload (parseKvField field)
      else Left (readFailure status payload)

httpDecryptTransit :: HttpVaultAddress -> VaultToken -> Text -> ByteString -> IO (Either VaultError ByteString)
httpDecryptTransit address token key ciphertext = do
  let requestPath = "/v1/transit/decrypt/" <> TextEncoding.encodeUtf8 key
      body = LazyByteString.toStrict (encode (object ["ciphertext" .= TextEncoding.decodeUtf8 ciphertext]))
  response <- httpJson address "POST" requestPath (Just token) body
  pure $ do
    (status, payload) <- response
    if status == 200
      then do
        encoded <- parseJson payload parseTransitPlaintext
        either (const (Left VaultDecryptDenied)) Right (Base64.decode encoded)
      else Left VaultDecryptDenied

parseJson :: ByteString -> (Value -> Parser value) -> Either VaultError value
parseJson payload parser = do
  value <- either (const (Left VaultUnavailable)) Right (eitherDecodeStrict' payload)
  either (const (Left VaultSecretMissing)) Right (parseEither parser value)

parseClientToken :: Value -> Parser ByteString
parseClientToken = withObject "login" $ \root -> do
  auth <- root .: "auth"
  withObject "auth" (\fields -> TextEncoding.encodeUtf8 <$> fields .: "client_token") auth

parseKvField :: Text -> Value -> Parser ByteString
parseKvField field = withObject "kv-response" $ \root -> do
  outerData <- root .: "data"
  withObject "kv-data" (\outer -> do
    innerData <- outer .: "data"
    withObject "kv-fields" (\fields -> case KeyMap.lookup (Key.fromText field) fields of
      Just (String value) -> pure (TextEncoding.encodeUtf8 value)
      _ -> fail "secret-field-missing") innerData) outerData

parseTransitPlaintext :: Value -> Parser ByteString
parseTransitPlaintext = withObject "transit-response" $ \root -> do
  body <- root .: "data"
  withObject "transit-data" (\fields -> TextEncoding.encodeUtf8 <$> fields .: "plaintext") body

loginFailure :: Int -> ByteString -> VaultError
loginFailure status payload
  | status == 503 && "not initialized" `ByteString.isInfixOf` payload = VaultUninitialized
  | status == 503 = VaultSealed
  | status == 400 || status == 403 = VaultPolicyMissing
  | otherwise = VaultUnavailable

readFailure :: Int -> ByteString -> VaultError
readFailure status payload
  | status == 503 && "not initialized" `ByteString.isInfixOf` payload = VaultUninitialized
  | status == 503 = VaultSealed
  | status == 403 = VaultPolicyMissing
  | status == 404 = VaultSecretMissing
  | otherwise = VaultUnavailable

httpJson
  :: HttpVaultAddress
  -> ByteString
  -> ByteString
  -> Maybe VaultToken
  -> ByteString
  -> IO (Either VaultError (Int, ByteString))
httpJson address method path token body = do
  attempted <- try (requestBytes address method path token body) :: IO (Either IOException ByteString)
  pure $ case attempted of
    Left _ -> Left VaultUnavailable
    Right response -> parseHttpResponse response

requestBytes :: HttpVaultAddress -> ByteString -> ByteString -> Maybe VaultToken -> ByteString -> IO ByteString
requestBytes address method path token body = do
  candidates <- getAddrInfo (Just defaultHints {addrSocketType = Stream}) (Just (vaultHost address)) (Just (vaultPort address))
  case candidates of
    [] -> fail "vault-address-unresolved"
    candidate : _ -> do
      socketHandle <- socket (addrFamily candidate) (addrSocketType candidate) (addrProtocol candidate)
      connect socketHandle (addrAddress candidate)
      let tokenHeader = case token of
            Nothing -> ByteString.empty
            Just (VaultToken value) -> "X-Vault-Token: " <> value <> "\r\n"
          request =
            method <> " " <> path <> " HTTP/1.1\r\n"
              <> "Host: " <> ByteString8.pack (vaultHost address) <> "\r\n"
              <> "Accept: application/json\r\nContent-Type: application/json\r\nConnection: close\r\n"
              <> tokenHeader
              <> "Content-Length: " <> ByteString8.pack (show (ByteString.length body)) <> "\r\n\r\n"
              <> body
      sendAll socketHandle request
      response <- receiveAll socketHandle
      close socketHandle
      pure response

receiveAll :: Socket -> IO ByteString
receiveAll socketHandle = go []
 where
  go chunks = do
    chunk <- recv socketHandle 65536
    if ByteString.null chunk
      then pure (ByteString.concat (reverse chunks))
      else go (chunk : chunks)

parseHttpResponse :: ByteString -> Either VaultError (Int, ByteString)
parseHttpResponse response = do
  let (headers, bodyWithSeparator) = ByteString8.breakSubstring "\r\n\r\n" response
      body = ByteString.drop 4 bodyWithSeparator
      statusLine = headOrEmpty (ByteString8.lines headers)
      statusWords = ByteString8.words statusLine
  status <- case drop 1 statusWords of
    value : _ -> maybe (Left VaultUnavailable) Right (readInt value)
    [] -> Left VaultUnavailable
  pure (status, body)

headOrEmpty :: [ByteString] -> ByteString
headOrEmpty values = case values of
  [] -> ByteString.empty
  value : _ -> value

readInt :: ByteString -> Maybe Int
readInt value = case reads (ByteString8.unpack value) of
  [(number, "")] -> Just number
  _ -> Nothing

runVaultReadCommand :: [String] -> IO ()
runVaultReadCommand arguments = case arguments of
  [host, port, role, namespace, serviceAccount, mount, path, field, jwtPath] -> do
    jwt <- ByteString8.strip <$> ByteString.readFile jwtPath
    reference <- either (fail . Text.unpack) pure (vaultSecretRef (Text.pack mount) (Text.pack path) (Text.pack field))
    let identity = KubernetesIdentity (Text.pack namespace) (Text.pack serviceAccount) (Text.pack role)
    result <- resolveSecret (mkHttpVaultTransport (HttpVaultAddress host port)) identity jwt reference Nothing
    case result of
      Left failure -> hPutStrLn stderr (Text.unpack (redactedErrorLog failure)) >> exitFailure
      Right value -> ByteString8.putStrLn value
  _ -> fail "usage: vault-read HOST PORT ROLE NAMESPACE SERVICEACCOUNT MOUNT PATH FIELD JWT_PATH"

runVaultTransitCommand :: [String] -> IO ()
runVaultTransitCommand arguments = case arguments of
  [host, port, role, namespace, serviceAccount, key, ciphertext, jwtPath] -> do
    jwt <- ByteString8.strip <$> ByteString.readFile jwtPath
    reference <- either (fail . Text.unpack) pure (transitKeyRef (Text.pack key))
    let identity = KubernetesIdentity (Text.pack namespace) (Text.pack serviceAccount) (Text.pack role)
    result <- resolveSecret (mkHttpVaultTransport (HttpVaultAddress host port)) identity jwt reference (Just (ByteString8.pack ciphertext))
    case result of
      Left failure -> hPutStrLn stderr (Text.unpack (redactedErrorLog failure)) >> exitFailure
      Right value -> ByteString8.putStrLn value
  _ -> fail "usage: vault-transit-decrypt HOST PORT ROLE NAMESPACE SERVICEACCOUNT KEY CIPHERTEXT JWT_PATH"

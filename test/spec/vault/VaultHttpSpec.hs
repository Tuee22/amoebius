{-# LANGUAGE OverloadedStrings #-}

module VaultHttpSpec (verifyVaultHttpBoundary) where

import Amoebius.Vault.Client
import Control.Concurrent (forkFinally, killThread)
import Control.Exception (bracket, finally)
import Control.Monad (forever, unless)
import Crypto.Random (getRandomBytes)
import Data.Aeson (Value (..), eitherDecodeStrict', encode, object, (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as Bytes
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Char8 qualified as Char8
import Data.ByteString.Lazy qualified as Lazy
import Data.IORef
import Data.Text.Encoding qualified as TextEncoding
import Network.Socket
import Network.Socket.ByteString (recv, sendAll)
import System.Timeout (timeout)

-- A register-2 HTTP peer implements Vault's documented KV-v2 wire contract.
-- It denies secret-value reads and metadata writes while allowing the writer
-- and presence-only operations. The separate live gate uses the real Vault.
verifyVaultHttpBoundary :: IO ()
verifyVaultHttpBoundary = do
  result <- timeout 30000000 verifyBoundary
  unless (result == Just ()) (fail "Vault HTTP boundary timed out")

verifyBoundary :: IO ()
verifyBoundary = bracket (socket AF_INET Stream defaultProtocol) close $ \listener -> do
  bind listener (SockAddrInet 0 (tupleToHostAddress (127, 0, 0, 1)))
  listen listener 8
  address <- getSocketName listener
  port <- case address of
    SockAddrInet value _ -> pure (show value)
    _ -> fail "expected loopback HTTP listener"
  stored <- newIORef Nothing
  racing <- newIORef False
  requests <- newIORef []
  let respond connection = do
        (method, path, headers, body) <- request connection
        modifyIORef' requests ((method, path) :)
        let json = either (const Null) id (eitherDecodeStrict' body)
            fields = case json of
              Object root -> case KeyMap.lookup "data" root of
                Just (Object values) -> values
                _ -> KeyMap.empty
              _ -> KeyMap.empty
        current <- readIORef stored
        (status, payload) <- case (method, path) of
          ("PATCH", "/v1/secret/data/canary") -> do
            unless (lookup "Content-Type" headers == Just "application/merge-patch+json") (fail "merge-patch media type absent")
            case current of
              Nothing -> pure (404, object ["errors" .= (["not found"] :: [String])])
              Just prior -> writeIORef stored (Just (fields `KeyMap.union` prior)) >> pure (200, object ["data" .= object ["version" .= (2 :: Int)]])
          ("POST", "/v1/secret/data/canary") -> do
            let correctCas = case json of
                  Object root -> KeyMap.lookup "options" root == Just (object ["cas" .= (0 :: Int)])
                  _ -> False
            unless correctCas (fail "initial field write lacks CAS=0")
            race <- readIORef racing
            if race
              then do
                writeIORef racing False
                writeIORef stored (Just (KeyMap.singleton "peer" (String "retained")))
                pure (400, object ["errors" .= (["check-and-set mismatch"] :: [String])])
              else case current of
                Just _ -> pure (400, object ["errors" .= (["check-and-set mismatch"] :: [String])])
                Nothing -> writeIORef stored (Just fields) >> pure (200, object ["data" .= object ["version" .= (1 :: Int)]])
          ("GET", "/v1/secret/subkeys/canary?depth=1") -> pure $ case current of
            Nothing -> (404, object ["errors" .= (["not found"] :: [String])])
            Just values -> (200, object ["data" .= object ["subkeys" .= Object (fmap (const Null) values)]])
          -- This forged, stale custom metadata must never establish presence.
          ("GET", "/v1/secret/metadata/canary") -> pure (200, object ["data" .= object ["custom_metadata" .= object ["amoebius-fields" .= ("ghost,a,b" :: String)]]])
          _ -> pure (403, object ["errors" .= (["permission denied"] :: [String])])
        let encoded = Lazy.toStrict (encode payload)
        sendAll connection ("HTTP/1.1 " <> Char8.pack (show (status :: Int)) <> " result\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: " <> Char8.pack (show (Bytes.length encoded)) <> "\r\n\r\n" <> encoded)
      serve = forever (bracket (fst <$> accept listener) close respond)
  worker <- forkFinally serve (const (pure ()))
  (do
      let transport = mkHttpVaultTransport (HttpVaultAddress "127.0.0.1" port)
          writer = VaultToken "scoped-write-token"
          presence = VaultToken "scoped-presence-token"
      -- The unpredictable value is issued after the HTTP subject has started.
      challenge <- Base64.encode <$> (getRandomBytes 24 :: IO Bytes.ByteString)
      expect "write-only field creation requires no metadata permission" (Right ()) =<< writeKvField transport writer "secret" "canary" "alpha" challenge
      expect "field update preserves sibling data" (Right ()) =<< writeKvField transport writer "secret" "canary" "beta" "second"
      actual <- readIORef stored
      expect "original field survives a later field write" (Just (String (TextEncoding.decodeUtf8 challenge))) (actual >>= KeyMap.lookup "alpha")
      expect "presence uses authoritative value-free subkeys" (Right True) =<< kvFieldExists transport presence "secret" "canary" "alpha"
      expect "custom metadata cannot fabricate a field" (Right False) =<< kvFieldExists transport presence "secret" "canary" "ghost"
      expect "comma-containing field write" (Right ()) =<< writeKvField transport writer "secret" "canary" "a,b" "third"
      expect "field names are exact" (Right True) =<< kvFieldExists transport presence "secret" "canary" "a,b"
      expect "comma does not manufacture another field" (Right False) =<< kvFieldExists transport presence "secret" "canary" "a"
      writeIORef stored Nothing
      expect "deleted secret cannot survive through metadata" (Right False) =<< kvFieldExists transport presence "secret" "canary" "alpha"
      writeIORef racing True
      expect "concurrent creation is retried without overwrite" (Right ()) =<< writeKvField transport writer "secret" "canary" "after-race" challenge
      raced <- readIORef stored
      expect "concurrent creator's field survives" (Just (String "retained")) (raced >>= KeyMap.lookup "peer")
      observed <- readIORef requests
      unless (all (\(method, path) -> not ("/metadata/" `Bytes.isInfixOf` path) && not (method == "GET" && "/data/" `Bytes.isInfixOf` path)) observed)
        (fail "presence/write transport read a secret value or used custom metadata")
    ) `finally` killThread worker

expect :: Eq value => String -> value -> value -> IO ()
expect label expected actual = unless (expected == actual) (fail label)

request :: Socket -> IO (Bytes.ByteString, Bytes.ByteString, [(Bytes.ByteString, Bytes.ByteString)], Bytes.ByteString)
request connection = do
  bytes <- headers Bytes.empty
  let (prefix, suffix) = Bytes.breakSubstring "\r\n\r\n" bytes
      rows = Char8.lines prefix
  (method, path) <- case rows of
    first : _ -> case Char8.words first of
      [verb, target, _protocol] -> pure (verb, target)
      _ -> fail "malformed test HTTP request"
    [] -> fail "empty test HTTP request"
  let fields = [(key, Char8.dropWhile (== ' ') (Char8.filter (/= '\r') (Bytes.drop 1 value)))
               | row <- drop 1 rows, let (key, value) = Char8.break (== ':') row]
  count <- case lookup "Content-Length" fields of
    Just value -> case reads (Char8.unpack value) of
      [(size, "")] | size >= 0 && size <= 8192 -> pure size
      _ -> fail "invalid test HTTP content length"
    Nothing -> fail "test HTTP content length absent"
  body <- readBody count (Bytes.drop 4 suffix)
  pure (method, path, fields, body)
 where
  headers buffer
    | Bytes.length buffer > 16384 = fail "test HTTP headers exceed bound"
    | "\r\n\r\n" `Bytes.isInfixOf` buffer = pure buffer
    | otherwise = do
        chunk <- recv connection 4096
        if Bytes.null chunk then fail "incomplete test HTTP headers" else headers (buffer <> chunk)
  readBody expected buffer
    | Bytes.length buffer >= expected = pure (Bytes.take expected buffer)
    | otherwise = do
        chunk <- recv connection (expected - Bytes.length buffer)
        if Bytes.null chunk then fail "incomplete test HTTP body" else readBody expected (buffer <> chunk)

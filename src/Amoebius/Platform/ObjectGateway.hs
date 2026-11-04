{-# LANGUAGE OverloadedStrings #-}

-- | The bounded application-writer arm. Registry and offloader adapters must
-- use their own admitted arms before this can be the sole platform gateway.
module Amoebius.Platform.ObjectGateway (serveApplication) where

import Amoebius.Platform.ObjectGatewayPolicy
import Amoebius.Vault.Client
import Control.Monad (unless)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import Data.Text.Encoding qualified as Text
import System.IO
import Text.Read (readMaybe)

serveApplication :: VaultTransport IO -> (BS.ByteString -> IO ()) -> IO BS.ByteString -> Handle -> IO ()
serveApplication transport store retrieve stream = do
  line <- limitedLine stream
  headers <- readHeaders stream 0
  case B.words line of
    ["GET", "/ready", "HTTP/1.1"] -> reply stream 200 "ready"
    [method, path, "HTTP/1.1"] | method `elem` ["GET", "PUT"] -> do
      let authorized = lookup "authorization" headers >>= BS.stripPrefix "Bearer "
      case authorized of
        Nothing -> reply stream 401 "writer-identity-required"
        Just jwt -> do
          admitted <- authenticateKubernetes transport
            (KubernetesIdentity "platform-system" "phase30-object-writer" "amoebius-phase30-object-writer") jwt
          case admitted of
            Left _ -> reply stream 401 "writer-identity-denied"
            Right _ | path /= allowedPath -> reply stream 403 "writer-scope-denied"
            Right _ | method == "PUT" -> do
              let size = lookup "content-length" headers >>= readMaybe . B.unpack
              if size /= Just objectBytes || lookup "transfer-encoding" headers /= Nothing
                then reply stream 413 "writer-extent-denied"
                else do
                  payload <- BS.hGet stream objectBytes
                  unless (BS.length payload == objectBytes) (fail "writer-body-truncated")
                  store payload
                  reply stream 200 "stored"
            Right _ -> retrieve >>= reply stream 200
    _ -> reply stream 400 "writer-request-invalid"
 where
  objectBytes = fromIntegral (applicationGatewayObjectBytes standardApplicationGateway) :: Int
  allowedPath = Text.encodeUtf8 ("/" <> applicationGatewayBucket standardApplicationGateway <> "/"
    <> applicationGatewayKey standardApplicationGateway)

reply :: Handle -> Int -> BS.ByteString -> IO ()
reply stream status body = do
  BS.hPut stream ("HTTP/1.1 " <> B.pack (show status) <> " Response\r\nConnection: close\r\nContent-Type: application/octet-stream\r\nContent-Length: "
    <> B.pack (show (BS.length body)) <> "\r\n\r\n" <> body)
  hFlush stream

limitedLine :: Handle -> IO BS.ByteString
limitedLine stream = loop [] 0
 where
  loop bytes count
    | count >= (8192 :: Int) = fail "writer-header-too-long"
    | otherwise = do
        byte <- BS.hGet stream 1
        if byte == "\n" then pure (B.strip (BS.concat (reverse bytes)))
        else if BS.null byte then fail "writer-header-truncated"
        else loop (byte : bytes) (count + 1)

readHeaders :: Handle -> Int -> IO [(BS.ByteString, BS.ByteString)]
readHeaders stream count = do
  unless (count < 32) (fail "writer-header-count")
  line <- limitedLine stream
  if BS.null line then pure [] else do
    let (name, raw) = B.break (== ':') line
    unless (not (BS.null name) && not (BS.null raw)) (fail "writer-header-invalid")
    rest <- readHeaders stream (count + 1)
    let key = B.map (\c -> if c >= 'A' && c <= 'Z' then toEnum (fromEnum c + 32) else c) name
    unless (lookup key rest == Nothing) (fail "writer-header-duplicate")
    pure ((key, B.strip (BS.drop 1 raw)) : rest)

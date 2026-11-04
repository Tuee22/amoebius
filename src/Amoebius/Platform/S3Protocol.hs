{-# LANGUAGE OverloadedStrings #-}

-- | The finite, unversioned DeleteObjects request grammar used by Distribution.
-- Reject other XML forms before forwarding, so the backend cannot interpret a
-- second key that escaped scope validation through namespaces or entities.
module Amoebius.Platform.S3Protocol
  (deleteObjectKeys, validateHeaderFields, publicResponseHeaders, publicErrorCode) where

import Control.Monad (unless)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import Data.Text (Text)
import Data.Text.Encoding qualified as Text

-- The bounded reader supplies normalized header names. User metadata is part
-- of the S3 object protocol: Pulsar checks its offloader format version on
-- reads. Keep it while rebuilding framing and excluding backend authority.
publicResponseHeaders :: [(BS.ByteString,BS.ByteString)] -> [(BS.ByteString,BS.ByteString)]
publicResponseHeaders = filter (\(name,_) -> "x-amz-meta-" `BS.isPrefixOf` name || name `elem`
  ["etag","content-type","last-modified","content-range","accept-ranges","x-amz-request-id"])

-- Backend codes identify protocol errors, including XAmzContentSHA256Mismatch.
-- Keep their digits while withholding free-form messages and unsafe markup.
publicErrorCode :: Maybe BS.ByteString -> BS.ByteString
publicErrorCode (Just code)
  | not (BS.null code) && BS.length code <= 64
    && B.all (\c -> c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9') code = code
publicErrorCode _ = "BackendError"

-- HTTP permits repeated Vary response fields. Framing and request authority
-- fields remain unambiguous; the proxy never forwards Vary downstream.
validateHeaderFields :: Bool -> [(BS.ByteString, BS.ByteString)] -> Either String ()
validateHeaderFields response = go []
 where
  go _ [] = Right ()
  go found ((name, _) : rest) = do
    unless (name `notElem` found || response && name == "vary")
      (Left (if response then "gateway-response-header-duplicate:" <> B.unpack name else "gateway-header-duplicate"))
    go (name : found) rest

deleteObjectKeys :: BS.ByteString -> Either String [Text]
deleteObjectKeys encoded = do
  unless (BS.length encoded <= 65536) (Left "gateway-delete-body-bound-exceeded")
  let trimmed = space encoded
      noDeclaration = maybe trimmed space (BS.stripPrefix "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" trimmed)
  body <- case BS.stripPrefix "<Delete xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">" noDeclaration of
    Just remainder -> Right remainder
    Nothing -> required "<Delete>" noDeclaration
  keys <- children [] False (space body)
  unless (not (null keys) && length keys <= 16) (Left "gateway-delete-grammar-denied")
  pure (reverse keys)
 where
  -- AWS Go SDK builds child elements from a map without sorting. Quiet can
  -- therefore precede or follow Object. Parse only the closed child grammar,
  -- with one optional boolean and all object keys independently scoped.
  children found quietSeen bytes
    | Just remainder <- BS.stripPrefix "<Object>" (space bytes) = do
      unless (length found < 16) (Left "gateway-delete-count-denied")
      value <- required "<Key>" (space remainder)
      let (key, tailBytes) = B.break (== '<') value
      unless (not (BS.null key) && BS.length key <= 512 && B.all allowed key) (Left "gateway-delete-key-denied")
      afterKey <- required "</Key>" tailBytes
      afterObject <- required "</Object>" (space afterKey)
      children (Text.decodeUtf8 key : found) quietSeen (space afterObject)
    | Just remainder <- BS.stripPrefix "<Quiet>" (space bytes) = do
      unless (not quietSeen) (Left "gateway-delete-grammar-denied")
      afterQuiet <- case BS.stripPrefix "false</Quiet>" remainder of
        Just rest -> Right rest
        Nothing -> required "true</Quiet>" remainder
      children found True (space afterQuiet)
    | otherwise = do
      end <- required "</Delete>" (space bytes)
      unless (BS.null (space end)) (Left "gateway-delete-grammar-denied")
      pure found
  allowed c = c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c `elem` ("/._-" :: String)
  required prefix bytes = maybe (Left "gateway-delete-grammar-denied") Right (BS.stripPrefix prefix bytes)
  space = B.dropWhile (`elem` (" \r\n\t" :: String))

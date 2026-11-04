{-# LANGUAGE OverloadedStrings #-}

-- | SigV4 mechanics shared by the bounded proxy and its backend connection.
-- Authentication callers obtain keys from Vault; request fields supply no
-- trusted writer identity. Secrets have no Show instance.
module Amoebius.Platform.S3Signing
  ( S3Credentials (..), SigningRequest (..), requestAccessKey
  , verifyS3Signature, signS3Headers, signS3HeadersWith, sha256Hex, decodeUri, canonicalQuery
  , verifyS3ChunkedPayload
  ) where

import Control.Monad (unless)
import Crypto.Hash.SHA256 qualified as SHA
import Data.ByteArray (constEq)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import Data.List (sort, sortOn)
import Data.Time
import Data.Word (Word8)
import Numeric (readHex)
import Numeric.Natural (Natural)
import Text.Read (readMaybe)

data S3Credentials = S3Credentials BS.ByteString BS.ByteString

data SigningRequest = SigningRequest
  { signingMethod :: BS.ByteString, signingTarget :: BS.ByteString
  , signingHeaders :: [(BS.ByteString, BS.ByteString)] }
  deriving stock (Eq, Show)

data Authorization = Authorization BS.ByteString BS.ByteString BS.ByteString
  [BS.ByteString] BS.ByteString Bool Integer

requestAccessKey :: SigningRequest -> Either String BS.ByteString
requestAccessKey request = do
  Authorization access _ _ _ _ _ _ <- authorization request
  pure access

verifyS3Signature :: UTCTime -> S3Credentials -> SigningRequest -> Either String ()
verifyS3Signature now (S3Credentials expectedAccess secret) request = do
  auth@(Authorization access day date signed supplied querySigned expiry) <- authorization request
  unless (access == expectedAccess) (Left "s3-writer-key-denied")
  timestamp <- maybe (Left "s3-signing-date-invalid") Right
    (parseTimeM True defaultTimeLocale "%Y%m%dT%H%M%SZ" (B.unpack date) :: Maybe UTCTime)
  let age = diffUTCTime now timestamp
  unless (age >= -300 && age <= fromInteger (if querySigned then expiry else 900))
    (Left "s3-signature-expired")
  unless (B.take 8 date == day) (Left "s3-signing-scope-date-mismatch")
  canonical <- canonicalRequest request auth
  unless (constEq supplied (signature secret day date canonical)) (Left "s3-signature-denied")
  unless (signed == sort signed && length signed == length (unique signed) && "host" `elem` signed)
    (Left "s3-signed-headers-invalid")

signS3Headers :: UTCTime -> S3Credentials -> BS.ByteString -> BS.ByteString
  -> BS.ByteString -> BS.ByteString -> Either String [(BS.ByteString, BS.ByteString)]
signS3Headers now (S3Credentials access secret) method target host payloadHash = do
  signS3HeadersWith now (S3Credentials access secret) method target host payloadHash []

signS3HeadersWith :: UTCTime -> S3Credentials -> BS.ByteString -> BS.ByteString
  -> BS.ByteString -> BS.ByteString -> [(BS.ByteString, BS.ByteString)]
  -> Either String [(BS.ByteString, BS.ByteString)]
signS3HeadersWith now (S3Credentials access secret) method target host payloadHash extra = do
  let day = B.pack (formatTime defaultTimeLocale "%Y%m%d" now)
      date = B.pack (formatTime defaultTimeLocale "%Y%m%dT%H%M%SZ" now)
      headers = sortOn fst ([("host", host), ("x-amz-content-sha256", payloadHash), ("x-amz-date", date)] <> extra)
      names = fmap fst headers
      request = SigningRequest method target headers
      auth = Authorization access day date names "" False 900
  canonical <- canonicalRequest request auth
  pure (headers <> [("authorization", "AWS4-HMAC-SHA256 Credential=" <> access <> "/" <> day
    <> "/us-east-1/s3/aws4_request, SignedHeaders=" <> B.intercalate ";" names
    <> ", Signature=" <> signature secret day date canonical)])

authorization :: SigningRequest -> Either String Authorization
authorization request = do
  query <- parseQuery (queryPart (signingTarget request))
  case lookup "authorization" (signingHeaders request) of
    Just encoded -> do
      fields <- maybe (Left "s3-authentication-required") Right (BS.stripPrefix "AWS4-HMAC-SHA256 " encoded)
      let pairs = fmap (splitPair . B.strip) (B.split ',' fields)
      credential <- required "Credential" pairs
      signed <- required "SignedHeaders" pairs
      supplied <- required "Signature" pairs
      date <- required "x-amz-date" (signingHeaders request)
      (access, day) <- scope credential
      unless (BS.length supplied == 64 && BS.all lowerHex supplied) (Left "s3-signature-invalid")
      pure (Authorization access day date (B.split ';' signed) supplied False 900)
    Nothing -> do
      algorithm <- required "X-Amz-Algorithm" query
      unless (algorithm == "AWS4-HMAC-SHA256" && signingMethod request `elem` ["GET", "HEAD"])
        (Left "s3-query-authentication-denied")
      (access, day) <- required "X-Amz-Credential" query >>= scope
      date <- required "X-Amz-Date" query
      signed <- required "X-Amz-SignedHeaders" query
      supplied <- required "X-Amz-Signature" query
      expiry <- required "X-Amz-Expires" query >>= maybe (Left "s3-query-expiry-invalid") Right . readMaybe . B.unpack
      unless (expiry > 0 && expiry <= 604800 && BS.length supplied == 64 && BS.all lowerHex supplied)
        (Left "s3-query-expiry-or-signature-invalid")
      pure (Authorization access day date (B.split ';' signed) supplied True expiry)
 where
  scope encoded = case B.split '/' encoded of
    [access, day, "us-east-1", "s3", "aws4_request"] | not (BS.null access) && BS.length day == 8 -> Right (access, day)
    _ -> Left "s3-signing-scope-denied"

canonicalRequest :: SigningRequest -> Authorization -> Either String BS.ByteString
canonicalRequest request (Authorization _ _ _ names _ querySigned _) = do
  let path = B.takeWhile (/= '?') (signingTarget request)
  decoded <- decodeUri path
  unless (not (BS.null path) && BS.head path == 47 && encodeUri True decoded == path)
    (Left "s3-noncanonical-object-path")
  query <- parseQuery (queryPart (signingTarget request))
  values <- traverse (\name -> do
    unless (BS.all (\c -> c >= 97 && c <= 122 || c >= 48 && c <= 57 || c == 45) name)
      (Left "s3-signed-header-name-invalid")
    value <- required name (signingHeaders request)
    pure (name <> ":" <> B.unwords (B.words value) <> "\n")) names
  let bodyHash = maybe (if querySigned then "UNSIGNED-PAYLOAD" else sha256Hex BS.empty) id
        (lookup "x-amz-content-sha256" (signingHeaders request))
      queryFields = if querySigned then filter ((/= "X-Amz-Signature") . fst) query else query
  pure (B.intercalate "\n" [signingMethod request, path, renderQuery queryFields,
    BS.concat values, B.intercalate ";" names, bodyHash])

canonicalQuery :: BS.ByteString -> Either String BS.ByteString
canonicalQuery encoded = renderQuery <$> parseQuery encoded

queryPart :: BS.ByteString -> BS.ByteString
queryPart = BS.drop 1 . B.dropWhile (/= '?')

parseQuery :: BS.ByteString -> Either String [(BS.ByteString, BS.ByteString)]
parseQuery encoded | BS.null encoded = Right []
parseQuery encoded = traverse (\part -> let (key, value) = splitPair part in (,) <$> decodeUri key <*> decodeUri value) (B.split '&' encoded)

renderQuery :: [(BS.ByteString, BS.ByteString)] -> BS.ByteString
renderQuery pairs = B.intercalate "&" [key <> "=" <> value | (key, value) <- sortOn id
  [(encodeUri False key, encodeUri False value) | (key, value) <- pairs]]

splitPair :: BS.ByteString -> (BS.ByteString, BS.ByteString)
splitPair encoded = let (key, value) = B.break (== '=') encoded in (key, BS.drop 1 value)

required :: BS.ByteString -> [(BS.ByteString, BS.ByteString)] -> Either String BS.ByteString
required key fields = case [value | (name, value) <- fields, name == key] of
  [value] -> Right value
  _ -> Left "s3-required-field-missing-or-duplicate"

decodeUri :: BS.ByteString -> Either String BS.ByteString
decodeUri = fmap BS.pack . go . BS.unpack
 where
  go [] = Right []
  go (37 : a : b : rest) = do
    high <- hexDigit a; low <- hexDigit b
    ((16 * high + low) :) <$> go rest
  go (37 : _) = Left "s3-uri-escape-invalid"
  go (byte : rest) = (byte :) <$> go rest
  hexDigit byte | byte >= 48 && byte <= 57 = Right (byte - 48)
                | byte >= 65 && byte <= 70 = Right (byte - 55)
                | byte >= 97 && byte <= 102 = Right (byte - 87)
                | otherwise = Left "s3-uri-escape-invalid"

encodeUri :: Bool -> BS.ByteString -> BS.ByteString
encodeUri preserveSlash = B.concatMap $ \c ->
  if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c `elem` ("-_.~" :: String) || preserveSlash && c == '/'
    then B.singleton c else B.pack ['%', digits !! (fromEnum c `div` 16), digits !! (fromEnum c `mod` 16)]
 where digits = "0123456789ABCDEF"

signature :: BS.ByteString -> BS.ByteString -> BS.ByteString -> BS.ByteString -> BS.ByteString
signature secret day date canonical =
  let key = signingKey secret day
      stringToSign = B.intercalate "\n" ["AWS4-HMAC-SHA256", date, day <> "/us-east-1/s3/aws4_request", sha256Hex canonical]
   in hex (SHA.hmac key stringToSign)

signingKey :: BS.ByteString -> BS.ByteString -> BS.ByteString
signingKey secret day = foldl SHA.hmac (SHA.hmac ("AWS4" <> secret) day) ["us-east-1", "s3", "aws4_request"]

-- | Verify the original writer's complete signed stream before translating
-- it to an ordinary root-signed request. Header re-signing alone cannot
-- preserve chunk MACs bound to a different key and seed signature.
verifyS3ChunkedPayload :: UTCTime -> S3Credentials -> SigningRequest
  -> Natural -> Natural -> Natural -> BS.ByteString -> Either String BS.ByteString
verifyS3ChunkedPayload now credentials@(S3Credentials _ secret) request maximumEncoded maximumDecoded maximumFrames encoded = do
  verifyS3Signature now credentials request
  Authorization _ day date _ seed querySigned _ <- authorization request
  unless (not querySigned && maximumEncoded <= 2097152 && maximumDecoded <= 1048576
    && maximumFrames > 0 && maximumFrames <= 1024 && fromIntegral (BS.length encoded) <= maximumEncoded)
    (Left "s3-chunk-profile-or-encoded-bound-denied")
  unless (lookup "x-amz-content-sha256" headers == Just "STREAMING-AWS4-HMAC-SHA256-PAYLOAD"
    && lookup "content-encoding" headers == Just "aws-chunked" && lookup "x-amz-trailer" headers == Nothing)
    (Left "s3-chunk-encoding-profile-denied")
  expected <- decimalHeader "x-amz-decoded-content-length"
  wireLength <- decimalHeader "content-length"
  unless (expected <= maximumDecoded && wireLength == fromIntegral (BS.length encoded))
    (Left "s3-chunk-length-denied")
  chunks <- parseChunks (signingKey secret day) day date seed Nothing 0 0 [] encoded
  let decoded = BS.concat (reverse chunks)
  unless (fromIntegral (BS.length decoded) == expected) (Left "s3-chunk-decoded-length-denied")
  pure decoded
 where
  headers = signingHeaders request
  decimalHeader name = do
    value <- maybe (Left "s3-chunk-length-header-required") Right (lookup name headers)
    unless (not (BS.null value) && B.all (\c -> c >= '0' && c <= '9') value) (Left "s3-chunk-length-header-invalid")
    maybe (Left "s3-chunk-length-header-invalid") Right (readMaybe (B.unpack value) :: Maybe Natural)
  parseChunks key day date previous lastData frames total found remaining = do
    unless (frames < maximumFrames) (Left "s3-chunk-frame-bound-denied")
    let (line, ending) = B.breakSubstring "\r\n" remaining
        (sizeText, signatureField) = B.breakSubstring ";chunk-signature=" line
        supplied = BS.drop 17 signatureField
    unless (BS.length line <= 256 && not (BS.null ending) && not (BS.null sizeText)
      && BS.length sizeText <= 16 && B.all (\c -> c `elem` ("0123456789abcdefABCDEF" :: String)) sizeText
      && BS.length signatureField == 81 && BS.length supplied == 64 && BS.all lowerHex supplied)
      (Left "s3-chunk-header-invalid")
    size <- case readHex (B.unpack sizeText) of
      [(value, "")] -> Right (value :: Natural)
      _ -> Left "s3-chunk-size-invalid"
    unless (size <= maximumDecoded && total + size <= maximumDecoded) (Left "s3-chunk-decoded-bound-denied")
    let (body, suffix) = BS.splitAt (fromIntegral size) (BS.drop 2 ending)
    unless (fromIntegral (BS.length body) == size && "\r\n" `BS.isPrefixOf` suffix) (Left "s3-chunk-body-truncated")
    let expectedMac = hex (SHA.hmac key (B.intercalate "\n"
          ["AWS4-HMAC-SHA256-PAYLOAD", date, day <> "/us-east-1/s3/aws4_request", previous,
           sha256Hex BS.empty, sha256Hex body]))
    unless (constEq supplied expectedMac) (Left "s3-chunk-signature-denied")
    if size == 0 then do
      unless (BS.null (BS.drop 2 suffix)) (Left "s3-chunk-trailer-denied")
      pure found
    else do
      unless (maybe True (>=8192) lastData) (Left "s3-chunk-nonfinal-too-small")
      parseChunks key day date supplied (Just size) (frames+1) (total+size) (body:found) (BS.drop 2 suffix)

sha256Hex :: BS.ByteString -> BS.ByteString
sha256Hex = hex . SHA.hash
hex :: BS.ByteString -> BS.ByteString
hex = B.pack . concatMap (\byte -> [digits !! fromIntegral (byte `div` 16), digits !! fromIntegral (byte `mod` 16)]) . BS.unpack
 where digits = "0123456789abcdef"
lowerHex :: Word8 -> Bool
lowerHex byte = byte >= 48 && byte <= 57 || byte >= 97 && byte <= 102
unique :: Eq value => [value] -> [value]
unique [] = []
unique (first : rest) = first : unique (filter (/= first) rest)

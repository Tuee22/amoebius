{-# LANGUAGE OverloadedStrings #-}
module S3SigningSpec (verifyS3Signing) where

import Amoebius.Platform.S3Signing
import Control.Monad (unless)
import Data.Time
import System.Exit (die)

-- Published AWS examples, not generated from the implementation:
-- https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sig-v4-header-based-auth.html
-- https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sigv4-query-string-auth.html
verifyS3Signing :: IO ()
verifyS3Signing = do
  now <- maybe (die "AWS vector date invalid") pure
    (parseTimeM True defaultTimeLocale "%Y%m%dT%H%M%SZ" "20130524T000000Z")
  let credentials = S3Credentials "AKIAIOSFODNN7EXAMPLE" "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      empty = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      common body = [("host", "examplebucket.s3.amazonaws.com"), ("x-amz-date", "20130524T000000Z"), ("x-amz-content-sha256", body)]
      authorization headers signature = ("authorization", "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=" <> headers <> ",Signature=" <> signature)
      get = SigningRequest "GET" "/test.txt" (common empty <> [("range", "bytes=0-9"),
        authorization "host;range;x-amz-content-sha256;x-amz-date" "f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"])
      putHash = "44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072"
      put = SigningRequest "PUT" "/test%24file.text" (common putHash <>
        [("date", "Fri, 24 May 2013 00:00:00 GMT"), ("x-amz-storage-class", "REDUCED_REDUNDANCY"),
         authorization "date;host;x-amz-content-sha256;x-amz-date;x-amz-storage-class" "98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd"])
      lifecycle = SigningRequest "GET" "/?lifecycle" (common empty <>
        [authorization "host;x-amz-content-sha256;x-amz-date" "fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543"])
      listing = SigningRequest "GET" "/?max-keys=2&prefix=J" (common empty <>
        [authorization "host;x-amz-content-sha256;x-amz-date" "34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7"])
      query = SigningRequest "GET" ("/test.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request"
        <> "&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404")
        [("host", "examplebucket.s3.amazonaws.com")]
  mapM_ (\(name, request) -> unless (verifyS3Signature now credentials request == Right ())
    (die ("published AWS SigV4 vector failed: " <> name <> ":" <> show (verifyS3Signature now credentials request))))
    [("GET range", get), ("PUT encoded key", put), ("bucket lifecycle", lifecycle), ("bucket listing", listing), ("presigned GET", query)]
  unless (verifyS3Signature now credentials (get {signingTarget = "/foreign.txt"}) == Left "s3-signature-denied")
    (die "SigV4 accepted a changed scope")
  unless (verifyS3Signature (addUTCTime 901 now) credentials get == Left "s3-signature-expired")
    (die "SigV4 accepted an expired header signature")
  unless (verifyS3Signature now (S3Credentials "foreign" "other") get == Left "s3-writer-key-denied")
    (die "SigV4 accepted a foreign writer key")
  unless (verifyS3Signature now credentials (get {signingHeaders = signingHeaders get <> [("host", "foreign")]})
    == Left "s3-required-field-missing-or-duplicate") (die "SigV4 accepted ambiguous authority")
  unless (canonicalQuery "z=%2B&a=x%20y" == Right "a=x%20y&z=%2B") (die "SigV4 canonical query escaping drift")
  unless (decodeUri "%GG" == Left "s3-uri-escape-invalid") (die "SigV4 accepted malformed URI escape")

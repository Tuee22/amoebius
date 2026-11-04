{-# LANGUAGE OverloadedStrings #-}

module S3AdmissionSpec (verifyS3Admission) where

import Amoebius.Platform.S3Protocol (deleteObjectKeys, validateHeaderFields, publicResponseHeaders, publicErrorCode)
import Amoebius.Platform.S3Admission
import Amoebius.Platform.S3Signing (sha256Hex)
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Exit (die)

verifyS3Admission :: IO ()
verifyS3Admission = do
  -- Published/pinned S3 error identifiers are programmatic codes; digits are
  -- part of SHA256, while backend messages/markup remain private.
  mapM_ (\code -> unless (publicErrorCode (Just code) == code) (die "S3 backend error code lost"))
    ["XAmzContentSHA256Mismatch", "BadDigest", "AccessDenied", BS.replicate 64 65]
  mapM_ (\code -> unless (publicErrorCode code == "BackendError") (die "unsafe S3 backend error code escaped"))
    [Nothing, Just "", Just "Bad<Digest", Just "Bad&Digest", Just "Bad Digest", Just (BS.replicate 65 65)]
  checkDeleteGrammar
  unless (validateHeaderFields True [("vary", "Origin"), ("vary", "Accept-Encoding")] == Right ())
    (die "standard repeated Vary response fields rejected")
  unless (validateHeaderFields False [("host", "writer"), ("host", "other")] == Left "gateway-header-duplicate")
    (die "duplicate writer authority accepted")
  unless (validateHeaderFields True [("content-length", "1"), ("content-length", "2")] == Left "gateway-response-header-duplicate:content-length")
    (die "ambiguous backend framing accepted")
  unless (publicResponseHeaders [("x-amz-meta-s3managedledgeroffloaderformatversion","1"),
      ("x-amz-meta-managedledgername","phase30/drill/persistent/topic"),("etag","digest"),
      ("authorization","private"),("set-cookie","private"),("transfer-encoding","chunked")]
    == [("x-amz-meta-s3managedledgeroffloaderformatversion","1"),
        ("x-amz-meta-managedledgername","phase30/drill/persistent/topic"),("etag","digest")])
    (die "offloader read metadata lost or backend authority/framing forwarded")

  let digest = "sha256:" <> Text.replicate 64 "a"
      canonical = "/registry/docker/registry/v2/blobs/sha256/aa/" <> Text.replicate 64 "a" <> "/data"
      offload = "/pulsar-offload/00000000-0000-0000-0000-000000000000-ledger-1"
  policy <- right (gatewayPolicy (Map.singleton canonical (1048576, digest)))
  (reserved, reservation) <- right (beginWrite policy emptyGatewayState RegistryWriter canonical 1048576 digest)
  check "reserve before mutation does not claim a committed object" (stateObjectCount reserved == 0)
  check "only one active write is admitted" (beginWrite policy reserved RegistryWriter canonical 1048576 digest == Left "gateway-write-already-active")
  committed <- right (finishWrite reserved reservation True)
  _ <- right (validateBackendInventory policy emptyGatewayState [(canonical,1048576)] [])
  check "canonical backend extent remains bound to immutable inventory"
    (validateBackendInventory policy emptyGatewayState [(canonical,1048575)] [] == Left "gateway-backend-canonical-extent-mismatch")
  check "fresh local state cannot erase retained offload occupancy"
    (validateBackendInventory policy emptyGatewayState [(offload,4096)] [] == Left "gateway-backend-unreserved-object")
  check "fresh local state cannot erase an existing multipart upload"
    (validateBackendInventory policy emptyGatewayState [] [(offload,"retained-upload")] == Left "gateway-backend-unreserved-upload")
  check "duplicate backend residents reject"
    (validateBackendInventory policy committed [(canonical,1048576),(canonical,1048576)] [] == Left "gateway-backend-inventory-duplicate")
  check "successful extent becomes resident" (admittedObject committed canonical == Just (1048576, digest))
  check "foreign writer cannot use canonical registry key"
    (beginWrite policy emptyGatewayState OffloadWriter canonical 1048576 digest == Left "gateway-writer-scope-denied")
  check "wrong canonical extent fails before backend mutation"
    (beginWrite policy emptyGatewayState RegistryWriter canonical 1048575 digest == Left "gateway-object-extent-denied")
  check "wrong canonical digest fails before backend mutation"
    (beginWrite policy emptyGatewayState RegistryWriter canonical 1048576 ("sha256:" <> Text.replicate 64 "b") == Left "gateway-object-digest-denied")
  check "one byte over offload maximum rejects"
    (beginWrite policy emptyGatewayState OffloadWriter offload 1048577 "UNSIGNED-PAYLOAD" == Left "gateway-object-extent-denied")
  (pending, write) <- right (beginWrite policy emptyGatewayState OffloadWriter offload 1048576 "UNSIGNED-PAYLOAD")
  failed <- right (finishWrite pending write False)
  (secondPending, _) <- right (beginWrite policy failed OffloadWriter offload 1048576 "UNSIGNED-PAYLOAD")
  -- A restart and a failed response consume the same funded orphan generation.
  let recovered = recoverInterrupted secondPending
  restored <- right (decodeGatewayState (gatewayStateValue recovered))
  check "failed debt survives restart and cannot be spent again"
    (beginWrite policy restored OffloadWriter offload 1048576 "UNSIGNED-PAYLOAD" == Left "gateway-failed-history-full")
  (opening, openReservation) <- right (beginMultipart policy emptyGatewayState OffloadWriter offload)
  upload <- right (bindMultipart opening openReservation "real-backend-upload-id")
  _ <- right (validateBackendInventory policy upload [] [(offload,"real-backend-upload-id")])
  check "multipart creation reserves a full object before any part"
    (admittedObject upload offload == Just (1048576, "UNSIGNED-PAYLOAD"))
  check "unreserved multipart identity rejects"
    (beginPart policy upload OffloadWriter offload "foreign-upload-id" 1 4096 == Left "gateway-multipart-part-denied")
  check "a second part cannot multiply reserved extents"
    (beginPart policy upload OffloadWriter offload "real-backend-upload-id" 2 4096 == Left "gateway-multipart-part-denied")
  check "multipart extent cannot exceed its reservation"
    (beginPart policy upload OffloadWriter offload "real-backend-upload-id" 1 1048577 == Left "gateway-multipart-extent-denied")
  (partPending, partReservation) <- right (beginPart policy upload OffloadWriter offload "real-backend-upload-id" 1 4096)
  withPart <- right (recordPart partPending partReservation "real-backend-upload-id" 4096)
  (completing, completeReservation) <- right (beginComplete policy withPart OffloadWriter offload "real-backend-upload-id")
  completed <- right (completeMultipart completing completeReservation "real-backend-upload-id")
  _ <- right (validateBackendInventory policy completed [(offload,4096)] [])
  check "backend cannot exceed its retained reservation on restart"
    (validateBackendInventory policy completed [(offload,4097)] [] == Left "gateway-backend-object-extent-mismatch")
  check "completed multipart retains its observed extent"
    (admittedObject completed offload == Just (4096, "UNSIGNED-PAYLOAD"))
  deleted <- right (forgetStoredObject policy completed OffloadWriter offload)
  check "owned offload deletion releases its resident extent" (admittedObject deleted offload == Nothing)
  check "foreign writer cannot delete offload state"
    (forgetStoredObject policy completed RegistryWriter offload == Left "gateway-writer-scope-denied")
  check "active upload cannot be deleted as a committed object"
    (forgetStoredObject policy upload OffloadWriter offload == Left "gateway-delete-scope-denied")
  check "unknown multipart abort cannot release an owned reservation"
    (finishMultipartAbort policy upload OffloadWriter offload "unknown" == Left "gateway-multipart-abort-scope-denied")
  check "foreign writer cannot abort an offload upload"
    (finishMultipartAbort policy upload RegistryWriter offload "real-backend-upload-id" == Left "gateway-writer-scope-denied")
  check "abort cannot race a pending part"
    (finishMultipartAbort policy partPending OffloadWriter offload "real-backend-upload-id" == Left "gateway-multipart-abort-scope-denied")
  aborted <- right (finishMultipartAbort policy withPart OffloadWriter offload "real-backend-upload-id")
  check "owned observed abort releases target and upload identity"
    (admittedObject aborted offload == Nothing
      && beginPart policy aborted OffloadWriter offload "real-backend-upload-id" 1 4096 == Left "gateway-multipart-part-denied")
  -- Failed part debt remains funded even when its upload is independently
  -- aborted and the target has been observed absent by the IO adapter.
  firstPartFailure <- right (finishWrite partPending partReservation False)
  (retryPending,retryReservation) <- right (beginPart policy firstPartFailure OffloadWriter offload "real-backend-upload-id" 1 4096)
  exhaustedUpload <- right (finishWrite retryPending retryReservation False)
  exhaustedAborted <- right (finishMultipartAbort policy exhaustedUpload OffloadWriter offload "real-backend-upload-id")
  exhaustedRestored <- right (decodeGatewayState (gatewayStateValue exhaustedAborted))
  check "abort and restart preserve failed-generation debt"
    (beginWrite policy exhaustedRestored OffloadWriter offload 4096 "UNSIGNED-PAYLOAD" == Left "gateway-failed-history-full")
  let temporary = "/registry/docker/registry/v2/repositories/amoebius/phase30-new/_uploads/fresh/data"
  (temporaryPending, temporaryReservation) <- right (beginWrite policy emptyGatewayState RegistryWriter temporary 4096 digest)
  temporaryStored <- right (finishWrite temporaryPending temporaryReservation True)
  temporaryDeleted <- right (forgetStoredObject policy temporaryStored RegistryWriter temporary)
  check "owned temporary registry deletion releases its extent" (admittedObject temporaryDeleted temporary == Nothing)
  check "canonical registry resident cannot be deleted by a producer"
    (forgetStoredObject policy committed RegistryWriter canonical == Left "gateway-delete-scope-denied")
  _ <- right (admitCopySource policy temporaryStored RegistryWriter temporary)
  check "offloader cannot use registry data as a copy source"
    (admitCopySource policy temporaryStored OffloadWriter temporary == Left "gateway-copy-source-scope-denied")
  check "copy source must be an observed committed temporary object"
    (admitCopySource policy emptyGatewayState RegistryWriter temporary == Left "gateway-copy-source-scope-denied")
  state <- fill policy emptyGatewayState 128
  check "offload data count exact limit fits" (stateObjectCount state == 128)
  check "one additional offload identity rejects"
    (beginWrite policy state OffloadWriter (offload <> "000") 1048576 "UNSIGNED-PAYLOAD" == Left "gateway-object-count-denied")
 where
  check label condition = unless condition (die label)
  right = either (die . Text.unpack) pure
  fill _ state 0 = pure state
  fill policy state count = do
    let path = "/pulsar-offload/00000000-0000-0000-0000-000000000000-ledger-" <> Text.pack (show (count :: Int))
    (reserved, reservation) <- right (beginWrite policy state OffloadWriter path 1048576 "UNSIGNED-PAYLOAD")
    next <- right (finishWrite reserved reservation True)
    fill policy next (count - 1)

checkDeleteGrammar :: IO ()
checkDeleteGrammar = do
  value <- Lazy.readFile "test/oracle/platform_backbone_delete_grammar.json" >>= right . eitherDecode
  right (parseEither corpus value) >>= sequence_
 where
  right :: Show problem => Either problem value -> IO value
  right = either (die . show) pure
  corpus = withObject "independent Distribution DeleteObjects corpus" $ \root -> do
    rows <- root .: "cases" :: Parser [Value]
    traverse (withObject "literal DeleteObjects case" $ \row -> do
      name <- row .: "id"
      body <- row .: "bodyUtf8"
      leading <- row .: "leadingSpaceBytes"
      bytes <- row .: "encodedBytes"
      digest <- row .: "sha256"
      expected <- row .: "expected" :: Parser Text.Text
      keys <- row .:? "expectedKeys"
      unless (leading >= 0 && leading <= 65537) (fail "invalid literal whitespace count")
      unless (expected `elem` ["accept", "reject"]) (fail "invalid expected outcome")
      unless ((expected == "accept") == maybe False (const True) keys) (fail "expected keys/outcome mismatch")
      let encoded = BS.replicate leading 32 <> TextEncoding.encodeUtf8 body
          check condition = unless condition (die ("independent DeleteObjects case: " <> Text.unpack name))
      pure $ do
        check (BS.length encoded == bytes && sha256Hex encoded == TextEncoding.encodeUtf8 digest)
        case deleteObjectKeys encoded of
          Left _ -> check (expected == "reject")
          Right actual -> check (expected == "accept" && Just actual == keys)) rows



module Amoebius.Ui.Offline.BlobUpload
  ( BlobError (..)
  , BlobId
  , BlobQuotaOutcome (..)
  , UploadState
  , appendChunk
  , beginUpload
  , blobId
  , blobQuota
  , publicLocalHandles
  , releaseDependent
  , resumeOffset
  , verifyContent
  ) where

import Amoebius.Ui.Offline.Receipt (Scope)
import Data.Bits (xor)
import Data.Char (ord)
import Data.List (sortOn)
import Data.Word (Word64)
import Numeric (showHex)

newtype BlobId = BlobId String
  deriving stock (Eq, Ord, Show)

data UploadState = UploadState
  { uploadScope :: Scope
  , expectedBlob :: BlobId
  , expectedChunks :: Int
  , receivedChunks :: [(Int, String)]
  , contentVerified :: Bool
  }
  deriving stock (Eq, Show)

data BlobError = WrongBlobScope | ChunkOutOfBounds | DuplicateChunk | ContentMismatch | IncompleteUpload
  deriving stock (Eq, Show)

data BlobQuotaOutcome = BlobStored | BlobQuotaRefused | BlobDependencyEvicted
  deriving stock (Eq, Show)

blobId :: String -> BlobId
blobId content = BlobId ("fnv64:" <> showHex (foldl step (14695981039346656037 :: Word64) content) "")
  where
    step hash character = (hash `xor` fromIntegral (ord character)) * 1099511628211

beginUpload :: Scope -> BlobId -> Int -> UploadState
beginUpload scope expected chunks = UploadState scope expected chunks [] False

appendChunk :: Scope -> Int -> String -> UploadState -> Either BlobError UploadState
appendChunk scope index bytes state
  | scope /= uploadScope state = Left WrongBlobScope
  | index < 0 || index >= expectedChunks state = Left ChunkOutOfBounds
  | index `elem` map fst (receivedChunks state) = Left DuplicateChunk
  | otherwise = Right state {receivedChunks = (index, bytes) : receivedChunks state}

resumeOffset :: UploadState -> Int
resumeOffset = length . receivedChunks

verifyContent :: BlobId -> UploadState -> Either BlobError UploadState
verifyContent _callerClaim state
  | length (receivedChunks state) /= expectedChunks state = Left IncompleteUpload
  | blobId content == expectedBlob state = Right state {contentVerified = True}
  | otherwise = Left ContentMismatch
  where
    content = concatMap snd (sortOn fst (receivedChunks state))

releaseDependent :: UploadState -> Bool
releaseDependent = contentVerified

blobQuota :: Int -> Int -> Int -> Bool -> BlobQuotaOutcome
blobQuota budget used requested _depended
  | used + requested <= budget = BlobStored
  | otherwise = BlobQuotaRefused

publicLocalHandles :: [String]
publicLocalHandles = []

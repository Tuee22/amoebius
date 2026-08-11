module Amoebius.Sim.Fakes.MinIO
  ( MinIOState
  , emptyMinIO
  , putBlob
  , getBlob
  ) where

import Amoebius.Sim.Env (BlobKey, BlobResult (..), PutCondition (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)

newtype MinIOState = MinIOState (Map BlobKey Text)
  deriving stock (Eq, Show)

emptyMinIO :: MinIOState
emptyMinIO = MinIOState Map.empty

putBlob :: PutCondition -> BlobKey -> Text -> MinIOState -> (BlobResult, MinIOState)
putBlob condition key value state@(MinIOState blobs)
  | condition == IfNoneMatch && Map.member key blobs = (BlobPreconditionFailed412, state)
  | otherwise = (BlobStored, MinIOState (Map.insert key value blobs))

getBlob :: BlobKey -> MinIOState -> Maybe Text
getBlob key (MinIOState blobs) = Map.lookup key blobs

module Amoebius.Ui.Offline.BlobStore where

newtype LocalBlobId = LocalBlobId String
newtype UploadHandle = UploadHandle String

data BlobState
  = EncryptedLocal
  | Uploading Int
  | AwaitingVerification
  | ContentVerified String
  | QuotaRefused

type BlobDependency =
  { blob :: LocalBlobId
  , commandId :: String
  }

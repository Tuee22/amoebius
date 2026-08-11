module Amoebius.Ui.Offline.Browser.ServiceWorker
  ( Asset (..)
  , AssetError (..)
  , admitAssetManifest
  ) where

data Asset = Asset
  { assetPath :: String
  , assetDigest :: String
  , publicAsset :: Bool
  , immutableAsset :: Bool
  }
  deriving stock (Eq, Show)

data AssetError = PrivateAsset | MutableAsset | MissingAssetDigest
  deriving stock (Eq, Show)

admitAssetManifest :: [Asset] -> Either AssetError [Asset]
admitAssetManifest = traverse admit
  where
    admit asset
      | not (publicAsset asset) = Left PrivateAsset
      | not (immutableAsset asset) = Left MutableAsset
      | null (assetDigest asset) = Left MissingAssetDigest
      | otherwise = Right asset

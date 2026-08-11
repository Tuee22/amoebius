module Amoebius.Ui.Offline.ServiceWorker where

type ImmutableAsset =
  { path :: String
  , digest :: String
  }

foreign import installImmutableAssets :: Array ImmutableAsset -> Unit

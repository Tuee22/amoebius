module Amoebius.Ui.Offline.Partition where

newtype PartitionKey = PartitionKey String

foreign import derivePartitionKey
  :: String -> String -> String -> String -> Int -> PartitionKey

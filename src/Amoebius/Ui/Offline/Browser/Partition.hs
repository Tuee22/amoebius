

module Amoebius.Ui.Offline.Browser.Partition
  ( PartitionKey
  , partitionKey
  , renderPartitionKey
  ) where

import Data.Bits (xor)
import Data.Char (ord)
import Data.Word (Word64)
import Numeric (showHex)

newtype PartitionKey = PartitionKey String
  deriving stock (Eq, Ord, Show)

partitionKey :: String -> String -> String -> String -> Int -> PartitionKey
partitionKey tenant subject device program epoch = PartitionKey (digest material)
  where
    material = tenant <> "|" <> subject <> "|" <> device <> "|" <> program <> "|" <> show epoch

renderPartitionKey :: PartitionKey -> String
renderPartitionKey (PartitionKey value) = value

digest :: String -> String
digest = (`showHex` "") . foldl step (2166136261 :: Word64)
  where
    step hash character = (hash `xor` fromIntegral (ord character)) * 16777619

{-# LANGUAGE OverloadedStrings #-}

-- | Shared spellings for the tab-separated stage dumps: one key and one value per line.
module Amoebius.Dsl.Dump
  ( row
  , rows
  , natural
  , commas
  , vector
  ) where

import Amoebius.Capacity.Vector (ResourceVector (..))
import Amoebius.Vocabulary (quantityText)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

row :: Text -> Text -> Text
row key value = key <> "\t" <> value

rows :: [Text] -> Text
rows = Text.unlines

natural :: Natural -> Text
natural = Text.pack . show

commas :: [Text] -> Text
commas = Text.intercalate ","

-- | The four axes in the order processor, memory, ephemeral storage, pod slots.
vector :: ResourceVector -> Text
vector resources = commas [quantityText (resourceCpu resources), quantityText (resourceMemory resources), quantityText (resourceEphemeralStorage resources), quantityText (resourcePodSlots resources)]

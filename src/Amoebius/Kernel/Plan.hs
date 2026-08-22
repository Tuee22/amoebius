{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Kernel.Plan
  ( renderChainPlan
  , renderChain
  , renderPlan
  ) where

import Amoebius.Kernel.Descent (Plan, foldLift)
import Amoebius.Kernel.Step (Step)
import Data.Aeson.Encode.Pretty
  ( Config (confCompare, confIndent)
  , Indent (Spaces)
  , defConfig
  , encodePretty'
  , keyOrder
  )
import Data.ByteString.Lazy (ByteString)

renderChainPlan :: [Step cfg] -> ByteString
renderChainPlan = renderPlan . foldLift ()

renderChain :: [Step cfg] -> ByteString
renderChain = renderChainPlan

renderPlan :: Plan -> ByteString
renderPlan plan = encodePretty' canonicalConfig plan <> "\n"

canonicalConfig :: Config
canonicalConfig =
  defConfig
    { confIndent = Spaces 2
    , confCompare = keyOrder []
    }

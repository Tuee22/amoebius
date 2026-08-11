{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Kernel.Plan
  ( renderChainPlan
  , renderChain
  ) where

import Amoebius.Kernel.Descent (foldLift)
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
renderChainPlan steps = encodePretty' canonicalConfig (foldLift () steps) <> "\n"

renderChain :: [Step cfg] -> ByteString
renderChain = renderChainPlan

canonicalConfig :: Config
canonicalConfig =
  defConfig
    { confIndent = Spaces 2
    , confCompare = keyOrder []
    }

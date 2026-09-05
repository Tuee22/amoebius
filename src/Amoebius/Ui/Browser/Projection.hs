{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Browser.Projection (projectPureScript, projectionIsSafe) where

import Data.Text (Text)
import Data.Text qualified as Text

projectPureScript :: Text
projectPureScript = Text.unlines
  [ "module Amoebius.Ui.Generated where"
  , "renderText = trustedText"
  , "request action = sameOrigin action"
#ifdef UI_BROWSER_UNSAFE_INLINE_BUILD_MUTANT
  , "unsafeInline = eval"
#endif
  ]

projectionIsSafe :: Text -> Bool
projectionIsSafe source = all (`Text.isInfixOf` source) ["trustedText", "sameOrigin"] && not (any (`Text.isInfixOf` source) ["eval", "http://", "https://", "localStorage", "IndexedDB", "Redis"])

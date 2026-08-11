{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Server.SecurityHeaders
  ( productionSecurityHeaders
  , contentTypeForPath
  ) where

import Data.Text (Text)

productionSecurityHeaders :: [(Text, Text)]
productionSecurityHeaders =
  [ ("Content-Security-Policy", "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'")
  , ("Cross-Origin-Opener-Policy", "same-origin")
  , ("Cross-Origin-Resource-Policy", "same-origin")
  , ("Referrer-Policy", "no-referrer")
  , ("X-Content-Type-Options", "nosniff")
  ]

contentTypeForPath :: Text -> Maybe Text
contentTypeForPath path = case path of
  "/" -> Just "text/html; charset=utf-8"
  "/index.html" -> Just "text/html; charset=utf-8"
  "/ui.js" -> Just "text/javascript; charset=utf-8"
  "/ui.css" -> Just "text/css; charset=utf-8"
  "/ui/client-plan" -> Just "application/json"
  _ -> Nothing

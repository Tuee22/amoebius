{-# LANGUAGE OverloadedStrings #-}

module ExtensionLawMutants
  ( partialOperation
  , ambientRender
  ) where

import Amoebius.Extension.Laws.PerExtension
  ( OperationOutcome (OperationReturned)
  )
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Environment (lookupEnv)

-- L1 defect: one generated input escapes the declared result vocabulary.
partialOperation :: Text -> OperationOutcome
partialOperation input =
  if input == "panic"
    then error "partial extension operation"
    else OperationReturned input

-- L2 defect: the rendering observes process-global ambient state that is absent from the
-- declaration. Two independently seeded processes therefore emit different bytes.
ambientRender :: Text -> Text -> IO ByteString
ambientRender extension input = do
  seed <- lookupEnv "AMOEBIUS_EXTENSION_LAW_SEED"
  pure (Encoding.encodeUtf8 (extension <> ":artifact:" <> input <> ":" <> Text.pack (show seed)))

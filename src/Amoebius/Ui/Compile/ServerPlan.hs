{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Compile.ServerPlan
  ( UiServerPlan
  , compileServerPlan
  , encodeServerPlan
  , serverActionPorts
  , serverActionRows
  ) where

import Amoebius.Ui.Bind
  ( BoundUiProgram
  , HandlerId
  , PortId
  , UiClientInstruction (..)
  , boundUiProjection
  , compiledHandler
  , compiledInstruction
  , handlerIdText
  , portIdText
  )
import qualified Data.Aeson as Aeson
import Data.ByteString.Lazy (ByteString)
import Data.List (intersperse, sortOn)
import Data.Text (Text)

newtype UiServerPlan = UiServerPlan [(PortId, HandlerId)]

compileServerPlan :: BoundUiProgram -> UiServerPlan
compileServerPlan program = UiServerPlan (sortOn fst (concatMap actionRow (boundUiProjection program)))
  where
    actionRow row = case (compiledInstruction row, compiledHandler row) of
      (EmitEvent _ port, Just handler) -> [(port, handler)]
      _ -> []

encodeServerPlan :: UiServerPlan -> ByteString
encodeServerPlan (UiServerPlan actions) = object
  [ ("abi", string "ui-server-v1")
  , ("actions", object [(portIdText port, string (handlerIdText handler)) | (port, handler) <- actions])
  , ("private", "true")
  ]

serverActionPorts :: UiServerPlan -> [PortId]
serverActionPorts (UiServerPlan actions) = map fst actions

serverActionRows :: UiServerPlan -> [(Text, Text)]
serverActionRows (UiServerPlan actions) =
  [(portIdText port, handlerIdText handler) | (port, handler) <- actions]

string :: Text -> ByteString
string = Aeson.encode

object :: [(Text, ByteString)] -> ByteString
object fields = "{" <> mconcat (intersperse "," (map renderField fields)) <> "}"
  where
    renderField (key, value) = string key <> ":" <> value

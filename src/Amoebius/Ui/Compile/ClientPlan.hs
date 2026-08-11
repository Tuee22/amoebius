{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Compile.ClientPlan
  ( ClientPlan
  , compileClientPlan
  , encodeClientPlan
  , clientActionPorts
  , clientEventNames
  , clientLinkIds
  , clientRouteIds
  ) where

import Amoebius.Ui.Bind
  ( BoundUiProgram
  , EventName
  , PortId
  , RouteId
  , UiClientInstruction (..)
  , boundUiProjection
  , compiledInstruction
  , compiledRoute
  , eventNameText
  , routeIdText
  )
import Amoebius.Ui.ExternalLinkCatalog (ExternalLinkId, externalLinkIdText)
import qualified Data.Aeson as Aeson
import Data.ByteString.Lazy (ByteString)
import Data.List (intersperse, sort)
import qualified Data.Set as Set
import Data.Text (Text)

data ClientPlan = ClientPlan
  { planEvents :: [(EventName, PortId)]
  , planLinks :: [ExternalLinkId]
  , planRoutes :: [RouteId]
  }

compileClientPlan :: BoundUiProgram -> ClientPlan
compileClientPlan program = ClientPlan
  { planEvents =
      [ (event, port)
      | row <- boundUiProjection program
      , EmitEvent event port <- [compiledInstruction row]
      ]
  , planLinks =
      [ link
      | row <- boundUiProjection program
      , NavigateExternal link <- [compiledInstruction row]
      ]
  , planRoutes = uniqueSorted (map compiledRoute (boundUiProjection program))
  }

encodeClientPlan :: ClientPlan -> ByteString
encodeClientPlan plan = object
  [ ("abi", string "ui-client-v1")
  , ("events", array (map (string . eventNameText . fst) (planEvents plan)))
  , ("links", array (map (string . externalLinkIdText) (planLinks plan)))
  , ("routes", array (map (string . routeIdText) (planRoutes plan)))
  ]

clientActionPorts :: ClientPlan -> [PortId]
clientActionPorts = sort . map snd . planEvents

clientEventNames :: ClientPlan -> [Text]
clientEventNames = map (eventNameText . fst) . planEvents

clientLinkIds :: ClientPlan -> [Text]
clientLinkIds = map externalLinkIdText . planLinks

clientRouteIds :: ClientPlan -> [Text]
clientRouteIds = map routeIdText . planRoutes

uniqueSorted :: Ord value => [value] -> [value]
uniqueSorted = Set.toAscList . Set.fromList

string :: Text -> ByteString
string = Aeson.encode

array :: [ByteString] -> ByteString
array values = "[" <> mconcat (intersperse "," values) <> "]"

object :: [(Text, ByteString)] -> ByteString
object fields = "{" <> mconcat (intersperse "," (map renderField fields)) <> "}"
  where
    renderField (key, value) = string key <> ":" <> value

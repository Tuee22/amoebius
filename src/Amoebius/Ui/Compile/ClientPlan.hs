{-# LANGUAGE CPP #-}
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
  , ("links", array (map (string . renderLink) (planLinks plan)))
  , ("routes", array (map (string . routeIdText) (planRoutes plan)))
#ifdef UI_PLAN_EMIT_PRIVATE_MUTANT
  , ("private", string "server-handle")
#endif
  ]

renderLink :: ExternalLinkId -> Text
#ifdef UI_PLAN_LINK_AS_FETCH_MUTANT
renderLink link = "fetch:" <> externalLinkIdText link
#else
renderLink = externalLinkIdText
#endif

clientActionPorts :: ClientPlan -> [PortId]
clientActionPorts = sort . map snd . planEvents

clientEventNames :: ClientPlan -> [Text]
clientEventNames = map (eventNameText . fst) . planEvents

clientLinkIds :: ClientPlan -> [Text]
clientLinkIds = map externalLinkIdText . planLinks

clientRouteIds :: ClientPlan -> [Text]
clientRouteIds = map routeIdText . planRoutes

uniqueSorted :: Ord value => [value] -> [value]
#ifdef UI_PLAN_INSERTION_ORDER_MUTANT
uniqueSorted = id
#else
uniqueSorted = Set.toAscList . Set.fromList
#endif

string :: Text -> ByteString
string = Aeson.encode

array :: [ByteString] -> ByteString
array values = "[" <> mconcat (intersperse "," values) <> "]"

object :: [(Text, ByteString)] -> ByteString
object fields = "{" <> mconcat (intersperse "," (map renderField fields)) <> "}"
  where
    renderField (key, value) = string key <> ":" <> value

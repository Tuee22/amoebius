{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Fabric.WgRender
  ( PeerRole (..)
  , PeerInventory (..)
  , FabricInventory (..)
  , RenderedPeer (..)
  , RenderedNode (..)
  , FabricError (..)
  , representativeInventory
  , renderFabric
  , renderPeerConfig
  , validateAllowedCidr
  , rejectInlineKeyLiteral
  , fabricErrorTag
  ) where

import Amoebius.Fabric.Keys
import Amoebius.Vault.SecretRef (SecretRef, foldSecretRef)
import Data.List (nub, sortOn)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as Text
import Text.Read (readMaybe)

data PeerRole = Gateway | Spoke
  deriving stock (Eq, Ord, Show)

data PeerInventory = PeerInventory
  { peerNodeId :: Text
  , peerClusterId :: Text
  , peerRole :: PeerRole
  , peerVpnIp :: Text
  , peerUnderlayIp :: Text
  , peerEndpoint :: Maybe Text
  , peerKeys :: PeerKeyRef
  }
  deriving stock (Eq, Show)

data FabricInventory = FabricInventory
  { fabricCidr :: Text
  , fabricInterfaceName :: Text
  , fabricListenPort :: Int
  , fabricPeers :: [PeerInventory]
  }
  deriving stock (Eq, Show)

data RenderedPeer = RenderedPeer
  { renderedPeerNodeId :: Text
  , renderedPublicKeyRef :: Text
  , renderedAllowedIps :: Text
  , renderedEndpoint :: Maybe Text
  }
  deriving stock (Eq, Show)

data RenderedNode = RenderedNode
  { renderedNodeId :: Text
  , renderedAddress :: Text
  , renderedListenPort :: Int
  , renderedPrivateKeyRef :: Text
  , renderedPeers :: [RenderedPeer]
  }
  deriving stock (Eq, Show)

data FabricError
  = InlineKeyLiteral
  | VpnIpOverlap
  | AllowedIpsOutsideFabric
  | InvalidFabricCidr
  | MissingGateway
  | MultipleGateways
  | GatewayEndpointMissing
  | DuplicateNodeId
  | EmptyPeerSet
  deriving stock (Eq, Show)

representativeInventory :: Either Text FabricInventory
representativeInventory = do
  hubKeys <- peerKeyRef "secret" "amoebius/wireguard/gateway-root" "private" "public"
  spokeKeys <- peerKeyRef "secret" "amoebius/wireguard/spoke-alpha" "private" "public"
  pure FabricInventory
    { fabricCidr = "10.77.0.0/16"
    , fabricInterfaceName = "wg0"
    , fabricListenPort = 51820
    , fabricPeers =
        [ PeerInventory "gateway-root" "root" Gateway "10.77.0.1" "192.0.2.1" (Just "192.0.2.1:51820") hubKeys
        , PeerInventory "spoke-alpha" "alpha" Spoke "10.77.1.2" "192.0.2.2" Nothing spokeKeys
        ]
    }

renderFabric :: FabricInventory -> Either FabricError [RenderedNode]
renderFabric inventory = do
  validateInventory inventory
  traverse (renderNode inventory) (sortOn peerNodeId (fabricPeers inventory))

renderNode :: FabricInventory -> PeerInventory -> Either FabricError RenderedNode
renderNode inventory local = do
  let remotes = filter ((/= peerNodeId local) . peerNodeId) (fabricPeers inventory)
  rendered <- traverse renderRemote remotes
  pure RenderedNode
    { renderedNodeId = peerNodeId local
    , renderedAddress = peerVpnIp local <> "/32"
    , renderedListenPort = fabricListenPort inventory
    , renderedPrivateKeyRef = renderSecretRef (peerPrivateRef (peerKeys local))
    , renderedPeers = sortOn renderedPeerNodeId rendered
    }
 where
  renderRemote remote = do
    let normalEndpoint = if peerRole remote == Gateway then peerEndpoint remote else Nothing
#ifdef PHASE41_HUB_NO_ENDPOINT_MUTANT
        endpoint = (Nothing :: Maybe Text)
#else
        endpoint = normalEndpoint
#endif
    if peerRole remote == Gateway && endpoint == Nothing
      then Left GatewayEndpointMissing
      else Right RenderedPeer
        { renderedPeerNodeId = peerNodeId remote
        , renderedPublicKeyRef = renderSecretRef (peerPublicRef (peerKeys remote))
        , renderedAllowedIps = peerVpnIp remote <> "/32"
        , renderedEndpoint = endpoint
        }

renderPeerConfig :: [RenderedNode] -> Text
renderPeerConfig nodes = Text.intercalate "\n\n" (map (Text.dropWhileEnd (== '\n') . renderNodeBlock) (sortOn renderedNodeId nodes)) <> "\n"
 where
  renderNodeBlock node = Text.unlines $
    [ "[" <> renderedNodeId node <> "]"
    , "Interface.Address = " <> renderedAddress node
    , "Interface.ListenPort = " <> Text.pack (show (renderedListenPort node))
    , "Interface.PrivateKeyRef = " <> renderedPrivateKeyRef node
    ] <> concatMap renderRemote (renderedPeers node)
  renderRemote remote =
    [ "Peer.NodeId = " <> renderedPeerNodeId remote
    , "Peer.PublicKeyRef = " <> renderedPublicKeyRef remote
    , "Peer.AllowedIPs = " <> renderedAllowedIps remote
    ] <> catMaybes
      [ ("Peer.Endpoint = " <>) <$> renderedEndpoint remote
      , if renderedEndpoint remote == Nothing then Nothing else Just "Peer.PersistentKeepalive = 25"
      ]

validateInventory :: FabricInventory -> Either FabricError ()
validateInventory inventory = do
  if null (fabricPeers inventory) then Left EmptyPeerSet else Right ()
  if distinct (map peerNodeId (fabricPeers inventory)) then Right () else Left DuplicateNodeId
  if distinct (map peerVpnIp (fabricPeers inventory)) then Right () else Left VpnIpOverlap
  prefix <- maybe (Left InvalidFabricCidr) Right (parseV4Cidr (fabricCidr inventory))
  if all (within prefix <=< parseV4) (map peerVpnIp (fabricPeers inventory))
    then Right ()
    else Left AllowedIpsOutsideFabric
  case filter ((== Gateway) . peerRole) (fabricPeers inventory) of
    [] -> Left MissingGateway
    [gateway] | peerEndpoint gateway == Nothing -> Left GatewayEndpointMissing
    [_] -> Right ()
    _ -> Left MultipleGateways
 where
  (<=<) predicate parser value = maybe False predicate (parser value)

validateAllowedCidr :: Text -> Text -> Either FabricError ()
validateAllowedCidr cidr allowed = do
  fabricPrefix <- maybe (Left InvalidFabricCidr) Right (parseV4Cidr cidr)
  allowedPrefix <- maybe (Left AllowedIpsOutsideFabric) Right (parseV4Cidr allowed)
  if prefixWithin fabricPrefix allowedPrefix then Right () else Left AllowedIpsOutsideFabric

rejectInlineKeyLiteral :: Text -> Either FabricError ()
rejectInlineKeyLiteral source
  | "privateKey" `Text.isInfixOf` source || "private-key" `Text.isInfixOf` source = Left InlineKeyLiteral
  | otherwise = Right ()

fabricErrorTag :: FabricError -> Text
fabricErrorTag failure = case failure of
  InlineKeyLiteral -> "gate1-inline-key-literal"
  VpnIpOverlap -> "decode-vpn-ip-overlap"
  AllowedIpsOutsideFabric -> "decode-allowed-ips-outside-fabric"
  InvalidFabricCidr -> "decode-invalid-fabric-cidr"
  MissingGateway -> "decode-missing-gateway"
  MultipleGateways -> "decode-multiple-gateways"
  GatewayEndpointMissing -> "decode-gateway-endpoint-missing"
  DuplicateNodeId -> "decode-duplicate-node-id"
  EmptyPeerSet -> "decode-empty-peer-set"

renderSecretRef :: SecretRef -> Text
renderSecretRef = foldSecretRef
  (\mount path field -> "vault:" <> mount <> "/" <> path <> "#" <> field)
  (\key -> "transit:" <> key)
  (\name _purpose -> "prompt:" <> name)

type Prefix = (Integer, Int)

parseV4Cidr :: Text -> Maybe Prefix
parseV4Cidr value = case Text.splitOn "/" value of
  [address, widthText] -> do
    addressValue <- parseV4 address
    width <- readMaybe (Text.unpack widthText)
    if width >= 0 && width <= 32
      then Just (mask width addressValue, width)
      else Nothing
  _ -> Nothing

parseV4 :: Text -> Maybe Integer
parseV4 value = case traverse (readMaybe . Text.unpack) (Text.splitOn "." value) of
  Just octets@[_, _, _, _]
    | all (\octet -> octet >= (0 :: Integer) && octet <= 255) octets ->
        Just (foldl (\acc octet -> acc * 256 + octet) 0 octets)
  _ -> Nothing

mask :: Int -> Integer -> Integer
mask width value
  | width == 0 = 0
  | otherwise = value - value `mod` (2 ^ (32 - width))

within :: Prefix -> Integer -> Bool
within (network, width) address = mask width address == network

prefixWithin :: Prefix -> Prefix -> Bool
prefixWithin outer@(_, outerWidth) (innerNetwork, innerWidth) =
  innerWidth >= outerWidth && within outer innerNetwork

distinct :: Eq value => [value] -> Bool
distinct values = length values == length (nub values)

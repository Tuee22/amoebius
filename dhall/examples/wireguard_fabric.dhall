let PeerRole = < Gateway | Spoke >

let SecretRef =
      { mount : Text
      , path : Text
      , privateField : Text
      , publicField : Text
      }

let Peer =
      { nodeId : Text
      , clusterId : Text
      , role : PeerRole
      , vpnIp : Text
      , underlayIp : Text
      , endpoint : Optional Text
      , key : SecretRef
      }

in  { fabricCidr = "10.77.0.0/16"
    , interfaceName = "wg0"
    , listenPort = 51820
    , peers =
      [ { nodeId = "gateway-root"
        , clusterId = "root"
        , role = PeerRole.Gateway
        , vpnIp = "10.77.0.1"
        , underlayIp = "192.0.2.1"
        , endpoint = Some "192.0.2.1:51820"
        , key =
          { mount = "secret"
          , path = "amoebius/wireguard/gateway-root"
          , privateField = "private"
          , publicField = "public"
          }
        }
      , { nodeId = "spoke-alpha"
        , clusterId = "alpha"
        , role = PeerRole.Spoke
        , vpnIp = "10.77.1.2"
        , underlayIp = "192.0.2.2"
        , endpoint = None Text
        , key =
          { mount = "secret"
          , path = "amoebius/wireguard/spoke-alpha"
          , privateField = "private"
          , publicField = "public"
          }
        }
      ] : List Peer
    }

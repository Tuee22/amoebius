let Capacity = ./Capacity.dhall

let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let Rke2Servers =
      < Single : Capacity.Rke2NodeDemand
      | Ha3 :
          { s0 : Capacity.Rke2NodeDemand
          , s1 : Capacity.Rke2NodeDemand
          , s2 : Capacity.Rke2NodeDemand
          }
      | Ha5 :
          { s0 : Capacity.Rke2NodeDemand
          , s1 : Capacity.Rke2NodeDemand
          , s2 : Capacity.Rke2NodeDemand
          , s3 : Capacity.Rke2NodeDemand
          , s4 : Capacity.Rke2NodeDemand
          }
      >

let Rke2AgentPool =
      < Fixed : { nodes : NonEmpty Capacity.Rke2NodeDemand }
      | Autoscaled :
          { floor : NonEmpty Capacity.Rke2NodeDemand
          , candidates : NonEmpty Capacity.ProviderNodeClass
          , quota : Capacity.ProviderQuota
          , policy : { cooldownSeconds : Natural }
          }
      >

let Ingress =
      < InternalOnly
      | KeycloakEnvoy : { host : Text, dnsRecord : Text, ttlSeconds : Natural }
      >

let Networking = < Gateway : { endpoint : Text } | Vpn : { fabric : Text } >

let RemoteHostWorker = { host : Text, site : Text, networking : Networking }

let ManagedAttachment = < HostWorker : RemoteHostWorker >

let Substrate =
      < LinuxKind : { host : Text, engine : Capacity.KindEngineDemand }
      | LinuxRke2 : { site : Text }
      | ManagedEks :
          { account : Text
          , nodeClasses : NonEmpty Capacity.ProviderNodeClass
          , quota : Capacity.ProviderQuota
          }
      | AppleMetalVm :
          { host : Text, linuxVm : Text, engine : Capacity.KindEngineDemand }
      >

in  { Rke2Servers
    , Rke2AgentPool
    , Ingress
    , Substrate
    , Networking
    , RemoteHostWorker
    , ManagedAttachment
    , single = \(server : Capacity.Rke2NodeDemand) -> Rke2Servers.Single server
    , ha3 =
        \(s0 : Capacity.Rke2NodeDemand) ->
        \(s1 : Capacity.Rke2NodeDemand) ->
        \(s2 : Capacity.Rke2NodeDemand) ->
          Rke2Servers.Ha3 { s0, s1, s2 }
    , ha5 =
        \(s0 : Capacity.Rke2NodeDemand) ->
        \(s1 : Capacity.Rke2NodeDemand) ->
        \(s2 : Capacity.Rke2NodeDemand) ->
        \(s3 : Capacity.Rke2NodeDemand) ->
        \(s4 : Capacity.Rke2NodeDemand) ->
          Rke2Servers.Ha5 { s0, s1, s2, s3, s4 }
    , fixedAgents =
        \(nodes : NonEmpty Capacity.Rke2NodeDemand) ->
          Rke2AgentPool.Fixed { nodes }
    , autoscaledAgents =
        \(floor : NonEmpty Capacity.Rke2NodeDemand) ->
        \(candidates : NonEmpty Capacity.ProviderNodeClass) ->
        \(quota : Capacity.ProviderQuota) ->
        \(policy : { cooldownSeconds : Natural }) ->
          Rke2AgentPool.Autoscaled { floor, candidates, quota, policy }
    , internalOnly = Ingress.InternalOnly
    , keycloakEnvoy =
        \(host : Text) ->
        \(dnsRecord : Text) ->
        \(ttlSeconds : Natural) ->
          Ingress.KeycloakEnvoy { host, dnsRecord, ttlSeconds }
    }

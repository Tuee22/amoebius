{ serviceType = "NodePort"
, bindAddress = "127.0.0.1"
, envoyRoute = False
, daemonWildIngress = False
, rawMinioNodePort = False
, services = [ "ContentMutationGateway", "Pulsar" ]
}

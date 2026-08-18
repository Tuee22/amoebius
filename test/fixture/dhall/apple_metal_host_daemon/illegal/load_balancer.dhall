let green = ./green_host_comms.dhall
let HostOriginMustBeNodePort = green with serviceType = "LoadBalancer"
let _ = assert : HostOriginMustBeNodePort.serviceType === "NodePort"
in HostOriginMustBeNodePort

let green = ./green_host_comms.dhall
let HostOriginMustNotHaveEnvoyRoute = green with envoyRoute = True
let _ = assert : HostOriginMustNotHaveEnvoyRoute.envoyRoute === False
in HostOriginMustNotHaveEnvoyRoute

let green = ./green_host_comms.dhall
let HostWorkerMustNotPublishIngress = green with daemonWildIngress = True
let _ = assert : HostWorkerMustNotPublishIngress.daemonWildIngress === False
in HostWorkerMustNotPublishIngress

let green = ./green_host_comms.dhall
let HostOriginMustBindLoopback = green with bindAddress = "0.0.0.0"
let _ = assert : HostOriginMustBindLoopback.bindAddress === "127.0.0.1"
in HostOriginMustBindLoopback

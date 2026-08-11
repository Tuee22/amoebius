let Topology = ../amoebius/Topology.dhall
let V = ./legal_values.dhall
in  Topology.Substrate.LinuxKind { host = "linux-host", engine = V.kindEngine }

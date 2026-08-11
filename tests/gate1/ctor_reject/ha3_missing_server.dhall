let Topology = ../../../dhall/amoebius/Topology.dhall

let Values = ../../../dhall/examples/legal_values.dhall

in    Topology.ha3 Values.rke2Server Values.rke2Server
    : Topology.Rke2Servers

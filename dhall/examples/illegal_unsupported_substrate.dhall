let Cluster = ../amoebius/Cluster.dhall

let legal = ./legal_multisubstrate_cluster.dhall

let UnsupportedSubstrate = < WindowsBare | MultiNodeKind : { nodes : Natural } >

in  legal // { substrate = UnsupportedSubstrate.WindowsBare } : Cluster.Type

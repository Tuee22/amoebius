let Cluster = ../amoebius/Cluster.dhall

let legal = ./legal_multisubstrate_cluster.dhall

let InvalidServerCount = < Even : Natural | Zero >

in  legal // { servers = InvalidServerCount.Even 2 } : Cluster.Type

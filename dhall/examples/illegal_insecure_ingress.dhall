let Cluster = ../amoebius/Cluster.dhall

let legal = ./legal_multisubstrate_cluster.dhall

let InsecureIngress = < Backdoor : { port : Natural } >

in    legal // { ingress = InsecureIngress.Backdoor { port = 8080 } }
    : Cluster.Type

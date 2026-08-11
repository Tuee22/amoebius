let Topology = ../amoebius/Topology.dhall

in  { host = "worker-a", site = "site-b" } : Topology.RemoteHostWorker

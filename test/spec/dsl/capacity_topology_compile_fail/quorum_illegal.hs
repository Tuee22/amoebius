module QuorumIllegal where
import Amoebius.Dsl.Topology
quorum :: Rke2Quorum Int
quorum = Two 1 2

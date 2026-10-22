module QuorumLegal where
import Amoebius.Dsl.Topology
quorum :: Rke2Quorum Int
quorum = Three 1 2 3

{-# LANGUAGE DataKinds #-}
module QuorumLegal where
import Amoebius.Dsl.Topology
quorum = mkServerQuorum OddThreeToken

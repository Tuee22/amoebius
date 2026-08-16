{-# LANGUAGE DataKinds #-}
module QuorumIllegal where
import Amoebius.Dsl.Topology
quorum = mkServerQuorum EvenTwoToken

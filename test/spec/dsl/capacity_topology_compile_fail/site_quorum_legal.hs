{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module SiteQuorumLegal where
import Amoebius.Dsl.Topology
quorum = mkThreeSiteQuorum (hostAt SiteAToken "s0") (hostAt SiteAToken "s1") (hostAt SiteAToken "s2")

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module SiteQuorumIllegal where
import Amoebius.Dsl.Topology
quorum = mkThreeSiteQuorum (hostAt SiteAToken "s0") (hostAt SiteAToken "s1") (hostAt SiteBToken "s2")

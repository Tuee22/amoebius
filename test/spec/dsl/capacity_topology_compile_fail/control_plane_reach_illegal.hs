{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module ControlPlaneReachIllegal where
import Amoebius.Dsl.Topology
agent = mkStretchedAgent NoReachToken (hostAt SiteAToken "agent-a")

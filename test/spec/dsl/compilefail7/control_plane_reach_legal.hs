{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module ControlPlaneReachLegal where
import Amoebius.Dsl.Topology
agent = mkStretchedAgent ControlPlaneToken (hostAt SiteAToken "agent-a")

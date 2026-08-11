{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module HostWorkerReachLegal where
import Amoebius.Dsl.Topology
worker = mkHostWorkerReach DataPlaneToken (hostAt SiteBToken "worker-b")

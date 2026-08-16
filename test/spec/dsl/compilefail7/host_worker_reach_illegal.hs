{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module HostWorkerReachIllegal where
import Amoebius.Dsl.Topology
worker = mkHostWorkerReach ControlPlaneToken (hostAt SiteBToken "worker-b")

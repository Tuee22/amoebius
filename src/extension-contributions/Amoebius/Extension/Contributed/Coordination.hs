{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Extension.Contributed.Coordination (contribution) where

import Amoebius.Extension.Surface qualified as S

contribution :: seal -> Either S.SurfaceRefusal (S.ProductSpec seal)
contribution seal = do
  monitoring <- S.sloMonitoring "amoebius_coordination_success"
  S.mkContribution "coordination" S.CoordinationConfig [S.Coordination] [S.ServiceCapability S.MessageBus]
    (monitoring S.:| []) seal

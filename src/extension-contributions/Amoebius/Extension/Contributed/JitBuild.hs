{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Extension.Contributed.JitBuild (contribution) where

import Amoebius.Extension.Surface qualified as S

contribution :: seal -> Either S.SurfaceRefusal (S.ProductSpec seal)
contribution seal = do
  monitoring <- S.sloMonitoring "amoebius_jit_build_success"
  S.mkContribution "jit-build" S.BuildCacheConfig [S.JitBuild] [S.ServiceCapability S.ObjectStore, S.ServiceCapability S.Registry]
    (monitoring S.:| []) seal

{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Extension.Contributed.Infernix (contribution) where

import Amoebius.Extension.Surface qualified as S

contribution :: seal -> Either S.SurfaceRefusal (S.ProductSpec seal)
contribution seal = do
  monitoring <- S.sloMonitoring "amoebius_infernix_success"
  S.mkContribution "infernix" S.InferenceConfig [S.ServiceCapability S.InferenceEngine] [S.JitBuild]
    (monitoring S.:| []) seal

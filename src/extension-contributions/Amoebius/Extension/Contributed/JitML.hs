{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Extension.Contributed.JitML (contribution) where

import Amoebius.Extension.Surface qualified as S

contribution :: seal -> Either S.SurfaceRefusal (S.ProductSpec seal)
contribution seal = do
  monitoring <- S.sloMonitoring "amoebius_jitml_success"
  S.mkContribution "jitml" S.TrainingConfig [] [S.JitBuild, S.Coordination, S.ServiceCapability S.InferenceEngine]
    (monitoring S.:| [S.tensorBoardMonitoring]) seal

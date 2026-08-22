{-# LANGUAGE OverloadedStrings #-}

module DispatchOracle
  ( runDispatchOracle
  ) where

-- Component diagnostic only. This pins the public dispatcher's current
-- refusal barriers so deleting one cannot silently turn structural checks into
-- a candidate. It performs no snapshot, hardware, container, or live-system
-- validation.

import Amoebius.Validation.Dispatch (phaseZeroReadinessBlockers, validatePhase)
import Amoebius.Validation.Types (CheckResult (..), Finding (findingCode))
import Control.Monad (unless)
import Data.Set qualified as Set
import Data.Text qualified as Text

runDispatchOracle :: IO ()
runDispatchOracle = do
  later <- validatePhase "/not-used/git" "/not-used/repository" 1
  outside <- validatePhase "/not-used/git" "/not-used/repository" 96
  let readinessCodes = Set.fromList (map findingCode (checkFindings phaseZeroReadinessBlockers))
      requiredReadiness =
        Set.fromList
          [ "QUALIFICATION-NOT-EXECUTED"
          , "POLICY-CONTRACT-MISSING"
          , "PB-GRAMMAR-UNIMPLEMENTED"
          , "SOURCE-CONSUMER-GRAPH-MISSING"
          , "WORKTREE-INDEX-OBSERVER-INCOMPLETE"
          , "PHASE-CONTRACT-SEMANTICS-MISSING"
          , "LEGACY-PREDICATE-DISPATCH-MISSING"
          , "INDEPENDENT-REVIEW-MISSING"
          , "CLEANROOM-OBSERVER-MISSING"
          , "EVIDENCE-INTEGRATION-MISSING"
          , "EVIDENCE-SCHEMA-INCOMPLETE"
          , "SOURCE-DIGEST-SCHEME-MISMATCH"
          , "GIT-ACQUISITION-UNAUTHENTICATED"
          ]
      problems =
        [ "Phase 0 readiness refusal inventory changed: " <> show readinessCodes
        | readinessCodes /= requiredReadiness
        ]
          <> ["Phase 1 public dispatch was not blocked" | not (hasCode "DISPATCH-PHASE-BLOCKED" later)]
          <> ["out-of-domain public dispatch was not refused" | not (hasCode "DISPATCH-PHASE-INVALID" outside)]
  unless
    (null problems)
    (fail ("DispatchOracle component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))

hasCode :: Text.Text -> CheckResult -> Bool
hasCode code = any ((== code) . findingCode) . checkFindings

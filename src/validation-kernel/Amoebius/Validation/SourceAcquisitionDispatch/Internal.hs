{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden source-acquisition pipeline to validation-dispatch route.
--
-- The callback is supplied only by the package-hidden Dispatch implementation;
-- package opacity and the closed import graph prevent a public caller from
-- replacing the real acquired-snapshot checker.
module Amoebius.Validation.SourceAcquisitionDispatch.Internal
  ( runSourceAcquisitionDispatch
  ) where

import Amoebius.Validation.SourceAcquisition.Internal
  ( AnchoredSourceAcquisitionSession
  )
import Amoebius.Validation.SourceAcquisitionPipeline.Internal
  ( runSourceAcquisitionPipeline
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , finding
  , observation
  )
import Data.Text (Text)
import System.IO (Handle)

runSourceAcquisitionDispatch
  :: (AcquiredSourceSnapshot -> IO CheckResult)
  -> AnchoredSourceAcquisitionSession
  -> Text
  -> Handle
  -> Handle
  -> Handle
  -> IO CheckResult
runSourceAcquisitionDispatch acquiredCheck session reservedReplayIdentity expectedManifestHandle wireHandle bundleHandle = do
  pipelineResult <-
    runSourceAcquisitionPipeline
      session
      reservedReplayIdentity
      expectedManifestHandle
      wireHandle
      bundleHandle
  case pipelineResult of
    Left refusal -> pure (sourceAcquisitionDispatchFailure refusal)
    Right acquired -> sourceAcquisitionDispatchSuccess acquiredCheck acquired

sourceAcquisitionDispatchFailure :: CheckResult -> CheckResult
#if defined(VALIDATION_SOURCE_ACQUISITION_DISPATCH_PIPELINE_FAILURE_MAPPING_MUTANT)
sourceAcquisitionDispatchFailure refusal = refusal `seq` sourceAcquisitionDispatchCompositionRefusal
#else
sourceAcquisitionDispatchFailure refusal =
  sourceAcquisitionDispatchCompositionRefusal `seq` refusal
#endif

sourceAcquisitionDispatchSuccess
  :: (AcquiredSourceSnapshot -> IO CheckResult)
  -> AcquiredSourceSnapshot
  -> IO CheckResult
#if defined(VALIDATION_SOURCE_ACQUISITION_DISPATCH_PIPELINE_SUCCESS_ROUTE_MUTANT)
sourceAcquisitionDispatchSuccess acquiredCheck acquired =
  acquiredCheck `seq` acquired `seq` pure sourceAcquisitionDispatchCompositionRefusal
#else
sourceAcquisitionDispatchSuccess acquiredCheck acquired =
  sourceAcquisitionDispatchCompositionRefusal `seq` acquiredCheck acquired
#endif

sourceAcquisitionDispatchCompositionRefusal :: CheckResult
sourceAcquisitionDispatchCompositionRefusal =
  CheckResult
    { checkName = "source-acquisition-dispatch"
    , checkObservations =
        [observation "source-acquisition.dispatch.status" "refused"]
    , checkFindings =
        [ finding
            "SOURCE-ACQUISITION-DISPATCH"
            "source-acquisition/dispatch"
            "the acquired-snapshot dispatcher composition was changed"
        ]
    }

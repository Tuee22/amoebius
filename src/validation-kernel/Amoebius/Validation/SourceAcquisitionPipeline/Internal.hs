{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden bounded-ingress to acquired-snapshot composition.
--
-- The external supervisor must establish the anchored session before calling
-- this module. This pipeline neither manufactures that authority nor exposes a
-- public success-shaped value; it only preserves the closed route from three
-- independently bounded handles through signature/content verification to the
-- opaque acquired snapshot.
module Amoebius.Validation.SourceAcquisitionPipeline.Internal
  ( runSourceAcquisitionPipeline
  ) where

import Amoebius.Validation.SourceAcquisition.Internal
  ( AnchoredSourceAcquisitionSession
  , acquireExternallyVerifiedSourceSnapshotFromReservedIngress
  )
import Amoebius.Validation.SourceAcquisitionIngress.Internal
  ( SourceAcquisitionIngress
  , ingressBundleBytes
  , ingressExpectedManifestBytes
  , ingressWireBytes
  , readSourceAcquisitionIngress
  )
import Amoebius.Validation.SourceClosure.Internal (AcquiredSourceSnapshot)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , finding
  , observation
  )
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import System.IO (Handle)

runSourceAcquisitionPipeline
  :: AnchoredSourceAcquisitionSession
  -> Text
  -> Handle
  -> Handle
  -> Handle
  -> IO (Either CheckResult AcquiredSourceSnapshot)
runSourceAcquisitionPipeline session reservedReplayIdentity expectedManifestHandle wireHandle bundleHandle = do
  ingressResult <-
    readSourceAcquisitionIngress
      expectedManifestHandle
      wireHandle
      bundleHandle
  pure $ case ingressResult of
    Left refusal -> pipelineIngressFailure refusal
    Right ingress ->
      pipelineIngressSuccess
        ( pipelineVerificationResult
            ( acquireExternallyVerifiedSourceSnapshotFromReservedIngress
                session
                reservedReplayIdentity
                (pipelineExpectedManifestBytes ingress)
                (pipelineWireBytes ingress)
                (pipelineBundleBytes ingress)
            )
        )

pipelineIngressFailure
  :: CheckResult
  -> Either CheckResult AcquiredSourceSnapshot
#if defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_INGRESS_FAILURE_MAPPING_MUTANT)
pipelineIngressFailure refusal = refusal `seq` Left pipelineCompositionRefusal
#else
pipelineIngressFailure refusal = pipelineCompositionRefusal `seq` Left refusal
#endif

pipelineIngressSuccess
  :: Either CheckResult AcquiredSourceSnapshot
  -> Either CheckResult AcquiredSourceSnapshot
#if defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_INGRESS_SUCCESS_ROUTE_MUTANT)
pipelineIngressSuccess result = result `seq` Left pipelineCompositionRefusal
#else
pipelineIngressSuccess result = pipelineCompositionRefusal `seq` result
#endif

pipelineExpectedManifestBytes :: SourceAcquisitionIngress -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_EXPECTED_MANIFEST_ROUTE_MUTANT)
pipelineExpectedManifestBytes = ByteString.drop 1 . ingressExpectedManifestBytes
#else
pipelineExpectedManifestBytes = ByteString.drop 0 . ingressExpectedManifestBytes
#endif

pipelineWireBytes :: SourceAcquisitionIngress -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_SIGNED_ENVELOPE_ROUTE_MUTANT)
pipelineWireBytes = ByteString.drop 1 . ingressWireBytes
#else
pipelineWireBytes = ByteString.drop 0 . ingressWireBytes
#endif

pipelineBundleBytes :: SourceAcquisitionIngress -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_IMMUTABLE_BUNDLE_ROUTE_MUTANT)
pipelineBundleBytes = ByteString.drop 1 . ingressBundleBytes
#else
pipelineBundleBytes = ByteString.drop 0 . ingressBundleBytes
#endif

pipelineVerificationResult
  :: Either CheckResult AcquiredSourceSnapshot
  -> Either CheckResult AcquiredSourceSnapshot
#if defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_VERIFICATION_FAILURE_MAPPING_MUTANT)
pipelineVerificationResult result = case result of
  Left refusal -> refusal `seq` Left pipelineCompositionRefusal
  Right acquired -> Right acquired
#elif defined(VALIDATION_SOURCE_ACQUISITION_PIPELINE_VERIFICATION_SUCCESS_ROUTE_MUTANT)
pipelineVerificationResult result = case result of
  Left refusal -> Left refusal
  Right acquired -> acquired `seq` Left pipelineCompositionRefusal
#else
pipelineVerificationResult result = pipelineCompositionRefusal `seq` result
#endif

pipelineCompositionRefusal :: CheckResult
pipelineCompositionRefusal =
  CheckResult
    { checkName = "source-acquisition-pipeline"
    , checkObservations =
        [observation "source-acquisition.pipeline.status" "refused"]
    , checkFindings =
        [ finding
            "SOURCE-ACQUISITION-PIPELINE"
            "source-acquisition/pipeline"
            "the bounded-ingress to verifier composition was changed"
        ]
    }

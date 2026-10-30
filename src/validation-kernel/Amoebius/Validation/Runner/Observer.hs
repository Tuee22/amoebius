-- | Capture every child executable, argv, cwd, actual environment, policy, exit and output,
-- then bind its digest to the current challenge (gate_runner_doctrine.md section 3).
module Amoebius.Validation.Runner.Observer
( ObservedRun (..), chainDigest, observe, observeNativeCabal, buildProductBinary, observedDigest, renderObserved, sha256Hex, ActualPreparedTuple, observeActualTuple, observeActualNativeCabal, NativeCabalRequest, prepareNativeCabalRequest, sha256Bytes, renderTsv, OracleTranscriptKind (..), inspectOracleTranscript ) where
import Amoebius.Validation.Authority.Core

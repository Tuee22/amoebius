-- | Verifier commands and reproducible receipt custody (gate_runner_doctrine.md section 6; DL-0013).
module Amoebius.Validation.Custody
( CommandOutcome (..), CustodyConfig (..), defaultCustodyConfig, acceptPhase, demoFile, previewPhase, replayThrough, receiptPublicationBound, resetGeneration, runFresh, voidFromPhase, receiptCompatibility ) where
import Amoebius.Validation.Authority.Core

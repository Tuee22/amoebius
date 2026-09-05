{-# LANGUAGE OverloadedStrings #-}

-- | Independent literals for the Phase-1 policy sabotage matrix.
-- This oracle imports only the refusal projection; it cannot construct an
-- acquired supervisor run or candidate evidence.
module ToolchainAcquisitionOracle
  ( runToolchainAcquisitionOracle
  ) where

import Amoebius.Validation.ToolchainSpikeRun.Internal
  ( toolchainSpikeInternalQualificationDiagnostic
  )
import Control.Monad (unless)
import Data.Text (Text)

runToolchainAcquisitionOracle :: IO ()
runToolchainAcquisitionOracle = do
  unless (toolchainSpikeInternalQualificationDiagnostic == expected) $
    fail
      ( "ToolchainAcquisitionOracle: expected "
          <> show expected
          <> ", observed "
          <> show toolchainSpikeInternalQualificationDiagnostic
      )
  putStrLn "ToolchainAcquisitionOracle: the clean policy and six one-change subjects have exact independent refusal loci; no gate evidence was minted."

expected :: [(Text, [Text])]
expected =
  [ ("clean", [])
  , ("missing-dependency", ["PHASE-01-POLICY-DEPENDENCY"])
  , ("wrong-terminal", ["PHASE-01-POLICY-TERMINAL"])
  , ("mutable-identity", ["PHASE-01-POLICY-IDENTITY"])
  , ("foreign-probe", ["PHASE-01-POLICY-PROBE-SOURCE"])
  , ("top-level-vendor", ["PHASE-01-POLICY-VENDOR-SOURCE"])
  , ("resolution-output", ["PHASE-01-POLICY-RESOLUTION-OUTPUT"])
  ]

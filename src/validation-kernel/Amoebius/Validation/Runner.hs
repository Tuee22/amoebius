-- | One generic gate runner. Suites and oracles provide observations; only this runner mints verdicts.
module Amoebius.Validation.Runner
  ( GateOutcome (..), PassedGate, RunnerConfig (..), RunnerRefusal (..), compiledBlocks, defaultRunnerConfig, reproducibleCore, Ledger
  , parseLedger, ledgerGreen, ledgerDigest, suiteLedger, renderRefusal, roleFor, runGate, specDigest ) where
import Amoebius.Validation.Authority.Core

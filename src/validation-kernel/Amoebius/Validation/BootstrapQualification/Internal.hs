-- | Finite seed protocol (gate integrity section M.4): compile exact predicate/driver copies,
-- then each of three bypasses, under the hash-chained process observer. Clean exits silently;
-- each mutant fails with empty stdout and exactly its case label plus a newline on stderr.
module Amoebius.Validation.BootstrapQualification.Internal
  ( SeedCase (..), SeedAttempt (..), SeedOutcome (..), SeedProtocol (..), defaultSeedProtocol, renderSeedOutcome, runSeedProtocol, runCapturedSeedProtocol, seedCases
  , seedGreen, attemptRuns, seedInterrupted ) where
import Amoebius.Validation.Authority.Core

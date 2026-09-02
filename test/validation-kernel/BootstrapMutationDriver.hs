module BootstrapMutationDriver (main) where

import Amoebius.Validation.BootstrapPredicate
  ( bootstrapDigestMatches
  , bootstrapInputPathAllowed
  , bootstrapSnapshotMatches
  )
import Control.Monad (unless, when)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  unless (bootstrapDigestMatches digestA digestA) (reject "positive-digest-control-refused")
  when (bootstrapDigestMatches digestA digestB) (reject "digest-equality-bypass")
  when (bootstrapDigestMatches "not-a-digest" "not-a-digest") (reject "malformed-digest-accepted")
  unless (bootstrapSnapshotMatches digestA digestA) (reject "positive-snapshot-control-refused")
  when (bootstrapSnapshotMatches digestA digestB) (reject "snapshot-freshness-bypass")
  unless
    (bootstrapInputPathAllowed ".build/bootstrap-inputs/ghc-SHA256SUMS")
    (reject "canonical-bootstrap-input-path-refused")
  when
    (bootstrapInputPathAllowed ".build/bootstrap-inputs/../escape")
    (reject "bootstrap-path-bypass")
  when
    (bootstrapInputPathAllowed "src/validation-kernel/Main.hs")
    (reject "tracked-source-accepted-as-bootstrap-input")

reject :: String -> IO ()
reject label = hPutStrLn stderr label >> exitFailure

digestA, digestB :: String
digestA = replicate 64 'a'
digestB = replicate 64 'b'

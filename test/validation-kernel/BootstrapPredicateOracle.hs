module BootstrapPredicateOracle (runBootstrapPredicateOracle) where

import Amoebius.Validation.BootstrapPredicate
  ( bootstrapDigestMatches
  , bootstrapInputPathAllowed
  , bootstrapSnapshotMatches
  )
import Control.Monad (unless)

runBootstrapPredicateOracle :: IO ()
runBootstrapPredicateOracle =
  unless (null problems) (fail (unlines ("BootstrapPredicateOracle:" : map ("  " <>) problems)))
 where
  problems =
    [ "equal canonical digests were refused"
    | not (bootstrapDigestMatches digestA digestA)
    ]
      <> ["unequal digests were accepted" | bootstrapDigestMatches digestA digestB]
      <> ["malformed equal digests were accepted" | bootstrapDigestMatches "bad" "bad"]
      <> ["equal snapshots were refused" | not (bootstrapSnapshotMatches digestA digestA)]
      <> ["changed snapshots were accepted" | bootstrapSnapshotMatches digestA digestB]
      <> [ "the canonical bootstrap pin path was refused"
         | not (bootstrapInputPathAllowed ".build/bootstrap-inputs/ghc-SHA256SUMS")
         ]
      <> [ "path traversal was accepted"
         | bootstrapInputPathAllowed ".build/bootstrap-inputs/../escape"
         ]
      <> [ "an absolute path was accepted"
         | bootstrapInputPathAllowed "/.build/bootstrap-inputs/ghc-SHA256SUMS"
         ]

digestA, digestB :: String
digestA = replicate 64 'a'
digestB = replicate 64 'b'

module Main (main) where

-- Expected compiler diagnostic: the package-hidden acquired-snapshot
-- constructor module cannot be imported through validation-kernel.
import Amoebius.Validation.SourceSnapshot.Internal
  ( AcquiredSourceSnapshot (AcquiredSourceSnapshot)
  )

private :: AcquiredSourceSnapshot -> AcquiredSourceSnapshot
private value = value

main :: IO ()
main = private `seq` pure ()

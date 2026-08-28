module Main (main) where

-- Expected compiler diagnostic: the package-hidden candidate verifier module
-- cannot be imported through the exposed validation-kernel library.
import Amoebius.Validation.SourceAcquisition.Internal

main :: IO ()
main = pure ()

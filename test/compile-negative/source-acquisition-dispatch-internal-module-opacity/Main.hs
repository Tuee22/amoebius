module Main (main) where

-- A package-external client must not replace the real acquired checker.
import Amoebius.Validation.SourceAcquisitionDispatch.Internal
  ( runSourceAcquisitionDispatch
  )

main :: IO ()
main = runSourceAcquisitionDispatch `seq` pure ()

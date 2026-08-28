module Main (main) where

-- This package-external client must not reach the success-shaped composition.
import Amoebius.Validation.SourceAcquisitionPipeline.Internal
  ( runSourceAcquisitionPipeline
  )

main :: IO ()
main = runSourceAcquisitionPipeline `seq` pure ()

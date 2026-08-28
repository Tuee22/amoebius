module Main (main) where

-- This client is deliberately outside lib:validation-kernel. The module must
-- remain package-hidden even though the production supervisor consumes it.
import Amoebius.Validation.SourceAcquisitionIngress.Internal
  ( readSourceAcquisitionIngress
  )

main :: IO ()
main = readSourceAcquisitionIngress `seq` pure ()

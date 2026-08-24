module Main (main) where

-- Expected compiler diagnostic: Amoebius.Validation.SourceAcquisition does
-- not export verifySourceAcquisitionDiagnostic. Exactly one forbidden symbol
-- is named so an unrelated private import cannot hide a raw-verifier leak.

import Amoebius.Validation.SourceAcquisition (verifySourceAcquisitionDiagnostic)

main :: IO ()
main = verifySourceAcquisitionDiagnostic `seq` pure ()

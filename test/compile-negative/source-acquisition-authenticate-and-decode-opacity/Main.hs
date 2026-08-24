module Main (main) where

-- Expected compiler diagnostic: Amoebius.Validation.SourceAcquisition does
-- not export authenticateAndDecode. Exactly one forbidden symbol is named so
-- another private import cannot mask a selective authenticated-success leak.

import Amoebius.Validation.SourceAcquisition (authenticateAndDecode)

main :: IO ()
main = authenticateAndDecode `seq` pure ()

module Main (main) where

-- Expected compiler diagnostic: Amoebius.Validation.SourceAcquisition does
-- not export SourceAcquisitionExpectation. Exactly one forbidden symbol is
-- named so another private import cannot mask a selective expectation leak.

import Amoebius.Validation.SourceAcquisition (SourceAcquisitionExpectation)

forbiddenExpectation :: Maybe SourceAcquisitionExpectation
forbiddenExpectation = Nothing

main :: IO ()
main = forbiddenExpectation `seq` pure ()

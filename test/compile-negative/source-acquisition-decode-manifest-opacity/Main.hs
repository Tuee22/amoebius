module Main (main) where

-- Expected compiler diagnostic: Amoebius.Validation.SourceAcquisition does
-- not export decodeManifest. Exactly one forbidden symbol is named so another
-- private import cannot mask a selective decoder leak.

import Amoebius.Validation.SourceAcquisition (decodeManifest)

main :: IO ()
main = decodeManifest `seq` pure ()

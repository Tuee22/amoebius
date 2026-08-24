module Main (main) where

-- Expected compiler diagnostic: Amoebius.Validation.SourceAcquisition does
-- not export decodeExpectedManifest. Exactly one forbidden symbol is named so
-- another private import cannot mask a selective decoder leak.

import Amoebius.Validation.SourceAcquisition (decodeExpectedManifest)

main :: IO ()
main = decodeExpectedManifest `seq` pure ()

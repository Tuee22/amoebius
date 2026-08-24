module Main (main) where

-- Expected compiler diagnostic: Amoebius.Validation.SourceAcquisition does
-- not export SourceAcquisitionManifest. Exactly one forbidden symbol is named
-- so an unrelated private import cannot hide a manifest opacity leak.

import Amoebius.Validation.SourceAcquisition (SourceAcquisitionManifest)

forbiddenManifest :: Maybe SourceAcquisitionManifest
forbiddenManifest = Nothing

main :: IO ()
main = forbiddenManifest `seq` pure ()

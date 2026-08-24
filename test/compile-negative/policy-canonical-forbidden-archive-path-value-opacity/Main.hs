module Main (main) where

import Amoebius.Validation.PolicyContract (canonicalForbiddenArchivePath)

main :: IO ()
main = canonicalForbiddenArchivePath `seq` pure ()

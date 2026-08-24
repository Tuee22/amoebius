module Main (main) where

-- External clients must not be able to import the package-hidden implementation.
import Amoebius.Validation.SourceClosure.Internal ()

main :: IO ()
main = pure ()

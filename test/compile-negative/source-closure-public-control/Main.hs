module Main (main) where

-- Paired positive control: the sole refusal-only public front door remains
-- callable from an external package client.
import Amoebius.Validation.SourceClosure (sourceClosureDiagnostic)

main :: IO ()
main = sourceClosureDiagnostic mempty [] `seq` pure ()

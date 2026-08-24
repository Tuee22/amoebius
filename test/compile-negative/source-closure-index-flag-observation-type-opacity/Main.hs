module Main (main) where

-- One-symbol external attack: this detachable SourceClosure type must not
-- cross the refusal-only public facade.
import Amoebius.Validation.SourceClosure (IndexFlagObservation)

private :: Maybe IndexFlagObservation
private = Nothing

main :: IO ()
main = private `seq` pure ()

module Main (main) where

-- One-symbol external attack: this detachable SourceClosure value must not
-- cross the refusal-only public facade.
import Amoebius.Validation.SourceClosure (objectFormatBoundaryProblems)

private :: ()
private = objectFormatBoundaryProblems `seq` ()

main :: IO ()
main = private `seq` pure ()

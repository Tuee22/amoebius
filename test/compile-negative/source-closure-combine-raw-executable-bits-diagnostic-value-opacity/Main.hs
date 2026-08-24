module Main (main) where

-- One-symbol external attack: this detachable SourceClosure value must not
-- cross the refusal-only public facade.
import Amoebius.Validation.SourceClosure (combineRawExecutableBitsDiagnostic)

private :: ()
private = combineRawExecutableBitsDiagnostic `seq` ()

main :: IO ()
main = private `seq` pure ()

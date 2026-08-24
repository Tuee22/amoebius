module Main (main) where

-- The implementation module is intentionally hidden by the package even
-- though the public facade re-exports its one refusal-only entry point.
import Amoebius.Validation.CompilerElaboratedPlan.Internal ()

main :: IO ()
main = pure ()

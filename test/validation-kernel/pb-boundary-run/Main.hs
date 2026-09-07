module Main (main) where

import Amoebius.Validation.PbBoundaryRun (runPbBoundaryComponentDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Monad (unless)
import System.Exit (exitFailure)

main :: IO ()
main = do
  result <- runPbBoundaryComponentDiagnostic "."
  mapM_ printFinding (checkFindings result)
  unless (null (checkFindings result)) exitFailure
  putStrLn "pb-boundary-run-component: PASS (complete acquired runner; no predecessor or candidate evidence)"

printFinding :: Finding -> IO ()
printFinding item = putStrLn (show (findingCode item) <> "\t" <> findingSubject item <> "\t" <> show (findingDetail item))

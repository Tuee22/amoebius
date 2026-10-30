-- | The identical raw process and ordered lookup operations used by native callers.
-- Callers retain every tool, environment-selection and failure policy.
module Amoebius.Internal.Process.EmptyInput (tryReadEmptyInput, presentEnvironment) where

import Control.Exception (IOException, try)
import System.Environment (lookupEnv)
import System.Exit (ExitCode)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

-- | Return the actual operation result; an IOException is never an exit code.
tryReadEmptyInput :: FilePath -> FilePath -> [String] -> Maybe [(String, String)] -> IO (Either IOException (ExitCode, String, String))
tryReadEmptyInput directory executable arguments environment =
  try (readCreateProcessWithExitCode ((proc executable arguments) {cwd = Just directory, env = environment}) "")

-- | Look up each requested occurrence in order, retaining present empty values.
presentEnvironment :: [String] -> IO [(String, String)]
presentEnvironment names = do
  pairs <- mapM (\name -> fmap (fmap (\value -> (name, value))) (lookupEnv name)) names
  pure [pair | Just pair <- pairs]

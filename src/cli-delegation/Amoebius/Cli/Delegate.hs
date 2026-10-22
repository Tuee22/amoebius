-- | Portable product-to-verifier transport. Only the verifier decides results.
module Amoebius.Cli.Delegate (delegateValidate, verifierFileName) where

import System.Directory (doesFileExist, exeExtension, findExecutable)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.IO (hPutStrLn, stderr)
import System.Process (rawSystem)

verifierFileName :: String -> FilePath
verifierFileName extension = "amoebius-validate" <> extension

-- Arguments, standard streams, working directory and environment are inherited;
-- the parent waits and propagates the child's status without interpreting it.
-- Process replacement by the bounded Python bootstrap is a separate handoff.
delegateValidate :: [String] -> IO ()
delegateValidate options = do
  self <- getExecutablePath
  let sibling = takeDirectory self </> verifierFileName exeExtension
  siblingExists <- doesFileExist sibling
  resolved <- if siblingExists then pure (Just sibling) else findExecutable "amoebius-validate"
  case resolved of
    Just verifier -> rawSystem verifier options >>= exitWith
    Nothing -> do
      hPutStrLn stderr "amoebius validate: the verifier executable amoebius-validate is neither beside amoebius nor on PATH"
      exitWith (ExitFailure 2)

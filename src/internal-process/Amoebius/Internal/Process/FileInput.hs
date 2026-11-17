-- | Raw file-backed process transport; callers own paths, environment and verdicts.
module Amoebius.Internal.Process.FileInput (tryRunFileInput) where

import Control.Exception (IOException, try)
import Control.Monad (when)
import Data.List (nubBy)
import System.Exit (ExitCode)
import System.FilePath (equalFilePath)
import System.IO (IOMode (ReadMode, WriteMode), withBinaryFile)
import System.Process (CreateProcess (cwd, env, std_in, std_out, std_err), StdStream (UseHandle), proc, waitForProcess, withCreateProcess)

-- | Refuse the same named stream twice before opening any file for output.
tryRunFileInput :: FilePath -> FilePath -> [String] -> Maybe [(String, String)] -> FilePath -> FilePath -> FilePath -> IO (Either IOException ExitCode)
tryRunFileInput directory executable arguments environment input output errors = try $ do
  when (length (nubBy equalFilePath [input, output, errors]) /= 3) (ioError (userError "process stream paths must differ"))
  withBinaryFile input ReadMode $ \inputHandle -> withBinaryFile output WriteMode $ \outputHandle -> withBinaryFile errors WriteMode $ \errorHandle ->
    withCreateProcess ((proc executable arguments) {cwd = Just directory, env = environment, std_in = UseHandle inputHandle, std_out = UseHandle outputHandle, std_err = UseHandle errorHandle}) $ \_ _ _ process -> waitForProcess process

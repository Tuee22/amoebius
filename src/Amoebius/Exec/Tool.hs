module Amoebius.Exec.Tool
  ( ToolPath
  , ToolError (..)
  , ToolResult (..)
  , mkToolPath
  , toolPath
  , runTool
  ) where

import Amoebius.Host.Ensure qualified as Ensure
import Data.ByteString.Lazy (ByteString)
import System.Exit (ExitCode)

data ToolPath = ToolPath
  { toolPath :: FilePath
  , toolAbsExe :: Ensure.AbsExe
  }
  deriving stock (Eq, Show)

data ToolError = ToolPathNotAbsolute FilePath
  deriving stock (Eq, Show)

data ToolResult = ToolResult
  { toolExitCode :: ExitCode
  , toolStdout :: ByteString
  , toolStderr :: ByteString
  }
  deriving stock (Eq, Show)

mkToolPath :: FilePath -> Either ToolError ToolPath
mkToolPath path = case Ensure.mkAbsExe path of
  Left _ -> Left (ToolPathNotAbsolute path)
  Right absolute -> Right (ToolPath path absolute)

runTool :: ToolPath -> [String] -> ByteString -> IO ToolResult
runTool resolved arguments stdinBytes = do
  result <- Ensure.runToolWithStdin (toolAbsExe resolved) arguments stdinBytes
  pure (ToolResult (Ensure.toolExitCode result) (Ensure.toolStdout result) (Ensure.toolStderr result))

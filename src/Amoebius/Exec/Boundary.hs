{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Exec.Boundary
  ( BoundaryTools
  , mkBoundaryTools
  , runBoundaryCorpus
  ) where

import Amoebius.Exec.Tool
import Control.Monad (unless)
import Data.ByteString.Lazy (ByteString)
#ifdef BOUNDARY_BYTE_MUTANT
import Data.ByteString.Lazy qualified as ByteString
#endif
import System.Exit (ExitCode (ExitSuccess))

data BoundaryTools = BoundaryTools
  { boundaryKubectl :: ToolPath
  , boundaryDocker :: ToolPath
  , boundaryHelmNegativeControl :: ToolPath
  , boundaryPulumi :: ToolPath
  }

mkBoundaryTools :: FilePath -> FilePath -> FilePath -> FilePath -> Either ToolError BoundaryTools
mkBoundaryTools kubectl docker helm pulumi =
  BoundaryTools
    <$> mkToolPath kubectl
    <*> mkToolPath docker
    <*> mkToolPath helm
    <*> mkToolPath pulumi

runBoundaryCorpus :: BoundaryTools -> ByteString -> IO [ToolResult]
runBoundaryCorpus tools manifestBytes = do
  let invocations =
        [ (boundaryKubectl tools, kubectlArguments, kubectlBytes)
        , (boundaryDocker tools, ["build", "--pull=false", "."], "")
        , (boundaryDocker tools, ["push", "amoebius:test"], "")
        , (boundaryPulumi tools, ["up", "--yes", "--skip-preview"], "")
        ]
      _helmNegativeControl = boundaryHelmNegativeControl tools
  results <- mapM (\(tool, arguments, input) -> runTool tool arguments input) invocations
  unless (all ((== ExitSuccess) . toolExitCode) results) (fail ("boundary fixture tool failed: " <> show results))
  pure results
 where
  kubectlArguments =
#ifdef BOUNDARY_ARGV_MUTANT
    ["apply", "--server-side=true", "-f"]
#else
    ["apply", "--server-side=true", "-f", "-"]
#endif
  kubectlBytes =
#ifdef BOUNDARY_BYTE_MUTANT
    flipFirstByte manifestBytes
#else
    manifestBytes
#endif

#ifdef BOUNDARY_BYTE_MUTANT
flipFirstByte :: ByteString -> ByteString
flipFirstByte bytes = case ByteString.uncons bytes of
  Nothing -> "x"
  Just (first, remaining) -> ByteString.cons (first + 1) remaining
#endif

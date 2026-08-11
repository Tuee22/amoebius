{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Exec.Boundary
  ( BoundaryTools
  , mkBoundaryTools
  , runBoundaryCorpus
  ) where

import Amoebius.Exec.Tool
import Control.Monad (unless)
import Data.ByteString.Lazy (ByteString)
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
        [ (boundaryKubectl tools, ["apply", "--server-side=true", "-f", "-"], manifestBytes)
        , (boundaryDocker tools, ["build", "--pull=false", "."], "")
        , (boundaryDocker tools, ["push", "amoebius:test"], "")
        , (boundaryPulumi tools, ["up", "--yes", "--skip-preview"], "")
        ]
      _helmNegativeControl = boundaryHelmNegativeControl tools
  results <- mapM (\(tool, arguments, input) -> runTool tool arguments input) invocations
  unless (all ((== ExitSuccess) . toolExitCode) results) (fail "boundary fixture tool failed")
  pure results

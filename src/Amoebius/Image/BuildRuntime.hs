{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.BuildRuntime
  ( BuildRequest (..)
  , BuildEnactmentResult (..)
  , BuildRuntimeError (..)
  , BuildAction
  , prepareBuildAction
  , enactBuildAction
  , renderBuildRuntimeError
  ) where

import Amoebius.Image.BuildAdmission
  ( BuildAdmissionError
  , ObservedBuildHost (..)
  , ValidatedBuildTarget
  , consumeValidatedBuildTarget
  )
import Control.DeepSeq (NFData)
import Data.Char (isAlphaNum)
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, isRelative, makeRelative, normalise, splitDirectories, (</>))

boundedBuildkitImage :: Text
boundedBuildkitImage =
  "moby/buildkit:buildx-stable-1@sha256:2f5adac4ecd194d9f8c10b7b5d7bceb5186853db1b26e5abd3a657af0b7e26ec"

-- | The only Phase-25.1 build process shape.  Platforms and OCI output are
-- fixed here so callers cannot quietly turn an admitted multi-arch build into
-- two unrelated image builds or a daemon-local image export.
data BuildRequest = BuildRequest
  { buildDockerExecutable :: FilePath
  , buildDockerConfig :: FilePath
  , buildBuilderName :: Text
  , buildDockerfile :: FilePath
  , buildContext :: FilePath
  , buildOciOutput :: FilePath
  , buildCacheRoot :: FilePath
  , buildScratchRoot :: FilePath
  , buildBuildkitConfig :: FilePath
  , buildBuildkitImage :: Text
  , buildBuildkitContainer :: Text
  , buildStateVolume :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BuildEnactmentResult = BuildSucceeded | BuildFailed Int
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BuildRuntimeError
  = BuildRequestPathNotAbsolute FilePath
  | BuildRequestBuilderNameInvalid Text
  | BuildRequestBuildkitImageInvalid Text
  | BuildRequestPathOutsideScratch FilePath
  | BuildRequestBackingAlias FilePath
  | BuildAdmissionRejected BuildAdmissionError
  | BuildActionSnapshotChanged Text Text
  | BuildActionAlreadyConsumed
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BuildAction = BuildAction
  { actionFingerprint :: Text
  , actionRequest :: BuildRequest
  , actionConsumed :: IORef Bool
  }

prepareBuildAction
  :: ValidatedBuildTarget
  -> ObservedBuildHost
  -> BuildRequest
  -> IO (Either BuildRuntimeError BuildAction)
prepareBuildAction target observed request = case validateRequest request of
  Left problem -> pure (Left problem)
  Right () -> do
    admitted <- consumeValidatedBuildTarget target observed
    case admitted of
      Left problem -> pure (Left (BuildAdmissionRejected problem))
      Right _ -> do
        consumed <- newIORef False
        pure
          ( Right
              BuildAction
                { actionFingerprint = observedBuildFingerprint observed
                , actionRequest = request
                , actionConsumed = consumed
                }
          )

-- | Enact through an injected process boundary so tests can prove that every
-- rejection performs zero builder invocations.  Production supplies
-- @readProcess@/typed-process at this one boundary.
enactBuildAction
  :: BuildAction
  -> ObservedBuildHost
  -> (FilePath -> [String] -> IO ExitCode)
  -> IO (Either BuildRuntimeError BuildEnactmentResult)
enactBuildAction action observed runProcess
  | actionFingerprint action /= observedBuildFingerprint observed =
      pure
        ( Left
            ( BuildActionSnapshotChanged
                (actionFingerprint action)
                (observedBuildFingerprint observed)
            )
        )
  | otherwise = do
      won <- atomicModifyIORef' (actionConsumed action) (\consumed -> (True, not consumed))
      if not won
        then pure (Left BuildActionAlreadyConsumed)
        else do
          result <- runInvocations runProcess (buildInvocations (actionRequest action))
          pure (Right result)

renderBuildRuntimeError :: BuildRuntimeError -> Text
renderBuildRuntimeError problem = case problem of
  BuildRequestPathNotAbsolute _ -> "BuildRequestPathNotAbsolute"
  BuildRequestBuilderNameInvalid _ -> "BuildRequestBuilderNameInvalid"
  BuildRequestBuildkitImageInvalid _ -> "BuildRequestBuildkitImageInvalid"
  BuildRequestPathOutsideScratch _ -> "BuildRequestPathOutsideScratch"
  BuildRequestBackingAlias _ -> "BuildRequestBackingAlias"
  BuildAdmissionRejected _ -> "BuildAdmissionRejected"
  BuildActionSnapshotChanged _ _ -> "BuildActionSnapshotChanged"
  BuildActionAlreadyConsumed -> "BuildActionAlreadyConsumed"

validateRequest :: BuildRequest -> Either BuildRuntimeError ()
validateRequest request = do
  mapM_ requireAbsolute
    [ buildDockerExecutable request
    , buildDockerConfig request
    , buildDockerfile request
    , buildContext request
    , buildOciOutput request
    , buildCacheRoot request
    , buildScratchRoot request
    , buildBuildkitConfig request
    ]
  if buildBuildkitImage request /= boundedBuildkitImage
    then Left (BuildRequestBuildkitImageInvalid (buildBuildkitImage request))
    else Right ()
  if all validBuilderName
      [ buildBuilderName request
      , buildBuildkitContainer request
      , buildStateVolume request
      ]
    then Right ()
    else Left (BuildRequestBuilderNameInvalid (buildBuilderName request))
  if normalise (buildCacheRoot request) == normalise (buildScratchRoot request)
    then Left (BuildRequestBackingAlias (buildCacheRoot request))
    else Right ()
  mapM_
    (requireWithin (buildScratchRoot request))
    [buildDockerConfig request, buildOciOutput request]
 where
  requireAbsolute path =
    if isAbsolute path
      then Right ()
      else Left (BuildRequestPathNotAbsolute path)
  requireWithin parent child =
    let relative = makeRelative (normalise parent) (normalise child)
     in if isRelative relative && case splitDirectories relative of
          ".." : _ -> False
          _ -> True
          then Right ()
          else Left (BuildRequestPathOutsideScratch child)

validBuilderName :: Text -> Bool
validBuilderName value =
  not (Text.null value)
    && Text.all (\character -> isAlphaNum character || character `elem` ['-', '_', '.']) value

buildInvocations :: BuildRequest -> [(FilePath, [String])]
buildInvocations request =
  [ ( "/usr/bin/mkdir"
    , [ "-p"
      , buildDockerConfig request
      , buildScratchRoot request </> "buildkit-run"
      , buildScratchRoot request </> "buildkit-tmp"
      , buildScratchRoot request </> "buildkit-state"
      , buildScratchRoot request </> "oci"
      ]
    )
  , docker
      [ "volume", "create", "--driver", "local"
      , "--opt", "type=none", "--opt", "o=bind"
      , "--opt", "device=" <> buildScratchRoot request </> "buildkit-state"
      , Text.unpack (buildStateVolume request)
      ]
  , docker
      [ "run", "--detach", "--name", Text.unpack (buildBuildkitContainer request)
      , "--runtime", "runc", "--privileged"
      , "--cpus", "7", "--memory", "7516192768", "--memory-swap", "7516192768"
      , "--restart", "no"
      , "--mount", "type=volume,source=" <> Text.unpack (buildStateVolume request) <> ",target=/var/lib/buildkit"
      , "--mount", "type=bind,source=" <> buildScratchRoot request <> ",target=/amoebius-scratch"
      , "--mount", "type=bind,source=" <> buildBuildkitConfig request <> ",target=/etc/buildkit/buildkitd.toml,readonly"
      , "--env", "TMPDIR=/amoebius-scratch/buildkit-tmp"
      , Text.unpack (buildBuildkitImage request)
      , "--addr", "unix:///amoebius-scratch/buildkit-run/buildkitd.sock"
      , "--group", "1000"
      , "--config", "/etc/buildkit/buildkitd.toml"
      ]
  , docker
      [ "buildx", "create", "--name", Text.unpack (buildBuilderName request)
      , "--driver", "remote"
      , "unix://" <> buildScratchRoot request </> "buildkit-run/buildkitd.sock"
      ]
  , docker
      [ "buildx", "inspect", "--builder", Text.unpack (buildBuilderName request), "--bootstrap" ]
  , docker
      [ "buildx", "build", "--builder", Text.unpack (buildBuilderName request)
      , "--platform", "linux/amd64,linux/arm64"
      , "--file", buildDockerfile request
      , "--provenance=false"
      , "--sbom=false"
      , "--output", "type=oci,dest=" <> buildOciOutput request
      , "--cache-to", "type=local,dest=" <> buildCacheRoot request </> "buildx-cache,mode=min"
      , buildContext request
      ]
  ]
 where
  docker arguments =
    ( buildDockerExecutable request
    , ["--config", buildDockerConfig request] <> arguments
    )

runInvocations
  :: (FilePath -> [String] -> IO ExitCode)
  -> [(FilePath, [String])]
  -> IO BuildEnactmentResult
runInvocations _ [] = pure BuildSucceeded
runInvocations runProcess ((executable, arguments) : rest) = do
  status <- runProcess executable arguments
  case status of
    ExitSuccess -> runInvocations runProcess rest
    ExitFailure code -> pure (BuildFailed code)

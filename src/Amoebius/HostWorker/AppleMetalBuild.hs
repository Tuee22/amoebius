module Amoebius.HostWorker.AppleMetalBuild
  ( BuildEnvelope (..)
  , AppleMetalBuildPlan
  , AppleMetalBuildError (..)
  , planAppleMetalBuild
  , buildArgv
  , buildEnvironment
  , buildUsesVm
  , buildUsesSwiftPm
  , buildUnlocksKeychain
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Word (Word64)

data BuildEnvelope = BuildEnvelope
  { buildCpuCores :: Word64
  , buildRssBytes :: Word64
  , buildScratchBytes :: Word64
  , buildCacheWriteBytes :: Word64
  , buildScratchPool :: String
  , buildCachePool :: String
  , buildStageConcurrency :: Word64
  }
  deriving stock (Eq, Show)

data AppleMetalBuildPlan = AppleMetalBuildPlan [String] (Map String String)
  deriving stock (Eq, Show)

data AppleMetalBuildError
  = AbsoluteClangRequired
  | EmptyBuildPoolIdentity
  | SerialBuildRequired
  | EmptyBuildEnvelope
  deriving stock (Eq, Show)

planAppleMetalBuild :: FilePath -> FilePath -> FilePath -> BuildEnvelope -> Either AppleMetalBuildError AppleMetalBuildPlan
planAppleMetalBuild clang source output envelope
  | not (absolute clang) = Left AbsoluteClangRequired
  | buildScratchPool envelope == "" || buildCachePool envelope == "" = Left EmptyBuildPoolIdentity
  | buildStageConcurrency envelope /= 1 = Left SerialBuildRequired
  | any (== 0) [buildCpuCores envelope, buildRssBytes envelope, buildScratchBytes envelope, buildCacheWriteBytes envelope] = Left EmptyBuildEnvelope
  | otherwise = Right (AppleMetalBuildPlan
      [clang, "-fno-fast-math", "-framework", "Foundation", "-framework", "Metal", "-dynamiclib", source, "-o", output]
      Map.empty)
 where
  absolute ('/' : _) = True
  absolute _ = False

buildArgv :: AppleMetalBuildPlan -> [String]
buildArgv (AppleMetalBuildPlan argv _) = argv

buildEnvironment :: AppleMetalBuildPlan -> Map String String
buildEnvironment (AppleMetalBuildPlan _ environment) = environment

buildUsesVm :: AppleMetalBuildPlan -> Bool
buildUsesVm _ = False

buildUsesSwiftPm :: AppleMetalBuildPlan -> Bool
buildUsesSwiftPm _ = False

buildUnlocksKeychain :: AppleMetalBuildPlan -> Bool
buildUnlocksKeychain _ = False

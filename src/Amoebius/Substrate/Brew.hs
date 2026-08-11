module Amoebius.Substrate.Brew
  ( BrewTool (..)
  , BrewEnsurePlan (..)
  , planBrewEnsure
  , closedSpawnEnvironment
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

data BrewTool = Lima
  deriving stock (Eq, Show)

data BrewEnsurePlan = AlreadyPresent FilePath | InstallThenResolve [FilePath] FilePath
  deriving stock (Eq, Show)

planBrewEnsure :: FilePath -> Maybe FilePath -> BrewTool -> Either String BrewEnsurePlan
planBrewEnsure brew observed tool
  | not (absolute brew) = Left "brew-path-must-be-absolute"
  | Just path <- observed, absolute path = Right (AlreadyPresent path)
  | Just _ <- observed = Left "resolved-tool-path-must-be-absolute"
  | otherwise = Right (InstallThenResolve [brew, "install", formula tool] brew)
 where
  formula Lima = "lima"
  absolute ('/' : _) = True
  absolute _ = False

closedSpawnEnvironment :: Map String String
closedSpawnEnvironment = Map.empty

{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.Resolver
  ( resolverVersion
  , runResolverCommand
  ) where

import Data.Text (Text)
import Data.Text.IO qualified as Text
import System.Exit (die)

resolverVersion :: Text
resolverVersion = "0.1.0.0"

-- | The Phase-26 packaged resolver entry point.  Catalog materialization and
-- cache ownership remain deliberately unavailable until Phase 49 can supply
-- a provisioned CacheBudget and content-addressed owner.
runResolverCommand :: [String] -> IO ()
runResolverCommand arguments = case arguments of
  ["--version"] -> Text.putStrLn resolverVersion
  _ -> die "jit-build-resolver requires --version before the Phase-49 cache owner is provisioned"

{-# LANGUAGE OverloadedStrings #-}

module GatewayMigrationTrace
  ( PinnedTrace (..)
  , readPinnedTrace
  , validatePinnedTrace
  ) where

import Amoebius.Formal.Model (Value (AtomValue))
import Amoebius.Multicluster.GatewayMigration
import Data.Aeson (FromJSON (..), eitherDecodeFileStrict', withObject, (.:))
import Data.Map.Strict qualified as Map

data PinnedTrace = PinnedTrace
  { pinnedActions :: [String]
  , pinnedBranch :: String
  , pinnedTerminalPhase :: String
  }
  deriving stock (Eq, Show)

instance FromJSON PinnedTrace where
  parseJSON = withObject "PinnedTrace" $ \value -> PinnedTrace
    <$> value .: "actions"
    <*> value .: "branch"
    <*> value .: "terminalPhase"

readPinnedTrace :: FilePath -> IO PinnedTrace
readPinnedTrace path = eitherDecodeFileStrict' path >>= either fail pure

validatePinnedTrace :: PinnedTrace -> MigrationTrace -> Either String ()
validatePinnedTrace pinned trace
  | migrationActions trace /= pinnedActions pinned = Left "trace actions differ from independent golden"
  | terminalPhase /= Just (AtomValue (pinnedTerminalPhase pinned)) = Left "trace terminal phase differs"
  | otherwise = Right ()
 where
  terminalPhase = case reverse (migrationStates trace) of
    [] -> Nothing
    finalState : _ -> Map.lookup "phase" finalState

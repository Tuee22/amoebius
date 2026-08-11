module Amoebius.Sim.Fakes.Vault
  ( VaultState
  , emptyVault
  , runVaultOp
  ) where

import Amoebius.Sim.Env (VaultOp (..), VaultPath, VaultResult (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)

data VaultState = VaultState
  { sealed :: Bool
  , values :: Map VaultPath Text
  }
  deriving stock (Eq, Show)

emptyVault :: Bool -> VaultState
emptyVault isSealed = VaultState isSealed Map.empty

runVaultOp :: VaultOp -> VaultState -> (VaultResult, VaultState)
runVaultOp operation state
  | sealed state = (VaultRejectedSealed, state)
  | otherwise = case operation of
      VaultRead path -> (VaultValue (Map.lookup path (values state)), state)
      VaultWrite path value -> (VaultValue (Just value), state {values = Map.insert path value (values state)})

module Amoebius.Ui.Compile.Demand
  ( RuntimeDemand
  , compileRuntimeDemand
  , browserRouteDemand
  , browserEventDemand
  , browserLinkDemand
  , serverActionDemand
  , serverContractDemand
  , authoritySourceDemand
  ) where

import Amoebius.Ui.Bind
  ( BoundUiProgram
  , UiClientInstruction (..)
  , boundAuthoritySource
  , boundUiProjection
  , compiledInstruction
  , compiledRoute
  )
import qualified Data.Set as Set

data RuntimeDemand = RuntimeDemand
  { browserRouteDemand :: Int
  , browserEventDemand :: Int
  , browserLinkDemand :: Int
  , serverActionDemand :: Int
  , serverContractDemand :: Int
  , authoritySourceDemand :: Int
  }
  deriving stock (Eq, Ord, Show)

compileRuntimeDemand :: BoundUiProgram -> RuntimeDemand
compileRuntimeDemand program = RuntimeDemand
  { browserRouteDemand = Set.size (Set.fromList (map compiledRoute rows))
  , browserEventDemand = length events
  , browserLinkDemand = length links
  , serverActionDemand = length events
  , serverContractDemand = length events
  , authoritySourceDemand = length (boundAuthoritySource program)
  }
  where
    rows = boundUiProjection program
    events = [() | row <- rows, EmitEvent _ _ <- [compiledInstruction row]]
    links = [() | row <- rows, NavigateExternal _ <- [compiledInstruction row]]

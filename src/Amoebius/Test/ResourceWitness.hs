module Amoebius.Test.ResourceWitness
  ( ResourceWitness
  , resourceWitness
  , witnessedSupply
  , witnessedDemand
  ) where

import Amoebius.Test.Topology

data ResourceWitness = ResourceWitness ResourceVector ResourceVector
  deriving stock (Eq, Show)

resourceWitness :: ProvisionedTestTopology -> ResourceWitness
resourceWitness provisioned = ResourceWitness
  (topologySupply topology)
  (topologyDemand topology)
 where
  topology = provisionedTopology provisioned

witnessedSupply :: ResourceWitness -> ResourceVector
witnessedSupply (ResourceWitness supply _) = supply

witnessedDemand :: ResourceWitness -> ResourceVector
witnessedDemand (ResourceWitness _ demand) = demand

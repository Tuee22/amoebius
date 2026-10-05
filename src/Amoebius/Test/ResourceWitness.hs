module Amoebius.Test.ResourceWitness
  ( ResourceWitness
  , resourceWitness
  , witnessedSupply
  , witnessedDemand
  ) where

import Amoebius.Test.Topology

data ResourceWitness = ResourceWitness TestResourceVector TestResourceVector
  deriving stock (Eq, Show)

resourceWitness :: ProvisionedTestTopology -> ResourceWitness
resourceWitness provisioned = ResourceWitness
  (topologySupply topology)
  (topologyDemand topology)
 where
  topology = provisionedTopology provisioned

witnessedSupply :: ResourceWitness -> TestResourceVector
witnessedSupply (ResourceWitness supply _) = supply

witnessedDemand :: ResourceWitness -> TestResourceVector
witnessedDemand (ResourceWitness _ demand) = demand

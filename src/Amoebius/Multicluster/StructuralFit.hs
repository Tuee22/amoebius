module Amoebius.Multicluster.StructuralFit
  ( MigrationEdge (..)
  , FitClause (..)
  , FitMode (..)
  , structuralFit
  , structuralFitWith
  ) where

import Amoebius.Formal.GatewayMigration
import Data.List (group, nub, sort)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set

data MigrationEdge = MigrationEdge
  { edgeActive :: String
  , edgeStandby :: String
  , edgeDnsRecord :: String
  , edgeDataLossBudget :: Integer
  , edgeTtl :: Integer
  , edgeFreshnessBound :: Integer
  , edgeMaxOffset :: Integer
  }
  deriving stock (Eq, Ord, Show)

data FitClause
  = Pairwise
  | GraphIndependent
  | ResourceIndependent
  | Acyclic
  | BudgetWithinCap
  | TtlInRegime
  | FreshnessInRegime
  | OffsetDomainWithinConstants
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data FitMode
  = CompleteFit
  | DeleteClause FitClause
  deriving stock (Eq, Ord, Show)

structuralFit :: [MigrationEdge] -> Either [FitClause] ()
structuralFit = structuralFitWith CompleteFit

structuralFitWith :: FitMode -> [MigrationEdge] -> Either [FitClause] ()
structuralFitWith mode edges = case failures of
  [] -> Right ()
  _ -> Left failures
  where
    failures =
      [ clause
      | (clause, holds) <- checks edges
      , not holds
      , mode /= DeleteClause clause
      ]

checks :: [MigrationEdge] -> [(FitClause, Bool)]
checks edges =
  [ (Pairwise, noDuplicates (map edgeActive edges))
  , (GraphIndependent, noDuplicates (map edgeDnsRecord edges))
  , (ResourceIndependent, resourcesIndependent edges)
  , (Acyclic, graphAcyclic edges)
  , (BudgetWithinCap, all ((<= maxDataLoss) . edgeDataLossBudget) edges)
  , (TtlInRegime, all (\edge -> edgeTtl edge >= minTtl && edgeTtl edge <= maxTtl) edges)
  , (FreshnessInRegime, all ((<= maxFreshness) . edgeFreshnessBound) edges)
  , (OffsetDomainWithinConstants, all ((<= maxOffset) . edgeMaxOffset) edges)
  ]

noDuplicates :: Ord value => [value] -> Bool
noDuplicates values = all ((== 1) . length) (group (sort values))

resourcesIndependent :: [MigrationEdge] -> Bool
resourcesIndependent edges =
  all (\edge -> edgeActive edge /= edgeStandby edge) edges
    && noDuplicates (concat [[edgeActive edge, edgeStandby edge] | edge <- edges])

graphAcyclic :: [MigrationEdge] -> Bool
graphAcyclic edges = all (not . reachesSelf) vertices
  where
    adjacency = Map.fromListWith (<>) [(edgeActive edge, [edgeStandby edge]) | edge <- edges]
    vertices = nub (concat [[edgeActive edge, edgeStandby edge] | edge <- edges])
    reachesSelf start = walk Set.empty start start
    walk visited origin current
      | current `Set.member` visited = False
      | otherwise = any (\next -> next == origin || walk (Set.insert current visited) origin next)
          (Map.findWithDefault [] current adjacency)

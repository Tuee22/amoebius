{-# LANGUAGE OverloadedStrings #-}

module DepGraphOracle
  ( expectedAllowEdges
  ) where

import Amoebius.Manifest.K8sObject
  ( DependencyEdge (DependencyEdge)
  , K8sObject (..)
  , ObjectMetadata (..)
  )
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set

-- Hand-authored dependency-graph rule: each capability policy admits only
-- its own declared service owner. No renderer connectivity helper is reused.
expectedAllowEdges :: K8sObject -> Set DependencyEdge
expectedAllowEdges object = case Map.lookup "amoebius.io/owner" (metadataLabels (objectMetadata object)) of
  Nothing -> Set.empty
  Just owner -> Set.singleton (DependencyEdge owner owner)

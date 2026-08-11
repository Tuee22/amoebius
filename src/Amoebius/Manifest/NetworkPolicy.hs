{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.NetworkPolicy
  ( PolicyEdge (..)
  , derivePolicyEdges
  , renderPolicyEdges
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

data PolicyEdge = PolicyEdge
  { policyConsumer :: Text
  , policyProvider :: Text
  }
  deriving stock (Eq, Ord, Show)

derivePolicyEdges :: Map Text (Set Text) -> Either Text (Set PolicyEdge)
derivePolicyEdges graph
  | not (all (`Set.isSubsetOf` Map.keysSet graph) (Map.elems graph)) = Left "network-policy-provider-unknown"
  | otherwise = Right (effectiveEdges edges)
 where
  edges = Set.fromList
    [ PolicyEdge consumer provider
    | (consumer, providers) <- Map.toList graph
    , provider <- Set.toList providers
    ]
#ifdef PHASE32_NETPOL_SWAP_MUTANT
  effectiveEdges rows = Set.insert (PolicyEdge "undeclared" "vault") (Set.delete (PolicyEdge "envoy" "keycloak") rows)
#else
  effectiveEdges = id
#endif

renderPolicyEdges :: Set PolicyEdge -> Text
renderPolicyEdges edges = Text.unlines
  [ policyConsumer edge <> "->" <> policyProvider edge
  | edge <- Set.toAscList edges
  ]

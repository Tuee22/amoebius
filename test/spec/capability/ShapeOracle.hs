{-# LANGUAGE OverloadedStrings #-}

module ShapeOracle
  ( objectNodeMultiset
  , structurallyDifferentByNodeMultiset
  , validateBoundExecutionInventory
  , normalizedAppSlice
  ) where

import Amoebius.Capability.Types
  ( BoundExecutionSet (..)
  , BoundServiceSpec (..)
  , ControllerChildEnvelope (..)
  , ProviderObject (..)
  )
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Dhall qualified
import Dhall.Core qualified as Core
import System.Directory (makeAbsolute)

-- | Independently classify object nodes only by kind and role.  Identities,
-- shape tags, and every scalar field are excluded from this oracle.
objectNodeMultiset :: BoundServiceSpec -> Map (Text, Text) Int
objectNodeMultiset service =
  Map.fromListWith (+)
    [ ((providerObjectKind object, providerObjectRole object), 1)
    | object <- boundProviderGraph service
    ]

structurallyDifferentByNodeMultiset :: BoundServiceSpec -> BoundServiceSpec -> Bool
structurallyDifferentByNodeMultiset single distributed =
  memberCount single == 1
    && memberCount distributed >= 2
    && objectNodeMultiset single /= objectNodeMultiset distributed
    && roleCount "member-discovery" single == 0
    && roleCount "member-discovery" distributed == 1
    && roleCount "quorum-policy" single == 0
    && roleCount "quorum-policy" distributed == 1
 where
  memberCount = roleCount "member"

roleCount :: Text -> BoundServiceSpec -> Int
roleCount role service =
  length [() | object <- boundProviderGraph service, providerObjectRole object == role]

validateBoundExecutionInventory :: BoundServiceSpec -> Bool
validateBoundExecutionInventory service =
  runnableKeys == Map.keysSet units
    && childKeys == Map.keysSet units
    && length children == Map.size units
    && all childJoinsUnit children
 where
  units = boundExecutionUnits (boundServiceExecutions service)
  children = boundControllerChildren service
  runnableKeys =
    Set.fromList
      [ providerObjectIdentity object
      | object <- boundProviderGraph service
      , providerObjectRole object `elem` ["member", "bootstrap"]
      ]
  childKeys = Set.fromList (fmap childIdentity children)
  childJoinsUnit child =
    childSourceObject child == childIdentity child
      && Map.lookup (childIdentity child) units == Just (childExecutionUnit child)

normalizedAppSlice :: FilePath -> IO Text
normalizedAppSlice path = do
  absolute <- makeAbsolute path
  expression <- Dhall.inputExpr ("(" <> Text.pack absolute <> ").app")
  pure (Core.pretty expression)

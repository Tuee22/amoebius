{-# LANGUAGE CPP #-}

module Amoebius.Dsl.ChildInForceSpec
  ( ParentForest
  , ForestNode
  , ChildInForceSpec
  , ProjectionError (..)
  , parentForest
  , subtree
  , projectSubtree
  , childClusterId
  , childPath
  , childOwnPayload
  , childVisibleClusters
  ) where

import Data.Text (Text)

data ForestNode = ForestNode
  { nodeClusterId :: Text
  , nodePayload :: Text
  , nodeChildren :: [ForestNode]
  }
  deriving stock (Eq, Show)

newtype ParentForest = ParentForest ForestNode
  deriving stock (Eq, Show)

data ChildInForceSpec = ChildInForceSpec
  { childClusterId :: Text
  , childPath :: [Text]
  , childOwnPayload :: Text
  , childVisibleClusters :: [Text]
  }
  deriving stock (Eq, Show)

data ProjectionError
  = EmptyChildPath
  | ChildPathNotFound [Text]
  deriving stock (Eq, Show)

parentForest :: Text -> Text -> [ForestNode] -> ParentForest
parentForest cluster payload children = ParentForest (ForestNode cluster payload children)

subtree :: Text -> Text -> [ForestNode] -> ForestNode
subtree = ForestNode

projectSubtree :: [Text] -> ParentForest -> Either ProjectionError ChildInForceSpec
projectSubtree [] _ = Left EmptyChildPath
projectSubtree wanted (ParentForest root) = case descend wanted root of
  Nothing -> Left (ChildPathNotFound wanted)
  Just selected ->
    Right ChildInForceSpec
      { childClusterId = nodeClusterId selected
      , childPath = nodeClusterId root : wanted
      , childOwnPayload = nodePayload selected
#ifdef PHASE42_PROJECT_IDENTITY_MUTANT
      , childVisibleClusters = flatten root
#else
      , childVisibleClusters = flatten selected
#endif
      }

descend :: [Text] -> ForestNode -> Maybe ForestNode
descend [] node = Just node
descend (segment : rest) node = do
  child <- findChild segment (nodeChildren node)
  descend rest child

findChild :: Text -> [ForestNode] -> Maybe ForestNode
findChild _ [] = Nothing
findChild wanted (candidate : rest)
  | nodeClusterId candidate == wanted = Just candidate
  | otherwise = findChild wanted rest

flatten :: ForestNode -> [Text]
flatten node = nodeClusterId node : concatMap flatten (nodeChildren node)

{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Check
  ( CheckedUiProgram
  , UiCheckError (..)
  , checkUiSource
  , checkedCaseName
  , checkedGraphRows
  ) where

import Amoebius.Ui.Source
import Control.Monad (foldM)
import Data.List (find, group, sort, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Maybe (listToMaybe)

data UiCheckError
  = RecursiveEffect Text Text
  | UnboundedCollection Text Text
  | DuplicateQualifiedId Text Text
  | MissingReference Text Text
  | DuplicateExternalLinkRequirement Text Text
  | PortTypeMismatch Text Text
  | NonExhaustiveEvent Text Text
  | PrivateValueProjection Text Text
  deriving stock (Eq, Ord, Show)

data CheckedUiProgram = CheckedUiProgram
  { checkedSource :: UiSource
  , checkedNodes :: Map Text UiNode
  }

checkUiSource :: UiSource -> Either UiCheckError CheckedUiProgram
checkUiSource source = do
  table <- buildNodeTable source
  checkCycles table
  checkReferences table
  checkBounds table
  checkLinks (externalLinks source)
  checkPorts table
  checkEvents table
  checkPublicProjection table
  pure (CheckedUiProgram (normalize source) table)

checkedCaseName :: CheckedUiProgram -> Text
checkedCaseName = caseName . checkedSource

checkedGraphRows :: CheckedUiProgram -> [(Text, NodeKind, ValueType, [Text], [Text])]
checkedGraphRows checked =
  [ (qualified, nodeKind node, valueType node, qualifyEdges qualified node, sort (events node))
  | (qualified, node) <- Map.toAscList (checkedNodes checked)
  ]

buildNodeTable :: UiSource -> Either UiCheckError (Map Text UiNode)
buildNodeTable source = do
  let rows =
        [ (moduleId uiModule <> "." <> nodeId node, node)
        | uiModule <- modules source
        , node <- nodes uiModule
        ]
      duplicate = findDuplicate (map fst rows)
  case duplicate of
    Just qualified -> Left (DuplicateQualifiedId qualified "ui.module:1")
    Nothing -> pure (Map.fromList rows)

checkCycles :: Map Text UiNode -> Either UiCheckError ()
checkCycles table = foldM visitRoot () (Map.keys table)
  where
    visitRoot () root = walk Set.empty root
    walk stack current
      | current `Set.member` stack = Left (RecursiveEffect current "ui.effect:1")
      | otherwise = case Map.lookup current table of
          Nothing -> pure ()
          Just node -> foldM (\() target -> walk (Set.insert current stack) target) () (qualifyEdges current node)

checkReferences :: Map Text UiNode -> Either UiCheckError ()
checkReferences table = case find (`Map.notMember` table) targets of
  Just missing -> Left (MissingReference missing "ui.graph:1")
  Nothing -> pure ()
  where
    targets = concat [qualifyEdges qualified node | (qualified, node) <- Map.toList table]

checkBounds :: Map Text UiNode -> Either UiCheckError ()
checkBounds table = case find invalid (Map.toAscList table) of
  Just (qualified, _) -> Left (UnboundedCollection qualified "ui.collection:1")
  Nothing -> pure ()
  where
    invalid (_, node) = case maxItems node of
      Nothing -> True
      Just bound -> bound == 0 || bound > 64

checkLinks :: [ExternalLinkRequirement] -> Either UiCheckError ()
checkLinks requirements = case findDuplicate (map name requirements) of
  Just duplicate -> Left (DuplicateExternalLinkRequirement duplicate "ui.link:2")
  Nothing -> pure ()

checkPorts :: Map Text UiNode -> Either UiCheckError ()
checkPorts table = case find invalid (Map.toAscList table) of
  Just (qualified, _) -> Left (PortTypeMismatch qualified "ui.port:1")
  Nothing -> pure ()
  where
    invalid (_, node) = case nodeKind node of
      Port -> portType node /= Just (valueType node)
      _ -> portType node /= Nothing

checkEvents :: Map Text UiNode -> Either UiCheckError ()
checkEvents table = case find invalid (Map.toAscList table) of
  Just (qualified, _) -> Left (NonExhaustiveEvent qualified "ui.event:1")
  Nothing -> pure ()
  where
    invalid (_, node) = sort (events node) /= sort (branches node)

checkPublicProjection :: Map Text UiNode -> Either UiCheckError ()
checkPublicProjection table = case find invalid (Map.toAscList table) of
  Just (qualified, _) -> Left (PrivateValueProjection qualified "ui.projection:1")
  Nothing -> pure ()
  where
    invalid (_, node) = public node && valueType node == ServerHandle

normalize :: UiSource -> UiSource
normalize source =
  source
    { modules =
        [ uiModule {nodes = sortOn nodeId (nodes uiModule)}
        | uiModule <- sortOn moduleId (modules source)
        ]
    , externalLinks = sortOn name (externalLinks source)
    }

qualifyEdges :: Text -> UiNode -> [Text]
qualifyEdges qualified node =
  let modulePrefix = Text.intercalate "." (initSafe (Text.splitOn "." qualified))
   in sort [if "." `Text.isInfixOf` edge then edge else modulePrefix <> "." <> edge | edge <- edges node]

initSafe :: [value] -> [value]
initSafe [] = []
initSafe [_] = []
initSafe (value : values) = value : initSafe values

findDuplicate :: Ord value => [value] -> Maybe value
findDuplicate values = listToMaybe [value | duplicates@(value : _) <- group (sort values), length duplicates > 1]

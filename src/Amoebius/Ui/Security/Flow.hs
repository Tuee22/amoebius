{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Security.Flow
  ( Audience (..)
  , Integrity (..)
  , Provenance (..)
  , FlowLabel
  , CanFlowTo
  , FlowError (..)
  , subjectLabel
  , tenantLabel
  , publicLabel
  , checkFlow
  , checkFlowPath
  ) where

import Amoebius.Ui.Security.Scope (Subject, Tenant)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)

data Audience = SubjectAudience | TenantAudience | PublicAudience
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data Integrity = LowIntegrity | HighIntegrity
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data Provenance = TrustedServer | AuthoredPublic | ProviderResult
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data FlowLabel = FlowLabel
  { labelTenant :: Tenant
  , labelSubject :: Maybe Subject
  , labelAudience :: Audience
  , labelIntegrity :: Integrity
  , labelProvenance :: Provenance
  }
  deriving stock (Eq, Ord, Show)

data CanFlowTo = CanFlowTo FlowLabel FlowLabel
  deriving stock (Eq, Ord, Show)

data FlowError
  = TenantFlowMismatch
  | SubjectFlowMismatch
  | AudienceWidening
  | IntegrityElevation
  | MissingFlowMember [Text]
  | FlowCycleDetected [Text]
  | FlowPathMissing [Text]
  | TransitiveLeak [Text] FlowError
  deriving stock (Eq, Ord, Show)

subjectLabel :: Tenant -> Subject -> Integrity -> Provenance -> FlowLabel
subjectLabel tenant subject integrity provenance =
  FlowLabel tenant (Just subject) SubjectAudience integrity provenance

tenantLabel :: Tenant -> Integrity -> Provenance -> FlowLabel
tenantLabel tenant integrity provenance =
  FlowLabel tenant Nothing TenantAudience integrity provenance

publicLabel :: Tenant -> Integrity -> Provenance -> FlowLabel
publicLabel tenant integrity provenance =
  FlowLabel tenant Nothing PublicAudience integrity provenance

checkFlow :: FlowLabel -> FlowLabel -> Either FlowError CanFlowTo
checkFlow source sink
  | labelTenant source /= labelTenant sink = Left TenantFlowMismatch
  | labelIntegrity source == LowIntegrity && labelIntegrity sink == HighIntegrity = Left IntegrityElevation
  | labelAudience source /= labelAudience sink = Left AudienceWidening
  | labelAudience source == SubjectAudience && labelSubject source /= labelSubject sink = Left SubjectFlowMismatch
  | otherwise = Right (CanFlowTo source sink)

checkFlowPath
  :: Map Text FlowLabel
  -> [(Text, Text)]
  -> Text
  -> Text
  -> Either FlowError [CanFlowTo]
checkFlowPath labels edges source sink = do
  checkMembers labels edges source sink
  checkReachableCycles edges source
  path <- maybe (Left (FlowPathMissing [source, sink])) Right (findPath edges source sink)
  checkPath labels path

checkMembers :: Map Text FlowLabel -> [(Text, Text)] -> Text -> Text -> Either FlowError ()
checkMembers labels edges source sink =
  let members = source : sink : concatMap (\(left, right) -> [left, right]) edges
      missing = filter (`Map.notMember` labels) members
   in if null missing then Right () else Left (MissingFlowMember missing)

checkReachableCycles :: [(Text, Text)] -> Text -> Either FlowError ()
checkReachableCycles edges = walk Set.empty []
  where
    walk :: Set Text -> [Text] -> Text -> Either FlowError ()
    walk visited stack current
      | current `elem` stack = Left (FlowCycleDetected (reverse (current : stack)))
      | current `Set.member` visited = Right ()
      | otherwise =
          foldMapEither (walk (Set.insert current visited) (current : stack)) (neighbors edges current)

findPath :: [(Text, Text)] -> Text -> Text -> Maybe [Text]
findPath edges source sink = search Set.empty [[source]]
  where
    search _ [] = Nothing
    search visited (path@(current : _) : rest)
      | current == sink = Just (reverse path)
      | current `Set.member` visited = search visited rest
      | otherwise =
          let extended = [next : path | next <- neighbors edges current]
           in search (Set.insert current visited) (rest <> extended)
    search visited ([] : rest) = search visited rest

checkPath :: Map Text FlowLabel -> [Text] -> Either FlowError [CanFlowTo]
checkPath labels path = go path
  where
    go (left : right : rest) = do
      source <- maybe (Left (MissingFlowMember [left])) Right (Map.lookup left labels)
      sink <- maybe (Left (MissingFlowMember [right])) Right (Map.lookup right labels)
      witness <- case checkFlow source sink of
        Left problem
          | length path > 2 -> Left (TransitiveLeak path problem)
          | otherwise -> Left problem
        Right value -> Right value
      remaining <- go (right : rest)
      pure (witness : remaining)
    go _ = Right []

neighbors :: [(Text, Text)] -> Text -> [Text]
neighbors edges current = [right | (left, right) <- edges, left == current]

foldMapEither :: (value -> Either problem ()) -> [value] -> Either problem ()
foldMapEither check = go
  where
    go [] = Right ()
    go (value : rest) = check value >> go rest

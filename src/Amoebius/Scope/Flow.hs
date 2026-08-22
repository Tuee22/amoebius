module Amoebius.Scope.Flow
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

import Amoebius.Scope.Index
  ( RequestScope
  , ScopeError (TenantMismatch)
  , Subject
  , scopeTenant
  , subjectTenant
  )
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

data FlowLabel scope = FlowLabel
  { labelSubject :: Maybe Subject
  , labelAudience :: Audience
  , labelIntegrity :: Integrity
  , labelProvenance :: Provenance
  }
  deriving stock (Eq, Ord, Show)

data CanFlowTo scope = CanFlowTo (FlowLabel scope) (FlowLabel scope)
  deriving stock (Eq, Ord, Show)

data FlowError
  = SubjectFlowMismatch
  | AudienceWidening
  | IntegrityElevation
  | MissingFlowMember [Text]
  | FlowCycleDetected [Text]
  | FlowPathMissing [Text]
  | TransitiveLeak [Text] FlowError
  deriving stock (Eq, Ord, Show)

subjectLabel
  :: RequestScope scope
  -> Subject
  -> Integrity
  -> Provenance
  -> Either ScopeError (FlowLabel scope)
subjectLabel request subject integrity provenance
  | subjectTenant subject /= scopeTenant request = Left TenantMismatch
  | otherwise = Right (FlowLabel (Just subject) SubjectAudience integrity provenance)

tenantLabel :: RequestScope scope -> Integrity -> Provenance -> FlowLabel scope
tenantLabel _ = FlowLabel Nothing TenantAudience

publicLabel :: RequestScope scope -> Integrity -> Provenance -> FlowLabel scope
publicLabel _ = FlowLabel Nothing PublicAudience

checkFlow :: FlowLabel scope -> FlowLabel scope -> Either FlowError (CanFlowTo scope)
checkFlow source sink
  | labelIntegrity source == LowIntegrity && labelIntegrity sink == HighIntegrity = Left IntegrityElevation
  | labelAudience source /= labelAudience sink = Left AudienceWidening
  | labelAudience source == SubjectAudience && labelSubject source /= labelSubject sink = Left SubjectFlowMismatch
  | otherwise = Right (CanFlowTo source sink)

checkFlowPath
  :: Map Text (FlowLabel scope)
  -> [(Text, Text)]
  -> Text
  -> Text
  -> Either FlowError [CanFlowTo scope]
checkFlowPath labels edges source sink = do
  checkMembers labels edges source sink
  checkReachableCycles edges source
  path <- maybe (Left (FlowPathMissing [source, sink])) Right (findPath edges source sink)
  checkPath labels path

checkMembers :: Map Text (FlowLabel scope) -> [(Text, Text)] -> Text -> Text -> Either FlowError ()
checkMembers labels edges source sink =
  let members = source : sink : concatMap (\(left, right) -> [left, right]) edges
      (_, missing) = foldl collectMissing (Set.empty, []) members
   in if null missing then Right () else Left (MissingFlowMember missing)
  where
    collectMissing (seen, missing) member
      | member `Set.member` seen = (seen, missing)
      | member `Map.member` labels = (Set.insert member seen, missing)
      | otherwise = (Set.insert member seen, missing <> [member])

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

checkPath :: Map Text (FlowLabel scope) -> [Text] -> Either FlowError [CanFlowTo scope]
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

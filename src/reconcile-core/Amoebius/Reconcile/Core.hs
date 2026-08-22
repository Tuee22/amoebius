{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module Amoebius.Reconcile.Core
  ( Presence (..)
  , ResourceId (..)
  , DesiredRevision (..)
  , DesiredIndex
  , desiredIndex
  , Observation (..)
  , SomeObservation (..)
  , ObservedInventory
  , observedInventory
  , inventoryEntries
  , Action (..)
  , SomeAction (..)
  , ActionSet
  , Refusal (..)
  , planReconcile
  , renderAction
  , renderObservation
  , inventorySemantic
  , applyActionToInventory
  ) where

import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)

data Presence = IsPresent | IsAbsent | IsUnreachable

newtype ResourceId = ResourceId {unResourceId :: Text}
  deriving stock (Eq, Ord, Show)

newtype DesiredRevision = DesiredRevision {unDesiredRevision :: Text}
  deriving stock (Eq, Ord, Show)

newtype DesiredIndex = DesiredIndex (Map ResourceId DesiredRevision)
  deriving stock (Eq, Show)

desiredIndex :: [(ResourceId, DesiredRevision)] -> DesiredIndex
desiredIndex = DesiredIndex . Map.fromList

data Observation (presence :: Presence) where
  PresentObservation :: Text -> Observation 'IsPresent
  AbsentObservation :: Observation 'IsAbsent
  UnreachableObservation :: Text -> Observation 'IsUnreachable

deriving instance Eq (Observation presence)
deriving instance Show (Observation presence)

data SomeObservation where
  SomeObservation :: Observation presence -> SomeObservation

instance Eq SomeObservation where
  left == right = renderObservation left == renderObservation right

instance Show SomeObservation where
  show = show . renderObservation

newtype ObservedInventory = ObservedInventory (Map ResourceId SomeObservation)
  deriving stock (Eq, Show)

observedInventory :: [(ResourceId, SomeObservation)] -> ObservedInventory
observedInventory = ObservedInventory . Map.fromList

inventoryEntries :: ObservedInventory -> [(ResourceId, SomeObservation)]
inventoryEntries (ObservedInventory entries) = Map.toAscList entries

data Action (presence :: Presence) where
  CreateObject
    :: ResourceId
    -> DesiredRevision
    -> Observation 'IsAbsent
    -> Action 'IsAbsent
  ApplyObject
    :: ResourceId
    -> DesiredRevision
    -> Observation 'IsPresent
    -> Action 'IsPresent
  DeleteObject
    :: ResourceId
    -> Observation 'IsPresent
    -> Action 'IsPresent

deriving instance Show (Action presence)

data SomeAction where
  SomeAction :: Action presence -> SomeAction

instance Eq SomeAction where
  left == right = renderAction left == renderAction right

instance Show SomeAction where
  show = show . renderAction

type ActionSet = [SomeAction]

data Refusal
  = ObservationUnreachable [ResourceId]
  | ObservationMissing [ResourceId]
  deriving stock (Eq, Show)

planReconcile :: ObservedInventory -> DesiredIndex -> Either Refusal ActionSet
planReconcile (ObservedInventory observed) (DesiredIndex desired)
  | not (null unreachable) = Left (ObservationUnreachable unreachable)
  | not (null missing) = Left (ObservationMissing missing)
  | otherwise = Right (concatMap decide domain)
 where
  domain = Set.toAscList (Map.keysSet observed `Set.union` Map.keysSet desired)
  missing = Set.toAscList (Map.keysSet desired `Set.difference` Map.keysSet observed)
  unreachable =
    [ identifier
    | (identifier, SomeObservation UnreachableObservation {}) <- Map.toAscList observed
    ]

  decide identifier = case (Map.lookup identifier observed, Map.lookup identifier desired) of
    (Just (SomeObservation present@(PresentObservation current)), Just wanted)
      | current == unDesiredRevision wanted -> []
      | otherwise -> [SomeAction (ApplyObject identifier wanted present)]
    (Just (SomeObservation absent@AbsentObservation), Just wanted) ->
      [SomeAction (CreateObject identifier wanted absent)]
    (Just (SomeObservation present@PresentObservation {}), Nothing) ->
      [SomeAction (DeleteObject identifier present)]
    (Just (SomeObservation AbsentObservation), Nothing) -> []
    (Just (SomeObservation UnreachableObservation {}), _) -> []
    (Nothing, _) -> []

renderAction :: SomeAction -> Text
renderAction (SomeAction action) = case action of
  CreateObject identifier revision _ ->
    "create:" <> unResourceId identifier <> "@" <> unDesiredRevision revision
  ApplyObject identifier revision (PresentObservation current) ->
    "apply:" <> unResourceId identifier <> ":" <> current <> "->" <> unDesiredRevision revision
  DeleteObject identifier (PresentObservation current) ->
    "delete:" <> unResourceId identifier <> "@" <> current

renderObservation :: SomeObservation -> Text
renderObservation (SomeObservation observation) = case observation of
  PresentObservation revision -> "present:" <> revision
  AbsentObservation -> "absent"
  UnreachableObservation reason -> "unreachable:" <> reason

inventorySemantic :: ObservedInventory -> [Text]
inventorySemantic (ObservedInventory entries) = sort
  [unResourceId identifier <> "=" <> renderObservation observation | (identifier, observation) <- Map.toList entries]

applyActionToInventory :: SomeAction -> ObservedInventory -> ObservedInventory
applyActionToInventory (SomeAction action) (ObservedInventory entries) =
  ObservedInventory $ case action of
    CreateObject identifier revision _ -> present identifier revision
    ApplyObject identifier revision _ -> present identifier revision
    DeleteObject identifier _ -> Map.insert identifier (SomeObservation AbsentObservation) entries
 where
  present identifier revision =
    Map.insert identifier (SomeObservation (PresentObservation (unDesiredRevision revision))) entries

module Amoebius.Formal.Explore
  ( Violation (..)
  , ExploreResult (..)
  , explore
  , canonicalFingerprint
  , renderCanonicalValue
  ) where

import Amoebius.Formal.Interpret
import Amoebius.Formal.Model
import Data.List (intercalate, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set

data Violation = Violation
  { violationInvariant :: Name
  , violationFingerprint :: String
  }
  deriving stock (Eq, Ord, Show)

data ExploreResult = ExploreResult
  { exploreStates :: Map String State
  , exploreViolation :: Maybe Violation
  , exploreBoundaryStates :: Set String
  }
  deriving stock (Eq, Show)

explore :: Model -> Either String ExploreResult
explore model = do
  initial <- initialState model
  allowed <- satisfiesConstraint initial
  if not allowed
    then Right (ExploreResult Map.empty Nothing Set.empty)
    else walk Map.empty Set.empty [initial] Nothing
  where
    walk seen boundaries [] violation = Right (ExploreResult seen violation boundaries)
    walk seen boundaries (state : queue) violation = do
      let fingerprint = canonicalFingerprint model state
      if Map.member fingerprint seen
        then walk seen boundaries queue violation
        else do
          currentViolation <- firstViolation state
          expandable <- satisfiesExpansionLimit state
          successors <- if expandable then traverseSuccessors state else Right []
          let seen' = Map.insert fingerprint state seen
              boundaries' = if expandable then boundaries else Set.insert fingerprint boundaries
              violation' = violation <|> currentViolation
          walk seen' boundaries' (queue <> successors) violation'

    traverseSuccessors state = do
      candidates <- traverse toCandidate (enabledEvents model state)
      pure [successor | Just successor <- candidates]
      where
        toCandidate event = case interpret model event state of
          Nothing -> Right Nothing
          Just successor -> do
            allowed <- satisfiesConstraint successor
            pure (if allowed then Just successor else Nothing)

    satisfiesConstraint state = case modelConstraint model of
      Nothing -> Right True
      Just named -> evalExpr model Map.empty state (namedExprBody named) >>= valueAsBool

    satisfiesExpansionLimit state = case modelExpansionLimit model of
      Nothing -> Right True
      Just expr -> evalExpr model Map.empty state expr >>= valueAsBool

    firstViolation state = go (modelInvariants model)
      where
        go [] = Right Nothing
        go (named : rest) = do
          valid <- evalExpr model Map.empty state (namedExprBody named) >>= valueAsBool
          if valid
            then go rest
            else Right (Just (Violation (namedExprName named) (canonicalFingerprint model state)))

    (<|>) (Just value) _ = Just value
    (<|>) Nothing other = other

canonicalFingerprint :: Model -> State -> String
canonicalFingerprint model state = intercalate "|"
  [ name <> "=" <> maybe "<missing>" renderCanonicalValue (Map.lookup name state)
  | name <- modelVariables model
  ]

renderCanonicalValue :: Value -> String
renderCanonicalValue value = case value of
  BoolValue True -> "TRUE"
  BoolValue False -> "FALSE"
  IntValue integer -> show integer
  AtomValue atom -> show atom
  SetValue values -> "{" <> intercalate "," (map renderCanonicalValue (sortOn renderCanonicalValue values)) <> "}"
  FunctionValue pairs -> "[" <> intercalate "," rendered <> "]"
    where
      rendered =
        [ renderCanonicalValue key <> "|->" <> renderCanonicalValue result
        | (key, result) <- sortOn (renderCanonicalValue . fst) pairs
        ]

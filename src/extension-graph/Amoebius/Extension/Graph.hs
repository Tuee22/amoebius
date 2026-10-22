{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Total link-graph refinement shared by the statically compiled catalog.
-- The concrete contributed-source catalog is added at the admission seam;
-- this module alone cannot admit a source file or mint a scope.
module Amoebius.Extension.Graph
  ( LinkSet, LinkRefusal (..), Provider (..), mergeExtensions
  , extensionsIn, providerFor, extensionOrder, linkRefusalTag
  , BindingProof, proveBinding, bindingIssuer, bindingApplication, bindingNeed, bindingCapability
  , BindingSubject
  ) where

import Amoebius.Extension.Capability
import Amoebius.Extension.BindingSubject.Internal
  (BindingSubject, subjectApplication, subjectNeed, subjectCapability)
import Amoebius.Extension.Spec
import Amoebius.Vocabulary (ExtensionId, extensionIdText)
import Control.Monad (foldM, forM_)
import Data.List (nub, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

data Provider = CoreProvider | ExtensionProvider ExtensionId
  deriving (Eq, Ord, Show)

data LinkRefusal
  = DuplicateExtensionId ExtensionId
  | ShadowingExtension DeclaredCapability Provider Provider
  | UnboundRequirement ExtensionId DeclaredCapability
  | CyclicExtension [ExtensionId]
  | ProviderDeclarationAbsent ExtensionId
  | UnboundApplicationNeed Text Text DeclaredCapability
  | InvalidApplicationNeed Text Text
  | InvalidContributedSpec Text
  deriving (Eq, Show)

linkRefusalTag :: LinkRefusal -> Text
linkRefusalTag refusal = case refusal of
  DuplicateExtensionId _ -> "DuplicateExtensionId"
  ShadowingExtension {} -> "ShadowingExtension"
  UnboundRequirement {} -> "UnboundCapability"
  CyclicExtension _ -> "CyclicExtension"
  ProviderDeclarationAbsent _ -> "UnboundCapability"
  UnboundApplicationNeed {} -> "UnboundCapability"
  InvalidApplicationNeed {} -> "InvalidApplicationNeed"
  InvalidContributedSpec _ -> "InvalidContributedSpec"

type Registered c l x s h m d p = ExtensionSpec ExtensionId c DeclaredCapability l x s h m d p

type role LinkSet nominal nominal nominal nominal nominal nominal nominal nominal
data LinkSet c l x s h m d p = LinkSet
  [Registered c l x s h m d p]
  (Map DeclaredCapability Provider)
  [ExtensionId]

extensionsIn :: LinkSet c l x s h m d p -> [Registered c l x s h m d p]
extensionsIn (LinkSet values _ _) = values

providerFor :: DeclaredCapability -> LinkSet c l x s h m d p -> Maybe Provider
providerFor capability (LinkSet _ providers _) = Map.lookup capability providers

extensionOrder :: LinkSet c l x s h m d p -> [ExtensionId]
extensionOrder (LinkSet _ _ order) = order

mergeExtensions
  :: [Registered c l x s h m d p]
  -> Either LinkRefusal (LinkSet c l x s h m d p)
mergeExtensions specifications = do
  let identifiers = map extId specifications
      byId = Map.fromList [(extId specification, specification) | specification <- specifications]
  case [identifier | identifier <- nub identifiers, length (filter (== identifier) identifiers) > 1] of
    duplicate : _ -> Left (DuplicateExtensionId duplicate)
    [] -> Right ()
  providers <- foldM insertExtension
    (Map.fromList [(capability, CoreProvider) | capability <- coreCapabilities])
    specifications
  forM_ specifications $ \specification ->
    forM_ (extRequires specification) $ \capability ->
      if Map.member capability providers then Right ()
        else Left (UnboundRequirement (extId specification) capability)
  (_, order) <- foldM (visit providers byId []) (Set.empty, []) (sort identifiers)
  pure (LinkSet specifications providers order)
 where
  insertExtension providers specification =
    foldM (insertCapability (ExtensionProvider (extId specification))) providers (extProvides specification)
  insertCapability owner providers capability = case Map.lookup capability providers of
    Just previous -> Left (ShadowingExtension capability owner previous)
    Nothing -> Right (Map.insert capability owner providers)
  visit providers byId stack state@(seen, _) identifier
    | identifier `elem` stack = Left (CyclicExtension (reverse (identifier : stack)))
    | identifier `Set.member` seen = Right state
    | otherwise = case Map.lookup identifier byId of
        Nothing -> Left (ProviderDeclarationAbsent identifier)
        Just specification -> do
          (visited, dependencies) <- foldM (visit providers byId (identifier : stack)) state
            [owner | capability <- extRequires specification, Just (ExtensionProvider owner) <- [Map.lookup capability providers]]
          pure (Set.insert identifier visited, dependencies <> [identifier])

-- | Evidence is produced only by resolving a requirement against a refined
-- graph. Its source-seal index cannot be coerced to another admission boundary.
type role BindingProof nominal
data BindingProof seal = BindingProof !Text !Text !Text !DeclaredCapability !(Maybe seal)

proveBinding
  :: BindingSubject -> LinkSet c l x s h m d seal
  -> Either LinkRefusal (BindingProof seal)
proveBinding subject links
  | Text.null application || Text.null need = Left (InvalidApplicationNeed application need)
  | otherwise = case providerFor capability links of
      Nothing -> Left (UnboundApplicationNeed application need capability)
      Just CoreProvider -> Right (BindingProof
        ("core/" <> declaredCapabilityName capability) application need capability Nothing)
      Just (ExtensionProvider identifier) -> case
          [extSourceSeal specification | specification <- extensionsIn links, extId specification == identifier] of
        [seal] -> Right (BindingProof ("extension/" <> extensionIdText identifier) application need capability (Just seal))
        _ -> Left (ProviderDeclarationAbsent identifier)
 where
  application = subjectApplication subject
  need = subjectNeed subject
  capability = ServiceCapability (subjectCapability subject)

bindingIssuer :: BindingProof seal -> Text
bindingIssuer (BindingProof value _ _ _ _) = value

bindingApplication :: BindingProof seal -> Text
bindingApplication (BindingProof _ value _ _ _) = value

bindingNeed :: BindingProof seal -> Text
bindingNeed (BindingProof _ _ value _ _) = value

bindingCapability :: BindingProof seal -> DeclaredCapability
bindingCapability (BindingProof _ _ _ capability _) = capability

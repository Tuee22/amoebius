{-# LANGUAGE OverloadedStrings #-}

-- | The closed set of artifact kinds, and the type index that carries one.
--
-- 'jit_artifact_doctrine.md' section 3 fixes the shape: a target is a /type index/
-- rather than a string, so a consumer expecting one kind cannot be handed another, and
-- the set is closed — adding a kind of artifact is a change to this module, never a new
-- string in a configuration file.
module Amoebius.Calculus.Artifact.Target
  ( ArtifactKind (..)
  , Target (..)
  , SomeTarget (..)
  , targetTag
  , targetKind
  , everyTarget
  ) where

import Data.Text (Text)

-- | The closed kind set. It is promoted, and 'Target' indexes on it.
data ArtifactKind
  = DhallSchema
  | ContainerRecipe
  | ObjectManifest
  | SqlSchema
  | PureScriptContract
  | BuildMutant
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | The index itself. Each constructor inhabits exactly one kind, so @Target
-- 'DhallSchema@ and @Target 'ContainerRecipe@ are different types.
data Target (k :: ArtifactKind) where
  DhallSchemaTarget :: Target 'DhallSchema
  ContainerRecipeTarget :: Target 'ContainerRecipe
  ObjectManifestTarget :: Target 'ObjectManifest
  SqlSchemaTarget :: Target 'SqlSchema
  PureScriptContractTarget :: Target 'PureScriptContract
  BuildMutantTarget :: Target 'BuildMutant

deriving stock instance Eq (Target k)

deriving stock instance Show (Target k)

-- | A target with its index hidden, for the places that enumerate the whole set.
data SomeTarget where
  SomeTarget :: Target k -> SomeTarget

-- | The tag the address folds. It is derived from the constructor rather than authored
-- beside it, so a new kind cannot reach the digest without one.
targetTag :: Target k -> Text
targetTag = tagOf . targetKind

-- | The value-level kind of a target.
targetKind :: Target k -> ArtifactKind
targetKind = \case
  DhallSchemaTarget -> DhallSchema
  ContainerRecipeTarget -> ContainerRecipe
  ObjectManifestTarget -> ObjectManifest
  SqlSchemaTarget -> SqlSchema
  PureScriptContractTarget -> PureScriptContract
  BuildMutantTarget -> BuildMutant

-- | Every target, once. The list is written against the promoted set below, so a kind
-- added to 'ArtifactKind' without a 'Target' constructor fails to compile here rather
-- than silently shrinking whatever enumerates it.
everyTarget :: [SomeTarget]
everyTarget = fmap witness [minBound .. maxBound]
  where
    witness :: ArtifactKind -> SomeTarget
    witness = \case
      DhallSchema -> SomeTarget DhallSchemaTarget
      ContainerRecipe -> SomeTarget ContainerRecipeTarget
      ObjectManifest -> SomeTarget ObjectManifestTarget
      SqlSchema -> SomeTarget SqlSchemaTarget
      PureScriptContract -> SomeTarget PureScriptContractTarget
      BuildMutant -> SomeTarget BuildMutantTarget

tagOf :: ArtifactKind -> Text
tagOf = \case
  DhallSchema -> "dhall-schema"
  ContainerRecipe -> "container-recipe"
  ObjectManifest -> "object-manifest"
  SqlSchema -> "sql-schema"
  PureScriptContract -> "purescript-contract"
  BuildMutant -> "build-mutant"

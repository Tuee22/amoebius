{-# LANGUAGE OverloadedStrings #-}

-- | Recipes: pure functions from a declaration to rendered content, at a target.
--
-- 'jit_artifact_doctrine.md' section 3 requires purity in the strong sense L2 asks for —
-- no clock, no environment, no directory listing, no unordered traversal. The type
-- carries the first part of that: a recipe is @decl -> Rendered k@ and not
-- @decl -> IO (Rendered k)@, so an observation of the world has nowhere to enter except
-- as an argument, which makes it part of the declaration and therefore part of the
-- address.
--
-- What the type cannot carry is the rest: a pure function may still traverse an
-- unordered structure. That residue is checked rather than typed, by rendering each
-- target from two independently seeded processes and requiring the bytes to agree.
module Amoebius.Calculus.Artifact.Recipe
  ( RecipeId (..)
  , recipeIdBytes
  , Rendered (..)
  , renderedBytes
  , Declaration (..)
  , Recipe (..)
  , render
  ) where

import Amoebius.Calculus.Artifact.Target (ArtifactKind, Target)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text.Encoding qualified as Encoding
import Data.Word (Word32)

-- | A recipe's own identity, folded into every address it produces. The revision is what
-- makes a recipe change and an input change indistinguishable to a consumer, which is
-- the doctrine's intent: both mean /this artifact is not the one you had/.
data RecipeId = RecipeId
  { recipeName :: Text
  , recipeRevision :: Word32
  }
  deriving stock (Eq, Ord, Show)

-- | The identity's canonical bytes.
recipeIdBytes :: RecipeId -> ByteString
recipeIdBytes value =
  Encoding.encodeUtf8 (recipeName value <> "@" <> decimal (recipeRevision value))

-- | Rendered content, indexed by the target that produced it.
newtype Rendered (k :: ArtifactKind) = Rendered ByteString
  deriving stock (Eq, Ord, Show)

renderedBytes :: Rendered k -> ByteString
renderedBytes (Rendered bytes) = bytes

-- | A declaration is whatever a recipe consumes. It has to be encodable, because the
-- address folds it; the encoding is canonical, so two equal declarations fold alike.
class Declaration d where
  declarationBytes :: d -> ByteString

-- | A recipe at a target: its identity, and the pure rendering.
data Recipe (k :: ArtifactKind) d = Recipe
  { recipeTarget :: Target k
  , recipeIdentity :: RecipeId
  , recipeRender :: d -> Rendered k
  }

-- | Apply a recipe. This exists so callers never reach past 'recipeRender' into a field
-- accessor that a later mutation could widen into an effect.
render :: Recipe k d -> d -> Rendered k
render recipe = recipeRender recipe

-- | Decimal rendering, written out rather than taken from 'show', because the address
-- folds these bytes and 'show' is a class method a later instance could redefine.
decimal :: Word32 -> Text
decimal value
  | value < 10 = digit value
  | otherwise = decimal (value `div` 10) <> digit (value `mod` 10)
  where
    digit n = case n of
      0 -> "0"
      1 -> "1"
      2 -> "2"
      3 -> "3"
      4 -> "4"
      5 -> "5"
      6 -> "6"
      7 -> "7"
      8 -> "8"
      _ -> "9"

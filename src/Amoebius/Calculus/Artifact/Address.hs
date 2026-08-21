{-# LANGUAGE CPP #-}

-- | The content address, which folds in the rendered text.
--
-- 'jit_artifact_doctrine.md' section 4 fixes what the digest is taken over: the target,
-- the recipe's own identity, the declaration, and the rendering. Folding the output into
-- its own name is redundant if the recipe is deterministic, and that redundancy is the
-- point — it turns determinism from a property somebody asserts into one the naming
-- scheme detects, because two runs producing different bytes produce different addresses.
--
-- The rendering is /total/: every artifact has an address and equal content yields one
-- address. It is /not injective/, and the word is refused here deliberately: a digest
-- over unbounded content cannot be injective. What the scheme has is collision
-- resistance, which is an assumption about SHA-256 rather than a property of a type, and
-- every claim resting on this module rests on it too.
module Amoebius.Calculus.Artifact.Address
  ( Address
  , addressDigest
  , addressHex
  , addressOf
  , addressInputs
  , AddressInput (..)
  ) where

import Amoebius.Calculus.Artifact.Recipe
  ( Declaration (declarationBytes)
  , Recipe (recipeIdentity, recipeTarget)
  , Rendered
  , recipeIdBytes
  , renderedBytes
  )
import Amoebius.Calculus.Artifact.Target (ArtifactKind, targetTag)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as Lazy
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)

-- | An artifact's name, at its target.
--
-- The digest is taken here rather than through @Amoebius.Store.ContentAddress@, and the
-- reason is layering rather than preference: the calculus is the bottom of the stack and
-- the store sits above it, so a dependency the other way would invert the layers. Which
-- of the two renderings survives is a re-derivation the store's own phase owns, and it is
-- recorded as a divergence rather than left as an accident.
newtype Address (k :: ArtifactKind) = Address ByteString
  deriving stock (Eq, Ord)

instance Show (Address k) where
  show = Text.unpack . addressHex

addressDigest :: Address k -> ByteString
addressDigest (Address digest) = digest

addressHex :: Address k -> Text
addressHex (Address digest) = Text.pack (concatMap byteHex (ByteString.unpack digest))
  where
    byteHex byte = case showHex byte "" of
      [single] -> ['0', single]
      digits -> digits

-- | The four things the digest folds, named so an oracle can be written against the set
-- rather than against the digest. Perturbing any one of these must change the address,
-- and perturbing nothing outside them must not; that biconditional is what the Phase-3
-- gate checks, and it is why the set is a value here instead of a comment.
data AddressInput
  = TargetTag
  | RecipeIdentity
  | DeclarationContent
  | RenderedContent
  deriving stock (Eq, Ord, Show, Enum, Bounded)

addressInputs :: [AddressInput]
addressInputs = [minBound .. maxBound]

-- | The address of a rendering. The rendering is passed rather than recomputed, because
-- the digest is over the bytes a consumer will actually receive; recomputing here would
-- fold a second rendering and hide exactly the disagreement section 4 exists to surface.
addressOf :: Declaration d => Recipe k d -> d -> Rendered k -> Address k
addressOf recipe declaration rendered =
  Address (SHA256.hash (frame parts))
  where
    parts =
      [ Encoding.encodeUtf8 (targetTag (recipeTarget recipe))
      , recipeIdBytes (recipeIdentity recipe)
      , declarationBytes declaration
#ifdef ARTIFACT_CALCULUS_ADDRESS_DROPS_RENDERED_MUTANT
      ]
    _unusedRendering = renderedBytes rendered
#else
      , renderedBytes rendered
      ]
#endif

-- | Length-prefixed framing, so the concatenation is unambiguous. Without it a recipe
-- named @ab@ rendering @c@ and one named @a@ rendering @bc@ fold identical bytes, and the
-- collision would be in the framing rather than in the hash.
frame :: [ByteString] -> ByteString
frame =
  Lazy.toStrict . Builder.toLazyByteString . foldMap piece
  where
    piece bytes =
      Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

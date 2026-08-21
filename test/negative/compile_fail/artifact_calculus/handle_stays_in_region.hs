{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in what leaves the region.
--
-- The same region and the same materialization, with the artifact's /address/ leaving
-- instead of its handle. An address is a value that names content; a handle is a
-- capability to reach content inside a scope. That the first may leave and the second may
-- not is the whole distinction, and it is what makes the illegal twin's rejection a
-- statement about escape rather than about the surrounding code.
module ArtifactCalculusHandleStaysInRegion where

import Amoebius.Calculus.Artifact.Address (addressHex)
import Amoebius.Calculus.Artifact.Recipe (Declaration (..), Recipe (..), RecipeId (..), Rendered (..))
import Amoebius.Calculus.Artifact.Region (RegionOutcome, handleAddress, materialize, runRegion)
import Amoebius.Calculus.Artifact.Target (ArtifactKind (DhallSchema), Target (DhallSchemaTarget))
import Data.Text (Text)
import Data.Text.Encoding qualified as Encoding

newtype Declared = Declared Text

instance Declaration Declared where
  declarationBytes (Declared value) = Encoding.encodeUtf8 value

recipe :: Recipe 'DhallSchema Declared
recipe =
  Recipe
    { recipeTarget = DhallSchemaTarget
    , recipeIdentity = RecipeId {recipeName = "escape", recipeRevision = 1}
    , recipeRender = \(Declared value) -> Rendered (Encoding.encodeUtf8 value)
    }

-- The accepted program: the address, which is a value, leaves; the handle does not.
kept :: RegionOutcome Text
kept = runRegion (fmap (addressHex . handleAddress) (materialize recipe (Declared "escape")))

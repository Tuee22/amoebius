{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the region pair: a handle referenced after its region ends.
--
-- 'runRegion' quantifies the region's skolem, so the result type cannot mention it. Trying
-- to return the handle makes the result mention @s@ and the program has no type. This is
-- the claim 'jit_artifact_doctrine.md' section 5 makes into a type rather than a
-- convention, and it is what the seeded escape mutant breaks by dropping the quantifier.
module ArtifactCalculusHandleEscapesRegion where

import Amoebius.Calculus.Artifact.Recipe (Declaration (..), Recipe (..), RecipeId (..), Rendered (..))
import Amoebius.Calculus.Artifact.Region (Handle, RegionOutcome, materialize, runRegion)
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

-- The rejected program: the handle would outlive the region that made it.
escaped :: RegionOutcome (Handle s 'DhallSchema)
escaped = runRegion (materialize recipe (Declared "escape"))

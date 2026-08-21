{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The recipe corpus the Phase-3 gate renders: one recipe per target, each a pure
-- function from a small declaration to bytes.
--
-- The corpus is deliberately dull. It exists to exercise the calculus, not to be the real
-- rendering of a Dhall schema or a container recipe — those belong to the phases that own
-- those artifact classes. What it has to be is /deterministic/, and that is the property
-- the seeded clock mutant breaks.
--
-- The seed is threaded as an argument rather than read from the environment, so the clean
-- build has no ambient read to remove and the mutant has to /add/ a dependence on it. A
-- recipe that folds the seed is a recipe that took an observation of the world without
-- putting it in the declaration, which is what section 3 forbids: two processes seeded
-- differently then render different bytes.
module ArtifactCorpus
  ( Declared (..)
  , Seed (..)
  , declaredCorpus
  , corpusRecipes
  , RecipeUnder (..)
  ) where

import Amoebius.Calculus.Artifact.Recipe
  ( Declaration (declarationBytes)
  , Recipe (..)
  , RecipeId (..)
  , Rendered (Rendered)
  )
import Amoebius.Calculus.Artifact.Target
  ( Target (..)
  )
import Data.ByteString (ByteString)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding

-- | The per-process seed. Nothing in a clean rendering may depend on it.
newtype Seed = Seed Text
  deriving stock (Eq, Show)

-- | One declaration shape serves every target here: a name and a set of fields. The set
-- is sorted before encoding, which is the ordered-traversal half of L2 — an unordered
-- traversal is pure and still nondeterministic.
data Declared = Declared
  { declaredName :: Text
  , declaredFields :: [Text]
  }
  deriving stock (Eq, Show)

instance Declaration Declared where
  declarationBytes value =
    Encoding.encodeUtf8
      (declaredName value <> "{" <> Text.intercalate "," (sort (declaredFields value)) <> "}")

-- | A recipe with its index hidden, so the corpus is one list. The tag travels beside it
-- for reporting, because the index cannot.
data RecipeUnder = forall k. RecipeUnder (Target k) (Recipe k Declared)

-- | The declarations the corpus renders, one per target, in target order.
declaredCorpus :: [Declared]
declaredCorpus =
  [ Declared "schema" ["version", "arms", "fields"]
  , Declared "recipe" ["stage", "base", "entrypoint"]
  , Declared "manifest" ["kind", "spec", "metadata"]
  , Declared "schema-sql" ["table", "scope", "policy"]
  , Declared "contract" ["port", "payload"]
  , Declared "mutant" ["operator", "locus"]
  ]

-- | The corpus, one recipe per target, in target order.
corpusRecipes :: Seed -> [RecipeUnder]
corpusRecipes seed =
  [ RecipeUnder DhallSchemaTarget (recipeFor seed DhallSchemaTarget "dhall-schema-recipe" 1 "let ")
  , RecipeUnder ContainerRecipeTarget (recipeFor seed ContainerRecipeTarget "container-recipe-recipe" 1 "FROM ")
  , RecipeUnder ObjectManifestTarget (recipeFor seed ObjectManifestTarget "object-manifest-recipe" 2 "apiVersion: ")
  , RecipeUnder SqlSchemaTarget (recipeFor seed SqlSchemaTarget "sql-schema-recipe" 1 "CREATE ")
  , RecipeUnder PureScriptContractTarget (recipeFor seed PureScriptContractTarget "purescript-contract-recipe" 3 "module ")
  , RecipeUnder BuildMutantTarget (recipeFor seed BuildMutantTarget "build-mutant-recipe" 1 "-- mutant ")
  ]

recipeFor :: Seed -> Target k -> Text -> Word -> Text -> Recipe k Declared
recipeFor seed target name revision prefix =
  Recipe
    { recipeTarget = target
    , recipeIdentity = RecipeId {recipeName = name, recipeRevision = fromIntegral revision}
    , recipeRender = \declared -> Rendered (body seed prefix declared)
    }

body :: Seed -> Text -> Declared -> ByteString
body seed prefix declared =
  Encoding.encodeUtf8
    (prefix <> declaredName declared <> fields <> ambient seed)
  where
    fields = "(" <> Text.intercalate "|" (sort (declaredFields declared)) <> ")"

-- | The seeded observation. Clean, it is the empty string and the seed is unused; under
-- the mutant the rendering folds it, and the two-process comparison sees it immediately.
ambient :: Seed -> Text
#ifdef ARTIFACT_CALCULUS_RECIPE_ADMITS_CLOCK_MUTANT
ambient (Seed value) = "@" <> value
#else
ambient (Seed _) = ""
#endif

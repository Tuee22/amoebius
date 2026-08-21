{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-3 suite: the artifact calculus against its authored oracle.
--
-- Every claim is checked as a biconditional rather than as a spot value, because a check
-- that only ever asserts \"this equals that\" passes for a fold that ignores half its
-- inputs. Each of the four address inputs the oracle names is perturbed on its own and
-- must move the address; one perturbation outside that set is applied and must not.
--
-- The determinism claim is the one this binary cannot settle alone, because a single
-- process shares whatever ambient state a recipe reached for. It prints its renderings
-- under a seed given on the command line, and the gate runs it twice with different seeds
-- and compares — which is what makes \"two independently seeded processes\" a check
-- rather than a phrase.
module Main (main) where

import Amoebius.Calculus.Artifact.Address
  ( AddressInput (..)
  , addressHex
  , addressInputs
  , addressOf
  )
import Amoebius.Calculus.Artifact.Recipe
  ( Recipe (..)
  , RecipeId (..)
  , Rendered (Rendered)
  , render
  , renderedBytes
  )
import Amoebius.Calculus.Artifact.Region
  ( Reaper (GenerationBound)
  , RegionOutcome (..)
  , RetainedArtifact (retainedReaper)
  , consume
  , materialize
  , promote
  , runRegion
  )
import Amoebius.Calculus.Artifact.Target
  ( ArtifactKind (DhallSchema)
  , SomeTarget (..)
  , Target (DhallSchemaTarget)
  , everyTarget
  , targetTag
  )
import ArtifactCorpus (Declared (..), RecipeUnder (..), Seed (..), corpusRecipes, declaredCorpus)
import Data.ByteString qualified as ByteString
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--render", seed] -> renderReport (Seed (Text.pack seed))
    _ -> checks

-- | The determinism half: one line per target, its address and its rendered length. The
-- gate runs this twice under different seeds and requires the reports to be equal.
renderReport :: Seed -> IO ()
renderReport seed = mapM_ line (pairs seed)
  where
    line (RecipeUnder target recipe, declared) =
      putStrLn
        ( Text.unpack (targetTag target)
            <> "\t"
            <> Text.unpack (addressHex (addressOf recipe declared (render recipe declared)))
            <> "\t"
            <> show (ByteString.length (renderedBytes (render recipe declared)))
        )

pairs :: Seed -> [(RecipeUnder, Declared)]
pairs seed = zip (corpusRecipes seed) declaredCorpus

checks :: IO ()
checks = do
  oracle <- readOracle
  let results =
        [ ("target-set-closed", targetSetClosed)
        , ("oracle-names-every-input", oracleNamesEveryInput oracle)
        , ("address-folds-target", addressFoldsTarget)
        , ("address-folds-recipe-identity", perturbationMoves bumpRevision)
        , ("address-folds-declaration", perturbationMoves renameDeclaration)
        , ("address-folds-rendered", addressFoldsRendered)
        , ("address-folds-nothing-else", addressFoldsNothingElse)
        , ("region-reaps-ephemeral", regionReapsEphemeral)
        , ("region-keeps-retained", regionKeepsRetained)
        , ("materialize-is-idempotent", materializeIsIdempotent)
        , ("consume-returns-rendered", consumeReturnsRendered)
        ]
      failures = [name | (name, verdict) <- results, not verdict]
  mapM_ (\(name, verdict) -> putStrLn ((if verdict then "  ok   " else "  FAIL ") <> name)) results
  if null failures
    then
      putStrLn
        ( "artifact-calculus-spec: PASS ("
            <> show (length everyTarget)
            <> " targets, "
            <> show (length addressInputs)
            <> " address inputs, "
            <> show (length results)
            <> " checks)"
        )
    else do
      putStrLn ("artifact-calculus-spec: FAIL " <> unwords failures)
      exitFailure

-- | Every declared kind has a target constructor, and the corpus covers each exactly once.
targetSetClosed :: Bool
targetSetClosed =
  sort [targetTag t | SomeTarget t <- everyTarget]
    == sort [targetTag t | RecipeUnder t _ <- corpusRecipes (Seed "0")]

-- | The oracle is load-bearing only if it names, for every target, exactly the inputs the
-- suite perturbs. A row missing here is a fold nothing checks; a row too many is a claim
-- no check discharges.
oracleNamesEveryInput :: [(Text, Text)] -> Bool
oracleNamesEveryInput oracle =
  sort oracle
    == sort
      [ (targetTag target, oracleName input)
      | SomeTarget target <- everyTarget
      , input <- addressInputs
      ]

-- | The target is a type index, so \"the same recipe at another target\" cannot be
-- spelled — that foreclosure is the point. The tag it contributes to the digest is
-- reached the only way left: two targets, everything else held equal, must not collide.
addressFoldsTarget :: Bool
addressFoldsTarget = length (nub addresses) == length everyTarget
  where
    addresses = [addressHex (addressOf (fixedRecipe target) fixedDeclared fixedRendered) | SomeTarget target <- everyTarget]
    fixedRendered = Rendered (Encoding.encodeUtf8 "held-equal")

fixedRecipe :: Target k -> Recipe k Declared
fixedRecipe target =
  Recipe
    { recipeTarget = target
    , recipeIdentity = RecipeId {recipeName = "held-equal", recipeRevision = 1}
    , recipeRender = \_ -> Rendered (Encoding.encodeUtf8 "held-equal")
    }

fixedDeclared :: Declared
fixedDeclared = Declared {declaredName = "held-equal", declaredFields = ["one", "two"]}

-- | Perturb one input of every corpus recipe and require the address to move.
perturbationMoves :: (forall k. (Recipe k Declared, Declared) -> (Recipe k Declared, Declared)) -> Bool
perturbationMoves perturb =
  and
    [ addressAt recipe declared /= uncurry addressAt (perturb (recipe, declared))
    | (RecipeUnder _ recipe, declared) <- pairs (Seed "0")
    ]

bumpRevision :: (Recipe k Declared, Declared) -> (Recipe k Declared, Declared)
bumpRevision (recipe, declared) =
  (recipe {recipeIdentity = bump (recipeIdentity recipe)}, declared)
  where
    bump identity = identity {recipeRevision = recipeRevision identity + 1}

renameDeclaration :: (Recipe k Declared, Declared) -> (Recipe k Declared, Declared)
renameDeclaration (recipe, declared) =
  (recipe, declared {declaredName = declaredName declared <> "'"})

-- | The rendered half is perturbed at the argument rather than through the recipe,
-- because that is exactly the redundancy section 4 asks for: the digest is over the bytes
-- a consumer receives, so handing it different bytes must produce a different name.
addressFoldsRendered :: Bool
addressFoldsRendered =
  and
    [ addressAt recipe declared
        /= addressHex (addressOf recipe declared (widen (render recipe declared)))
    | (RecipeUnder _ recipe, declared) <- pairs (Seed "0")
    ]
  where
    widen rendered = Rendered (renderedBytes rendered <> Encoding.encodeUtf8 " ")

-- | The other half of the biconditional. Writing a declaration's fields in another order
-- is not one of the four inputs, because the declaration encodes them sorted, so it must
-- leave the address alone. A fold that reacted to it would be folding traversal order,
-- which is the determinism failure L2 names.
addressFoldsNothingElse :: Bool
addressFoldsNothingElse =
  and
    [ addressAt recipe declared == addressAt recipe declared {declaredFields = reverse (declaredFields declared)}
    | (RecipeUnder _ recipe, declared) <- pairs (Seed "0")
    ]

addressAt :: Recipe k Declared -> Declared -> Text
addressAt recipe declared = addressHex (addressOf recipe declared (render recipe declared))

regionReapsEphemeral :: Bool
regionReapsEphemeral =
  length (regionReaped outcome) == 2 && null (regionRetained outcome)
  where
    outcome = runRegion $ do
      _ <- materialize (fixedRecipe firstTarget) fixedDeclared
      _ <- materialize (fixedRecipe firstTarget) otherDeclared
      pure ()

regionKeepsRetained :: Bool
regionKeepsRetained =
  length (regionReaped outcome) == 1
    && fmap retainedReaper (regionRetained outcome) == [GenerationBound 3]
  where
    outcome = runRegion $ do
      _ <- materialize (fixedRecipe firstTarget) fixedDeclared
      handle <- materialize (fixedRecipe firstTarget) otherDeclared
      promote (GenerationBound 3) handle
      pure ()

materializeIsIdempotent :: Bool
materializeIsIdempotent = length (regionReaped outcome) == 1
  where
    outcome = runRegion $ do
      _ <- materialize (fixedRecipe firstTarget) fixedDeclared
      _ <- materialize (fixedRecipe firstTarget) fixedDeclared
      pure ()

consumeReturnsRendered :: Bool
consumeReturnsRendered = regionValue outcome == Just expected
  where
    expected = renderedBytes (render (fixedRecipe firstTarget) fixedDeclared)
    outcome = runRegion $ do
      handle <- materialize (fixedRecipe firstTarget) fixedDeclared
      fmap (fmap renderedBytes) (consume handle)

-- | The one concrete target the region checks use. The region is indifferent to which
-- kind it holds, so naming one keeps those checks about lifetime rather than about
-- indexing, which 'addressFoldsTarget' already settles.
firstTarget :: Target 'DhallSchema
firstTarget = DhallSchemaTarget

otherDeclared :: Declared
otherDeclared = Declared {declaredName = "held-equal-two", declaredFields = ["one"]}

oracleName :: AddressInput -> Text
oracleName = \case
  TargetTag -> "target"
  RecipeIdentity -> "recipe-identity"
  DeclarationContent -> "declaration"
  RenderedContent -> "rendered"

readOracle :: IO [(Text, Text)]
readOracle = do
  contents <- readFile "test/oracle/artifact_calculus/address_inputs.tsv"
  pure [row | line <- lines contents, row <- parse line]
  where
    parse line = case splitTabs line of
      target : input : _ | take 1 line /= "#" && not (null target) -> [(Text.pack target, Text.pack input)]
      _ -> []

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (front, []) -> [front]
  (front, _ : rest) -> front : splitTabs rest

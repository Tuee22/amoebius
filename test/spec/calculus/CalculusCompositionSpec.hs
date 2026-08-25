{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | The Phase-11 suite: all ordered pairs of the five calculi, plus generated
-- index-preservation properties.
module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (..))
import Amoebius.Calculus.Budget.Grant (Bytes (..), Slots (..), allowance)
import Amoebius.Calculus.Composition
  ( Calculus (..)
  , Component
  , append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , componentCalculus
  , componentDescriptor
  , componentName
  , componentResource
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , emptyComposition
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , renameComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (..), addResources)
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM_, unless)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Numeric.Natural (Natural)
import System.Exit (exitFailure)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Gen
  , Property
  , checkCoverage
  , chooseInt
  , conjoin
  , counterexample
  , cover
  , elements
  , isSuccess
  , quickCheckWithResult
  , stdArgs
  , (===)
  )
import Test.QuickCheck.Test (Args (chatty, maxSuccess))
import Text.Read (readMaybe)

data PairRow = PairRow
  { pairLeft :: Calculus
  , pairRight :: Calculus
  , pairExpected :: ResourceVector
  }
  deriving stock (Eq, Show)

data ComponentSeed = ComponentSeed
  { seedCalculus :: Calculus
  , seedResource :: ResourceVector
  }
  deriving stock (Show)

instance Arbitrary ComponentSeed where
  arbitrary = ComponentSeed <$> elements everyCalculus <*> resourceVector

resourceVector :: Gen ResourceVector
resourceVector =
  ResourceVector
    <$> natural 0 100
    <*> natural 0 1000
    <*> natural 0 10000
    <*> natural 0 100
 where
  natural low high = fromIntegral <$> chooseInt (low, high)

main :: IO ()
main = do
  rows <- readPairOracle
  result <- withFixtureScope $ \scope -> runChecks scope rows
  case result of
    Left problem -> fail (show problem)
    Right () -> pure ()

withFixtureScope :: (forall scope. RequestScope scope -> IO result) -> IO (Either String result)
withFixtureScope continuation = case trustedTenant "phase-11-tenant" of
  Left problem -> pure (Left (show problem))
  Right tenant -> case trustedSubject tenant "phase-11-subject" of
    Left problem -> pure (Left (show problem))
    Right subject -> case activeMembership tenant subject of
      Left problem -> pure (Left (show problem))
      Right membership -> case withRequestScope tenant subject membership continuation of
        Left problem -> pure (Left (show problem))
        Right action -> Right <$> action

runChecks :: RequestScope scope -> [PairRow] -> IO ()
runChecks scope rows = do
  let components = [(kind, fixedComponent scope kind) | kind <- everyCalculus]
      lookupComponent wanted = [component | (kind, component) <- components, kind == wanted]
      pairResults =
        [ (row, composed)
        | row <- rows
        , left <- lookupComponent (pairLeft row)
        , right <- lookupComponent (pairRight row)
        , let composed = compose left right
        ]
      triples =
        [ (left, middle, right)
        | left <- fmap snd components
        , middle <- fmap snd components
        , right <- fmap snd components
        ]
      checks =
        [ ("calculus-set-closed", sort (fmap calculusTag everyCalculus) == sort ["artifact", "budget", "lift", "workflow", "evidence"])
        , ("pair-oracle-complete", pairOracleComplete rows)
        , ("ordered-pair-composition-total", length pairResults == 25)
        , ("pair-order-matches-oracle", and [compositionKinds result == [pairLeft row, pairRight row] | (row, result) <- pairResults])
        , ("resource-index-additivity", and [compositionResource result == pairExpected row | (row, result) <- pairResults])
        , ("append-associative", all associative triples)
        , ("identity-preserves-components", all (identityHolds scope) (fmap snd components))
        , ("transform-preserves-indices", all transformPreserves (fmap snd components))
        , ("payloads-remain-observable", all (not . Text.null . componentDescriptor . snd) components)
        ]
      failures = [name | (name, passed) <- checks, not passed]
  forM_ checks $ \(name, passed) -> putStrLn ((if passed then "  ok   " else "  FAIL ") <> name)
  properties <- runProperties scope
  unless (null failures && properties) $ do
    putStrLn ("calculus-composition-spec: FAIL " <> unwords failures)
    exitFailure
  putStrLn "calculus-composition-spec: PASS (25 ordered pairs, 125 triples, 3 properties, 9 checks)"

pairOracleComplete :: [PairRow] -> Bool
pairOracleComplete rows =
  length rows == 25
    && length (nub keys) == 25
    && sort keys == sort [(left, right) | left <- everyCalculus, right <- everyCalculus]
 where
  keys = [(pairLeft row, pairRight row) | row <- rows]

associative :: (Component scope, Component scope, Component scope) -> Bool
associative (left, middle, right) =
  append (compose left middle) (singleton right)
    == append (singleton left) (compose middle right)

identityHolds :: RequestScope scope -> Component scope -> Bool
identityHolds scope component =
  append (emptyComposition scope) (singleton component) == singleton component
    && append (singleton component) (emptyComposition scope) == singleton component

transformPreserves :: Component scope -> Bool
transformPreserves component =
  let renamed = renameComponent (componentName component <> "-renamed") component
   in componentName renamed /= componentName component
        && componentCalculus renamed == componentCalculus component
        && componentResource renamed == componentResource component
        && componentDescriptor renamed == componentDescriptor component

runProperties :: RequestScope scope -> IO Bool
runProperties scope = do
  resourceResult <- quickCheckWithResult arguments (propResourceAdditive scope)
  associativeResult <- quickCheckWithResult arguments (propAssociative scope)
  transformResult <- quickCheckWithResult arguments (propTransformPreserves scope)
  let results = [resourceResult, associativeResult, transformResult]
      passed = all isSuccess results
  putStrLn ((if passed then "  ok   " else "  FAIL ") <> "generated-index-properties")
  pure passed
 where
  arguments = stdArgs {maxSuccess = 500, chatty = False}

propResourceAdditive :: RequestScope scope -> ComponentSeed -> ComponentSeed -> Property
propResourceAdditive scope leftSeed rightSeed =
  covered leftSeed rightSeed
    ( compositionResource (compose left right)
        === addResources (componentResource left) (componentResource right)
    )
 where
  left = componentFromSeed scope "left" leftSeed
  right = componentFromSeed scope "right" rightSeed

propAssociative :: RequestScope scope -> ComponentSeed -> ComponentSeed -> ComponentSeed -> Property
propAssociative scope leftSeed middleSeed rightSeed =
  checkCoverage
    ( cover 15 (seedCalculus leftSeed == ArtifactCalculus) "artifact-left"
        . cover 15 (seedCalculus leftSeed == BudgetCalculus) "budget-left"
        . cover 15 (seedCalculus leftSeed == LiftCalculus) "lift-left"
        . cover 15 (seedCalculus leftSeed == WorkflowCalculus) "workflow-left"
        . cover 15 (seedCalculus leftSeed == EvidenceCalculus) "evidence-left"
        $ conjoin
          [ counterexample "component order changed" (compositionKinds leftAssociated === compositionKinds rightAssociated)
          , counterexample "resource fold changed" (compositionResource leftAssociated === compositionResource rightAssociated)
          , counterexample "component names changed" (compositionNames leftAssociated === compositionNames rightAssociated)
          ]
    )
 where
  left = componentFromSeed scope "left" leftSeed
  middle = componentFromSeed scope "middle" middleSeed
  right = componentFromSeed scope "right" rightSeed
  leftAssociated = append (compose left middle) (singleton right)
  rightAssociated = append (singleton left) (compose middle right)

propTransformPreserves :: RequestScope scope -> ComponentSeed -> Property
propTransformPreserves scope seed =
  checkCoverage
    ( cover 15 (seedCalculus seed == ArtifactCalculus) "artifact"
        . cover 15 (seedCalculus seed == BudgetCalculus) "budget"
        . cover 15 (seedCalculus seed == LiftCalculus) "lift"
        . cover 15 (seedCalculus seed == WorkflowCalculus) "workflow"
        . cover 15 (seedCalculus seed == EvidenceCalculus) "evidence"
        $ counterexample "label transform changed an index or payload" (transformPreserves component)
    )
 where
  component = componentFromSeed scope "before" seed

covered :: ComponentSeed -> ComponentSeed -> Property -> Property
covered left right =
  checkCoverage
    . cover 15 (seedCalculus left == ArtifactCalculus) "artifact-left"
    . cover 15 (seedCalculus left == BudgetCalculus) "budget-left"
    . cover 15 (seedCalculus left == LiftCalculus) "lift-left"
    . cover 15 (seedCalculus left == WorkflowCalculus) "workflow-left"
    . cover 15 (seedCalculus left == EvidenceCalculus) "evidence-left"
    . cover 15 (seedCalculus right == ArtifactCalculus) "artifact-right"
    . cover 15 (seedCalculus right == BudgetCalculus) "budget-right"
    . cover 15 (seedCalculus right == LiftCalculus) "lift-right"
    . cover 15 (seedCalculus right == WorkflowCalculus) "workflow-right"
    . cover 15 (seedCalculus right == EvidenceCalculus) "evidence-right"

fixedComponent :: RequestScope scope -> Calculus -> Component scope
fixedComponent scope calculus = componentFromSeed scope (calculusTag calculus) (ComponentSeed calculus (fixedResource calculus))

fixedResource :: Calculus -> ResourceVector
fixedResource calculus = case calculus of
  ArtifactCalculus -> ResourceVector 1 10 100 1
  BudgetCalculus -> ResourceVector 2 20 200 2
  LiftCalculus -> ResourceVector 3 30 300 3
  WorkflowCalculus -> ResourceVector 4 40 400 4
  EvidenceCalculus -> ResourceVector 5 50 500 5

componentFromSeed :: RequestScope scope -> Text -> ComponentSeed -> Component scope
componentFromSeed scope name seed = case seedCalculus seed of
  ArtifactCalculus -> artifactComponent scope name resources (RecipeId name 1)
  BudgetCalculus -> budgetComponent scope name resources (allowance (Bytes 4096) (Slots 4) (Bytes 1024))
  LiftCalculus -> liftComponent scope name resources OnHost
  WorkflowCalculus -> workflowComponent scope name resources emptyLedger
  EvidenceCalculus -> evidenceComponent scope name resources PureRegister
 where
  resources = seedResource seed

readPairOracle :: IO [PairRow]
readPairOracle = do
  contents <- Text.readFile "test/oracle/calculus_composition/pairs.tsv"
  case Text.lines contents of
    [] -> fail "calculus-composition pair oracle is empty"
    header : rows -> do
      unless (header == "left\tright\tcpu\tmemory\tephemeral\tpods")
        (fail "calculus-composition pair oracle header drifted")
      mapM parseRow rows

parseRow :: Text -> IO PairRow
parseRow row = case Text.splitOn "\t" row of
  [leftText, rightText, cpuText, memoryText, ephemeralText, podsText] -> do
    left <- parseCalculus leftText
    right <- parseCalculus rightText
    cpu <- parseNatural cpuText
    memory <- parseNatural memoryText
    ephemeral <- parseNatural ephemeralText
    pods <- parseNatural podsText
    pure (PairRow left right (ResourceVector cpu memory ephemeral pods))
  _ -> fail ("malformed calculus-composition pair row: " <> Text.unpack row)

parseCalculus :: Text -> IO Calculus
parseCalculus value = case [calculus | calculus <- everyCalculus, calculusTag calculus == value] of
  [calculus] -> pure calculus
  _ -> fail ("unknown calculus tag: " <> Text.unpack value)

parseNatural :: Text -> IO Natural
parseNatural value = case readMaybe (Text.unpack value) of
  Just number -> pure number
  Nothing -> fail ("invalid natural in pair oracle: " <> Text.unpack value)

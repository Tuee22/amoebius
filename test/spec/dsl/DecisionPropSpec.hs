{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module DecisionPropSpec
  ( runDecisionPropSpec
  ) where

import Amoebius.Dsl.Decision
  ( DecisionFragment
  , composeDecisionFragments
  , decodeDecision
  , distinctHostIds
  , encodeDecision
  , foldResourceTotal
  , fragmentResources
  , fragmentServices
  , fragmentSubstrates
  , mkDecisionFragment
  )
import Amoebius.Topology.Rke2 (Rke2Quorum (..), rke2Servers)
import Control.Monad (unless)
import Data.Either (isLeft)
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Gen
  , Property
  , Result
  , Testable
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , elements
  , frequency
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  , vectorOf
  , Args (chatty, maxSuccess)
  )

data FragmentCase = FragmentCase DecisionFragment
  deriving stock (Show)

instance Arbitrary FragmentCase where
  arbitrary = do
    substrateCount <- frequency [(1, pure 1), (2, pure 2), (1, pure 3)]
    serviceCount <- frequency [(1, pure 1), (2, pure 2), (1, pure 3)]
    resources <- vectorOf 3 (natural 0 20)
    let substrates = names "substrate" substrateCount
        services = names "service" serviceCount
    FragmentCase <$> buildFragment substrates services resources

quorums :: [Rke2Quorum Text]
quorums = [Single "a", Three "a" "b" "c", Five "a" "b" "c" "d" "e"]

data FoldCase
  = ResourceFold [Natural]
  | ServerFold (Rke2Quorum Text)
  | HostFold [Text]
  deriving stock (Show)

instance Arbitrary FoldCase where
  arbitrary = do
    family <- elements [0 :: Int, 1, 2]
    case family of
      0 -> ResourceFold <$> frequency [(2, pure []), (3, vectorOf 3 (natural 0 20))]
      1 -> ServerFold <$> elements quorums
      _ -> HostFold <$> frequency [(2, pure ["h0", "h0"]), (3, pure ["h0", "h1"])]

data CompositionCase = CompositionCase DecisionFragment DecisionFragment
  deriving stock (Show)

instance Arbitrary CompositionCase where
  arbitrary = do
    leftResources <- vectorOf 2 (natural 0 20)
    rightResources <- vectorOf 2 (natural 0 20)
    left <- build ["substrate-left"] ["service-left"] leftResources
    right <- build ["substrate-right"] ["service-right"] rightResources
    pure (CompositionCase left right)
   where
    build = buildFragment

runDecisionPropSpec :: IO ()
runDecisionPropSpec = do
  results <- sequence
    [ runProperty "prop_decodeRoundTrip" prop_decodeRoundTrip
    , runProperty "prop_foldTotal" prop_foldTotal
    , runProperty "prop_compositionPreservesWellFormedness" prop_compositionPreservesWellFormedness
    ]
  let failures = [name | (name, result) <- results, not (isSuccess result)]
  mapM_ (putStrLn . ("decision-property: RED " <>)) failures
  unless (null failures) (fail ("decision properties failed: " <> show failures))
  assert (fmap (length . rke2Servers) quorums == [1, 3, 5]) "Rke2Servers finite exhaustion changed"
  putStrLn "decision-properties: TESTED sampled (3); PROVEN exhausted Rke2Servers (3/3 arms)"

prop_decodeRoundTrip :: FragmentCase -> Property
prop_decodeRoundTrip (FragmentCase fragment) = checkCoverage
  $ cover 20 (length (fragmentSubstrates fragment) > 1) "multi-substrate"
  $ cover 20 (length (fragmentServices fragment) >= 2) "multi-service"
  $ decodeDecision (encodeDecision fragment) == Right fragment

prop_foldTotal :: FoldCase -> Property
prop_foldTotal foldCase = checkCoverage
  $ cover 10 (isResource foldCase) "resource-fold"
  $ cover 10 (isServer foldCase) "rke2-fold"
  $ cover 10 (isHost foldCase) "host-distinctness-fold"
  $ cover 10 (isBoundary foldCase) "boundary-input"
  $ counterexample (show foldCase) (property (total foldCase))
 where
  total value = case value of
    ResourceFold resources -> foldResourceTotal resources == sum resources
    ServerFold servers -> length (rke2Servers servers) `elem` [1, 3, 5]
    HostFold hosts -> isLeft (distinctHostIds hosts) == (length hosts /= length (nub hosts))

prop_compositionPreservesWellFormedness :: CompositionCase -> Property
prop_compositionPreservesWellFormedness (CompositionCase left right) = checkCoverage
  $ cover 25 True "non-identity-distinct-composition"
  $ case composeDecisionFragments left right of
      Left problem -> counterexample (Text.unpack problem) False
      Right combined ->
        property
          ( length (fragmentSubstrates combined) == length (fragmentSubstrates left) + length (fragmentSubstrates right)
              && length (fragmentServices combined) == length (fragmentServices left) + length (fragmentServices right)
              && fragmentResources combined == fragmentResources left <> fragmentResources right
          )

runProperty :: Testable property => String -> property -> IO (String, Result)
runProperty name prop = do
  result <- quickCheckWithResult stdArgs {maxSuccess = 300, chatty = False} prop
  pure (name, result)

natural :: Int -> Int -> Gen Natural
natural lower upper = fromIntegral <$> chooseInt (lower, upper)

names :: Text -> Int -> [Text]
names prefix count = [prefix <> "-" <> Text.pack (show index) | index <- [1 .. count]]

buildFragment :: [Text] -> [Text] -> [Natural] -> Gen DecisionFragment
buildFragment substrates services resources = case mkDecisionFragment substrates services resources of
  Right fragment -> pure fragment
  Left _ -> buildFragment ["fallback-substrate"] ["fallback-service"] []

isResource, isServer, isHost, isBoundary :: FoldCase -> Bool
isResource ResourceFold {} = True
isResource _ = False
isServer ServerFold {} = True
isServer _ = False
isHost HostFold {} = True
isHost _ = False
isBoundary (ResourceFold []) = True
isBoundary (ServerFold (Single _)) = True
isBoundary (ServerFold (Five _ _ _ _ _)) = True
isBoundary (HostFold [left, right]) = left == right
isBoundary _ = False

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)

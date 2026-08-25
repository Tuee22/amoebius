{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorProps
  ( runEngineAcceleratorProps
  ) where

import Amoebius.Capability.Engine
  ( engineProvisionErrorTag
  )
import Control.Monad (unless)
import EngineAcceleratorFixtures (EngineNegative (..), engineNegatives)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Args (chatty, maxSuccess)
  , Property
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )

newtype GeneratedEngineCase = GeneratedEngineCase Int
  deriving stock (Show)

instance Arbitrary GeneratedEngineCase where
  arbitrary = GeneratedEngineCase <$> chooseInt (0, length engineNegatives - 1)

runEngineAcceleratorProps :: IO Int
runEngineAcceleratorProps = do
  result <- quickCheckWithResult stdArgs {chatty = False, maxSuccess = 1200} propSpecificEngineBranches
  unless (isSuccess result) (fail ("Phase-33 accelerator-provision property failed: " <> show result))
  putStrLn "engine-accelerator-properties: TESTED sampled (8 provision branches, each >=9%)"
  pure 1

propSpecificEngineBranches :: GeneratedEngineCase -> Property
propSpecificEngineBranches (GeneratedEngineCase selected) =
  checkCoverage
    $ foldr (\row next -> cover 9 (engineNegativeName row == engineNegativeName chosen) (show (engineNegativeName row)) next) assertion engineNegatives
 where
  chosen = engineNegatives !! selected
  assertion = case engineNegativeOutcome chosen of
    Left problem ->
      counterexample (show problem)
        $ property
          ( engineProvisionErrorTag problem == engineNegativeExpected chosen
              && isRight (engineNegativeTwinOutcome chosen)
          )
    Right value -> counterexample (show value) (property False)

isRight outcome = case outcome of
  Left _ -> False
  Right _ -> True

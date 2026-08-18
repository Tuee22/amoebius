{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulumi.Teardown
import Control.Monad (unless)
import System.Exit (die)

main :: IO ()
main = do
  assertEq "present-destroy" (Right DestroyThenReobserve) (teardownDecision Ephemeral Present)
  assertEq "absent-skip" (Right AlreadyAbsent) (teardownDecision Ephemeral Absent)
  assertEq "unreachable-refuse" (Left RefuseOnUnreachable) (teardownDecision Ephemeral Unreachable)
  assertEq "durable-retain" (Right RetainDurable) (teardownDecision Durable Present)
  let criteria = SweepCriteria "phase47" "vpc-phase47" "amoebius-p47"
      tagged = ObservedResource "eni-tagged" Ephemeral (Just "phase47") Nothing Nothing
      logOrphan = ObservedResource "log-untagged" Ephemeral Nothing Nothing (Just "amoebius-p47")
      elbOrphan = ObservedResource "elb-untagged" Ephemeral Nothing (Just "vpc-phase47") Nothing
      durable = ObservedResource "vol-durable" Durable (Just "phase47") (Just "vpc-phase47") (Just "amoebius-p47")
      foreignResource = ObservedResource "eni-foreign" Ephemeral (Just "other") (Just "vpc-other") (Just "other")
  assertEq "mut-47.2-skip-sweep" ["eni-tagged"] (sweepRunOwned criteria [tagged])
  assertEq "mut-47-untagged-orphan" ["log-untagged", "elb-untagged"] (sweepRunOwned criteria [logOrphan, elbOrphan])
  assertEq "durable-and-foreign-excluded" [] (sweepRunOwned criteria [durable, foreignResource])
  putStrLn "provider-teardown-contract: PASS (fail-closed teardown and broadened run-owned sweep)"

assertEq :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEq label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

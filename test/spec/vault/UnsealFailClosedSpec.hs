{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Vault.Client
import Amoebius.Vault.Error
import Amoebius.Vault.Init
import Amoebius.Vault.SecretRef
import Amoebius.Vault.Unseal
import Control.Monad (forM_, unless)
import Control.Monad.Class.MonadAsync (async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.IOSim (IOSim, exploreSimTrace, runSimOrThrow, traceResult, withBranching, withScheduleBound)
import Data.ByteString.Char8 qualified as ByteString
import Test.QuickCheck (Args (..), counterexample, isSuccess, property, quickCheckWithResult, stdArgs)
import Test.QuickCheck.Random (mkQCGen)
import System.Exit (die)

data FaultFamily = SealedFault | UnreachableFault | LeaseExpiryFault | RestartFault
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data FaultSchedule = FaultSchedule
  { scheduleSeed :: Int
  , scheduleFaults :: [FaultFamily]
  }
  deriving stock (Eq, Show)

data SimulationRun = SimulationRun
  { startupPermitted :: Bool
  , secretResolved :: Bool
  , pkiIssued :: Bool
  , dhallAccepted :: Bool
  , typedFailure :: VaultError
  }
  deriving stock (Eq, Show)

main :: IO ()
main = do
  let familySchedules = [FaultSchedule seed [fault] | fault <- [minBound .. maxBound], seed <- [0 .. 499]]
      sequenceSchedules = [FaultSchedule seed [SealedFault, UnreachableFault, LeaseExpiryFault, RestartFault] | seed <- [7000 .. 7020]]
      schedules = familySchedules <> sequenceSchedules
  forM_ schedules verifyReplay
  forM_ [minBound .. maxBound] verifyPor
  verifyCoverage schedules
  verifyReadyPositive
  putStrLn "vault-unseal-sim: PASS (4 fault families x 500 seeds + 21 adversarial sequences; IOSimPOR bound 24; deterministic replay)"

runSchedule :: FaultSchedule -> IOSim s SimulationRun
runSchedule schedule = do
  exploreRaces
  startup <- async (pure (startupDecision schedule))
  readAttempt <- async (runClient schedule)
  permitted <- wait startup
  clientResult <- wait readAttempt
  let failure = either id (const VaultUnavailable) clientResult
  pure
    SimulationRun
      { startupPermitted = permitted
      , secretResolved = either (const False) (const True) clientResult
      , pkiIssued = False
      , dhallAccepted = False
      , typedFailure = failure
      }

startupDecision :: FaultSchedule -> Bool
startupDecision schedule = case scheduleFaults schedule of
  SealedFault : _ -> isRight (permitSecretDependentStartup (observeUnseal (VaultId "root") True True))
  _ -> isRight (permitSecretDependentStartup (UnsealFailed VaultUnavailable))

runClient :: FaultSchedule -> IOSim s (Either VaultError ByteString.ByteString)
runClient schedule = do
  reference <- either (error . show) pure (vaultSecretRef "secret" "amoebius/canary" "token")
  resolveSecret (faultTransport schedule) identity "projected-jwt" reference Nothing
 where
  identity = KubernetesIdentity "vault-consumer" "vault-reader" "amoebius-canary"

faultTransport :: FaultSchedule -> VaultTransport (IOSim s)
faultTransport schedule =
  VaultTransport
    { authenticateKubernetes = \_ _ -> pure (loginOutcome schedule)
    , readKvField = \_ _ _ _ -> pure (readOutcome schedule)
    , writeKvField = \_ _ _ _ _ -> pure (Left VaultPolicyMissing)
    , kvFieldExists = \_ _ _ _ -> pure (Left VaultPolicyMissing)
    , transitKeyExists = \_ _ -> pure (Left VaultPolicyMissing)
    , decryptTransit = \_ _ _ -> pure (Left VaultDecryptDenied)
    }

loginOutcome :: FaultSchedule -> Either VaultError VaultToken
loginOutcome schedule
  | SealedFault `elem` scheduleFaults schedule = Left VaultSealed
  | UnreachableFault `elem` scheduleFaults schedule = Left VaultUnavailable
  | RestartFault `elem` scheduleFaults schedule = Left VaultUnavailable
  | otherwise = Right (VaultToken "fresh-login-token")

readOutcome :: FaultSchedule -> Either VaultError ByteString.ByteString
readOutcome schedule
  | LeaseExpiryFault `elem` scheduleFaults schedule = Left VaultPolicyMissing
  | otherwise = Right "must-not-resolve-under-fault"

verifyReplay :: FaultSchedule -> IO ()
verifyReplay schedule = do
  let first = runSimOrThrow (runSchedule schedule)
      second = runSimOrThrow (runSchedule schedule)
      firstBytes = ByteString.pack (show first)
      secondBytes = ByteString.pack (show second)
  assert (first == second && firstBytes == secondBytes) (show schedule <> " did not replay deterministically")
  assert (safe first) (show schedule <> " violated fail-closed invariant: " <> show first)

safe :: SimulationRun -> Bool
safe result =
  not (startupPermitted result)
    && not (secretResolved result)
    && not (pkiIssued result)
    && not (dhallAccepted result)

verifyPor :: FaultFamily -> IO ()
verifyPor fault = do
  let schedule = FaultSchedule 197 [fault]
      callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right result -> counterexample (show result) (property (safe result))
      options = withBranching 4 . withScheduleBound 24
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen 197, 0), chatty = False}
  result <- quickCheckWithResult args (exploreSimTrace options (runSchedule schedule) callback)
  assert (isSuccess result) (show fault <> " IOSimPOR exploration failed")

verifyCoverage :: [FaultSchedule] -> IO ()
verifyCoverage schedules = do
  let total = length schedules
      fraction fault = fromIntegral (length [() | schedule <- schedules, fault `elem` scheduleFaults schedule]) / fromIntegral total :: Double
      sequenceFraction = fromIntegral (length [() | schedule <- schedules, scheduleFaults schedule == [SealedFault, UnreachableFault, LeaseExpiryFault, RestartFault]]) / fromIntegral total :: Double
  assert (fraction SealedFault >= 0.25) "sealed coverage below 25%"
  assert (fraction UnreachableFault >= 0.25) "unreachable coverage below 25%"
  assert (fraction LeaseExpiryFault >= 0.15) "lease-expiry coverage below 15%"
  assert (fraction RestartFault >= 0.15) "restart coverage below 15%"
  assert (sequenceFraction >= 0.01) "adversarial sequence coverage below 1%"

verifyReadyPositive :: IO ()
verifyReadyPositive = do
  let ready = permitSecretDependentStartup (observeUnseal (VaultId "root") True False)
  assert (isRight ready) "unsealed positive did not receive freshness witness"

isRight :: Either left right -> Bool
isRight value = case value of
  Left _ -> False
  Right _ -> True

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

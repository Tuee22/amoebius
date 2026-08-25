{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Sim.Reconcile
  ( referenceReconcile
  , referenceReconcileCommands
  ) where

import Amoebius.Sim.Env
import Control.Monad (forM)
import Control.Monad.Class.MonadAsync (MonadAsync, async, wait)
import Data.Text (Text)

-- | A committed reference program for the substrate gate. Later phases run
-- their own reconcilers through the same 'Env' interface.
referenceReconcile :: MonadAsync m => Env m -> m InvariantOutcome
referenceReconcile = referenceReconcileCommands ["object-store", "sql"]

-- | The same reference program with its intended component sequence supplied as data.
-- Phase 17 uses this seam to consume a real Phase-11 'Composition' projection without
-- making the simulation substrate depend on the calculi it can host.
referenceReconcileCommands :: MonadAsync m => [Text] -> Env m -> m InvariantOutcome
referenceReconcileCommands commands env = do
  publishers <- forM commands (async . envPublish env commandsTopic . ("activate:" <>))
  _ <- mapM wait publishers
  initial <- envConsume env commandsTopic
  messages <- if null initial then envDelay env 10 >> envConsume env commandsTopic else pure initial
  if null messages
    then pure (Violated "CommandEventuallyObserved")
    else persistAndApply env

persistAndApply :: Monad m => Env m -> m InvariantOutcome
persistAndApply env = do
  blob <- envPutBlob env IfNoneMatch (BlobKey "intent") "desired-v1"
  blobOk <- case blob of
    BlobStored -> pure True
    BlobPreconditionFailed412 -> (== Just "desired-v1") <$> envGetBlob env (BlobKey "intent")
  applied <- applyWithRetry env
  _ <- envWriteDns env (DnsName "service.example") (DnsValue "new")
  _ <- envReadDns env (DnsName "service.example")
  secret <- envVaultOp env (VaultWrite (VaultPath "service/token") "token")
  _ <- envNow env
  pure $ case (blobOk, applied, secret) of
    (True, True, VaultValue (Just "token")) -> Upheld
    (False, _, _) -> Violated "BlobIntentStable"
    (_, False, _) -> Violated "ObjectEventuallyApplied"
    (_, _, _) -> Violated "VaultWriteAccepted"

applyWithRetry :: Monad m => Env m -> m Bool
applyWithRetry env = do
  first <- envApplyObject env (ObjectName "service") (ResourceVersion 0) "desired-v1"
  case first of
    ObjectApplied _ -> pure True
    ApplyCrashed -> envDelay env 10 >> retry
    ResourceVersionConflict current -> retryAt current
  where
    retry = do
      result <- envApplyObject env (ObjectName "service") (ResourceVersion 0) "desired-v1"
      pure $ case result of
        ObjectApplied _ -> True
        ResourceVersionConflict _ -> False
        ApplyCrashed -> False
    retryAt version = do
      result <- envApplyObject env (ObjectName "service") version "desired-v1"
      pure $ case result of
        ObjectApplied _ -> True
        ResourceVersionConflict _ -> False
        ApplyCrashed -> False

commandsTopic :: Topic
commandsTopic = Topic "amoebius.commands"

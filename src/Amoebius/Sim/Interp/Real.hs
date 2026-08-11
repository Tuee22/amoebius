{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Sim.Interp.Real
  ( RealClients (..)
  , noOpRealClients
  , realEnv
  ) where

import Amoebius.Sim.Env
import Control.Monad.Class.MonadTime (MonadTime, getCurrentTime)
import Control.Monad.Class.MonadTimer (MonadDelay, threadDelay)
import qualified Data.Text

-- | The production interpreter delegates to injected real clients. Keeping
-- the clients as a record makes the reconcile program identical under both
-- interpreters while preserving an explicit effect boundary.
data RealClients m = RealClients
  { realPublish :: Topic -> Data.Text.Text -> m MessageId
  , realConsume :: Topic -> m [Message]
  , realPutBlob :: PutCondition -> BlobKey -> Data.Text.Text -> m BlobResult
  , realGetBlob :: BlobKey -> m (Maybe Data.Text.Text)
  , realApplyObject :: ObjectName -> ResourceVersion -> Data.Text.Text -> m ApplyResult
  , realWatchObjects :: ResourceVersion -> m WatchResult
  , realWriteDns :: DnsName -> DnsValue -> m DnsResult
  , realReadDns :: DnsName -> m (Maybe DnsValue)
  , realVaultOp :: VaultOp -> m VaultResult
  }

noOpRealClients :: Applicative m => RealClients m
noOpRealClients =
  RealClients
    { realPublish = \_ _ -> pure (MessageId 1)
    , realConsume = \_ -> pure [Message (MessageId 1) "noop"]
    , realPutBlob = \_ _ _ -> pure BlobStored
    , realGetBlob = \_ -> pure Nothing
    , realApplyObject = \_ _ _ -> pure (ObjectApplied (ResourceVersion 1))
    , realWatchObjects = \_ -> pure (WatchObjects [])
    , realWriteDns = \_ _ -> pure DnsWritten
    , realReadDns = \_ -> pure Nothing
    , realVaultOp = \operation -> case operation of
        VaultRead _ -> pure (VaultValue Nothing)
        VaultWrite _ value -> pure (VaultValue (Just value))
    }

realEnv :: (MonadTime m, MonadDelay m) => RealClients m -> Env m
realEnv clients =
  Env
    { envPublish = realPublish clients
    , envConsume = realConsume clients
    , envPutBlob = realPutBlob clients
    , envGetBlob = realGetBlob clients
    , envApplyObject = realApplyObject clients
    , envWatchObjects = realWatchObjects clients
    , envWriteDns = realWriteDns clients
    , envReadDns = realReadDns clients
    , envVaultOp = realVaultOp clients
    , envNow = getCurrentTime
    , envDelay = threadDelay
    }

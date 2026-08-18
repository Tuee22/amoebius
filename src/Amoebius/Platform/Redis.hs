{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Redis
  ( RedisDemand (..)
  , ProvisionedRedis (..)
  , provisionRedis
  , renderRedis
  ) where

import Amoebius.Platform.Types
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data RedisDemand = RedisDemand
  { redisImage :: Text
  , redisDataReplicas :: Natural
  , redisSentinelReplicas :: Natural
  , redisMaximumMemoryBytes :: Natural
  , redisMaximumClients :: Natural
  , redisOutputBufferBytes :: Natural
  , redisChallengeTtlSeconds :: Natural
  , redisTlsSecretRef :: Text
  , redisPersistenceRequested :: Bool
  , redisReceiptAuthorityRequested :: Bool
  , redisResources :: ResourceEnvelope
  , redisSentinelResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

newtype ProvisionedRedis = ProvisionedRedis {provisionedRedisDemand :: RedisDemand}
  deriving stock (Eq, Show)

provisionRedis :: RedisDemand -> Either Text ProvisionedRedis
provisionRedis demand = do
  _ <- traverse validateResourceEnvelope [redisResources demand, redisSentinelResources demand]
  if redisDataReplicas demand < 3 || redisSentinelReplicas demand < 3
    then Left "redis-sentinel-ha-topology-required"
    else if Text.null (redisTlsSecretRef demand)
      then Left "redis-vault-tls-secret-required"
      else if effectivePersistence demand
        then Left "redis-persistence-forbidden"
        else if effectiveBuffer demand == 0 || redisMaximumMemoryBytes demand == 0 || redisMaximumClients demand == 0 || redisChallengeTtlSeconds demand == 0
          then Left "redis-bounds-must-be-finite-positive"
          else if effectiveReceiptAuthority demand
            then Left "redis-receipt-authority-forbidden"
            else if isPublic (effectiveImage demand)
              then Left "redis-public-image-forbidden"
              else Right (ProvisionedRedis demand)
 where
#ifdef PLATFORM_SERVICES_2_REDIS_PVC_MUTANT
  effectivePersistence _ = True
#else
  effectivePersistence = redisPersistenceRequested
#endif
#ifdef PLATFORM_SERVICES_2_REDIS_UNBOUNDED_BUFFER_MUTANT
  effectiveBuffer _ = 0
#else
  effectiveBuffer = redisOutputBufferBytes
#endif
#ifdef PLATFORM_SERVICES_2_REDIS_RECEIPT_AUTHORITY_MUTANT
  effectiveReceiptAuthority _ = True
#else
  effectiveReceiptAuthority = redisReceiptAuthorityRequested
#endif
#ifdef PLATFORM_SERVICES_2_REDIS_PUBLIC_IMAGE_MUTANT
  effectiveImage _ = "docker.io/library/redis:latest"
#else
  effectiveImage = redisImage
#endif
  isPublic image = any (`Text.isPrefixOf` image) ["docker.io/", "quay.io/", "ghcr.io/"]

renderRedis :: ProvisionedRedis -> [PlatformObject]
renderRedis provision =
  [ object "StatefulSet" "redis" (redisDataReplicas demand)
      ["/bin/bash", "-ec", redisServerCommand]
      (redisResources demand)
  , object "Deployment" "sentinel" (redisSentinelReplicas demand)
      ["/bin/bash", "-ec", sentinelCommand]
      (redisSentinelResources demand)
  ]
 where
  demand = provisionedRedisDemand provision
  object kind name replicas arguments resources =
    PlatformObject kind "redis-system" name replicas (redisImage demand) arguments (Just resources) Nothing Nothing
  redisServerCommand =
    "ordinal=${HOSTNAME##*-}; replica=''; if [ \"$ordinal\" != 0 ]; then replica='--replicaof redis-0.redis-headless.redis-system.svc 6379'; fi; exec /usr/bin/redis-server --port 0 --tls-port 6379 --tls-cert-file /tls/tls.crt --tls-key-file /tls/tls.key --tls-ca-cert-file /tls/ca.crt --tls-auth-clients yes --tls-replication yes --aclfile /tls/users.acl --masteruser replication --masterauth \"$(cat /tls/replication-password)\" --dir /data --save '' --appendonly no --maxmemory "
      <> showText (redisMaximumMemoryBytes demand)
      <> " --maxclients " <> showText (redisMaximumClients demand)
      <> " --client-output-buffer-limit 'normal " <> showText (redisOutputBufferBytes demand) <> " " <> showText (redisOutputBufferBytes demand) <> " 1' $replica"
  sentinelCommand =
    "password=$(cat /tls/replication-password); sentinel_password=$(cat /tls/sentinel-password); cat > /tmp/sentinel.conf <<EOF\nport 0\ntls-port 26379\ntls-cert-file /tls/tls.crt\ntls-key-file /tls/tls.key\ntls-ca-cert-file /tls/ca.crt\ntls-auth-clients yes\ntls-replication yes\nrequirepass $sentinel_password\nsentinel monitor amoebius redis-0.redis-headless.redis-system.svc 6379 2\nsentinel auth-user amoebius replication\nsentinel auth-pass amoebius $password\nsentinel sentinel-user default\nsentinel sentinel-pass $sentinel_password\nsentinel resolve-hostnames yes\nsentinel announce-hostnames yes\nsentinel down-after-milliseconds amoebius 5000\nsentinel failover-timeout amoebius 30000\nEOF\nexec /usr/bin/redis-server /tmp/sentinel.conf --sentinel"
  showText = Text.pack . show

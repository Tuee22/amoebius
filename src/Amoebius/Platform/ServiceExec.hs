{-# LANGUAGE OverloadedStrings #-}

-- | Fixed service launch profiles. Kubernetes carries only a Vault identity;
-- credentials are fetched before exec and exist only in the child environment.
module Amoebius.Platform.ServiceExec (runPlatformServiceExec) where

import Amoebius.Vault.Client
import Control.Monad (unless)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import System.Environment (getEnvironment)
import System.Posix.Process (executeFile)

runPlatformServiceExec :: [String] -> IO ()
runPlatformServiceExec [profile] = do
  (namespace, account, role, credentialPath, program, arguments, names) <- case profile of
    "minio" -> pure ("platform-system", "minio-server", "amoebius-minio-server", "phase30/minio", "/usr/bin/minio",
      ["server", "/data0", "/data1", "/data2", "/data3", "--address", ":9000", "--console-address", ":9001"],
      ("MINIO_ROOT_USER", "MINIO_ROOT_PASSWORD"))
    "registry" -> pure ("platform-system", "registry-writer", "amoebius-registry-writer", "phase30/writers/registry", "/usr/bin/docker-registry", ["serve", "/etc/distribution/config.yml"],
      ("REGISTRY_STORAGE_S3_ACCESSKEY", "REGISTRY_STORAGE_S3_SECRETKEY"))
    "pulsar-broker" -> pure ("pulsar-system", "pulsar-offload-writer", "amoebius-pulsar-offload-writer", "phase30/writers/pulsar-offload", "/bin/bash", ["-ec",
      "cp /phase30-config/broker.conf /tmp/broker.conf; printf 'advertisedAddress=%s.broker-headless.pulsar-system.svc.cluster.local\\n' \"$HOSTNAME\" >> /tmp/broker.conf; exec /pulsar/bin/pulsar broker"],
      ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"))
    _ -> fail "platform-service-profile-unknown"
  jwt <- BS.readFile "/var/run/secrets/kubernetes.io/serviceaccount/token"
  let transport = mkHttpVaultTransport (HttpVaultAddress "root-vault.vault-system.svc" "8200")
  token <- authenticateKubernetes transport (KubernetesIdentity namespace account role) jwt
    >>= either (const (fail "platform-service-vault-login-denied")) pure
  access <- readKvField transport token "secret" credentialPath "access-key"
    >>= either (const (fail "platform-service-vault-access-denied")) pure
  secret <- readKvField transport token "secret" credentialPath "secret-key"
    >>= either (const (fail "platform-service-vault-secret-denied")) pure
  unless (all (\value -> not (BS.null value) && not (BS.elem 0 value)) [access, secret])
    (fail "platform-service-vault-value-invalid")
  environment <- getEnvironment
  let (accessName, secretName) = names
      projected = [(accessName, B.unpack access), (secretName, B.unpack secret)]
        <> filter (\(key, _) -> key `notElem` [accessName, secretName]) environment
  executeFile program False arguments (Just projected)
runPlatformServiceExec _ = fail "usage: platform-service-exec minio|registry|pulsar-broker"

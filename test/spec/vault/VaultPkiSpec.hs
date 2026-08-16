{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Vault.Client
import Amoebius.Vault.Error
import Amoebius.Vault.Init
import Amoebius.Vault.Pki
import Amoebius.Vault.Seal
import Amoebius.Vault.SecretRef
import Amoebius.Vault.Unseal
import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Exit (die)

main :: IO ()
main = do
  verifyInitAndStorage
  verifyEnvelope
  verifyPki
  verifyErrors
  verifyClient
  verifyFailClosedFreshness
  putStrLn "vault-pki-spec: PASS (init-once, Argon2id-AEAD, bounded storage, PKI, direct client, typed failures)"

verifyInitAndStorage :: IO ()
verifyInitAndStorage = do
  let identity = VaultId "vault-cluster-a"
  assertEqual "empty initializes once" InitializeOnce (planInit EmptyRetainedVolume)
  assertEqual "initialized sealed unseals" (UnsealExisting identity) (planInit (InitializedSealed identity))
  assertEqual "nonempty uninitialized refuses" RefuseNonEmptyUninitialized (planInit NonEmptyUninitializedVolume)
  provisioned <- requireRight (provisionVaultStorage 134217728 67108864 standardVaultStorageDemand standardVaultAuditDemand)
  assertEqual "resident bytes" 425984 (vaultResidentBytes provisioned)
  assertEqual "Raft usable high-water" 2023424 (vaultRequiredUsableBytes provisioned)
  assertEqual "rounded durable raw" 134217728 (vaultProvisionedRawBytes provisioned)
  assertEqual "audit usable" 4194304 (auditRequiredUsableBytes provisioned)
  assertEqual "audit raw minimum" 67108864 (auditProvisionedRawBytes provisioned)
  assertEqual
    "one-byte-under durable is effectless rejection"
    (Left (DurableBackingTooSmall 134217728 134217727))
    (provisionVaultStorage 134217727 67108864 standardVaultStorageDemand standardVaultAuditDemand)
  assertEqual
    "one-byte-under audit is effectless rejection"
    (Left (AuditBackingTooSmall 67108864 67108863))
    (provisionVaultStorage 134217728 67108863 standardVaultStorageDemand standardVaultAuditDemand)

verifyEnvelope :: IO ()
verifyEnvelope = do
  let password = "phase29-test-password"
      plaintext = "unseal-key-and-root-token-never-logged"
      salt = ByteString.pack [0 .. 15]
      nonce = ByteString.pack [16 .. 27]
  envelope <- requireRight (sealUnlockMaterial password salt nonce plaintext)
  magicSpec <- ByteString.readFile "test/golden/vault/unlock-envelope.spec"
  assertBool "oracle pins Argon2id" ("kdf=Argon2id-v1.3" `ByteString.isInfixOf` magicSpec)
  assertBool "envelope has pinned magic" ("AMOEBIUS-VAULT-UNLOCK\0" `ByteString.isPrefixOf` envelope)
  assertEqual "round trip" (Right plaintext) (openUnlockMaterial password envelope)
  assertBool "wrong password fails authentication" (isLeft (openUnlockMaterial "wrong-password" envelope))
  let finalIndex = ByteString.length envelope - 1
      tampered = ByteString.take finalIndex envelope <> ByteString.singleton (ByteString.index envelope finalIndex + 1)
  assertBool "tamper fails authentication" (isLeft (openUnlockMaterial password tampered))

verifyPki :: IO ()
verifyPki = do
  let root = RootCa "root-key-a"
  leaf <- requireRight (issueInternalLeaf False root "service.vault-system.svc")
  assertBool "leaf chains to root" (verifiesAgainst root leaf)
  assertEqual "sealed issuance fails" (Left VaultSealed) (issueInternalLeaf True root "denied.vault-system.svc")

verifyErrors :: IO ()
verifyErrors = do
  rows <- fmap Text.lines (TextIO.readFile "test/golden/vault/error-tags.golden")
  let actual = [errorTag failure <> "|" <> redactedErrorLog failure | failure <- [minBound .. maxBound]]
  assertEqual "six exact typed redacted errors" rows actual
  assertBool "missing log contains no requested path" (not ("amoebius/canary" `Text.isInfixOf` redactedErrorLog VaultSecretMissing))

verifyClient :: IO ()
verifyClient = do
  loginCount <- newIORef (0 :: Int)
  writtenValue <- newIORef Nothing
  let transport =
        VaultTransport
          { authenticateKubernetes = \identity jwt -> do
              modifyIORef' loginCount (+ 1)
              pure $ if identityNamespace identity == "vault-consumer" && identityServiceAccount identity == "vault-reader" && jwt == "jwt"
                then Right (VaultToken "login-token")
                else Left VaultPolicyMissing
          , readKvField = \token mount path field ->
              pure $ if token == VaultToken "login-token" && (mount, path, field) == ("secret", "amoebius/canary", "token")
                then Right "phase29-canary-32-byte-value!!!!"
                else Left VaultSecretMissing
          , writeKvField = \token mount path field secretValue ->
              if token == VaultToken "login-token" && (mount, path, field) == ("secret", "operator/bootstrap", "password")
                then writeIORef writtenValue (Just secretValue) >> pure (Right ())
                else pure (Left VaultPolicyMissing)
          , kvFieldExists = \_ mount path field ->
              pure (Right ((mount, path, field) == ("secret", "amoebius/canary", "token")))
          , transitKeyExists = \_ key -> pure (Right (key == "canary-key"))
          , decryptTransit = \_ key ciphertext ->
              pure $ if key == "canary-key" && ciphertext == "vault:v1:ciphertext" then Right "transit-cleartext" else Left VaultDecryptDenied
          }
      identity = KubernetesIdentity "vault-consumer" "vault-reader" "amoebius-canary"
  reference <- requireRight (vaultSecretRef "secret" "amoebius/canary" "token")
  value <- resolveSecret transport identity "jwt" reference Nothing
  assertEqual "SecretRef resolves by name" (Right "phase29-canary-32-byte-value!!!!") value
  assertEqual "client performs auth/kubernetes/login" 1 =<< readIORef loginCount
  transit <- requireRight (transitKeyRef "canary-key")
  clear <- resolveSecret transport identity "jwt" transit (Just "vault:v1:ciphertext")
  assertEqual "TransitKey unwrap" (Right "transit-cleartext") clear
  prompt <- requireRight (promptRef "bootstrap-password" "initialize the root Vault")
  stored <- writePromptSecret transport identity "jwt" prompt "secret" "operator/bootstrap" "password" "typed-at-stdin"
  assertEqual "Prompt writes into Vault" (Right ()) stored
  assertEqual "prompt value reaches only write transport" (Just "typed-at-stdin") =<< readIORef writtenValue
  missingKv <- requireRight (vaultSecretRef "secret" "missing/one" "token")
  missingTransit <- requireRight (transitKeyRef "missing-key")
  presence <- assertSecretsPresent transport identity "jwt" [reference, transit, missingKv, missingTransit]
  assertEqual "presence reports every missing reference" (Left (MissingSecrets [missingKv, missingTransit])) presence
  beforeEmpty <- readIORef loginCount
  assertEqual "empty reference set needs no Vault" (Right ()) =<< assertSecretsPresent transport identity "not-used" []
  assertEqual "empty admission did not authenticate" beforeEmpty =<< readIORef loginCount
  denied <- resolveSecret transport (identity {identityServiceAccount = "foreign"}) "jwt" reference Nothing
  assertEqual "foreign service account denied" (Left VaultPolicyMissing) denied

verifyFailClosedFreshness :: IO ()
verifyFailClosedFreshness = do
  let identity = VaultId "vault-cluster-a"
  assertBool "sealed cannot start" (isLeft (permitSecretDependentStartup (observeUnseal identity True True)))
  assertBool "uninitialized cannot start" (isLeft (permitSecretDependentStartup (observeUnseal identity False True)))
  assertBool "unsealed can start" (not (isLeft (permitSecretDependentStartup (observeUnseal identity True False))))

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

isLeft :: Either left right -> Bool
isLeft value = case value of
  Left _ -> True
  Right _ -> False

assertBool :: String -> Bool -> IO ()
assertBool label condition
  | condition = pure ()
  | otherwise = die label

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)

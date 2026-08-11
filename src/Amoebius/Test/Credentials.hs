{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Test.Credentials
  ( SecretRef
  , TestCredential
  , CredentialError (..)
  , secretRef
  , flaggedTestCredential
  , credentialSecretName
  , credentialIsTestSimulation
  ) where

import Data.Text (Text)

newtype SecretRef = SecretRef Text
  deriving stock (Eq, Show)

data TestCredential = TestCredential SecretRef Bool
  deriving stock (Eq, Show)

data CredentialError = EmptySecretRef | TestSimulationFlagRequired
  deriving stock (Eq, Show)

secretRef :: Text -> Either CredentialError SecretRef
secretRef name
  | name == "" = Left EmptySecretRef
  | otherwise = Right (SecretRef name)

flaggedTestCredential :: SecretRef -> Bool -> Either CredentialError TestCredential
flaggedTestCredential ref True = Right (TestCredential ref True)
flaggedTestCredential _ False = Left TestSimulationFlagRequired

credentialSecretName :: TestCredential -> Text
credentialSecretName (TestCredential (SecretRef name) _) = name

credentialIsTestSimulation :: TestCredential -> Bool
credentialIsTestSimulation (TestCredential _ flagged) = flagged

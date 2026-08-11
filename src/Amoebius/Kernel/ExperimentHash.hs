{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Kernel.ExperimentHash
  ( ResolvedDhall (..)
  , FingerprintWitness (..)
  , SubstrateFingerprint
  , ExperimentHash
  , mkSubstrateFingerprint
  , substrateFingerprintBytes
  , experimentHashText
  , deriveExperimentHash
  ) where

import Amoebius.Kernel.ContentAddress (blobShaText, contentAddress)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as Char8
import Data.List (sortOn)
import Data.Text (Text)
import Data.Text qualified as Text

newtype ResolvedDhall = ResolvedDhall {resolvedDhallBytes :: ByteString}
  deriving stock (Eq, Ord, Show)

data FingerprintWitness = FingerprintWitness
  { witnessName :: Text
  , witnessAbsoluteProbe :: FilePath
  , witnessValue :: Text
  }
  deriving stock (Eq, Ord, Show)

data SubstrateFingerprint = SubstrateFingerprint Text [FingerprintWitness]
  deriving stock (Eq, Ord, Show)

newtype ExperimentHash = ExperimentHash Text
  deriving stock (Eq, Ord, Show)

mkSubstrateFingerprint :: Text -> [FingerprintWitness] -> Either Text SubstrateFingerprint
mkSubstrateFingerprint lane witnesses
  | lane == "" = Left "FingerprintLaneMissing"
  | map witnessName (sortOn witnessName witnesses) /= ["ghc", "isa", "libcAbi", "rts"] = Left "FingerprintWitnessSetMismatch"
  | any (not . absolute . witnessAbsoluteProbe) witnesses = Left "FingerprintProbeNotAbsolute"
  | any ((== "") . witnessValue) witnesses = Left "FingerprintWitnessValueMissing"
  | otherwise = Right (SubstrateFingerprint lane (sortOn witnessName witnesses))
 where
  absolute ('/' : _) = True
  absolute _ = False

substrateFingerprintBytes :: SubstrateFingerprint -> ByteString
substrateFingerprintBytes (SubstrateFingerprint lane witnesses) =
  Char8.pack (Text.unpack lane) <> mconcat (map render witnesses)
 where
  render witness = Char8.pack ("\0" <> Text.unpack (witnessName witness) <> "\0" <> witnessAbsoluteProbe witness <> "\0" <> Text.unpack (witnessValue witness))

experimentHashText :: ExperimentHash -> Text
experimentHashText (ExperimentHash value) = value

deriveExperimentHash :: ResolvedDhall -> SubstrateFingerprint -> ExperimentHash
deriveExperimentHash (ResolvedDhall program) fingerprint =
#ifdef PHASE48_CONST_FINGERPRINT_MUTANT
  ExperimentHash (blobShaText (contentAddress (program <> Char8.pack "\0linux-cpu")))
#else
  ExperimentHash (blobShaText (contentAddress (program <> Char8.pack "\0" <> substrateFingerprintBytes fingerprint)))
#endif

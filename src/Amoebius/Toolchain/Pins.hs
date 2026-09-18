{-# LANGUAGE OverloadedStrings #-}

-- | The GenesisTrust pins spelled once in product code (phase_01, Sprint 1.1).
--
-- Seven local-custody files, the compiler and package-tool identities, and the
-- one canonical platform. Nothing here reads a host: the values are literals the
-- independent oracle restates, and every other toolchain module consumes them.
module Amoebius.Toolchain.Pins
  ( Pin (..)
  , PinRole (..)
  , Platform (..)
  , ToolIdentity (..)
  , compilerIdentity
  , genesisPins
  , inputsDirectory
  , keyringFile
  , manifestNameFor
  , packageToolIdentity
  , pinFor
  , platform
  , renderPin
  , renderPinRole
  , renderPlatform
  , signatureNameFor
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

-- | What a pinned file is for. The archives carry the tools, the manifests carry
-- the publisher's digests, and the signatures bind each manifest or archive to
-- the publisher key.
data PinRole
  = CompilerArchive
  | CompilerArchiveSignature
  | CompilerManifest
  | CompilerManifestSignature
  | PackageToolArchive
  | PackageToolManifest
  | PackageToolManifestSignature
  deriving (Bounded, Enum, Eq, Ord, Show)

renderPinRole :: PinRole -> Text
renderPinRole role = case role of
  CompilerArchive -> "compiler-archive"
  CompilerArchiveSignature -> "compiler-archive-signature"
  CompilerManifest -> "compiler-manifest"
  CompilerManifestSignature -> "compiler-manifest-signature"
  PackageToolArchive -> "package-tool-archive"
  PackageToolManifest -> "package-tool-manifest"
  PackageToolManifestSignature -> "package-tool-manifest-signature"

-- | One pinned file: its name beneath the inputs directory, its exact byte
-- count, and its lowercase SHA-256.
data Pin = Pin
  { pinRole :: PinRole
  , pinName :: FilePath
  , pinBytes :: Integer
  , pinSha256 :: Text
  }
  deriving (Eq, Ord, Show)

-- | The repository-relative directory the seven files live in. It is ignored by
-- Git and prepared by the operator; nothing beneath it is authored source.
inputsDirectory :: FilePath
inputsDirectory = ".build/bootstrap-inputs"

-- | The operator-supplied publisher keyring beside the pins. It is trusted, not
-- authenticated (phase_01 residue row).
keyringFile :: FilePath
keyringFile = "publisher-keyring.gpg"

genesisPins :: [Pin]
genesisPins =
  [ Pin CompilerArchive "ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz" 302637420 "4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa"
  , Pin CompilerArchiveSignature "ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig" 438 "a5c8828b3c1c53cfc8d5e4459de0790efa5a8dea96cc16dd564382f005280cc5"
  , Pin CompilerManifest "ghc-SHA256SUMS" 6585 "67869bc776c7f0ffe76226a689c234b367b2194aececbb53da2275892040053b"
  , Pin CompilerManifestSignature "ghc-SHA256SUMS.sig" 438 "9db94ced16b87713e89a41c408bf5efcb29462971c2494fbfec7e05a33de6bad"
  , Pin PackageToolArchive "cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz" 5288744 "9d68bd17d4aa87e93eea3f667d3edf41ab1cb2b5194bf1745da9dee678426c17"
  , Pin PackageToolManifest "cabal-SHA256SUMS" 2799 "19ef5e11a70d6d06ae23a2b4cae6b52bcf19575be7343fc9dfcce4104bce8bb3"
  , Pin PackageToolManifestSignature "cabal-SHA256SUMS.sig" 95 "59fa7dbebd873bd1714f440111fe1607148d25afd23450e4c5ee9afdc38c4eb3"
  ]

pinFor :: PinRole -> Maybe Pin
pinFor role = case [pin | pin <- genesisPins, pinRole pin == role] of
  [pin] -> Just pin
  _ -> Nothing

-- | The manifest that must list an archive's digest, and the signature that
-- binds a signed file, by role.
manifestNameFor :: PinRole -> Maybe FilePath
manifestNameFor role = case role of
  CompilerArchive -> pinName <$> pinFor CompilerManifest
  PackageToolArchive -> pinName <$> pinFor PackageToolManifest
  _ -> Nothing

signatureNameFor :: PinRole -> Maybe FilePath
signatureNameFor role = case role of
  CompilerArchive -> pinName <$> pinFor CompilerArchiveSignature
  CompilerManifest -> pinName <$> pinFor CompilerManifestSignature
  PackageToolManifest -> pinName <$> pinFor PackageToolManifestSignature
  _ -> Nothing

renderPin :: Pin -> Text
renderPin pin = Text.intercalate " " [renderPinRole (pinRole pin), Text.pack (pinName pin), Text.pack (show (pinBytes pin)), pinSha256 pin]

-- | A tool the archives carry: its name, version, the path of its executable
-- inside the extracted archive, and the SHA-256 of that executable's bytes.
data ToolIdentity = ToolIdentity
  { toolName :: Text
  , toolVersion :: Text
  , toolExecutable :: FilePath
  , toolSha256 :: Text
  }
  deriving (Eq, Ord, Show)

compilerIdentity :: ToolIdentity
compilerIdentity =
  ToolIdentity
    { toolName = "ghc"
    , toolVersion = "9.12.4"
    , toolExecutable = "ghc-9.12.4-x86_64-unknown-linux/bin/ghc-9.12.4"
    , toolSha256 = "29b0a853efd81eeed37f5d5ffe8add38f3bd0daa87a8838deaf088ec458e99fc"
    }

packageToolIdentity :: ToolIdentity
packageToolIdentity =
  ToolIdentity
    { toolName = "cabal-install"
    , toolVersion = "3.16.1.0"
    , toolExecutable = "cabal"
    , toolSha256 = "27a896cd2389c336d8c492dbb4d49dd22148a278150f9e4619a84c0ea6a307fb"
    }

-- | The one canonical @<os>-<arch>@ value this pin set is for. It is supplied as
-- a case, never discovered from a host.
data Platform = Platform
  { platformOs :: Text
  , platformArch :: Text
  }
  deriving (Eq, Ord, Show)

platform :: Platform
platform = Platform "linux" "x86_64"

renderPlatform :: Platform -> Text
renderPlatform value = platformOs value <> "-" <> platformArch value

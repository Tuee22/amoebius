{-# LANGUAGE OverloadedStrings #-}

-- | Upstream provenance for the maintained fork (phase_01, Sprint 1.7).
--
-- The immutable upstream identity is a Haskell value: the release name, its
-- version, and the digest of its source tree. Upstream material is acquired
-- from the network-independent package input beneath @.build/vendor/**@ as an
-- archive extraction at that identity, never as a nested version-control
-- checkout, and a digest that does not match the acquired bytes is refused. The
-- maintained Haskell fork lives beneath @src/vendor/**@; a top-level vendor
-- root, a patch program, a tracked foreign package description, a mutable
-- reference, and a developer-home path are refused by name.
module Amoebius.Toolchain.Provenance
  ( AcquiredUpstream (..)
  , ProvenanceRefusal (..)
  , Reference (..)
  , UpstreamIdentity (..)
  , acquireUpstream
  , admitReference
  , forkModules
  , forkUpstream
  , refuseLayout
  , renderAcquiredUpstream
  , renderProvenanceRefusal
  , renderReference
  , treeDigest
  , verifyFork
  ) where

import Amoebius.Toolchain.Acquire (Acquisition (..), ChildRecord (..), sha256Bytes, sha256File, spawnChild)
import Control.Monad (filterM, forM)
import Data.Char (isHexDigit)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath (makeRelative, (</>))

-- | An immutable upstream identity: a released source tree whose digest is
-- fixed. The digest is over the sorted @<relative path> <sha256>@ lines of the
-- extracted tree.
data UpstreamIdentity = UpstreamIdentity
  { upstreamName :: Text
  , upstreamVersion :: Text
  , upstreamTreeDigest :: Text
  , upstreamFileCount :: Int
  }
  deriving (Eq, Ord, Show)

-- | The fork's upstream: the supernova release the Pulsar client re-derives.
forkUpstream :: UpstreamIdentity
forkUpstream =
  UpstreamIdentity
    { upstreamName = "supernova"
    , upstreamVersion = "0.0.3"
    , upstreamTreeDigest = "2e2f01be19b08128cd8549befcc1da3fea172b1f5b3471845d05ef8dc06dda33"
    , upstreamFileCount = 22
    }

-- | The maintained fork modules beneath @src/vendor/**@, as a value.
forkModules :: [Text]
forkModules =
  [ "Pulsar"
  , "Pulsar.AppState"
  , "Pulsar.Connection"
  , "Pulsar.Consumer"
  , "Pulsar.Core"
  , "Pulsar.Internal.Core"
  , "Pulsar.Internal.Logger"
  , "Pulsar.Internal.TCPClient"
  , "Pulsar.Producer"
  , "Pulsar.Protocol.CheckSum"
  , "Pulsar.Protocol.Commands"
  , "Pulsar.Protocol.Decoder"
  , "Pulsar.Protocol.Encoder"
  , "Pulsar.Protocol.Frame"
  , "Pulsar.Types"
  , "Data.Bifunctor.Flip"
  , "Control.Category.Dual"
  ]

data ProvenanceRefusal
  = MutableIdentity Text
  | AbsentIdentity Text
  | DeveloperHome FilePath
  | DigestMismatch Text Text
  | NestedCheckout FilePath
  | TopLevelVendor FilePath
  | PatchProgram FilePath
  | TrackedForeignPackage FilePath
  | ForkModuleMissing Text
  | AcquisitionFailed Text
  deriving (Eq, Ord, Show)

renderProvenanceRefusal :: ProvenanceRefusal -> Text
renderProvenanceRefusal refusal = case refusal of
  MutableIdentity reference -> "MutableIdentity: " <> reference
  AbsentIdentity reference -> "AbsentIdentity: " <> reference
  DeveloperHome path -> "DeveloperHomePath: " <> Text.pack path
  DigestMismatch expected observed -> "DigestMismatch: expected=" <> expected <> " observed=" <> observed
  NestedCheckout path -> "NestedCheckout: " <> Text.pack path
  TopLevelVendor path -> "TopLevelVendor: " <> Text.pack path
  PatchProgram path -> "PatchProgram: " <> Text.pack path
  TrackedForeignPackage path -> "TrackedForeignPackage: " <> Text.pack path
  ForkModuleMissing name -> "ForkModuleMissing: " <> name
  AcquisitionFailed detail -> "UpstreamAcquisitionFailed: " <> detail

-- | How an upstream may be named. Only an immutable form is admitted.
data Reference
  = HackageRelease Text Text
  | GitCommit Text Text
  | GitBranch Text Text
  | LocalPath FilePath
  deriving (Eq, Ord, Show)

renderReference :: Reference -> Text
renderReference reference = case reference of
  HackageRelease name version -> "hackage:" <> name <> "-" <> version
  GitCommit location commit -> "git:" <> location <> "@" <> commit
  GitBranch location branch -> "git:" <> location <> "#" <> branch
  LocalPath path -> "path:" <> Text.pack path

-- | A release or a full commit is immutable; a branch, an empty identity, or
-- a developer-home path is refused.
admitReference :: Reference -> Either ProvenanceRefusal Reference
admitReference reference = case reference of
  HackageRelease name version
    | Text.null name || Text.null version -> Left (AbsentIdentity (renderReference reference))
    | otherwise -> Right reference
  GitCommit _ commit
    | Text.length commit == 40 && Text.all isHexDigit commit -> Right reference
    | Text.null commit -> Left (AbsentIdentity (renderReference reference))
    | otherwise -> Left (MutableIdentity (renderReference reference))
  GitBranch {} -> Left (MutableIdentity (renderReference reference))
  LocalPath path
    | "/home/" `isPrefixOf` path || "/Users/" `isPrefixOf` path || "~" `isPrefixOf` path -> Left (DeveloperHome path)
    | otherwise -> Left (MutableIdentity (renderReference reference))

-- | The tree digest and file count of a directory.
treeDigest :: FilePath -> IO (Text, Int)
treeDigest root = do
  files <- sort . map (makeRelative root) <$> walk root
  rows <- forM files $ \file -> (\digest -> Text.pack file <> " " <> digest) <$> sha256File (root </> file)
  pure (sha256Bytes (TextEncoding.encodeUtf8 (Text.unlines rows)), length files)
 where
  walk directory = do
    names <- listDirectory directory
    directories <- filterM (doesDirectoryExist . (directory </>)) names
    nested <- concat <$> mapM (walk . (directory </>)) directories
    pure ([directory </> name | name <- names, name `notElem` directories] <> nested)

data AcquiredUpstream = AcquiredUpstream
  { acquiredIdentity :: UpstreamIdentity
  , acquiredRoot :: FilePath
  , acquiredDigest :: Text
  , acquiredFiles :: Int
  , acquiredChild :: ChildRecord
  }
  deriving (Eq, Show)

renderAcquiredUpstream :: AcquiredUpstream -> [(Text, Text)]
renderAcquiredUpstream acquired =
  [ ("upstream.identity", upstreamName (acquiredIdentity acquired) <> "-" <> upstreamVersion (acquiredIdentity acquired))
  , ("upstream.root", Text.pack (acquiredRoot acquired))
  , ("upstream.tree-sha256", acquiredDigest acquired)
  , ("upstream.files", Text.pack (show (acquiredFiles acquired)))
  ]

-- | Acquire the upstream release beneath the vendor root from the package
-- input with the acquisition's package tool, then refuse a nested checkout or a
-- digest that differs from the identity.
acquireUpstream :: Acquisition -> FilePath -> UpstreamIdentity -> IO (Either ProvenanceRefusal AcquiredUpstream)
acquireUpstream acquisition vendorRoot identity = do
  createDirectoryIfMissing True vendorRoot
  let release = Text.unpack (upstreamName identity <> "-" <> upstreamVersion identity)
      target = vendorRoot </> release
  (child, _, err) <- spawnChild vendorRoot (acquisitionPackageTool acquisition) ["get", release, "-d", vendorRoot, "-v0"]
  present <- doesDirectoryExist target
  if childExit child /= 0 || not present
    then pure (Left (AcquisitionFailed (Text.strip (Text.take 200 (Text.pack err)))))
    else do
      nested <- doesDirectoryExist (target </> ".git")
      if nested
        then pure (Left (NestedCheckout target))
        else do
          (digest, count) <- treeDigest target
          pure $
            if digest /= upstreamTreeDigest identity || count /= upstreamFileCount identity
              then Left (DigestMismatch (upstreamTreeDigest identity) digest)
              else Right AcquiredUpstream {acquiredIdentity = identity, acquiredRoot = target, acquiredDigest = digest, acquiredFiles = count, acquiredChild = child}

-- | Layout refusals over the authored tree: a top-level vendor root, a patch
-- program, or a tracked foreign package description.
refuseLayout :: [FilePath] -> [ProvenanceRefusal]
refuseLayout paths =
  concat
    [ [TopLevelVendor path | "vendor/" `isPrefixOf` path]
        <> [PatchProgram path | any (`isSuffixOf` path) [".patch", ".diff"]]
        <> [TrackedForeignPackage path | ".cabal" `isSuffixOf` path, path `notElem` ["amoebius.cabal", "probe/probe.cabal"]]
    | path <- paths
    ]

-- | Every maintained fork module has its source file beneath @src/vendor/**@.
verifyFork :: FilePath -> IO [ProvenanceRefusal]
verifyFork root =
  concat
    <$> forM
      forkModules
      ( \name -> do
          let path = root </> "src" </> "vendor" </> Text.unpack (Text.replace "." "/" name <> ".hs")
          present <- doesFileExist path
          pure [ForkModuleMissing name | not present]
      )

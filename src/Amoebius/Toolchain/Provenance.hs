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
  , UpstreamAction (..)
  , ProvenanceRefusal (..)
  , Reference (..)
  , VendorSourceFault (..)
  , vendorSourceExamples
  , vendorSourcePaths
  , UpstreamIdentity (..)
  , acquireUpstream
  , acquireUpstreamFromArchive
  , cachedUpstreamArchive
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

import Amoebius.Build.Serial (nativeCabalPath)
import Amoebius.Toolchain.Acquire (Acquisition (..), ChildRecord (..), sha256Bytes, sha256File)
import Amoebius.Toolchain.Resolve (ResolveRefusal (..), admitGeneratedRoot)
import Codec.Archive.Tar qualified as Tar
import Codec.Archive.Tar.Entry qualified as TarEntry
import Codec.Compression.GZip qualified as GZip
import Control.Exception (SomeAsyncException, SomeException, bracketOnError, catch, evaluate, fromException, throwIO)
import Control.Monad (filterM, forM, unless)
import Data.Aeson (eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Types (parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAlphaNum, isControl, isDigit, isHexDigit)
import Data.List (isPrefixOf, isSuffixOf, nub, sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory (createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, makeAbsolute, removePathForcibly)
import System.FilePath (isAbsolute, makeRelative, takeDirectory, takeExtension, (</>))
import System.FilePath.Posix qualified as Posix

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
  | InvalidIdentity Text
  | DeveloperHome FilePath
  | DigestMismatch Text Text
  | NestedCheckout FilePath
  | TopLevelVendor FilePath
  | PatchProgram FilePath
  | TrackedForeignPackage FilePath
  | TrackedVendorProto FilePath
  | ForkModuleMissing Text
  | CachedArchiveMissing FilePath
  | CachedArchiveInvalid Text
  | UpstreamRootOutsideBuild FilePath
  | UpstreamRootNotAbsent FilePath
  | AcquisitionFailed Text
  deriving (Eq, Ord, Show)

renderProvenanceRefusal :: ProvenanceRefusal -> Text
renderProvenanceRefusal refusal = case refusal of
  MutableIdentity reference -> "MutableIdentity: " <> reference
  AbsentIdentity reference -> "AbsentIdentity: " <> reference
  InvalidIdentity reference -> "InvalidIdentity: " <> reference
  DeveloperHome path -> "DeveloperHomePath: " <> Text.pack path
  DigestMismatch expected observed -> "DigestMismatch: expected=" <> expected <> " observed=" <> observed
  NestedCheckout path -> "NestedCheckout: " <> Text.pack path
  TopLevelVendor path -> "TopLevelVendor: " <> Text.pack path
  PatchProgram path -> "PatchProgram: " <> Text.pack path
  TrackedForeignPackage path -> "TrackedForeignPackage: " <> Text.pack path
  TrackedVendorProto path -> "TrackedVendorProto: " <> Text.pack path
  ForkModuleMissing name -> "ForkModuleMissing: " <> name
  CachedArchiveMissing path -> "CachedArchiveMissing: " <> Text.pack path
  CachedArchiveInvalid detail -> "CachedArchiveInvalid: " <> detail
  UpstreamRootOutsideBuild path -> "UpstreamRootOutsideBuild: " <> Text.pack path
  UpstreamRootNotAbsent path -> "UpstreamRootNotAbsent: " <> Text.pack path
  AcquisitionFailed detail -> "UpstreamAcquisitionFailed: " <> detail

-- | How an upstream may be named. Only an immutable form is admitted.
data Reference
  = HackageRelease Text Text
  | GitCommit Text Text
  | GitBranch Text Text
  | LocalPath FilePath
  deriving (Eq, Ord, Show)

data VendorSourceFault = ReintroducedVendorFile FilePath Text | MutableVendorReference Reference
  deriving (Eq, Show)

vendorSourceExamples :: [(Text, Text, VendorSourceFault)]
vendorSourceExamples =
  [("top-level-vendor", "haskell", ReintroducedVendorFile "vendor/supernova/src/Pulsar.hs" "module Pulsar where\n")
  ,("mutable-reference", "branch", MutableVendorReference (GitBranch "https://github.com/cr-org/supernova" "main"))
  ,("mutable-reference", "short-commit", MutableVendorReference (GitCommit "https://github.com/cr-org/supernova" "abcdef0"))
  ,("mutable-reference", "local-path", MutableVendorReference (LocalPath "checkout/supernova"))
  ,("mutable-reference", "empty-name", MutableVendorReference (HackageRelease "" "0.0.3"))
  ,("mutable-reference", "empty-version", MutableVendorReference (HackageRelease "supernova" ""))
  ,("mutable-reference", "empty-commit", MutableVendorReference (GitCommit "https://github.com/cr-org/supernova" ""))
  ,("mutable-reference", "developer-home", MutableVendorReference (LocalPath "/Users/operator/checkout"))
  ,("tracked-vendor-proto", "schema", ReintroducedVendorFile "src/vendor/Probe.proto" "syntax = \"proto3\";\nmessage Probe {}\n")
  ,("tracked-foreign-package", "cabal", ReintroducedVendorFile "dependency/dependency.cabal" "cabal-version: 3.0\nname: dependency\n")
  ,("tracked-foreign-package", "npm", ReintroducedVendorFile "src/vendor/package.json" "{\"scripts\":{\"test\":\"true\"}}\n")
  ,("tracked-foreign-package", "cargo", ReintroducedVendorFile "src/vendor/Cargo.toml" "[package]\nname = \"foreign\"\n")
  ,("tracked-patch-program", "patch", ReintroducedVendorFile "patches/vendor.patch" "--- a/source\n+++ b/source\n@@ -1 +1 @@\n-old\n+new\n")
  ,("tracked-patch-program", "diff", ReintroducedVendorFile "patches/vendor.diff" "--- a/source\n+++ b/source\n@@ -1 +1 @@\n-old\n+new\n")]

vendorSourcePaths :: [FilePath] -> [FilePath]
vendorSourcePaths = filter (\path -> any (`isPrefixOf` path) ["vendor/", "src/vendor/"]
  || any (`isSuffixOf` path) [".patch", ".diff", ".cabal"])

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
    | not (Text.all (\character -> isAlphaNum character || character == '-') name)
        || any (\part -> Text.null part || not (Text.all isDigit part)) (Text.splitOn "." version) -> Left (InvalidIdentity (renderReference reference))
    | otherwise -> Right reference
  GitCommit location commit
    | Text.null location || Text.null commit -> Left (AbsentIdentity (renderReference reference))
    | Text.length commit == 40 && Text.all isHexDigit commit -> Right reference
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
  , acquiredArchive :: FilePath
  , acquiredArchiveDigest :: Text
  , acquiredCacheQuery :: Maybe ChildRecord
  , acquiredActions :: [UpstreamAction]
  }
  deriving (Eq, Show)

-- | Observed local file operations. Extraction never starts a child process;
-- the optional cache query records only the actual read-only Cabal invocation.
data UpstreamAction
  = CachedArchiveRead FilePath Text
  | ArchiveDirectoryCreated FilePath
  | ArchiveFileWritten FilePath Text
  deriving (Eq, Show)

renderAcquiredUpstream :: AcquiredUpstream -> [(Text, Text)]
renderAcquiredUpstream acquired =
  [ ("upstream.identity", upstreamName (acquiredIdentity acquired) <> "-" <> upstreamVersion (acquiredIdentity acquired))
  , ("upstream.root", Text.pack (acquiredRoot acquired))
  , ("upstream.tree-sha256", acquiredDigest acquired)
  , ("upstream.files", Text.pack (show (acquiredFiles acquired)))
  , ("upstream.archive", Text.pack (acquiredArchive acquired))
  , ("upstream.archive-sha256", acquiredArchiveDigest acquired)
  , ("upstream.cache-query", Text.pack (show (acquiredCacheQuery acquired)))
  , ("upstream.actions", Text.pack (show (acquiredActions acquired)))
  ]

-- | Locate the explicitly installed native package cache. This command reads
-- configuration only: it neither resolves nor downloads a package. A cache
-- miss is final; no network-capable acquisition command is a fallback.
cachedUpstreamArchive :: Acquisition -> FilePath -> UpstreamIdentity -> IO (Either ProvenanceRefusal (FilePath, ChildRecord))
cachedUpstreamArchive acquisition observations identity = case admitReference reference of
  Left problem -> pure (Left problem)
  Right _ -> do
    queried <- nativeCabalPath (acquisitionRoot acquisition) (acquisitionPackageTool acquisition) observations ["--remote-repo-cache"]
    case queried of
      Left problem -> pure (Left (AcquisitionFailed problem))
      Right (child, output, _) -> do
        let cache = eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.pack output))
              >>= parseEither (withObject "native package cache" (.: "remote-repo-cache"))
        case cache of
          Right directory | childExit child == 0 && isAbsolute directory -> do
            let archive = directory </> "hackage.haskell.org" </> Text.unpack (upstreamName identity)
                  </> Text.unpack (upstreamVersion identity) </> releaseName identity <> ".tar.gz"
            present <- doesFileExist archive
            pure (if present then Right (archive, child) else Left (CachedArchiveMissing archive))
          _ -> pure (Left (AcquisitionFailed "native package cache location unavailable"))
 where reference = HackageRelease (upstreamName identity) (upstreamVersion identity)

-- | Read an already cached source archive and extract it in Haskell. The
-- archive's digest is an observation, not a toolchain admission pin.
acquireUpstream :: Acquisition -> FilePath -> UpstreamIdentity -> IO (Either ProvenanceRefusal AcquiredUpstream)
acquireUpstream acquisition vendorRoot identity = case admitReference reference of
  Left problem -> pure (Left problem)
  Right _ -> synchronous $ do
    admitted <- admitUpstreamRoot vendorRoot
    case admitted of
      Left problem -> pure (Left problem)
      Right owned -> do
        createDirectoryIfMissing True (takeDirectory owned)
        cached <- cachedUpstreamArchive acquisition (takeDirectory owned) identity
        case cached of
          Left problem -> pure (Left problem)
          Right (archive, query) -> fmap (fmap (\acquired -> acquired {acquiredCacheQuery = Just query}))
            (acquireUpstreamFromArchive archive owned identity)
 where reference = HackageRelease (upstreamName identity) (upstreamVersion identity)

releaseName :: UpstreamIdentity -> FilePath
releaseName identity = Text.unpack (upstreamName identity <> "-" <> upstreamVersion identity)

-- | No subprocess or network operation exists on this path. Identity, cached
-- bytes, every archive entry, and the expected source tree are checked before
-- creating the fresh destination. On extraction failure its owned root is removed.
acquireUpstreamFromArchive :: FilePath -> FilePath -> UpstreamIdentity -> IO (Either ProvenanceRefusal AcquiredUpstream)
acquireUpstreamFromArchive supplied requested identity = case admitReference reference of
  Left problem -> pure (Left problem)
  Right _ -> synchronous $ do
    admitted <- admitUpstreamRoot requested
    case admitted of
      Left problem -> pure (Left problem)
      Right vendorRoot -> extractAt vendorRoot
 where
  reference = HackageRelease (upstreamName identity) (upstreamVersion identity)
  extractAt vendorRoot = do
    archive <- makeAbsolute supplied
    present <- doesFileExist archive
    if not present then pure (Left (CachedArchiveMissing archive))
    else do
      bytes <- ByteString.readFile archive
      case archiveEntries vendorRoot identity bytes of
        Left problem -> pure (Left problem)
        Right entries -> do
          -- Force decompression and all file payloads before any output effect.
          mapM_ (evaluate . ByteString.length . snd) [(path, body) | (path, Just body) <- entries]
          let files = sortOn fst [(path, body) | (path, Just body) <- entries]
              sourceRows = [Text.pack (Posix.makeRelative (releaseName identity) path) <> " " <> sha256Bytes body | (path, body) <- files]
              expectedDigest = sha256Bytes (TextEncoding.encodeUtf8 (Text.unlines sourceRows))
          if expectedDigest /= upstreamTreeDigest identity || length files /= upstreamFileCount identity
            then pure (Left (DigestMismatch (upstreamTreeDigest identity) expectedDigest))
            else do
              createDirectoryIfMissing True (takeDirectory vendorRoot)
              bracketOnError (createDirectory vendorRoot) (const (removePathForcibly vendorRoot)) $ \() -> do
                let directories = sortOn (\path -> (length (Posix.splitDirectories path), path))
                      (nub ([path | (path, Nothing) <- entries] <> concatMap (parents . fst) entries))
                directoryActions <- forM directories $ \path -> do
                  createDirectory (vendorRoot </> path)
                  pure (ArchiveDirectoryCreated (vendorRoot </> path))
                fileActions <- forM files $ \(path, body) -> do
                  ByteString.writeFile (vendorRoot </> path) body
                  pure (ArchiveFileWritten (vendorRoot </> path) (sha256Bytes body))
                let target = vendorRoot </> releaseName identity
                (digest, count) <- treeDigest target
                if digest /= expectedDigest || count /= length files
                  then removePathForcibly vendorRoot >> pure (Left (DigestMismatch expectedDigest digest))
                  else pure (Right AcquiredUpstream
                    { acquiredIdentity = identity, acquiredRoot = target, acquiredDigest = digest, acquiredFiles = count
                    , acquiredArchive = archive, acquiredArchiveDigest = sha256Bytes bytes, acquiredCacheQuery = Nothing
                    , acquiredActions = CachedArchiveRead archive (sha256Bytes bytes) : ArchiveDirectoryCreated vendorRoot : directoryActions <> fileActions
                    })
  parents path = let parent = Posix.takeDirectory path in if parent == "." then [] else parent : parents parent

admitUpstreamRoot :: FilePath -> IO (Either ProvenanceRefusal FilePath)
admitUpstreamRoot requested = fmap (either refuse Right) (admitGeneratedRoot requested)
 where
  refuse (ResolutionRootNotAbsent _) = Left (UpstreamRootNotAbsent requested)
  refuse _ = Left (UpstreamRootOutsideBuild requested)

archiveEntries :: FilePath -> UpstreamIdentity -> ByteString -> Either ProvenanceRefusal [(FilePath, Maybe ByteString)]
archiveEntries vendorRoot identity bytes = do
  entries <- collect (Tar.read (GZip.decompress (LazyByteString.fromStrict bytes)))
  let paths = map fst entries
  unless (not (null entries) && length paths == length (nub paths)) (Left (CachedArchiveInvalid "empty or duplicate entry inventory"))
  pure entries
 where
  collect Tar.Done = Right []
  collect (Tar.Fail problem) = Left (CachedArchiveInvalid (Text.pack (show problem)))
  collect (Tar.Next entry rest) = do
    let path = reverse (dropWhile (== '/') (reverse (TarEntry.fromTarPathToPosixPath (TarEntry.entryTarPath entry))))
        pieces = Text.splitOn "/" (Text.pack path)
        invalid = null path || Posix.isAbsolute path || any (`elem` path) ['\\', ':']
          || any isControl path || any (`elem` ["", ".", ".."]) pieces
          || take 1 pieces /= [Text.pack (releaseName identity)]
    unless (not invalid) (Left (CachedArchiveInvalid ("unsafe archive path " <> Text.pack path)))
    unless (".git" `notElem` pieces) (Left (NestedCheckout (vendorRoot </> path)))
    body <- case TarEntry.entryContent entry of
      TarEntry.NormalFile content _ | length pieces > 1 -> Right (Just (LazyByteString.toStrict content))
      TarEntry.Directory -> Right Nothing
      _ -> Left (CachedArchiveInvalid ("unsupported archive entry " <> Text.pack path))
    remaining <- collect rest
    pure ((path, body) : remaining)

synchronous :: IO (Either ProvenanceRefusal a) -> IO (Either ProvenanceRefusal a)
synchronous action = action `catch` handle
 where
  handle problem = case fromException problem :: Maybe SomeAsyncException of
    Just asynchronous -> throwIO asynchronous
    Nothing -> pure (Left (CachedArchiveInvalid (Text.pack (show (problem :: SomeException)))))

-- | Layout refusals over the authored tree: a top-level vendor root, a patch
-- program, or a tracked foreign package description.
refuseLayout :: [FilePath] -> [ProvenanceRefusal]
refuseLayout paths =
  concat
    [ [TopLevelVendor path | "vendor/" `isPrefixOf` path]
        <> [PatchProgram path | any (`isSuffixOf` path) [".patch", ".diff"]]
        <> [TrackedForeignPackage path | (".cabal" `isSuffixOf` path && path `notElem` ["amoebius.cabal", "probe/probe.cabal"])
          || ("src/vendor/" `isPrefixOf` path && takeExtension path `notElem` [".hs", ".proto", ".patch", ".diff"])]
        <> [TrackedVendorProto path | "src/vendor/" `isPrefixOf` path && takeExtension path == ".proto"]
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

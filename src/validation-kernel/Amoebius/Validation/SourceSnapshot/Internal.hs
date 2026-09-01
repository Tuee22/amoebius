-- | Package-hidden source snapshot representation.
--
-- The public and exposed validation modules re-export only the diagnostic
-- snapshot shapes they need. The acquired wrapper itself lives in the
-- acquisition-owning SourceClosure module so this representation module
-- cannot provide a package-internal forging route.
module Amoebius.Validation.SourceSnapshot.Internal
  ( GitObjectFormat (..)
  , IndexEntry (..)
  , IndexMode (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)

data IndexMode
  = RegularFile
  | ExecutableFile
  | SymbolicLink
  deriving (Eq, Ord, Show)

data GitObjectFormat
  = GitObjectSha1
  | GitObjectSha256
  deriving (Eq, Ord, Show)

data IndexEntry = IndexEntry
  { indexPath :: FilePath
  , indexMode :: IndexMode
  , indexObjectId :: Text
  }
  deriving (Eq, Ord, Show)

data TrackedEntry = TrackedEntry
  { trackedIndex :: IndexEntry
  , trackedBytes :: ByteString
  }
  deriving (Eq, Ord, Show)

-- | The identity is a domain-separated SHA-256 digest of a canonical manifest
-- containing each locally captured path, mode, Git-style object id, and exact
-- byte commitment. A second capture must match before a gate result is kept.
data SourceSnapshot = SourceSnapshot
  { snapshotRoot :: FilePath
  , snapshotIdentity :: Text
  , snapshotEntries :: [TrackedEntry]
  }
  deriving (Eq, Show)

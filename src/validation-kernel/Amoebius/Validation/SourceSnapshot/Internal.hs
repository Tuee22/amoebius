-- | Package-hidden source snapshot representation.
--
-- The public and exposed validation modules re-export only the diagnostic
-- snapshot shapes they need. The acquired wrapper constructor is available
-- solely inside this package so the local snapshot loader can mint it after
-- capturing the exact candidate bytes. Production use of the constructor is
-- kept to that loader and audited as a closed call graph.
module Amoebius.Validation.SourceSnapshot.Internal
  ( AcquiredSourceSnapshot (..)
  , GitObjectFormat (..)
  , IndexEntry (..)
  , IndexMode (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
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

-- | Package-hidden marker for a locally captured candidate snapshot.
newtype AcquiredSourceSnapshot = AcquiredSourceSnapshot SourceSnapshot
  deriving (Eq, Show)

acquiredSourceSnapshot :: AcquiredSourceSnapshot -> SourceSnapshot
acquiredSourceSnapshot (AcquiredSourceSnapshot snapshot) = snapshot

-- | Package-hidden source snapshot representation.
--
-- The public and exposed validation modules re-export only the diagnostic
-- snapshot shapes they need.  The acquired wrapper constructor is available
-- solely inside this package so the signed acquisition verifier can mint it
-- after independently checking the immutable bundle.  Production use of the
-- constructor is kept to that verifier and audited as a closed call graph.
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

-- | The identity is a domain-separated SHA-256 digest of the independently
-- observed Git storage format and a canonical manifest containing mode, Git
-- object id, an independent SHA-256 commitment to the exact blob bytes, and
-- path for every stage-zero entry. Classification never consults mutable
-- worktree bytes.
data SourceSnapshot = SourceSnapshot
  { snapshotRoot :: FilePath
  , snapshotIdentity :: Text
  , snapshotEntries :: [TrackedEntry]
  }
  deriving (Eq, Show)

-- | Reserved candidate authority. The constructor is package-hidden and has
-- one ordinary production caller: the signed immutable-bundle verifier.
newtype AcquiredSourceSnapshot = AcquiredSourceSnapshot SourceSnapshot
  deriving (Eq, Show)

acquiredSourceSnapshot :: AcquiredSourceSnapshot -> SourceSnapshot
acquiredSourceSnapshot (AcquiredSourceSnapshot snapshot) = snapshot

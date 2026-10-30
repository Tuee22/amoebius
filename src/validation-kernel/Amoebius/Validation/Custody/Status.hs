-- | Status acquisition and one-frontier projection (DL-0009).
module Amoebius.Validation.Custody.Status
  ( StatusSurface (..), patchToFrontier, recordedFrontier, statusSurface, statusPrefixDigest, surfaceConsistent, surfaceDigest ) where
import Amoebius.Validation.Authority.Core

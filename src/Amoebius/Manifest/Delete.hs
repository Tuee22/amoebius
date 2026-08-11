{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Manifest.Delete
  ( DeleteCandidate (..)
  , DeleteAuthority (..)
  , DeleteError (..)
  , authorizeDelete
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data DeleteCandidate = DeleteCandidate
  { deleteCandidateIdentity :: Text
  , deleteCandidateOwner :: Text
  , deleteCandidateGeneration :: Text
  , deleteCandidateResourceVersion :: Text
  , deleteCandidateRetained :: Bool
  , deleteCandidateDependenciesReleased :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DeleteAuthority = DeleteAuthority
  { deleteAuthorityIdentity :: Text
  , deleteAuthorityOwner :: Text
  , deleteAuthorityGeneration :: Text
  , deleteAuthorityResourceVersion :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DeleteError = DeleteAuthorityMismatch | DeleteRetainedObject | DeleteDependencyActive
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

authorizeDelete :: DeleteAuthority -> DeleteCandidate -> Either DeleteError DeleteCandidate
#ifdef PHASE26_LABEL_ONLY_DELETE_MUTANT
authorizeDelete authority candidate
  | deleteAuthorityOwner authority == deleteCandidateOwner candidate = Right candidate
  | otherwise = Left DeleteAuthorityMismatch
#else
authorizeDelete authority candidate
  | deleteAuthorityIdentity authority /= deleteCandidateIdentity candidate = Left DeleteAuthorityMismatch
  | deleteAuthorityOwner authority /= deleteCandidateOwner candidate = Left DeleteAuthorityMismatch
  | deleteAuthorityGeneration authority /= deleteCandidateGeneration candidate = Left DeleteAuthorityMismatch
  | deleteAuthorityResourceVersion authority /= deleteCandidateResourceVersion candidate = Left DeleteAuthorityMismatch
  | deleteCandidateRetained candidate = Left DeleteRetainedObject
  | not (deleteCandidateDependenciesReleased candidate) = Left DeleteDependencyActive
  | otherwise = Right candidate
#endif

-- | Read-only prerequisites for the initial protected seed layout.
-- Every result remains explicitly unqualified; this API has no gate authority.
module Amoebius.Validation.SeedCustodyPrerequisites
  ( SeedCustodyRequest (..)
  , seedCustodyPrerequisitesDiagnostic
  ) where

import Amoebius.Validation.SeedCustodyPrerequisites.Internal
  ( SeedCustodyRequest (..)
  , seedCustodyPrerequisitesDiagnostic
  )

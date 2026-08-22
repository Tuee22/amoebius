{-# LANGUAGE OverloadedStrings #-}

module SecurityLawMutants
  ( acceptTamperedIdentity
  , trustCallerScope
  , exportUnscopedArm
  , distinguishRefusal
  , collapseNamespace
  , omitRevocationPolicy
  ) where

import Amoebius.Extension.Laws.Security
  ( NamespaceProbe (..)
  , RefusalProbe (..)
  , RevocationProbe (..)
  , SecurityObservations (..)
  )

acceptTamperedIdentity :: SecurityObservations -> SecurityObservations
acceptTamperedIdentity observations = observations {tamperedIdentityRefused = False}

trustCallerScope :: SecurityObservations -> SecurityObservations
trustCallerScope observations = observations {skolemCompilerBarriersPassed = False}

exportUnscopedArm :: SecurityObservations -> SecurityObservations
exportUnscopedArm observations = observations {exportedUnscopedOperationArms = 1}

distinguishRefusal :: SecurityObservations -> SecurityObservations
distinguishRefusal observations = observations
  { refusalProbes = case refusalProbes observations of
      [] -> []
      first : rest -> first {foreignRefusalBytes = "foreign-resource"} : rest
  }

collapseNamespace :: SecurityObservations -> SecurityObservations
collapseNamespace observations = observations
  { namespaceProbes = case namespaceProbes observations of
      [] -> []
      first : rest -> first {namespaceRight = namespaceLeft first} : rest
  }

omitRevocationPolicy :: SecurityObservations -> SecurityObservations
omitRevocationPolicy observations = observations
  { revocationProbes = case revocationProbes observations of
      [] -> []
      first : rest -> first {revocationPolicy = Nothing} : rest
  }

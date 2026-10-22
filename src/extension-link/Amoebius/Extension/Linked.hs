{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fforce-recomp #-}

-- | The actual static catalog used by the shipped executable. There is no
-- runtime provider toggle. Removing a member changes this Haskell source.
-- Re-evaluate admission when GHC visits this module: new source files are not
-- present in an older interface's addDependentFile list.
module Amoebius.Extension.Linked
  ( module Graph, ConcreteSpec, ConcreteLinkSet
  , linkedExtensions, linkedExtensionSet, proveLinkedBinding
  ) where

import Amoebius.Extension.AstCheck (CheckedExtensionSource)
import Amoebius.Extension.Calculi (mergeExtensions)
import Amoebius.Extension.Contributed.Coordination qualified as Coordination
import Amoebius.Extension.Contributed.Infernix qualified as Infernix
import Amoebius.Extension.Contributed.JitBuild qualified as JitBuild
import Amoebius.Extension.Contributed.JitML qualified as JitML
import Amoebius.Extension.Graph as Graph hiding (mergeExtensions)
import Amoebius.Extension.LinkSeal (admitContribution)
import Amoebius.Extension.Surface (ProductSpec, ProductLinkSet, SurfaceRefusal, surfaceRefusalTag)

-- Source seals are issued for the complete actual contributed closure. Each
-- expression names and applies its reified admitted factory, never a stub.
jitBuild, coordination, infernix, jitml :: Either SurfaceRefusal ConcreteSpec
jitBuild = $(admitContribution 'JitBuild.contribution)
coordination = $(admitContribution 'Coordination.contribution)
infernix = $(admitContribution 'Infernix.contribution)
jitml = $(admitContribution 'JitML.contribution)

type ConcreteSpec = ProductSpec CheckedExtensionSource
type ConcreteLinkSet = ProductLinkSet CheckedExtensionSource

-- The one catalog binding is also the runner's source-sibling locus.
linkedExtensions :: [Either SurfaceRefusal ConcreteSpec]
linkedExtensions = [jitBuild, coordination, infernix, jitml]

linkedExtensionSet :: Either LinkRefusal ConcreteLinkSet
linkedExtensionSet = do
  values <- traverse (either (Left . InvalidContributedSpec . surfaceRefusalTag) Right) linkedExtensions
  mergeExtensions values

proveLinkedBinding :: BindingSubject -> Either LinkRefusal (BindingProof CheckedExtensionSource)
proveLinkedBinding subject = do
  links <- linkedExtensionSet
  proveBinding subject links

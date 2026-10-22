{-# LANGUAGE RoleAnnotations #-}

-- | The single extension registration record. The foundation depends only on
-- base; the linked product fixes its parameters to the sanctioned product
-- vocabulary and to the checker's opaque source seal. An arbitrary seal type
-- therefore cannot stand in for a linked product extension.
module Amoebius.Extension.Spec
  ( ExtensionSpec, ExtensionSpecRefusal (..), mkExtensionSpec
  , extensionSpecRefusalName
  , extId, extConfig, extProvides, extRequires, extRequiresLane
  , extChain, extUiHandlers, extMonitoring, extDeclaration, extSourceSeal
  ) where

import Data.List (nub)
import Data.List.NonEmpty (NonEmpty)

-- Function projections, rather than exported record selectors, preserve the
-- construction boundary under record update. No Generic/Read/JSON instance
-- supplies another representation or constructor.
type role ExtensionSpec nominal nominal nominal nominal nominal nominal nominal nominal nominal nominal
data ExtensionSpec identifier config capability lane input step handler monitoring declaration seal
  = ExtensionSpec
      !identifier
      !config
      ![capability]
      ![capability]
      !lane
      (input -> [step])
      ![handler]
      !(NonEmpty monitoring)
      !declaration
      !seal

data ExtensionSpecRefusal
  = DuplicateProvidedCapability
  | DuplicateRequiredCapability
  deriving (Bounded, Enum, Eq, Ord, Show)

extensionSpecRefusalName :: ExtensionSpecRefusal -> String
extensionSpecRefusalName = show

mkExtensionSpec
  :: Eq capability
  => identifier
  -> config
  -> [capability]
  -> [capability]
  -> lane
  -> (input -> [step])
  -> [handler]
  -> NonEmpty monitoring
  -> declaration
  -> seal
  -> Either ExtensionSpecRefusal
       (ExtensionSpec identifier config capability lane input step handler monitoring declaration seal)
mkExtensionSpec identifier config provides requires lane chain handlers monitoring declaration seal
  | length provides /= length (nub provides) = Left DuplicateProvidedCapability
  | length requires /= length (nub requires) = Left DuplicateRequiredCapability
  | otherwise = Right (ExtensionSpec identifier config provides requires lane chain handlers monitoring declaration seal)

extId :: ExtensionSpec i c a l x s h m d p -> i
extId (ExtensionSpec value _ _ _ _ _ _ _ _ _) = value

extConfig :: ExtensionSpec i c a l x s h m d p -> c
extConfig (ExtensionSpec _ value _ _ _ _ _ _ _ _) = value

extProvides :: ExtensionSpec i c a l x s h m d p -> [a]
extProvides (ExtensionSpec _ _ value _ _ _ _ _ _ _) = value

extRequires :: ExtensionSpec i c a l x s h m d p -> [a]
extRequires (ExtensionSpec _ _ _ value _ _ _ _ _ _) = value

extRequiresLane :: ExtensionSpec i c a l x s h m d p -> l
extRequiresLane (ExtensionSpec _ _ _ _ value _ _ _ _ _) = value

extChain :: ExtensionSpec i c a l x s h m d p -> x -> [s]
extChain (ExtensionSpec _ _ _ _ _ value _ _ _ _) = value

extUiHandlers :: ExtensionSpec i c a l x s h m d p -> [h]
extUiHandlers (ExtensionSpec _ _ _ _ _ _ value _ _ _) = value

extMonitoring :: ExtensionSpec i c a l x s h m d p -> NonEmpty m
extMonitoring (ExtensionSpec _ _ _ _ _ _ _ value _ _) = value

extDeclaration :: ExtensionSpec i c a l x s h m d p -> d
extDeclaration (ExtensionSpec _ _ _ _ _ _ _ _ value _) = value

extSourceSeal :: ExtensionSpec i c a l x s h m d p -> p
extSourceSeal (ExtensionSpec _ _ _ _ _ _ _ _ _ value) = value

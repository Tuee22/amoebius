{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostWorker.MetalBridge
  ( MetalAvailability (..)
  , MetalDispatch
  , MetalBridgeError (..)
  , dispatchMetal
  , dispatchBytes
  , dispatchLibraryHandle
  , dispatchFastMath
  ) where

import Amoebius.HostWorker.ReferenceKernel (referenceKernel, renderFixedMsl)
import Data.ByteString (ByteString)
import Data.Text (Text)

data MetalAvailability
  = AppleMetalDevice Text
  | UnsupportedAppleMetalOnHost
  deriving stock (Eq, Show)

data MetalDispatch = MetalDispatch ByteString Text Bool ByteString
  deriving stock (Eq, Show)

data MetalBridgeError
  = MetalUnavailable
  | EmptyMetalLibraryHandle
  | FastMathMustBeDisabled
  deriving stock (Eq, Show)

-- | Models the fixed bridge boundary. The availability witness must come from
-- the host probe; Linux tests can validate the contract without claiming Metal.
dispatchMetal :: MetalAvailability -> [Float] -> Either MetalBridgeError MetalDispatch
dispatchMetal availability input = case availability of
  UnsupportedAppleMetalOnHost -> Left MetalUnavailable
  AppleMetalDevice handle
    | handle == "" -> Left EmptyMetalLibraryHandle
    | otherwise -> Right (MetalDispatch (referenceKernel input) handle False renderFixedMsl)

dispatchBytes :: MetalDispatch -> ByteString
dispatchBytes (MetalDispatch bytes _ _ _) = bytes

dispatchLibraryHandle :: MetalDispatch -> Text
dispatchLibraryHandle (MetalDispatch _ handle _ _) = handle

dispatchFastMath :: MetalDispatch -> Bool
dispatchFastMath (MetalDispatch _ _ fastMath _) = fastMath

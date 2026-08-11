{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Substrate.Lima
  ( FilesystemPresentation (..)
  , BackingAllocationPolicy (..)
  , VmDiskCarve (..)
  , ProvisionedVmDiskCarve
  , provisionVmDisk
  , provisionedVmDiskId
  , requiredUsableBytes
  , provisionedBytes
  , renderLimaCreateArgv
  , VmDiskError (..)
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word64)

data FilesystemPresentation = Filesystem Text
  deriving stock (Eq, Show)

data BackingAllocationPolicy = BackingAllocationPolicy
  { minimumBytes :: Word64
  , quantumBytes :: Word64
  , filesystemOverheadBasisPoints :: Word64
  , sparseImageOverheadBytes :: Word64
  }
  deriving stock (Eq, Show)

data VmDiskCarve = VmDiskCarve
  { vmDiskId :: Text
  , vmDiskPresentation :: FilesystemPresentation
  , vmDiskAllocation :: BackingAllocationPolicy
  , vmGuestSystemUsableBytes :: Word64
  , vmKubeletUniqueCarves :: Map Text Word64
  }
  deriving stock (Eq, Show)

data ProvisionedVmDiskCarve = ProvisionedVmDiskCarve
  { internalVmDiskId :: Text
  , internalRequiredUsableBytes :: Word64
  , internalProvisionedBytes :: Word64
  , internalPresentation :: FilesystemPresentation
  , internalAllocation :: BackingAllocationPolicy
  }
  deriving stock (Eq, Show)

data VmDiskError
  = EmptyVmDiskId
  | BlockGuestRootForbidden
  | EmptyKubeletLayout
  | InvalidAllocationQuantum
  | VmDiskArithmeticOverflow
  deriving stock (Eq, Show)

provisionVmDisk :: VmDiskCarve -> Either VmDiskError ProvisionedVmDiskCarve
provisionVmDisk raw = do
  if vmDiskId raw == "" then Left EmptyVmDiskId else Right ()
  case vmDiskPresentation raw of
    Filesystem fsType | fsType /= "" -> Right ()
    Filesystem _ -> Left BlockGuestRootForbidden
  if Map.null (vmKubeletUniqueCarves raw) then Left EmptyKubeletLayout else Right ()
  let allocation = vmDiskAllocation raw
  if quantumBytes allocation == 0 then Left InvalidAllocationQuantum else Right ()
  required <- checkedSum (vmGuestSystemUsableBytes raw : Map.elems (vmKubeletUniqueCarves raw))
  productValue <- checkedMultiply required (filesystemOverheadBasisPoints allocation)
  overhead <- checkedCeilingDivide productValue 10000
  withFilesystem <- checkedAdd required overhead
  withSparse <- checkedAdd withFilesystem (sparseImageOverheadBytes allocation)
  rounded <- roundUp withSparse (quantumBytes allocation)
  let supplied = max (minimumBytes allocation) rounded
  Right ProvisionedVmDiskCarve
    { internalVmDiskId = vmDiskId raw
    , internalRequiredUsableBytes = required
    , internalProvisionedBytes = supplied
    , internalPresentation = vmDiskPresentation raw
    , internalAllocation = allocation
    }

provisionedVmDiskId :: ProvisionedVmDiskCarve -> Text
provisionedVmDiskId = internalVmDiskId

requiredUsableBytes :: ProvisionedVmDiskCarve -> Word64
requiredUsableBytes = internalRequiredUsableBytes

provisionedBytes :: ProvisionedVmDiskCarve -> Word64
provisionedBytes = internalProvisionedBytes

renderLimaCreateArgv :: FilePath -> Text -> Word64 -> Word64 -> ProvisionedVmDiskCarve -> [String]
renderLimaCreateArgv limactl vmName cpu memory disk =
  [ limactl, "create", "--name=" <> showText vmName, "--cpus=" <> show cpu
  , "--memory=" <> show memory, "--disk=" <> show (provisionedBytes disk)
  ]

showText :: Text -> String
showText = Text.unpack

checkedSum :: [Word64] -> Either VmDiskError Word64
checkedSum = foldl step (Right 0)
 where
  step current next = current >>= (`checkedAdd` next)

checkedAdd :: Word64 -> Word64 -> Either VmDiskError Word64
checkedAdd left right
  | maxBound - left < right = Left VmDiskArithmeticOverflow
  | otherwise = Right (left + right)

checkedMultiply :: Word64 -> Word64 -> Either VmDiskError Word64
checkedMultiply left right
  | left /= 0 && maxBound `div` left < right = Left VmDiskArithmeticOverflow
  | otherwise = Right (left * right)

checkedCeilingDivide :: Word64 -> Word64 -> Either VmDiskError Word64
checkedCeilingDivide value divisor = do
  adjusted <- checkedAdd value (divisor - 1)
  Right (adjusted `div` divisor)

roundUp :: Word64 -> Word64 -> Either VmDiskError Word64
roundUp value quantum = do
  adjusted <- checkedAdd value (quantum - 1)
  checkedMultiply (adjusted `div` quantum) quantum

-- | Attribute discovered Proto sources to the existing migration boundaries.
module Amoebius.Toolchain.SourceOwnership
  ( ProtoSourceOwner (..)
  , protoSourceExamples
  , protoSourceAttribution
  ) where

import Amoebius.Toolchain.Provenance (ProvenanceRefusal (..), refuseLayout)
import System.FilePath (isPathSeparator, takeExtension)

data ProtoSourceOwner = WireSchemaSource | VendorSchemaSource deriving (Eq, Ord, Show)

-- | The product-owned corpus spans ordinary, maintained-vendor, and former
-- top-level-vendor paths. Independent expectations live in the oracle.
protoSourceExamples :: [FilePath]
protoSourceExamples = ["proto/PulsarApi.proto", "vendor/supernova/PulsarApi.proto", "src/vendor/PulsarApi.proto"]

protoSourceAttribution :: [FilePath] -> [(FilePath, ProtoSourceOwner)]
protoSourceAttribution paths =
  [ (path, if any vendorFinding (refuseLayout [portable path]) then VendorSchemaSource else WireSchemaSource)
  | path <- paths, takeExtension path == ".proto"
  ]
 where
  portable = map (\character -> if isPathSeparator character then '/' else character)
  vendorFinding finding = case finding of
    TopLevelVendor _ -> True
    TrackedVendorProto _ -> True
    _ -> False

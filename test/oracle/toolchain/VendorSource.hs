{-# LANGUAGE OverloadedStrings #-}
module VendorSource (vendorSourceChecks) where

import Control.Exception (IOException, try)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesPathExist)
import Text.Read (readMaybe)

type Observation = (Text, Text, Text, [FilePath], [Text], Text, Text)

vendorSourceChecks :: FilePath -> IO [(Text, Bool, Text)]
vendorSourceChecks directory = do
  observed <- readValue (directory <> "/vendor-source.data") :: IO (Maybe [Observation])
  fork <- readValue (directory <> "/vendor-fork.data") :: IO (Maybe ([Text], [(Text, [Text])]))
  cleanup <- readValue (directory <> "/vendor-source-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory <> "/vendor-source-tree")
  let rows = maybe [] id observed
      keys = [(name, variant, role) | (name, variant, _, _, _, _) <- examples, role <- ["positive", "negative"]]
      paths = sort (["amoebius.cabal", "probe/probe.cabal"] <> map modulePath modules)
      selected name role = [(variant, files, findings, reference, bytes) | (key, variant, control, files, findings, reference, bytes) <- rows, key == name, control == role]
      expected name role = [(variant, sort (paths <> [path | role == "negative", not (null path)]),
        [refusal | role == "negative"], if role == "negative" && null path then reference else "hackage:supernova-0.0.3",
        if role == "negative" then bytes else "") | (key, variant, path, bytes, reference, refusal) <- examples, key == name]
      check name green detail = ("vendor-source." <> name, green, detail)
      forkExpected = (modules, ("clean", []) : [(name, ["ForkModuleMissing: " <> name]) | name <- modules])
  pure (check "discovery" (sort [(name, variant, role) | (name, variant, role, _, _, _, _) <- rows] == sort keys) (Text.pack (show (length rows)))
    : [check (name <> "." <> role) (sort (selected name role) == sort (expected name role)) (Text.pack (show (selected name role)))
       | name <- ["top-level-vendor", "mutable-reference", "tracked-vendor-proto", "tracked-foreign-package", "tracked-patch-program"], role <- ["positive", "negative"]]
    <> [check "control.fork" (fork == Just forkExpected) (Text.pack (show fork))
       ,check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup, present)))])

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  bytes <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) bytes)

modulePath :: Text -> FilePath
modulePath name = "src/vendor/" <> Text.unpack (Text.replace "." "/" name) <> ".hs"

modules :: [Text]
modules = ["Pulsar", "Pulsar.AppState", "Pulsar.Connection", "Pulsar.Consumer", "Pulsar.Core",
  "Pulsar.Internal.Core", "Pulsar.Internal.Logger", "Pulsar.Internal.TCPClient", "Pulsar.Producer",
  "Pulsar.Protocol.CheckSum", "Pulsar.Protocol.Commands", "Pulsar.Protocol.Decoder",
  "Pulsar.Protocol.Encoder", "Pulsar.Protocol.Frame", "Pulsar.Types", "Data.Bifunctor.Flip", "Control.Category.Dual"]

examples :: [(Text, Text, FilePath, Text, Text, Text)]
examples = [("top-level-vendor", "haskell", "vendor/supernova/src/Pulsar.hs", "module Pulsar where\n", "", "TopLevelVendor: vendor/supernova/src/Pulsar.hs")
  ,("mutable-reference", "branch", "", "", "git:https://github.com/cr-org/supernova#main", "MutableIdentity: git:https://github.com/cr-org/supernova#main")
  ,("mutable-reference", "short-commit", "", "", "git:https://github.com/cr-org/supernova@abcdef0", "MutableIdentity: git:https://github.com/cr-org/supernova@abcdef0")
  ,("mutable-reference", "local-path", "", "", "path:checkout/supernova", "MutableIdentity: path:checkout/supernova")
  ,("tracked-vendor-proto", "schema", "src/vendor/Probe.proto", "syntax = \"proto3\";\nmessage Probe {}\n", "", "TrackedVendorProto: src/vendor/Probe.proto")
  ,("tracked-foreign-package", "cabal", "dependency/dependency.cabal", "cabal-version: 3.0\nname: dependency\n", "", "TrackedForeignPackage: dependency/dependency.cabal")
  ,("tracked-foreign-package", "npm", "src/vendor/package.json", "{\"scripts\":{\"test\":\"true\"}}\n", "", "TrackedForeignPackage: src/vendor/package.json")
  ,("tracked-foreign-package", "cargo", "src/vendor/Cargo.toml", "[package]\nname = \"foreign\"\n", "", "TrackedForeignPackage: src/vendor/Cargo.toml")
  ,("tracked-patch-program", "patch", "patches/vendor.patch", patchBytes, "", "PatchProgram: patches/vendor.patch")
  ,("tracked-patch-program", "diff", "patches/vendor.diff", patchBytes, "", "PatchProgram: patches/vendor.diff")]
 where patchBytes = "--- a/source\n+++ b/source\n@@ -1 +1 @@\n-old\n+new\n"

{-# LANGUAGE OverloadedStrings #-}

-- | Independent plan controls for the source-bound wire preparation image.
module Main (main) where

import Control.Exception (IOException, bracket, try)
import Control.Monad (forM_, unless)
import Amoebius.Validation.Runner (nativePlanWireTool)
import Data.Aeson (Value, encode, object, (.=))
import Data.Aeson.Types (parseEither)
import Data.ByteString.Char8 qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Owner (preparationOwner)
import Plan (parsePlan, selectPlan)
import System.Directory (canonicalizePath, createDirectory, createDirectoryLink, getTemporaryDirectory, listDirectory, removeFile, removePathForcibly)
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)

main :: IO ()
main = do
  nativeRoot <- canonicalizePath "."
  let good = [helper ["plugin-unit"] "local", plugin "plugin-unit" "0.9.1"]
      check condition label = unless condition (fail label)
      parse = parseEither selectPlan . plan
      native = nativePlanWireTool nativeRoot . LazyByteString.toStrict . encode . plan
      helperImage = nativeRoot </> ".build" </> "dist-native" </> "helper"
      pluginImage = nativeRoot </> "external-plugin"
      nativeHelper deps kind = helperAtRoot deps kind nativeRoot helperImage
      nativePlugin identity version = pluginAt identity version pluginImage
      nativeGood = [nativeHelper ["plugin-unit"] "local", nativePlugin "plugin-unit" "0.9.1"]
  check (parse good == Right ("/source", "/source/.build/dist-native/helper", "/store/plugin")) "planned plugin selection"
  check (parse [helper ["plugin-unit"] "local", plugin "plugin-unit" "0.9"] == Right ("/source", "/source/.build/dist-native/helper", "/store/plugin")) "minimum compatible plugin"
  check (parse [helper ["plugin-unit"] "local", plugin "plugin-unit" "0.9.99"] == Right ("/source", "/source/.build/dist-native/helper", "/store/plugin")) "compatible plugin patch version"
  check (isRefused (parse [helper ["different-unit"] "local", plugin "plugin-unit" "0.9.1"])) "unbound plugin refusal"
  check (isRefused (parse [helper ["plugin-unit"] "local", plugin "plugin-unit" "0.10.0"])) "incompatible plugin refusal"
  check (isRefused (parse [helper ["plugin-unit"] "local", plugin "plugin-unit" "0.8.9"])) "old plugin refusal"
  check (isRefused (parse [helper ["plugin-unit"] "local", plugin "plugin-unit" "0.9.1junk"])) "malformed plugin version refusal"
  check (isRefused (parse [helper ["plugin-unit"] "remote", plugin "plugin-unit" "0.9.1"])) "nonlocal source refusal"
  check (isRefused (parse (good <> [plugin "plugin-unit" "0.9.1"]))) "duplicate unit refusal"
  check (isRefused (parse (good <> [plugin "another-plugin" "0.9.1"]))) "ambiguous plugin refusal"
  check (isRefused (parse (good <> [helper ["plugin-unit"] "local"]))) "ambiguous helper refusal"
  check (isRefused (parse [helper ["plugin-unit", "another-tool"] "local", plugin "plugin-unit" "0.9.1"])) "extra tool refusal"
  check (isRefused (parse [helper [] "local", plugin "plugin-unit" "0.9.1"])) "missing tool dependency refusal"
  check (isRefused (parse [helper ["plugin-unit"] "local"])) "missing plugin refusal"
  check (isRefused (parsePlan (ByteString.pack "{\"install-plan\":[],\"install-plan\":[]}"))) "duplicate JSON key refusal"
  check (isRefused (parsePlan (ByteString.pack "{\"install-plan\":[{\"id\":\"first\",\"id\":\"second\"}]}"))) "nested duplicate JSON key refusal"
  check (isRefused (parsePlan (ByteString.pack "{\"install-plan\":["))) "truncated JSON refusal"
  check (isRefused (parsePlan (ByteString.pack "{\"install-plan\":[]} trailing"))) "trailing JSON refusal"
  check (native nativeGood == Just (helperImage, pluginImage)) "native plan selection"
  check (native [helperAtRoot ["plugin-unit"] "local" nativeRoot (nativeRoot </> "foreign-helper"), nativePlugin "plugin-unit" "0.9.1"] == Nothing) "native foreign helper refusal"
  check (native [nativeHelper ["plugin-unit"] "local", nativePlugin "plugin-unit" "0.9"] == Just (helperImage, pluginImage)) "native minimum compatible plugin"
  check (native [nativeHelper ["different-unit"] "local", nativePlugin "plugin-unit" "0.9.1"] == Nothing) "native unbound plugin refusal"
  check (native [nativeHelper ["plugin-unit", "another-tool"] "local", nativePlugin "plugin-unit" "0.9.1"] == Nothing) "native extra tool refusal"
  check (native [nativeHelper ["plugin-unit"] "remote", nativePlugin "plugin-unit" "0.9.1"] == Nothing) "native foreign source refusal"
  check (native [nativeHelper ["plugin-unit"] "local", nativePlugin "plugin-unit" "0.8.9"] == Nothing) "native old plugin refusal"
  check (native [nativeHelper ["plugin-unit"] "local", nativePlugin "plugin-unit" "0.10.0"] == Nothing) "native incompatible plugin refusal"
  check (native [nativeHelper ["plugin-unit"] "local", nativePlugin "plugin-unit" "0.9.1junk"] == Nothing) "native malformed version refusal"
  check (native (nativeGood <> [nativePlugin "another-plugin" "0.9.1"]) == Nothing) "native ambiguous plugin refusal"
  check (native (nativeGood <> [nativeHelper ["plugin-unit"] "local"]) == Nothing) "native ambiguous helper refusal"
  check (native [nativeHelper ["plugin-unit"] "local"] == Nothing) "native missing plugin refusal"
  check (native [nativeHelper ["plugin-unit"] "local", pluginAt "plugin-unit" "0.9.1" "relative-plugin"] == Nothing) "native relative plugin refusal"
  check (nativePlanWireTool nativeRoot (ByteString.pack "{\"install-plan\":[],\"install-plan\":[]}") == Nothing) "native duplicate key refusal"
  check (nativePlanWireTool nativeRoot (ByteString.pack "{\"install-plan\":[]} trailing") == Nothing) "native trailing JSON refusal"
  ownerChecks
 where
  isRefused (Left _) = True
  isRefused (Right _) = False

ownerChecks :: IO ()
ownerChecks = bracket temporary removePathForcibly $ \root -> do
  let clean = root </> "clean"
  createDirectory clean
  physicalClean <- canonicalizePath clean
  owner <- preparationOwner clean
  unless (owner == physicalClean </> ".build" </> "proto") (fail "clean preparation owner")
  forM_ ["build", "proto"] $ \part -> do
    let source = root </> (part <> "-source")
        outside = root </> (part <> "-outside")
        build = source </> ".build"
    createDirectory source
    createDirectory outside
    unless (part == "build") (createDirectory build)
    linked <- try (createDirectoryLink outside (if part == "build" then build else build </> "proto")) :: IO (Either IOException ())
    case linked of
      Left _ -> putStrLn ("symlink control unavailable: " <> part)
      Right () -> do
        result <- try (preparationOwner source) :: IO (Either IOException FilePath)
        entries <- listDirectory outside
        case result of
          Left _ | null entries -> pure ()
          _ -> fail ("redirected " <> part <> " owner accepted or modified")
 where
  temporary = do
    parent <- getTemporaryDirectory
    (path, handle) <- openTempFile parent "amoebius-wire-plan-"
    hClose handle
    removeFile path
    createDirectory path
    pure path

plan :: [Value] -> Value
plan rows = object ["install-plan" .= rows]

helper :: [Text] -> Text -> Value
helper dependencies sourceKind = helperAt dependencies sourceKind "/source/.build/dist-native/helper"

helperAt :: [Text] -> Text -> FilePath -> Value
helperAt dependencies sourceKind = helperAtRoot dependencies sourceKind "/source"

helperAtRoot :: [Text] -> Text -> FilePath -> FilePath -> Value
helperAtRoot dependencies sourceKind root image = object
  [ "pkg-name" .= ("amoebius" :: Text), "component-name" .= ("exe:amoebius-wire-prepare" :: Text)
  , "id" .= ("helper-unit" :: Text), "pkg-version" .= ("0.1.0.0" :: Text), "style" .= ("local" :: Text)
  , "bin-file" .= image, "exe-depends" .= dependencies
  , "pkg-src" .= object ["type" .= sourceKind, "path" .= root]
  ]

plugin :: Text -> Text -> Value
plugin identity version = pluginAt identity version "/store/plugin"

pluginAt :: Text -> Text -> FilePath -> Value
pluginAt identity version image = object
  [ "pkg-name" .= ("proto-lens-protoc" :: Text), "component-name" .= ("exe:proto-lens-protoc" :: Text)
  , "id" .= identity, "pkg-version" .= version, "style" .= ("global" :: Text)
  , "bin-file" .= image
  ]

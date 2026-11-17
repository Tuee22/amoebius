{-# LANGUAGE OverloadedStrings #-}

-- | Select the plugin that Cabal associated with this preparation image.
-- The verifier independently checks the same plan before accepting a build.
module Plan (plannedPlugin, selectPlan, parsePlan) where

import Control.Monad (unless, when)
import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:), (.:?), (.!=))
import Data.Aeson.Types (Parser, parseEither)
import Data.Aeson.Decoding.ByteString qualified as JsonBytes
import Data.Aeson.Decoding.Tokens qualified as Json
import Data.ByteString qualified as ByteString
import Data.List (nub)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Version (parseVersion, versionBranch)
import System.Directory (canonicalizePath, doesFileExist, makeAbsolute)
import System.Environment (getExecutablePath)
import System.FilePath (isAbsolute, (</>))
import Text.ParserCombinators.ReadP (readP_to_S)

data Unit = Unit Text Text Text Text Text (Maybe FilePath) [Text] (Maybe Value)

plannedPlugin :: IO FilePath
plannedPlugin = do
  root <- canonicalizePath "."
  let relative = ".build" </> "dist-native" </> "cache" </> "plan.json"
  expected <- makeAbsolute relative
  physical <- canonicalizePath expected
  unless (physical == expected) (fail "build plan is outside its source tree")
  bytes <- ByteString.readFile physical
  (source, image, plugin) <- either fail pure (parsePlan bytes)
  sourceRoot <- canonicalizePath source
  helper <- canonicalizePath image
  running <- getExecutablePath >>= canonicalizePath
  unless (sourceRoot == root && helper == running) (fail "build plan does not select this source and image")
  unless (isAbsolute plugin) (fail "plugin path is not absolute")
  actual <- canonicalizePath plugin
  present <- doesFileExist actual
  unless present (fail "planned plugin is absent")
  pure actual

-- Aeson objects alone do not retain repeated keys. Reject them before
-- interpreting the plan so no alternate source or image can be hidden.
parsePlan :: ByteString.ByteString -> Either String (FilePath, FilePath, FilePath)
parsePlan bytes = do
  when (ByteString.length bytes > 64 * 1024 * 1024) (Left "build plan exceeds limit")
  rest <- maybe (Left "build plan has malformed or duplicate JSON fields") Right (uniqueJson (JsonBytes.bsToTokens bytes))
  unless (ByteString.all (`elem` [9,10,13,32]) rest) (Left "build plan has trailing content")
  eitherDecodeStrict' bytes >>= parseEither selectPlan

uniqueJson :: Json.Tokens k e -> Maybe k
uniqueJson value = case value of
  Json.TkLit _ next -> Just next
  Json.TkText _ next -> Just next
  Json.TkNumber _ next -> Just next
  Json.TkArrayOpen rows -> array rows
  Json.TkRecordOpen rows -> object Set.empty rows
  Json.TkErr _ -> Nothing
 where
  array rows = case rows of
    Json.TkItem item -> uniqueJson item >>= array
    Json.TkArrayEnd next -> Just next
    Json.TkArrayErr _ -> Nothing
  object keys rows = case rows of
    Json.TkPair key item -> if Set.member key keys then Nothing else uniqueJson item >>= object (Set.insert key keys)
    Json.TkRecordEnd next -> Just next
    Json.TkRecordErr _ -> Nothing

selectPlan :: Value -> Parser (FilePath, FilePath, FilePath)
selectPlan = withObject "Cabal plan" $ \plan -> do
  rows <- plan .: "install-plan" >>= traverse unit
  let identities = [identity | Unit _ _ identity _ _ _ _ _ <- rows]
      helpers = [(image, dependencies, source) | Unit "amoebius" "exe:amoebius-wire-prepare" _ _ "local" image dependencies source <- rows]
      plugins = [(identity, version, image) | Unit "proto-lens-protoc" "exe:proto-lens-protoc" identity version "global" image _ _ <- rows]
  when (length identities /= length (nub identities)) (fail "duplicate plan unit identity")
  (helperImage, dependencies, source) <- case helpers of
    [(Just image, dependencies', Just source')] -> do
      local <- sourcePath source'
      pure (image, dependencies', local)
    _ -> fail "preparation image is absent or ambiguous in plan"
  (identity, version, image) <- case plugins of
    [(identity', version', Just image')] -> pure (identity', version', image')
    _ -> fail "plugin is absent or ambiguous in plan"
  unless (dependencies == [identity]) (fail "preparation tool dependency does not match plugin")
  parsed <- case [value | (value, "") <- readP_to_S parseVersion (Text.unpack version)] of
    [value] -> pure (versionBranch value)
    _ -> fail "plugin version is invalid"
  unless (parsed >= [0,9] && parsed < [0,10]) (fail "plugin version is incompatible")
  pure (source, helperImage, image)
 where
  unit = withObject "plan unit" $ \row -> Unit
    <$> row .: "pkg-name" <*> row .:? "component-name" .!= ""
    <*> row .: "id" <*> row .: "pkg-version" <*> row .:? "style" .!= ""
    <*> row .:? "bin-file" <*> row .:? "exe-depends" .!= [] <*> row .:? "pkg-src"
  sourcePath = withObject "source" $ \source -> do
    kind <- source .: "type"
    unless (kind == ("local" :: Text)) (fail "preparation source is not local")
    source .: "path"

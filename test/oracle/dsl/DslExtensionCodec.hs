{-# LANGUAGE OverloadedStrings #-}

-- Independent field-level expectations for the extension configuration codec.
module DslExtensionCodec (extensionCodecRows) where

import Control.Exception (IOException, try)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import DslEngineContract (engineRuntimes, inferenceFamilies, inferenceFamilyNames)
import System.FilePath ((</>))

extensionCodecRows :: FilePath -> IO [(Text, Bool, Text)]
extensionCodecRows directory = do
  inventory <- readMaybe (directory </> "inventory.tsv")
  let engineNames = [family <> "-" <> runtime | family <- inferenceFamilies, runtime <- engineRuntimes]
      negatives =
        [("zero-cache-budget", "InvalidCacheBounds"), ("zero-first-miss-concurrency", "InvalidCacheBounds"),
         ("temporary-above-budget", "InvalidCacheBounds"), ("cache-bounds-overflow", "InvalidCacheBounds"),
         ("reference-url", "InvalidExtensionReference"), ("duplicate-request", "DuplicateExtensionRequest")]
      names = "all-configurations" : engineNames <> map fst negatives
  configs <- judge "all-configurations"
    [ "extension.0.id\tjit-build", "extension.0.schema\tBuildCacheConfig", "extension.0.cache-budget\t4096"
    , "extension.0.cache-temporary\t1024", "extension.0.cache-concurrency\t3"
    , "extension.1.id\tcoordination", "extension.1.schema\tCoordinationConfig", "extension.1.reference\tevents"
    , "extension.2.id\tinfernix", "extension.2.schema\tInferenceConfig", "extension.2.cache-budget\t8192"
    , "extension.3.id\tjitml", "extension.3.schema\tTrainingConfig", "extension.3.reference\ttraining-data"
    ]
  engines <- mapM (\(family, runtime) -> judge (family <> "-" <> runtime)
    ["deployment.0.binding.0.engine-runtime\t" <> runtime,
     "deployment.0.binding.0.engine-family\t" <> familyName family])
    [(family, runtime) | family <- inferenceFamilies, runtime <- engineRuntimes]
  refused <- mapM (\(name, wanted) -> do
    refusal <- readMaybe (directory </> Text.unpack name </> "refusal.tsv")
    pure ("codec." <> name, refusal == Just (wanted <> "\n"), maybe "missing refusal" id refusal)) negatives
  pure (("codec.discovery", fmap (sort . Text.lines) inventory == Just (sort names), maybe "missing inventory" id inventory)
    : configs : engines <> refused)
 where
  judge name expected = do
    decoded <- readMaybe (directory </> Text.unpack name </> "decoded.dump")
    roundtrip <- readMaybe (directory </> Text.unpack name </> "roundtrip.tsv")
    let rows = maybe [] Text.lines decoded
    pure ("codec." <> name, roundtrip == Just "True\n" && all (\row -> length (filter (== row) rows) == 1) expected,
          maybe "missing dump" id decoded)
  familyName family = maybe "invalid-independent-family" id (lookup family inferenceFamilyNames)
  readMaybe path = either (const Nothing) Just <$> (try (Text.readFile path) :: IO (Either IOException Text))

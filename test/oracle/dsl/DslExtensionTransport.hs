{-# LANGUAGE OverloadedStrings #-}

-- Independent native-process expectations. No product library is imported.
module DslExtensionTransport (transportRows) where

import Control.Exception (IOException, try)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.FilePath ((</>))

transportRows :: FilePath -> IO [(Text, Bool, Text)]
transportRows directory = do
  inventory <- readMaybe (directory </> "transport.tsv")
  let rows = maybe [] (map (Text.splitOn "\t") . Text.lines) inventory
      expected =
        [ ("complete-peer-closure", "0", "False", Nothing)
        , ("pure-helper-closure", "0", "False", Just "Compiling Amoebius.Extension.Contributed.GuardProbe")
        , ("incremental-existing-unsafe-source", "1", "False", Just "JitBuild.hs:1:17:UnsafeOperation:options-pragma")
        , ("incremental-new-unsafe-source", "1", "False", Just "GuardProbe.hs:4:1:TemplateHaskell:splice-declaration")
        , ("precompile-plugin-option", "1", "False", Just "GuardProbe.hs:1:17:UnsafeOperation:options-pragma")
        , ("trusted-effect-control", "0", "True", Just "Compiling TrustedEffect")
        ]
  judgments <- mapM (judge rows) expected
  pure (("transport.discovery", sort (map (take 1) rows) == sort [[name] | (name, _, _, _) <- expected],
         Text.pack (show rows)) : judgments)
 where
  judge rows (name, code, marker, message) = do
    out <- readMaybe (directory </> Text.unpack name </> "stdout")
    err <- readMaybe (directory </> Text.unpack name </> "stderr")
    let actual = [row | row@(key : _) <- rows, key == name]
        output = maybe "" id out <> maybe "" id err
        matched = actual == [[name, code, marker]] && out /= Nothing && err /= Nothing
          && maybe True (`Text.isInfixOf` output) message
    pure ("transport." <> name, matched, Text.pack (show actual) <> ": " <> output)
  readMaybe path = either (const Nothing) Just <$> (try (Text.readFile path) :: IO (Either IOException Text))

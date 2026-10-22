{-# LANGUAGE OverloadedStrings #-}

module SpineExtensionAst (extensionAstSection) where

import Amoebius.Extension.AstCheck
import Amoebius.Dsl.Examples.Extensions.SourceInputs (extensionInputs)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

extensionAstSection :: FilePath -> IO ()
extensionAstSection directory = do
  createDirectoryIfMissing True directory
  Text.writeFile (directory </> "inventory.tsv") (Text.unlines (map fst extensionInputs))
  mapM_ observe extensionInputs
 where
  observe (name, source) = Text.writeFile (directory </> Text.unpack name <> ".tsv") $
    case checkExtensionSource "Contribution.hs" source of
      Accepted seal -> "accepted\t" <> Text.pack (show (linkCheckedExtension seal == source)) <> "\n"
      Rejected violations -> Text.unlines ("refused" : map renderAstViolation (NonEmpty.toList violations))

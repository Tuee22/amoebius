{-# LANGUAGE OverloadedStrings #-}
module PackageImportCases (runPackageImportCases) where

import Amoebius.Layout.Classify (renderFinding)
import Amoebius.Layout.PackageMap (emptyPackageCatalog, packageCatalogFromInputs)
import Amoebius.Layout.SourceGraph (sourceGraphWithPackageCatalog)
import Control.Monad (forM)
import Data.ByteString qualified as Bytes
import Data.ByteString.Char8 qualified as Char8
import Data.List (intercalate)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

-- These are inputs to the shipped graph reader, with no expected verdicts.
runPackageImportCases :: FilePath -> IO ()
runPackageImportCases directory = do
  createDirectoryIfMissing True directory
  observations <- forM names $ \name -> do
    let root = directory </> "package-imports" </> Text.unpack name
        requested = if name == "wrong" then "wrong" else if name == "other-package" then "probe" else "amoebius"
        package = if name == "other-package" then "probe" else "amoebius"
        source = case name of
          "mixed" -> mixedConsumer
          "declarations" -> declarationConsumer
          "reexport" -> facadeConsumer
          _ -> consumer requested
        files = [("provider/Shared.hs", provider), ("Consumer.hs", source)]
          <> [("home/Shared.hs", homeProvider) | name == "mixed"]
          <> [("other/Shared.hs", provider) | name == "ambiguous"]
          <> [("Facade.hs", facade) | name == "reexport"]
        components = Map.fromList
          ([("provider/Shared.hs", ["library:provider"]), ("Consumer.hs", ["test:consumer"])]
            <> [("home/Shared.hs", ["test:consumer"]) | name == "mixed"]
            <> [("other/Shared.hs", ["library:other"]) | name == "ambiguous"]
            <> [("Facade.hs", ["library:facade"]) | name == "reexport"])
        consumerDependencies = if name == "reexport" then ["library:facade"]
          else ["library:provider"] <> ["library:other" | name == "ambiguous"]
        dependencies = Map.fromList
          ([("test:consumer", consumerDependencies) | name /= "unlisted"]
            <> [("library:facade", ["library:provider"]) | name == "reexport"])
        units = [("provider-unit", package, "lib:provider", [])]
          <> [("provider-copy", "probe", "lib:provider", []) | name == "metadata-ambiguous"]
          <> [("other-unit", package, "lib:other", []) | name == "ambiguous"]
          <> [("facade-unit", "amoebius", "lib:facade", ["provider-unit"]) | name == "reexport"]
          <> [("consumer-unit", "amoebius", "test:consumer",
                if name == "plan-unlisted" then []
                else if name == "reexport" then ["facade-unit"]
                else ["provider-unit"] <> ["other-unit" | name == "ambiguous"])]
        declared = Map.fromList
          ([("library:provider", []), ("test:consumer", if name == "plan-unlisted" then [] else [package])]
            <> [("library:other", []) | name == "ambiguous"]
            <> [("library:facade", ["amoebius"]) | name == "reexport"])
        plan = renderPlan units
    createDirectoryIfMissing True root
    mapM_ (\(path, body) -> do
      createDirectoryIfMissing True (takeDirectory (root </> path))
      TextIO.writeFile (root </> path) body) files
    Bytes.writeFile (root </> "plan.json") plan
    let acquired = if name == "unknown" then Right emptyPackageCatalog
          else packageCatalogFromInputs declared plan ""
    case acquired of
      Left finding -> pure [[name, "catalog-finding", renderFinding finding]]
      Right catalog -> do
        (findings, rows) <- sourceGraphWithPackageCatalog root (map fst files)
          components dependencies catalog Map.empty
        pure ([name : Text.splitOn "\t" row | row <- rows]
          <> [[name, "finding", renderFinding finding] | finding <- findings])
  TextIO.writeFile (directory </> "package-imports.tsv")
    (Text.unlines [Text.intercalate "\t" row | rows <- observations, row <- rows])
 where
  names = ["named", "wrong", "unlisted", "ambiguous", "unknown",
    "other-package", "mixed", "declarations", "reexport", "metadata-ambiguous", "plan-unlisted"]

renderPlan :: [(Text, Text, Text, [Text])] -> Bytes.ByteString
renderPlan units = Char8.pack
  ("{\"compiler-id\":\"ghc-9.12.4\",\"compiler-abi\":\"5301\",\"install-plan\":["
    <> intercalate "," [entry unit package component dependencies
      | (unit, package, component, dependencies) <- units] <> "]}")
 where
  quoted = show . Text.unpack
  entry unit package component dependencies =
    "{\"id\":" <> quoted unit <> ",\"pkg-name\":" <> quoted package
      <> ",\"component-name\":" <> quoted component <> ",\"depends\":["
      <> intercalate "," (map quoted dependencies) <> "]}"

provider :: Text
provider = Text.unlines
  [ "{-# LANGUAGE NoImplicitPrelude #-}"
  , "module Shared (helper, Box(..), C(..)) where"
  , "helper x = x"
  , "data Box = Box { value :: () }"
  , "class C a where"
  , "  method :: a -> a"
  ]

homeProvider :: Text
homeProvider = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule Shared (helper) where\nhelper x = x\n"

consumer :: Text -> Text
consumer package = Text.unlines
  [ "{-# LANGUAGE NoImplicitPrelude, PackageImports #-}"
  , "module Consumer where"
  , "import \"" <> package <> "\" Shared (helper)"
  , "use = helper ()"
  ]

mixedConsumer :: Text
mixedConsumer = Text.unlines
  [ "{-# LANGUAGE NoImplicitPrelude, PackageImports #-}"
  , "module Consumer where"
  , "import qualified Shared as H"
  , "import qualified \"amoebius\" Shared as P"
  , "homeCall = H.helper ()"
  , "packageCall = P.helper ()"
  ]

declarationConsumer :: Text
declarationConsumer = Text.unlines
  [ "{-# LANGUAGE NoImplicitPrelude, PackageImports, FlexibleInstances #-}"
  , "module Consumer where"
  , "import \"amoebius\" Shared (Box(..), C(..), helper)"
  , "instance C () where"
  , "  method x = helper x"
  , "construct = Box ()"
  , "project = value construct"
  , "invoke = method ()"
  ]

facade :: Text
facade = Text.unlines
  [ "{-# LANGUAGE NoImplicitPrelude, PackageImports #-}"
  , "module Facade (module P) where"
  , "import \"amoebius\" Shared as P"
  ]

facadeConsumer :: Text
facadeConsumer = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule Consumer where\nimport Facade (helper)\nuse = helper ()\n"

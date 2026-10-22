{-# LANGUAGE OverloadedStrings #-}
module PackageImportOracle (packageImportChecks, runPackageImportOracle) where

import Control.Monad (forM, unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Exit (exitFailure)
import System.FilePath ((</>))

runPackageImportOracle :: FilePath -> IO ()
runPackageImportOracle directory = do
  checks <- packageImportChecks directory
  mapM_ (\(name, green, detail) ->
    TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", detail])) checks
  unless (all (\(_, green, _) -> green) checks) exitFailure

packageImportChecks :: FilePath -> IO [(Text, Bool, Text)]
packageImportChecks directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "package-imports.tsv")
  sourceChecks <- forM names $ \name -> do
    let root = directory </> "package-imports" </> Text.unpack name
    shared <- TextIO.readFile (root </> "provider/Shared.hs")
    found <- TextIO.readFile (root </> "Consumer.hs")
    let wanted = case name of
          "mixed" -> mixedSource
          "declarations" -> declarationSource
          "reexport" -> reexportSource
          "wrong" -> consumerSource "wrong"
          "other-package" -> consumerSource "probe"
          _ -> consumerSource "amoebius"
    pure ("package-imports." <> name <> ".source", shared == providerSource && found == wanted,
      "independent source literals")
  let observed name = [rest | key : rest <- rows, key == name]
      member name row = elem row (observed name)
      kind name tag = [row | row@(key : _) <- observed name, key == tag]
      stage name wanted = kind name "graph-stage" == [["graph-stage", wanted]]
      link name component consumer provider path imported =
        member name ["graph-link", component, consumer, provider, path, imported]
      call :: Text -> Text -> Text -> Text -> Text -> Text -> Text -> Bool
      call name owner target provider path callee imported =
        any (\row -> case row of
          ["graph-call-site-candidate", "test:consumer", "Consumer.hs", actualOwner, site,
            actualProvider, actualPath, actualCallee, actualImport] ->
              (actualOwner, actualProvider, actualPath, actualCallee, actualImport)
                == (owner, provider, path, callee, imported)
                && Just site == lookup (owner, target)
                    [(("use", "helper"), "4:7-4:16"),
                     (("homeCall", "H.helper"), "5:12-5:23"),
                     (("packageCall", "P.helper"), "6:15-6:26"),
                     (("construct", "Box"), "6:13-6:19"),
                     (("project", "value"), "7:11-7:26"),
                     (("invoke", "method"), "8:10-8:19")]
          _ -> False) (observed name)
      sourceBinding name component consumer package provider path unit =
        member name ["graph-import-source-package", component, consumer, package, "Shared", provider, path, package, unit]
      unresolved name =
        kind name "graph-import-unresolved" ==
          [["graph-import-unresolved", "test:consumer", "Consumer.hs", "Shared", "package-qualified"]]
      rejected name = unresolved name && null (kind name "graph-link")
        && null (kind name "graph-call-site-candidate")
        && null (kind name "graph-import-source-package") && stage name "partial-calls"
      positive name package =
        link name "test:consumer" "Consumer.hs" "library:provider" "provider/Shared.hs" "Shared"
          && call name "use" "helper" "library:provider" "provider/Shared.hs" "helper" "Shared"
          && sourceBinding name "test:consumer" "Consumer.hs" package "library:provider" "provider/Shared.hs" "provider-unit"
          && null (kind name "graph-import-unresolved") && stage name "resolved"
      check name green detail = ("package-imports." <> name, green, detail)
  pure (sourceChecks <>
    [ check "discovery" (sort (unique [name | name : _ <- rows]) == sort names
        && all (\name -> length (kind name "graph-stage") == 1) names) "eleven closed fixture inventories"
    , check "named" (positive "named" "amoebius") "package identity, declared library, call and unit"
    , check "other-package" (positive "other-package" "probe") "requested package is data"
    , check "wrong" (rejected "wrong") "wrong package cannot resolve the available module"
    , check "unknown" (rejected "unknown") "missing package metadata refuses"
    , check "metadata-ambiguous" (rejected "metadata-ambiguous") "ambiguous component identity refuses"
    , check "unlisted" (kind "unlisted" "finding" ==
        [["finding", "InternalImportDependencyMissing", "test:consumer:Consumer.hs:Shared"]]
        && null (kind "unlisted" "graph-link") && stage "unlisted" "partial-calls")
        "package qualification cannot grant a dependency"
    , check "plan-unlisted" (kind "plan-unlisted" "finding" ==
        [["finding", "InternalImportDependencyMissing", "test:consumer:Consumer.hs:Shared"]]
        && null (kind "plan-unlisted" "graph-link") && stage "plan-unlisted" "partial-calls")
        "the compiler plan must bind the exact provider unit"
    , check "ambiguous" (kind "ambiguous" "finding" ==
        [["finding", "AmbiguousSourceImport", "test:consumer:Consumer.hs:Shared"]]
        && null (kind "ambiguous" "graph-link")) "two matching libraries remain ambiguous"
    , check "mixed" (link "mixed" "test:consumer" "Consumer.hs" "test:consumer" "home/Shared.hs" "Shared"
        && link "mixed" "test:consumer" "Consumer.hs" "library:provider" "provider/Shared.hs" "Shared"
        && call "mixed" "homeCall" "H.helper" "test:consumer" "home/Shared.hs" "helper" "Shared"
        && call "mixed" "packageCall" "P.helper" "library:provider" "provider/Shared.hs" "helper" "Shared"
        && length (kind "mixed" "graph-call-site-candidate") == 2 && stage "mixed" "resolved")
        "aliases distinguish the home module from the named library"
    , check "declarations" (link "declarations" "test:consumer" "Consumer.hs" "library:provider" "provider/Shared.hs" "Shared"
        && member "declarations" ["graph-instance-method-source-contract", "Consumer.hs", "C ()", "C", "method", "provider/Shared.hs", "Shared"]
        && call "declarations" "construct" "Box" "library:provider" "provider/Shared.hs" "Box" "Shared"
        && call "declarations" "project" "value" "library:provider" "provider/Shared.hs" "value" "Shared"
        && call "declarations" "invoke" "method" "library:provider" "provider/Shared.hs" "method" "Shared"
        && stage "declarations" "resolved") "class, constructor and selector source routes"
    , check "reexport" (link "reexport" "library:facade" "Facade.hs" "library:provider" "provider/Shared.hs" "Shared"
        && call "reexport" "use" "helper" "library:provider" "provider/Shared.hs" "helper" "Facade"
        && sourceBinding "reexport" "library:facade" "Facade.hs" "amoebius" "library:provider" "provider/Shared.hs" "provider-unit"
        && stage "reexport" "resolved") "named-package routes survive re-export"
    ])
 where
  names = ["named", "wrong", "unlisted", "ambiguous", "unknown", "other-package", "mixed", "declarations", "reexport", "metadata-ambiguous", "plan-unlisted"]
  unique = foldr (\value values -> if elem value values then values else value : values) []

providerSource :: Text
providerSource = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule Shared (helper, Box(..), C(..)) where\nhelper x = x\ndata Box = Box { value :: () }\nclass C a where\n  method :: a -> a\n"

consumerSource :: Text -> Text
consumerSource package = "{-# LANGUAGE NoImplicitPrelude, PackageImports #-}\nmodule Consumer where\nimport \"" <> package <> "\" Shared (helper)\nuse = helper ()\n"

mixedSource :: Text
mixedSource = "{-# LANGUAGE NoImplicitPrelude, PackageImports #-}\nmodule Consumer where\nimport qualified Shared as H\nimport qualified \"amoebius\" Shared as P\nhomeCall = H.helper ()\npackageCall = P.helper ()\n"

declarationSource :: Text
declarationSource = "{-# LANGUAGE NoImplicitPrelude, PackageImports, FlexibleInstances #-}\nmodule Consumer where\nimport \"amoebius\" Shared (Box(..), C(..), helper)\ninstance C () where\n  method x = helper x\nconstruct = Box ()\nproject = value construct\ninvoke = method ()\n"

reexportSource :: Text
reexportSource = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule Consumer where\nimport Facade (helper)\nuse = helper ()\n"

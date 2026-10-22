{-# LANGUAGE OverloadedStrings #-}

-- Native client observations use product-owned source inputs and independent
-- diagnostic expectations. Each legal/illegal pair finishes before the next.
module DslExtensionTypes (conformanceTypeRows, closedApiRows) where

import Control.Exception (IOException, try)
import Data.List (sort)
import Data.Text qualified as Text
import DslConformanceContract (nativeScopeRoles)
import DslExtensionContract (closedApiBoundaries)
import DslParse
import DslTwins (Diagnostic (..), compileWithLibraries)
import System.Directory (listDirectory)
import System.Exit (ExitCode (ExitSuccess, ExitFailure))
import System.FilePath ((</>))

conformanceTypeRows :: Maybe FilePath -> FilePath -> FilePath -> IO [Row]
conformanceTypeRows compiler buildDirectory suite = do
  listing <- try (listDirectory inputs) :: IO (Either IOException [FilePath])
  rows <- mapM observe nativeScopeRoles
  pure (expectEqual "extensions.native-types.complete-inventory"
    (sort [Text.unpack name <> suffix <> ".hs" | name <- nativeScopeRoles, suffix <- ["-same-index", "-retag"]])
    (either (const Nothing) (Just . sort) listing) : rows)
 where
  inputs = suite </> "extensions/types"
  observe name = do
    legal <- readText (inputs </> Text.unpack name <> "-same-index.hs")
    illegal <- readText (inputs </> Text.unpack name <> "-retag.hs")
    let directory = suite </> "compiler-negative/extensions" </> Text.unpack name
        run = compileWithLibraries ["extension-conformance-gate", "extension-calculi", "scope-index",
          "extension-declaration", "extension-monitoring"] compiler buildDirectory directory
    admitted <- maybe (pure Nothing) (run "Legal") legal
    refused <- maybe (pure Nothing) (run "Illegal") illegal
    let positive = case admitted of Just (ExitSuccess, diagnostics) -> null [() | item <- diagnostics, diagnosticSeverity item == "Error"]; _ -> False
        negative = case refused of
          Just (ExitFailure 1, [item]) -> diagnosticSeverity item == "Error"
            && diagnosticCode item == 18872 && diagnosticLine item == 7 && diagnosticColumn item == 9
            && all (`Text.isInfixOf` diagnosticMessage item) ["ScopeAlpha", "ScopeBeta", "coerce"]
          _ -> False
    pure (check ("extensions.native-types." <> name) (positive && negative)
      (Text.pack (show (positive, negative, fmap (map diagnosticCode . snd) refused))))

closedApiRows :: Maybe FilePath -> FilePath -> FilePath -> IO [Row]
closedApiRows compiler buildDirectory suite = do
  listing <- try (listDirectory inputs) :: IO (Either IOException [FilePath])
  rows <- mapM observe closedApiBoundaries
  pure (expectEqual "scope.closed-api.complete-inventory"
    (sort [Text.unpack name <> suffix <> ".hs" | (name, _) <- closedApiBoundaries, suffix <- ["-legal", "-illegal"]])
    (either (const Nothing) (Just . sort) listing) : rows)
 where
  inputs = suite </> "extensions/closed-api"
  observe (name, fragments) = do
    legal <- readText (inputs </> Text.unpack name <> "-legal.hs")
    illegal <- readText (inputs </> Text.unpack name <> "-illegal.hs")
    let directory = suite </> "compiler-negative/closed-api" </> Text.unpack name
        run = compileWithLibraries ["extension-spec", "extension-graph", "extension-admission", "extension-contributions",
          "extension-monitoring", "scope-index", "workflow-calculus"] compiler buildDirectory directory
        expectedLine = case name of "spec-generic" -> 6; "claimed-identity" -> 5;
                                    "workflow-before-retag" -> 8; "workflow-after-retag" -> 8;
                                    "missing-monitoring" -> 4; "unrelated-factory-seal" -> 5; _ -> 3
    admitted <- maybe (pure Nothing) (run "Legal") legal
    refused <- maybe (pure Nothing) (run "Illegal") illegal
    let positive = case admitted of Just (ExitSuccess, diagnostics) -> null [() | item <- diagnostics, diagnosticSeverity item == "Error"]; _ -> False
        negative = case refused of
          Just (ExitFailure 1, diagnostics) ->
            let errors = [item | item <- diagnostics, diagnosticSeverity item == "Error"]
                message = Text.intercalate "\n" (map diagnosticMessage errors)
             in not (null errors) && all (\item -> diagnosticCode item > 0 && diagnosticLine item == expectedLine) errors
                && all (`Text.isInfixOf` message) fragments
                && (not ("workflow-" `Text.isPrefixOf` name) || all ((== 18872) . diagnosticCode) errors)
          _ -> False
    pure (check ("scope.closed-api." <> name) (positive && negative)
      (Text.pack (show (positive, negative, fmap (map (\item ->
        (diagnosticCode item, diagnosticLine item, diagnosticColumn item, diagnosticMessage item)) . snd) refused))))

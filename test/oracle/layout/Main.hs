{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the layout projection. No product package is
-- imported; the allowed classes and refusal tags are literals here.
module Main (main) where
import PackageImportOracle (packageImportChecks, runPackageImportOracle)
import TestSourceOracle (testSourceChecks, testSourceExampleChecks, runTestSourceOracle)
import ToolSourceOracle (toolSourceChecks, toolSourceExampleChecks, runToolSourceOracle)
import PulumiSourceOracle (pulumiSourceChecks, pulumiSourceExampleChecks, runPulumiSourceOracle)
import RuntimeIdentityOracle (runtimeIdentityChecks, runtimeIdentityExampleChecks, runRuntimeIdentityOracle)
import IgnoreContextOracle (ignoreContextChecks, ignoreContextExampleChecks, runIgnoreContextOracle)
import SourceGraphOracle (sourceGraphChecks, sourceGraphExampleChecks, runSourceGraphOracle)
import BootstrapSourceOracle (bootstrapSourceChecks, bootstrapSourceExampleChecks, runBootstrapSourceOracle, expectedBootstrapCalls, expectedBootstrapEffects)
import ReportTransport (expandLayoutReport)

import Control.Exception (IOException, SomeAsyncException, SomeException, evaluate, fromException, throwIO, try)
import Control.Monad (forM, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isAlphaNum, isControl, isLower, isUpper)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.Encoding.Error (lenientDecode)
import Data.Text.IO qualified as TextIO
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getCurrentDirectory, listDirectory, makeAbsolute, pathIsSymbolicLink)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitFailure, exitSuccess, exitWith)
import System.FilePath (normalise, takeExtension, (</>))
import System.IO (hFlush, hSetEncoding, hSetNewlineMode, noNewlineTranslation, stderr, stdout, utf8)
import System.IO.Error (isDoesNotExistError)
import System.Process (readProcessWithExitCode)
import Text.Read (readMaybe)
import SourceScan
import StaticTextCaptureOracle (staticTextReference)
import StaticTextCasesOracle (staticTextChecks, staticTextCaseNames, staticTextExampleChecks, runStaticTextOracle)
import LexicalCasesOracle (lexicalCompatibilityChecks, lexicalCompatibilityNames, lexicalCompatibilityExampleChecks, runLexicalCompatibilityOracle)
import StaticTextSurfaceOracle (surfaceChecks,surfaceNames,surfaceExampleChecks,runSurfaceOracle)
import Codec.Compression.GZip qualified as GZip
import Data.ByteString.Lazy qualified as LazyBytes

main :: IO ()
main = do
  supplied <- getArgs
  when (any (`elem` supplied) ["--oracle-invocation", "--oracle-inventory"]) $ do
    hSetEncoding stderr utf8
    hSetNewlineMode stderr noNewlineTranslation
  (invocation, arguments) <- invocationArguments supplied
  inventory <- inventoryRequest invocation arguments
  case inventory of
    Just (challenge, withBinary) -> do
      names <- layoutInventoryNames withBinary
      emitCompletion challenge (Text.unlines [name <> "\tgreen\tdeclared" | name <- names])
        (foldr (const (+ 1)) 0 names) "all-green" "-"
      exitWith ExitSuccess
    Nothing -> case invocation of
      Nothing -> legacyMain arguments
      Just challenge -> runNormalInvocation challenge arguments

-- Keep the specialized and unflagged diagnostics on their original routes.
legacyMain :: [String] -> IO ()
legacyMain arguments = do
  case arguments of
    ["--static-text-surface", target] -> runSurfaceOracle target >> exitSuccess
    ["--lexical-compatibility", target] -> runLexicalCompatibilityOracle target >> exitSuccess
    ["--static-text", target] -> runStaticTextOracle expectedSinkTable target >> exitSuccess
    ["--bootstrap-source", target] -> runBootstrapSourceOracle target >> exitSuccess
    ["--source-graph", target] -> runSourceGraphOracle target >> exitSuccess
    ["--ignore-context", target] -> runIgnoreContextOracle target >> exitSuccess
    ["--runtime-identity", target] -> runRuntimeIdentityOracle target >> exitSuccess
    ["--pulumi-source", target] -> runPulumiSourceOracle target >> exitSuccess
    ["--tool-source", target] -> runToolSourceOracle target >> exitSuccess
    ["--test-source", target] -> runTestSourceOracle target >> exitSuccess
    ["--package-imports", target] -> runPackageImportOracle target >> exitSuccess
    _ -> pure ()
  let directory = case arguments of
        [path] -> path
        _ -> ".build/runs/layout-suite"
  primary <- TextIO.readFile (directory </> "paths.txt")
  checks <- layoutChecks directory primary
  mapM_ (TextIO.putStrLn . renderCheck) checks
  unless (all (\(_, green, _) -> green) checks) exitFailure

-- A challenge is bookkeeping. Only the native runner can bind this output to
-- the source copy, actual process return and exact selected executable images.
invocationArguments :: [String] -> IO (Maybe Text, [String])
invocationArguments arguments = case arguments of
  "--oracle-invocation" : challenge : rest
    | "--oracle-invocation" `elem` rest -> invocationFailure "InvocationRepeated"
    | length challenge /= 64 || not (all lowerHex challenge) -> invocationFailure "InvocationMalformed"
    | otherwise -> pure (Just (Text.pack challenge), rest)
  ["--oracle-invocation"] -> invocationFailure "InvocationValueMissing"
  _ | "--oracle-invocation" `elem` arguments -> invocationFailure "InvocationPosition"
    | otherwise -> pure (Nothing, arguments)
 where lowerHex character = ('0' <= character && character <= '9') || ('a' <= character && character <= 'f')

inventoryRequest :: Maybe Text -> [String] -> IO (Maybe (Text, Bool))
inventoryRequest invocation arguments
  | "--oracle-inventory" `notElem` arguments = pure Nothing
  | otherwise = case (invocation, arguments) of
      (Just challenge, ["--oracle-inventory", "layout.full.v1"]) -> pure (Just (challenge, False))
      (Just challenge, ["--oracle-inventory", "layout.gate.v1"]) -> pure (Just (challenge, True))
      (Nothing, _) -> invocationFailure "InvocationRequired"
      (Just _, ["--oracle-inventory", _]) -> invocationFailure "InventoryProfileUnknown"
      _ -> invocationFailure "InventoryArguments"

invocationFailure :: String -> IO a
invocationFailure reason = do
  TextIO.hPutStrLn stderr ("oracle-layout: " <> Text.pack reason)
  exitWith (ExitFailure 2)

runNormalInvocation :: Text -> [String] -> IO ()
runNormalInvocation challenge arguments = do
  (withBinary, supplied) <- case arguments of
    [path] -> pure (True, path)
    ["--oracle-profile", "layout.full.v1", path] -> pure (False, path)
    ["--oracle-profile", "layout.gate.v1", path] -> pure (True, path)
    _ -> invocationFailure "InvocationArguments"
  directory <- makeAbsolute supplied
  present <- doesDirectoryExist directory
  unless present (invocationFailure "InvocationDirectoryRequired")
  primary <- requiredRead challenge (directory </> "paths.txt")
  original <- layoutChecks directory primary
  binary <- if withBinary then layoutBinaryChecks directory else pure []
  let checks = original <> binary
      prefix = Text.unlines (map renderCheck checks)
      count = foldr (const (+ 1)) 0 checks :: Natural
      green = all (\(_, okay, _) -> okay) checks
  emitCompletion challenge prefix count (if green then "all-green" else "some-red") "-"
  exitWith (if green then ExitSuccess else ExitFailure 1)

-- Only the actual primary read's missing IOException earns the probe marker.
-- Report absence is a red semantic result; other I/O failures remain raw.
requiredRead :: Text -> FilePath -> IO Text
requiredRead challenge path = do
  attempted <- try (strictRead path) :: IO (Either IOException Text)
  case attempted of
    Right contents -> pure contents
    Left problem | isDoesNotExistError problem -> do
      TextIO.hPutStrLn stderr (Text.pack (show problem))
      hFlush stderr
      emitCompletion challenge "" 0 "required-input-missing" (Text.pack (show (Text.pack path)))
      exitWith (ExitFailure 1)
    Left problem -> throwIO problem

-- An interrupted compiler observation is never a completed red semantic row.
trySynchronous :: IO value -> IO (Either SomeException value)
trySynchronous action = do
  result <- try action
  case result of
    Left problem -> case fromException problem :: Maybe SomeAsyncException of
      Just _ -> throwIO problem
      Nothing -> pure result
    Right _ -> pure result

strictRead :: FilePath -> IO Text
strictRead path = TextIO.readFile path >>= \contents -> evaluate (Text.length contents) >> pure contents

emitCompletion :: Text -> Text -> Natural -> Text -> Text -> IO ()
emitCompletion challenge prefix count purpose locus = do
  let footer = Text.intercalate "\t"
        ["oracle.protocol.complete.v1", "green", "retained-text-utf8.v1", challenge,
         Text.pack (show count), sha256Text (TextEncoding.encodeUtf8 prefix), purpose, locus] <> "\n"
  _ <- evaluate (Text.length prefix)
  _ <- evaluate (Text.length footer)
  hSetEncoding stdout utf8
  hSetNewlineMode stdout noNewlineTranslation
  TextIO.hPutStr stdout prefix
  hFlush stdout
  TextIO.hPutStr stdout footer
  hFlush stdout

-- No suite output is read here. Per-path names come from a separate complete
-- walk of the original source roots; all other names are oracle-owned values.
layoutInventoryNames :: Bool -> IO [Text]
layoutInventoryNames withBinary = do
  paths <- independentLayoutPaths
  pure (layoutFixedNames
    <> ["package-imports." <> name <> ".source" | name <- packageNames]
    <> ["package-imports.discovery"] <> ["package-imports." <> name | name <- packageNames]
    <> concat [factoryNames prefix keys <> [prefix <> ".product-examples"]
       | (prefix, keys) <-
          [("test-source", ["tracked-test-script", "tracked-test-table", "tracked-expected-output", "tracked-patch", "tracked-mutant-body"])
          ,("tool-source", ["tracked-python-gate", "renamed-tool-root"])
          ,("pulumi-source", ["tracked-pulumi-yaml", "renamed-pulumi-program"])
          ,("runtime-identity", ["stale-ordinal", "copied-ordinal", "phase-named-runtime"])
          ,("ignore-context", ["retired-generated-root", "undeclared-state-root"])
          ,("source-graph", ["path-omitted", "mode-changed", "bytes-changed", "foreign-behavior-disguised", "effect-unattributed"])
          ,("bootstrap-source", ["bootstrap-byte-changed", "bootstrap-extra-role", "bootstrap-argv-rewritten"])]]
    <> staticTextCaseNames <> ["static-text.product-examples","static-text.capture-examples"]
    <> lexicalCompatibilityNames <> ["lexical.product-examples"]
    <> surfaceNames <> ["opaque.product-examples"]
    <> ["path:" <> Text.pack path | path <- paths]
    <> ["case:" <> name | (name, _) <- expectedCases]
    <> ["challenge-finding:" <> name | (name, _) <- expectedChallengeTags]
    <> ["binary." <> name <> "." <> role | withBinary, name <- ["python", "dhall", "pulumi"], role <- ["input-contract", "finding"]])
 where
  packageNames = ["named", "wrong", "unlisted", "ambiguous", "unknown", "other-package", "mixed", "declarations", "reexport", "metadata-ambiguous", "plan-unlisted"]
  factoryNames prefix keys = [prefix <> ".discovery"]
    <> [prefix <> "." <> name <> "." <> role | name <- keys, role <- ["positive", "negative"]]
    <> [prefix <> ".control.inventory", prefix <> ".control.cleanup"]

independentLayoutPaths :: IO [FilePath]
independentLayoutPaths = do
  root <- getCurrentDirectory
  found <- concat <$> mapM (walk root) ["src", "app", "test", "probe", "pb", "documents", "DEVELOPMENT_PLAN"]
  pure (sort (metadata <> ["AGENTS.md", "CLAUDE.md", "README.md"] <> filter (`notElem` metadata) found))
 where
  walk root relative = do
    entries <- sort <$> listDirectory (root </> relative)
    concat <$> forM entries (\name -> do
      let path = relative <> "/" <> name
      linked <- pathIsSymbolicLink (root </> path)
      unless (not linked) (fail "LayoutInventorySymlink")
      directory <- doesDirectoryExist (root </> path)
      if directory then walk root path else do
        regular <- doesFileExist (root </> path)
        unless regular (fail "LayoutInventoryNode")
        pure [path])

-- Independent literals for every existing fixed semantic judgment. Neither a
-- product registry nor a subject-reported count supplies the namespace.
layoutFixedNames :: [Text]
layoutFixedNames =
  [ "path-set"
  , "finding-set"
  , "fixture-graph-call-inventory"
  , "fixture-graph-call-outcomes"
  , "case:six-metadata-files"
  , "challenge-set"
  , "compiler-parsed-source-set"
  , "compiler-import-control"
  , "compiler-module-reexport-control"
  , "compiler-declaration-control"
  , "compiler-class-method-control"
  , "compiler-class-declaration-control"
  , "compiler-class-effect-type-seed-control"
  , "compiler-instance-declaration-control"
  , "compiler-instance-source-contract-control"
  , "compiler-instance-external-contract-control"
  , "compiler-class-call-dispatch-control"
  , "compiler-class-method-body-route-control"
  , "compiler-type-signature-control"
  , "compiler-effect-type-seed-control"
  , "compiler-effect-route-closure-control"
  , "compiler-call-site-control"
  , "compiler-call-site-coverage-control"
  , "compiler-reference-site-control"
  , "compiler-control-edge-control"
  , "compiler-dynamic-load-control"
  , "compiler-quotation-controls"
  , "compiler-record-field-control"
  , "compiler-foreign-boundary-control"
  , "compiler-type-family-boundary-control"
  , "compiler-derived-instance-control"
  , "compiler-derived-class-head-control"
  , "compiler-derived-class-member-control"
  , "compiler-standalone-deriving-control"
  , "compiler-standalone-deriving-member-control"
  , "compiler-data-symbol-control"
  , "compiler-data-declaration-gap-control"
  , "compiler-local-call-candidate-control"
  , "compiler-standalone-local-call-control"
  , "compiler-standalone-lexical-call-control"
  , "compiler-standalone-imported-call-control"
  , "standalone-reexport-boundary"
  , "compiler-standalone-source-denied-control"
  , "compiler-rejected-source-call-control"
  , "compiler-standalone-closed-export-refusal-control"
  , "compiler-grant-rejection-control"
  , "compiler-standalone-external-call-control"
  , "compiler-standalone-registered-only-control"
  , "compiler-standalone-external-member-control"
  , "compiler-imported-call-candidate-control"
  , "compiler-local-import-control"
  , "compiler-dependency-import-control"
  , "compiler-component-control"
  , "compiler-cabal-dependency-control"
  , "compiler-standalone-import-partition"
  , "compiler-import-partition-control"
  , "compiler-constructor-reexport-control"
  , "compiler-constructor-reexport-pairs"
  , "compiler-external-call-candidate-control"
  , "compiler-external-member-call-control"
  , "compiler-available-call-candidate-control"
  , "compiler-available-member-call-control"
  , "compiler-deferred-seed-call-control"
  , "compiler-prelude-interface-control"
  , "compiler-available-prelude-control"
  , "compiler-standalone-prelude-control"
  , "compiler-wired-cons-control"
  , "compiler-standalone-wired-cons-control"
  , "compiler-wired-tuple-control"
  , "compiler-lexical-binding-control"
  , "compiler-parameter-binder-control"
  , "compiler-local-alias-control"
  , "compiler-alias-external-control"
  , "compiler-alias-imported-control"
  , "compiler-external-interface-control"
  , "compiler-interface-member-control"
  , "compiler-forward-owned-import-control"
  , "compiler-deferred-seed-import-control"
  , "compiler-unselected-unit-candidate-control"
  , "compiler-available-unit-control"
  , "compiler-residual-ownership-control"
  , "compiler-source-role-coverage"
  , "compiler-standalone-role-coverage"
  , "compiler-import-classification-control"
  , "compiler-inaccessible-internal-control"
  , "case:graph-qualified"
  , "bootstrap-call-sites"
  , "bootstrap-effect-sites"
  , "forward-owned-generated-proto"
  , "route-derived-coverage"
  , "route-derived-rules"
  , "route-standalone-coverage"
  , "route-instance-coverage"
  , "route-no-open-declaration"
  , "fork-declared-packages"
  , "sink-catalogue-recomputed"
  , "sink-use-anchors"
  , "sink-use-single-report"
  , "consumer-rows"
  , "consumer-text-read"
  , "consumer-coverage"
  , "fixture-routes"
  , "fixture-routes-unresolved"
  , "fixture-sinks"
  , "fixture-stages"
  , "fixture-forks"
  , "fixture-findings"
  ]

-- Independently authored from the complete graph fixtures. Keep duplicate
-- selections and loop expansions in their actual order: different ownership
-- and package catalogs still require separate completed product invocations.
type FixtureGraphCall = (Text, [FilePath], Either Text ())

expectedFixtureGraphCalls :: [(Text, [FilePath])]
expectedFixtureGraphCalls =
  [ ("sourceGraph", ["QuoteControl.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternal.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalMember.hs", "UseExternalWrongMember.hs"])
  , ("sourceGraphWithPackageCatalog",
      ["ExternalFacade.hs", "ExternalAbstract.hs", "ExternalHidden.hs", "ExternalNamed.hs",
       "ExternalRelay.hs", "ExternalCycleA.hs", "ExternalCycleB.hs", "UseExternalFacades.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalMember.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalMember.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalBroad.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalOpen.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalOpen.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseRegisteredOnly.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalHiding.hs"])
  , ("sourceGraphWithPackageCatalog", ["ImplicitPrelude.hs"])
  , ("sourceGraphWithPackageCatalog", ["NoPrelude.hs"])
  , ("sourceGraphWithPackageCatalog", ["ImplicitPrelude.hs"])
  , ("sourceGraphWithPackageCatalog", ["NoPrelude.hs"])
  , ("sourceGraphWithPackageCatalog", ["Calls.hs"])
  , ("sourceGraphWithPackageCatalog", ["NoPreludeDerive.hs"])
  , ("sourceGraphWithPackageCatalog", ["ExplicitPreludeDerive.hs"])
  , ("sourceGraphWithPackageCatalog", ["Derive.hs"])
  , ("sourceGraphWithPackageCatalog", ["NoPreludeStandaloneDerive.hs"])
  , ("sourceGraphWithPackageCatalog", ["ExplicitPreludeStandaloneDerive.hs"])
  , ("sourceGraphWithPackageCatalog", ["ImplicitPrelude.hs"])
  , ("sourceGraphWithPackageCatalog", ["NoPrelude.hs"])
  , ("sourceGraph", ["UseExternal.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternal.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternal.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternal.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseExternalOpen.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseFuture.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseFutureCall.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseFuture.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseJitFuture.hs"])
  , ("sourceGraphWithPackageCatalog", ["UseJitFuture.hs"])
  , ("sourceGraph", ["Duplicate.hs", "Use.hs"])
  , ("sourceGraph", ["ClassProvider.hs", "UseClass.hs", "UseClassHidden.hs", "UseClassInstance.hs", "UseClassInstanceHidden.hs"])
  , ("sourceGraph", ["RecordProvider.hs", "UseDot.hs"])
  , ("sourceGraph", ["Duplicate.hs", "other/Duplicate.hs", "Use.hs"])
  , ("sourceGraph", ["Duplicate.hs", "other/Duplicate.hs", "Use.hs"])
  , ("sourceGraph", ["Duplicate.hs", "Use.hs"])
  , ("sourceGraph", ["Duplicate.hs", "Use.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UsePackage.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseAlias.hs"])
  , ("sourceGraph", ["EffectProvider.hs", "UseEffect.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseSelective.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseConstructorOnly.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseHidden.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseValue.hs"])
  , ("sourceGraph", ["Duplicate.hs", "Reexport.hs", "UseReexport.hs"])
  , ("sourceGraph", ["Duplicate.hs", "AliasReexport.hs", "UseAliasReexport.hs"])
  , ("sourceGraph", ["Duplicate.hs", "QualifiedReexport.hs", "UseQualifiedReexport.hs"])
  , ("sourceGraph", ["Duplicate.hs", "ExplicitReexport.hs", "UseExplicitReexport.hs"])
  , ("sourceGraph", ["Duplicate.hs", "ExplicitDataReexport.hs", "UseExplicitDataReexport.hs"])
  , ("sourceGraph", ["Duplicate.hs", "HiddenReexport.hs", "UseHiddenReexport.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseHiding.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseHidingType.hs"])
  , ("sourceGraph", ["SpliceExpr.hs", "SpliceDecl.hs"])
  , ("sourceGraph", ["Foreign.hs"])
  , ("sourceGraph", ["Derive.hs"])
  , ("sourceGraph", ["Duplicate.hs", "UseFiltered.hs"])
  , ("sourceGraph", ["Duplicate.hs"])
  , ("sourceGraph", ["StandaloneLocal.hs"])
  , ("sourceGraph", ["StandaloneProvider.hs", "StandaloneUse.hs"])
  , ("sourceGraph", ["Duplicate.hs", "StandaloneFacade.hs", "StandaloneSelective.hs", "StandaloneReexport.hs", "StandaloneSelectiveUse.hs"])
  , ("sourceGraph", ["Mismatched.hs"])
  , ("sourceGraph", ["Calls.hs"])
  , ("sourceGraph", ["PlainData.hs"])
  , ("sourceGraphWithPackageCatalog", ["Routes.hs"])
  , ("sourceGraphWithPackageCatalog", ["RoutesUnresolved.hs"])
  , ("sourceGraph", ["Sinks.hs"])
  , ("sourceGraph", ["StageClean.hs"])
  , ("sourceGraph", ["StageImport.hs"])
  , ("sourceGraph", ["StageStandalone.hs"])
  , ("sourceGraph", ["StageOpaque.hs"])
  , ("sourceGraph", ["StageExpression.hs"])
  , ("sourceGraph", ["StageDeclaration.hs"])
  , ("sourceGraphWithPackageCatalog", ["ForkUser.hs"])
  , ("sourceGraphWithPackageCatalog", ["ForkUser.hs"])
  ]

readFixtureGraphCalls :: FilePath -> IO (Either Text [FixtureGraphCall])
readFixtureGraphCalls path = do
  input <- readReportText path
  pure $ do
    contents <- input
    case readMaybe (Text.unpack contents) of
      Just calls | Text.pack (show calls) == contents -> Right calls
      _ -> Left "FixtureGraphCallRecordMalformed"

-- Judge the public executable's actual planted inputs and reports, including
-- their semantic diagnostics. A copied nonce alone cannot satisfy a finding.
layoutBinaryChecks :: FilePath -> IO [(Text, Bool, Text)]
layoutBinaryChecks directory = concat <$> forM specifications (\(index, name, prefix, suffix, tag) -> do
  let root = directory </> "binary" </> index
  input <- optionalRead (root </> "input/paths.txt")
  output <- optionalRead (root </> "layout-report.tsv")
  let planted = [path | Just contents <- [input], path <- Text.lines contents,
          Just nonce <- [Text.stripPrefix prefix path >>= Text.stripSuffix suffix],
          Text.length nonce == 32 && Text.all lowerHex nonce]
      selected = case planted of [path] -> Just path; _ -> Nothing
  bytes <- maybe (pure Nothing) (optionalRead . ((root </> "tree") </>) . Text.unpack) selected
  expected <- independentLayoutPaths
  semantic <- case (input,output) of
    (Just supplied,Just contents) -> case parseStaticTextReport contents of
      Right parsed -> staticTextSemanticExpectation (root </> "tree") (map Text.unpack (Text.lines supplied)) parsed
      Left problem -> pure (Left problem)
    _ -> pure (Left "BinaryStaticTextInputUnavailable")
  let inputValid = case (input, selected) of
        (Just contents, Just path) -> sort (Text.lines contents) == sort (map Text.pack expected <> [path]) && bytes == Just "challenge\n"
        _ -> False
      findingValid = case (selected, output) of
        (Just path, Just contents) -> case parseStaticTextReport contents of
          Right parsed -> semantic == Right ()
            && filter ("finding\t" `Text.isPrefixOf`) (staticTextOldRows parsed) == ["finding\t" <> tag <> "\t" <> path]
          Left _ -> False
        _ -> False
      check role green = ("binary." <> name <> "." <> role, green, if green then "ok" else "input/report contract differs or required semantic boundary is unavailable")
  pure [check "input-contract" inputValid, check "finding" findingValid])
 where
  specifications = [("1", "python", "src/Challenge", ".py", "NonHaskellSource")
    ,("2", "dhall", "dhall/Challenge", ".dhall", "ForeignSourceOwed")
    ,("3", "pulumi", "pulumi/Pulumi", ".yaml", "TrackedPulumiProgram")]
  lowerHex character = ('0' <= character && character <= '9') || ('a' <= character && character <= 'f')
  optionalRead path = do
    attempted <- try (strictRead path) :: IO (Either IOException Text)
    case attempted of
      Right contents -> pure (Just contents)
      Left problem | isDoesNotExistError problem -> pure Nothing
      Left problem -> throwIO problem

layoutChecks :: FilePath -> Text -> IO [(Text, Bool, Text)]
layoutChecks directory primary = do
  let expectedPaths = map Text.unpack (Text.lines primary)
  packageChecks <- packageImportChecks directory
  testChecks <- testSourceChecks directory
  toolChecks <- toolSourceChecks directory
  pulumiChecks <- pulumiSourceChecks directory
  runtimeChecks <- runtimeIdentityChecks directory
  ignoreChecks <- ignoreContextChecks directory
  sourceChecks <- sourceGraphChecks directory
  bootstrapChecks <- bootstrapSourceChecks directory
  staticChecks <- staticTextChecks expectedSinkTable directory
  lexicalChecks <- lexicalCompatibilityChecks directory
  opaqueChecks <- surfaceChecks directory
  reportText <- readReportText (directory </> "layout.tsv")
  fullReportOutcomeText <- TextIO.readFile (directory </> "layout-report-result.data")
  fixtureGraphCalls <- readFixtureGraphCalls (directory </> "fixture-graph-calls.data")
  graphlessReports <- mapM (\(name, path) -> (,) name . (>>= parseStaticTextReport) <$> readReportText (directory </> path))
    [("report.nested-output", "nested/output/report.tsv"),
     ("report.default-exit", "default.tsv"), ("report.shebang-exit", "shebang.tsv")]
  cases <- parsePairs <$> TextIO.readFile (directory </> "cases.tsv")
  (grantCompilerValid, grantCompilerDetail) <- observeGrantTwin directory
  (methodImportValid, methodImportDetail) <- observeMethodImportTwin directory
  denialObservations <- mapM (observeDeniedConstructor directory) deniedConstructorExpectations
  scopeObservations <- mapM (observeScopeRejection directory) scopeRejectionExpectations
  topologySource <- TextIO.readFile "src/Amoebius/Pulsar/Topology.hs"
  producerSource <- TextIO.readFile "src/Amoebius/Pulsar/Producer.hs"
  topicSource <- TextIO.readFile "src/Amoebius/Pulsar/Internal/Types.hs"
  literalTopicSource <- TextIO.readFile "test/negative/pulsar_client/LiteralTopic.hs"
  rawPayloadSource <- TextIO.readFile "test/negative/pulsar_client/RawPayload.hs"
  familySource <- TextIO.readFile "src/Amoebius/Calculus/Workflow/Obligation.hs"
  foreignSource <- TextIO.readFile "test/fixture/chain_boundary/astcheck/negative_foreign.hs"
  liveGateSource <- TextIO.readFile "test/spec/integration/LiveDslDeployGate.hs"
  sourceTexts <- Map.fromList <$> mapM
    (\path -> (,) (Text.pack path) . TextEncoding.decodeUtf8With lenientDecode <$> ByteString.readFile path)
    [path | path <- expectedPaths, takeExtension path == ".hs"]
  fixtureRoutes <- Text.lines <$> TextIO.readFile (directory </> "fixture-routes.tsv")
  fixtureRoutesUnresolved <- Text.lines <$> TextIO.readFile (directory </> "fixture-routes-unresolved.tsv")
  fixtureSinks <- Text.lines <$> TextIO.readFile (directory </> "fixture-sinks.tsv")
  fixtureStages <- Text.lines <$> TextIO.readFile (directory </> "fixture-stages.tsv")
  fixtureForks <- Text.lines <$> TextIO.readFile (directory </> "fixture-forks.tsv")
  standaloneExports <- Text.lines <$> TextIO.readFile (directory </> "fixture-standalone-exports.tsv")
  fixtureFindings <- Text.lines <$> TextIO.readFile (directory </> "fixture-findings.tsv")
  quoteRows <- Text.lines <$> TextIO.readFile (directory </> "fixture-quotes.tsv")
  constructorReexportRows <- Text.lines <$> TextIO.readFile (directory </> "fixture-constructor-reexports.tsv")
  challengePaths <- parseChallenges <$> TextIO.readFile (directory </> "challenge-paths.tsv")
  challengeFindings <- mapM (readChallengeFinding directory) challengePaths
  fullSemantic <- either (pure . Left) (staticTextSemanticExpectation "." expectedPaths) (reportText >>= parseStaticTextReport)
  syntaxPaths <- map Text.unpack . Text.lines <$> strictRead (directory </> "challenge-syntax-paths.txt")
  syntaxSemantic <- case [parsed | ("syntax",_,_,_,parsed) <- challengeFindings] of
    [parsed] -> either (pure . Left) (staticTextSemanticExpectation (directory </> "challenge/syntax") syntaxPaths) parsed
    _ -> pure (Left "SyntaxChallengeInventoryMismatch")
  let parsedReport = reportText >>= parseStaticTextReport
      report = either (const []) staticTextOldRows parsedReport
      fullReportOutcome = readMaybe (Text.unpack fullReportOutcomeText) :: Maybe (Either Text (Either ExitCode ()))
      graphlessByCase = Map.fromList (graphlessReports
        <> [("report.no-graph", maybe (Left "MissingNestedReport") id (lookup "report.nested-output" graphlessReports))])
      masked = maskNonce (challengeNonce challengePaths)
      observedPaths = Map.fromList
        [(Text.unpack path, className) | line <- report, ["path", path, className] <- [Text.splitOn "\t" line]]
      findings = [line | line <- report, "finding\t" `Text.isPrefixOf` line]
      pathSet = Set.fromList expectedPaths
      reportSet = Map.keysSet observedPaths
      graphFiles = Set.fromList [Text.unpack path | line <- report,
        ["graph-file", path, _] <- [Text.splitOn "\t" line]]
      graphModules = Set.fromList [(path, name) | line <- report,
        ["graph-file", path, name] <- [Text.splitOn "\t" line]]
      graphImports = Set.fromList [(path, name) | line <- report,
        ["graph-import", path, name] <- [Text.splitOn "\t" line]]
      sourceReach seen [] = seen
      sourceReach seen (name : rest) = case
          [path | (path, moduleName) <- Set.toList graphModules, moduleName == name] of
        [path] | path `Set.notMember` seen -> sourceReach (Set.insert path seen)
          ([imported | (source, imported) <- Set.toList graphImports, source == path] <> rest)
        _ -> sourceReach seen rest
      graphModuleReexports = Set.fromList [(path, name) | line <- report,
        ["graph-module-reexport", path, name] <- [Text.splitOn "\t" line]]
      graphTopLevel = Set.fromList [(path, name) | line <- report,
        ["graph-top-level", path, name] <- [Text.splitOn "\t" line]]
      graphClassMethods = Set.fromList [(path, className, method) | line <- report,
        ["graph-class-method", path, className, method] <- [Text.splitOn "\t" line]]
      graphClassDeclarations = Set.fromList [(path, className) | line <- report,
        ["graph-class-declaration", path, className] <- [Text.splitOn "\t" line]]
      graphClassDefaults = Set.fromList [(path, className, method) | line <- report,
        ["graph-class-default", path, className, method] <- [Text.splitOn "\t" line]]
      graphClassMethodSignatures = Set.fromList
        [(path, className, method, signature) | line <- report,
         ["graph-class-method-signature", path, className, method, signature]
           <- [Text.splitOn "\t" line]]
      graphClassEffectTypeCandidates = Set.fromList
        [(path, className, method, effect, signature) | line <- report,
         ["graph-class-effect-type-candidate", path, className, method,
          effect, signature] <- [Text.splitOn "\t" line]]
      graphClassSuperclasses = Set.fromList
        [(path, className, superclass) | line <- report,
         ["graph-class-superclass", path, className, superclass]
           <- [Text.splitOn "\t" line]]
      graphInstanceDeclarations = Set.fromList [(path, headText, className) | line <- report,
        ["graph-instance-declaration", path, headText, className] <- [Text.splitOn "\t" line]]
      graphInstanceMethods = Set.fromList [(path, headText, className, method) | line <- report,
        ["graph-instance-method", path, headText, className, method] <- [Text.splitOn "\t" line]]
      graphInstanceSourceContracts = Set.fromList
        [(path, headText, className, method, provider, imported) | line <- report,
         ["graph-instance-method-source-contract", path, headText, className,
          method, provider, imported] <- [Text.splitOn "\t" line]]
      graphInstanceExternalContracts = Set.fromList
        [(path, headText, className, method, imported, package, unit, mode)
        | line <- report,
         ["graph-instance-method-external-contract", path, headText, className,
          method, imported, package, unit, mode] <- [Text.splitOn "\t" line]]
      uncontractedInstanceMethods = graphInstanceMethods `Set.difference`
        Set.fromList ([(path, headText, className, method)
          | (path, headText, className, method, _, _) <-
              Set.toList graphInstanceSourceContracts]
          <> [(path, headText, className, method)
             | (path, headText, className, method, _, _, _, _) <-
                 Set.toList graphInstanceExternalContracts])
      graphTypeSignatures = Set.fromList [(path, name, signature) | line <- report,
        ["graph-type-signature", path, name, signature] <- [Text.splitOn "\t" line]]
      graphEffectTypeCandidates = Set.fromList [(path, name, effect, signature) | line <- report,
        ["graph-effect-type-candidate", path, name, effect, signature] <- [Text.splitOn "\t" line]]
      graphEffectRoutes = Set.fromList [(component, path, owner, effect) | line <- report,
        ["graph-effect-route-candidate", component, path, owner, effect] <- [Text.splitOn "\t" line]]
      graphCallSites = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-call-site", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphLexicalCallSites = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-call-site-lexical", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphOpaqueCallSites = Set.fromList [(component, path, owner, site, target, reason) | line <- report,
        ["graph-call-site-opaque", component, path, owner, site, target, reason] <- [Text.splitOn "\t" line]]
      graphCompilerRejectedCalls = Set.fromList
        [(path, owner, site, target, code, rootSite, sourceDigest) | line <- report,
         ["graph-call-compiler-rejected", path, owner, site, target, code, rootSite, sourceDigest]
           <- [Text.splitOn "\t" line]]
      graphStandaloneLocalCalls = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-call-standalone-local-candidate", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphStandaloneLexicalCalls = Set.fromList [(path, owner, site, target, binderSite) | line <- report,
        ["graph-call-standalone-lexical-candidate", path, owner, site, target, binderSite] <- [Text.splitOn "\t" line]]
      graphStandaloneImportedCalls = Set.fromList [(path, owner, site, target, imported, provider, callee) | line <- report,
        ["graph-call-standalone-imported-candidate", path, owner, site, target,
         imported, provider, callee] <- [Text.splitOn "\t" line]]
      graphStandaloneDeniedSourceCalls = Set.fromList
        [(path, owner, site, target, imported, provider, callee, reason) | line <- report,
         ["graph-call-standalone-source-denied", path, owner, site, target,
          imported, provider, callee, reason] <- [Text.splitOn "\t" line]]
      graphClosedExportRefusals = Set.fromList
        [(path, owner, site, target, imported, provider, callee) | line <- report,
         ["graph-call-standalone-closed-export-refused", path, owner, site,
          target, imported, provider, callee] <- [Text.splitOn "\t" line]]
      rejectedCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- Set.toList graphCompilerRejectedCalls]
      closedExportRefusalKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- Set.toList graphClosedExportRefusals]
      expectedClosedExportRefusals = Set.fromList
        [(path, owner, site, target, imported, provider, target)
        | (path, owner, site, target) <- Set.toList graphCallSites
        , (wantedPath, wantedOwner, wantedTarget, imported, provider) <-
            [("test/negative/pulsar_client/LiteralTopic.hs", "illegal", "Topic",
              "Amoebius.Pulsar.Topology", "src/Amoebius/Pulsar/Topology.hs"),
             ("test/negative/pulsar_client/RawPayload.hs", "illegal", "produceRaw",
              "Amoebius.Pulsar.Producer", "src/Amoebius/Pulsar/Producer.hs")]
        , path == wantedPath, owner == wantedOwner, target == wantedTarget]
      closedExportSourceProof =
        "  ( Topic\n" `Text.isInfixOf` topologySource
          && not ("Topic (..)" `Text.isInfixOf` fst (Text.breakOn ") where" topologySource))
          && "newtype Topic = Topic" `Text.isInfixOf` topicSource
          && "import Amoebius.Pulsar.Internal.Types (Topic (..))" `Text.isInfixOf` topologySource
          && "import Amoebius.Pulsar.Topology (Topic)" `Text.isInfixOf` literalTopicSource
          && "illegal = Topic " `Text.isInfixOf` literalTopicSource
          && "  , produce\n" `Text.isInfixOf` producerSource
          && not ("produceRaw" `Text.isInfixOf` fst (Text.breakOn ") where" producerSource))
          && "import Amoebius.Pulsar.Producer (Producer, produceRaw)" `Text.isInfixOf` rawPayloadSource
          && "produceRaw producer bytes" `Text.isInfixOf` rawPayloadSource
      expectedCompilerRejectedCalls = Set.fromList
        [(path, owner, site, target, "1928", rootSite, sourceDigest)
        | (path, owner, rootTarget, rootSite, sourceDigest, True) <- denialObservations
        , (callPath, callOwner, site, target) <- Set.toList graphCallSites
        , callPath == path, callOwner == owner
        , siteContainedBy site rootSite
        -- These fixtures refuse the private head; Grant additionally encloses
        -- private Allowance heads. Public Location/Bytes/Slots arguments keep
        -- their ordinary resolved attribution despite the enclosing refusal.
        , target == rootTarget || (rootTarget == "Grant" && target == "Allowance")
        , Set.member (path, owner, rootSite, rootTarget) graphCallSites]
      expectedScopeRejectedCalls = Set.fromList
        [(path, owner, site, target, Text.pack (show code), rootSite, sourceDigest)
        | (path, owner, rootTarget, rootSite, code, sourceDigest, True) <- scopeObservations
        , (callPath, callOwner, site, target) <- Set.toList graphCallSites
        , callPath == path, callOwner == owner
        , siteContainedBy site rootSite
        , Set.member (path, owner, rootSite, rootTarget) graphCallSites]
      graphStandaloneExternalCalls = Set.fromList [(path, owner, site, target, imported, package, unit, callee) | line <- report,
        ["graph-call-standalone-external-candidate", path, owner, site, target,
         imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphStandaloneRegisteredOnlyCalls = Set.fromList
        [(path, owner, site, target, imported, package, unit, callee) | line <- report,
         ["graph-call-standalone-registered-only-candidate", path, owner, site, target,
          imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphStandaloneExternalMemberCalls = Set.fromList
        [(path, owner, site, target, imported, package, unit, parent, callee) | line <- report,
         ["graph-call-standalone-external-member-candidate", path, owner, site, target,
          imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphExternalCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, callee) | line <- report,
         ["graph-call-external-candidate", component, path, owner, site, target, imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphExternalMemberCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, parent, callee) | line <- report,
         ["graph-call-external-member-candidate", component, path, owner, site, target,
          imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphConstructorReexports = Set.fromList
        [(component, path, owner, site, target, facadeComponent, facadePath, imported, package, unit, parent, callee)
        | line <- report,
          ["graph-call-constructor-reexport-candidate", component, path, owner, site, target,
           facadeComponent, facadePath, imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphAvailableCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, callee) | line <- report,
         ["graph-call-available-unit-candidate", component, path, owner, site, target,
          imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphAvailableMemberCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, parent, callee) | line <- report,
         ["graph-call-available-member-candidate", component, path, owner, site, target,
          imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphDeferredSeedCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, role, callee) | line <- report,
         ["graph-call-deferred-seed-candidate", component, path, owner, site, target,
          imported, package, role, callee] <- [Text.splitOn "\t" line]]
      graphPreludeCallCandidates = Set.fromList
        [(component, path, owner, site, target, package, unit) | line <- report,
         ["graph-call-prelude-candidate", component, path, owner, site, target, package, unit] <- [Text.splitOn "\t" line]]
      graphAvailablePreludeCallCandidates = Set.fromList
        [(component, path, owner, site, target, package, unit) | line <- report,
         ["graph-call-prelude-available-candidate", component, path, owner, site,
          target, package, unit] <- [Text.splitOn "\t" line]]
      graphStandalonePreludeCallCandidates = Set.fromList
        [(path, owner, site, target, package, unit) | line <- report,
         ["graph-call-prelude-standalone-candidate", path, owner, site,
          target, package, unit] <- [Text.splitOn "\t" line]]
      graphWiredConsCandidates = Set.fromList
        [(component, path, owner, site, target, provider, unit) | line <- report,
         ["graph-call-wired-cons-candidate", component, path, owner, site, target, provider, unit] <- [Text.splitOn "\t" line]]
      graphStandaloneWiredConsCandidates = Set.fromList
        [(path, owner, site, target, provider, unit) | line <- report,
         ["graph-call-standalone-wired-cons-candidate", path, owner, site, target, provider, unit] <- [Text.splitOn "\t" line]]
      graphWiredTupleCandidates = Set.fromList
        [(component, path, owner, site, target, provider, unit) | line <- report,
         ["graph-call-wired-tuple-candidate", component, path, owner, site, target, provider, unit] <- [Text.splitOn "\t" line]]
      graphLexicalBindingCandidates = Set.fromList
        [(component, path, owner, site, target, binderSite) | line <- report,
         ["graph-call-lexical-binding-candidate", component, path, owner, site, target, binderSite] <- [Text.splitOn "\t" line]]
      graphLocalBinders = Set.fromList
        [(path, owner, name, binderSite) | line <- report,
         ["graph-local-binder", path, owner, name, binderSite] <- [Text.splitOn "\t" line]]
      graphParameterBinders = Set.fromList
        [(path, owner, name, binderSite) | line <- report,
         ["graph-parameter-binder", path, owner, name, binderSite] <- [Text.splitOn "\t" line]]
      graphLocalAliases = Set.fromList
        [(path, owner, name, binderSite, target, targetKind) | line <- report,
         ["graph-local-alias", path, owner, name, binderSite, target, targetKind] <- [Text.splitOn "\t" line]]
      graphLexicalAliasRoutes = Set.fromList
        [(component, path, owner, site, binder, binderSite, target, targetKind) | line <- report,
         ["graph-call-lexical-alias-route", component, path, owner, site, binder, binderSite, target, targetKind] <- [Text.splitOn "\t" line]]
      graphAliasInternalCalls = Set.fromList
        [((component, path, owner), (targetComponent, targetPath, callee)) | line <- report,
         ["graph-call-lexical-alias-local-candidate", component, path, owner, _, _, _, targetComponent, targetPath, callee] <- [Text.splitOn "\t" line]]
      graphAliasImportedCalls = Set.fromList
        [(component, path, owner, site, binder, binderSite, target, targetComponent, provider, callee, imported) | line <- report,
         ["graph-call-lexical-alias-imported-candidate", component, path, owner, site, binder, binderSite,
          target, targetComponent, provider, callee, imported] <- [Text.splitOn "\t" line]]
      graphAliasExternalCalls = Set.fromList
        [(component, path, owner, site, binder, binderSite, target, imported, package, unit, callee) | line <- report,
         ["graph-call-lexical-alias-external-candidate", component, path, owner, site, binder, binderSite,
          target, imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphReferenceSites = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-reference-site", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphControlEdges = Set.fromList [(path, owner, sourceSite, relation, targetSite) | line <- report,
        ["graph-control-edge", path, owner, sourceSite, relation, targetSite] <- [Text.splitOn "\t" line]]
      graphDynamicLoads = Set.fromList [(path, owner, site, kind, target) | line <- report,
        ["graph-dynamic-load", path, owner, site, kind, target] <- [Text.splitOn "\t" line]]
      graphRecordFields = Set.fromList [(path, owner, site, receiver, field) | line <- report,
        ["graph-record-field-site", path, owner, site, receiver, field] <- [Text.splitOn "\t" line]]
      graphRecordProjections = Set.fromList [(path, owner, site, field) | line <- report,
        ["graph-record-projection-site", path, owner, site, field] <- [Text.splitOn "\t" line]]
      graphRecordSelectorCandidates = Set.fromList
        [(component, path, owner, site, kind, field, targetComponent, provider, parent, imported) | line <- report,
         ["graph-record-selector-candidate", component, path, owner, site, kind, field,
          targetComponent, provider, parent, imported] <- [Text.splitOn "\t" line]]
      graphForeignSymbols = Set.fromList [(path, name, kind, target, site) | line <- report,
        ["graph-foreign-symbol", path, name, kind, target, site] <- [Text.splitOn "\t" line]]
      graphForeignSinks = Set.fromList [(path, name, kind, target, site) | line <- report,
        ["graph-effect-sink-foreign", path, name, kind, target, site] <- [Text.splitOn "\t" line]]
      graphTypeFamilies = Set.fromList [(path, name, site, role) | line <- report,
        ["graph-type-family", path, name, site, role] <- [Text.splitOn "\t" line]]
      expectedFamilyStarts = Map.fromList
        [(Text.takeWhile (/= ' ') rest, lineNumber)
        | (lineNumber, line) <- zip [1 :: Int ..] (Text.lines familySource)
        , Just rest <- [Text.stripPrefix "type family " line]]
      graphDerivedInstances = Set.fromList [(path, typeName, className, strategy) | line <- report,
        ["graph-derived-instance", path, typeName, className, strategy] <- [Text.splitOn "\t" line]]
      graphDerivedClassHeads = Set.fromList
        [(path, typeName, className, classHead, strategy) | line <- report,
         ["graph-derived-class-head", path, typeName, className,
          classHead, strategy] <- [Text.splitOn "\t" line]]
      graphDerivedClassMembers = Set.fromList
        [(path, typeName, className, classHead, strategy,
          imported, package, unit, member, mode) | line <- report,
         ["graph-derived-class-member-candidate", path, typeName, className,
          classHead, strategy, imported, package, unit, member, mode] <- [Text.splitOn "\t" line]]
      graphStandaloneDeriving = Set.fromList [(path, instanceType, strategy) | line <- report,
        ["graph-standalone-deriving", path, instanceType, strategy] <- [Text.splitOn "\t" line]]
      graphStandaloneDerivingHeads = Set.fromList
        [(path, instanceType, classHead, strategy) | line <- report,
         ["graph-standalone-deriving-class-head", path, instanceType, classHead, strategy]
           <- [Text.splitOn "\t" line]]
      graphStandaloneDerivingMembers = Set.fromList
        [(path, instanceType, classHead, strategy, imported, package, unit, member, mode)
        | line <- report,
         ["graph-standalone-deriving-member-candidate", path, instanceType, classHead,
          strategy, imported, package, unit, member, mode] <- [Text.splitOn "\t" line]]
      graphData = Set.fromList [(path, name) | line <- report,
        ["graph-data", path, name] <- [Text.splitOn "\t" line]]
      graphDerivedTypes = Set.fromList [path | line <- report,
        ["graph-derived-type", path, _] <- [Text.splitOn "\t" line]]
      graphConstructors = Set.fromList [(path, typeName, name) | line <- report,
        ["graph-constructor", path, typeName, name] <- [Text.splitOn "\t" line]]
      graphSelectors = Set.fromList [(path, typeName, name) | line <- report,
        ["graph-selector", path, typeName, name] <- [Text.splitOn "\t" line]]
      graphComponents = Set.fromList [(path, component) | line <- report,
        ["graph-component", path, component] <- [Text.splitOn "\t" line]]
      graphNoComponents = Set.fromList [path | line <- report,
        ["graph-no-component", path] <- [Text.splitOn "\t" line]]
      componentsByPath = Map.fromListWith (<>)
        [(path, [component]) | (path, component) <- Set.toList graphComponents]
      graphLinks = Set.fromList [(component, consumer, target, provider, name) | line <- report,
        ["graph-link", component, consumer, target, provider, name] <- [Text.splitOn "\t" line]]
      componentLinks = Map.fromListWith Set.union
        [(source, Set.singleton target)
        | (source, _, target, _, _) <- Set.toList graphLinks]
      graphLocalCallCandidates = Set.fromList [(component, consumer, owner, targetComponent, provider, callee) | line <- report,
        ["graph-call-local-candidate", component, consumer, owner, targetComponent, provider, callee] <- [Text.splitOn "\t" line]]
      graphCallCandidates = Set.fromList [(component, consumer, owner, targetComponent, provider, callee, imported) | line <- report,
        ["graph-call-candidate", component, consumer, owner, targetComponent, provider, callee, imported] <- [Text.splitOn "\t" line]]
      graphUniqueInternalCalls = Set.fromList
        [((component, consumer, owner), (targetComponent, provider, callee)) | line <- report,
         ["graph-call-unique-internal", component, consumer, owner, _, _, targetComponent, provider, callee, _] <- [Text.splitOn "\t" line]]
      graphUniqueInternalRows = Set.fromList
        [(component, consumer, owner, site, target, provider, callee) | line <- report,
         ["graph-call-unique-internal", component, consumer, owner, site, target,
          _, provider, callee, _] <- [Text.splitOn "\t" line]]
      graphClassCallDispatchCandidates = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instancePath, headText, className, method) | line <- report,
         ["graph-class-call-dispatch-candidate", component, path, owner, site,
          target, classProvider, instancePath, headText, className, method] <- [Text.splitOn "\t" line]]
      graphClassMethodBodyRoutes = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instanceComponent, instancePath, headText, className, method, methodOwner)
        | line <- report,
         ["graph-class-method-body-potential", component, path, owner, site,
          target, classProvider, instanceComponent, instancePath, headText,
          className, method, methodOwner] <- [Text.splitOn "\t" line]]
      expectedClassCallDispatchCandidates = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instancePath, headText, className, method)
        | (component, path, owner, site, target, classProvider, callee) <- Set.toList graphUniqueInternalRows
        , (instancePath, headText, className, method, provider, _) <- Set.toList graphInstanceSourceContracts
        , classProvider == provider, callee == method]
      expectedClassMethodBodyRoutes = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instanceComponent, instancePath, headText, className, method,
          "instance[" <> headText <> "]." <> method)
        | (component, path, owner, site, target, classProvider,
            instancePath, headText, className, method) <-
            Set.toList graphClassCallDispatchCandidates
        , (memberPath, instanceComponent) <- Set.toList graphComponents
        , memberPath == instancePath
        , instanceComponent `Set.member`
            componentClosureFromLinks componentLinks component]
      graphUniqueCallKeys = Set.fromList [(component, consumer, owner, site, target) | line <- report,
        ["graph-call-unique-internal", component, consumer, owner, site, target, _, _, _, _] <- [Text.splitOn "\t" line]]
      graphAmbiguousCallKeys = Set.fromList [(component, consumer, owner, site, target) | line <- report,
        ["graph-call-ambiguous-internal", component, consumer, owner, site, target, _] <- [Text.splitOn "\t" line]]
      componentCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (path, owner, site, target) <- Set.toList graphCallSites
        , component <- Map.findWithDefault [] path componentsByPath]
      standaloneCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target) <- Set.toList graphCallSites
        , path `Set.member` graphNoComponents]
      standaloneLocalCallKeys = Set.map (\(path, owner, site, target) ->
        ("-", path, owner, site, target)) graphStandaloneLocalCalls
      standaloneLexicalCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _) <- Set.toList graphStandaloneLexicalCalls]
      standaloneImportedCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- Set.toList graphStandaloneImportedCalls]
      standaloneExternalCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _, _) <- Set.toList graphStandaloneExternalCalls]
      standaloneExternalMemberCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _, _, _) <- Set.toList graphStandaloneExternalMemberCalls]
      externalCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- Set.toList graphExternalCallCandidates]
      externalMemberCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _) <- Set.toList graphExternalMemberCallCandidates]
      constructorReexportCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _, _, _) <- Set.toList graphConstructorReexports]
      availableCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- Set.toList graphAvailableCallCandidates]
      availableMemberCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _) <- Set.toList graphAvailableMemberCallCandidates]
      deferredSeedCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- Set.toList graphDeferredSeedCallCandidates]
      preludeCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphPreludeCallCandidates]
      availablePreludeCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphAvailablePreludeCallCandidates]
      standalonePreludeCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _) <- Set.toList graphStandalonePreludeCallCandidates]
      wiredConsCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphWiredConsCandidates]
      standaloneWiredConsCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _) <- Set.toList graphStandaloneWiredConsCandidates]
      wiredTupleCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphWiredTupleCandidates]
      lexicalBindingCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _) <- Set.toList graphLexicalBindingCandidates]
      unattributedCallKeys = (componentCallKeys `Set.union` standaloneCallKeys)
        `Set.difference` Set.unions
          [graphUniqueCallKeys, graphAmbiguousCallKeys,
           standaloneLocalCallKeys, standaloneLexicalCallKeys, standaloneImportedCallKeys,
           standaloneExternalCallKeys, standaloneExternalMemberCallKeys,
           externalCallKeys, externalMemberCallKeys, constructorReexportCallKeys,
           availableCallKeys, availableMemberCallKeys,
           deferredSeedCallKeys,
           preludeCallKeys, availablePreludeCallKeys, standalonePreludeCallKeys,
           wiredConsCallKeys, standaloneWiredConsCallKeys,
           wiredTupleCallKeys, lexicalBindingCallKeys, rejectedCallKeys,
           closedExportRefusalKeys]
      expectedOpaqueCallSites = Set.fromList
        [(component, path, owner, site, target,
           if component == "-" then "standalone"
           else if (path, owner, site, target) `Set.member` graphLexicalCallSites
             then "lexical" else "unattributed")
        | (component, path, owner, site, target) <- Set.toList unattributedCallKeys]
      graphUnresolved = Set.fromList [(component, consumer, name, reason) | line <- report,
        ["graph-import-unresolved", component, consumer, name, reason] <- [Text.splitOn "\t" line]]
      graphExternalImports = Set.fromList [(component, consumer, name, package, unit) | line <- report,
        ["graph-import-external", component, consumer, name, package, unit] <- [Text.splitOn "\t" line]]
      graphImplicitPreludeImports = Set.fromList [(component, consumer, package, unit) | line <- report,
        ["graph-import-implicit-prelude", component, consumer, package, unit] <- [Text.splitOn "\t" line]]
      graphAvailablePreludeImports = Set.fromList [(component, consumer, package, unit) | line <- report,
        ["graph-import-implicit-prelude-available", component, consumer, package, unit] <- [Text.splitOn "\t" line]]
      graphStandalonePreludeImports = Set.fromList [(path, package, unit) | line <- report,
        ["graph-import-implicit-prelude-standalone", path, package, unit] <- [Text.splitOn "\t" line]]
      graphPreludeInterfaces = Set.fromList [(unit, digest, count) | line <- report,
        ["graph-prelude-interface", unit, digest, count] <- [Text.splitOn "\t" line]]
      graphModuleInterfaceRows = [(unit, name, digest, count) | line <- report,
        ["graph-module-interface", unit, name, digest, count] <- [Text.splitOn "\t" line]]
      graphModuleInterfaceMembers = Set.fromList [(unit, name, parent, member) | line <- report,
        ["graph-module-interface-member", unit, name, parent, member] <- [Text.splitOn "\t" line]]
      graphModuleInterfaces = Set.fromList graphModuleInterfaceRows
      graphUnselectedCandidates = Set.fromList [(component, consumer, name, package, unit) | line <- report,
        ["graph-import-unselected-unit-candidate", component, consumer, name, package, unit] <- [Text.splitOn "\t" line]]
      graphAvailableUnits = Set.fromList [(component, consumer, name, package, unit) | line <- report,
        ["graph-import-available-unit", component, consumer, name, package, unit] <- [Text.splitOn "\t" line]]
      graphStandaloneAvailableUnits = Set.fromList [(path, name, package, unit) | line <- report,
        ["graph-import-standalone-available-unit", path, name, package, unit] <- [Text.splitOn "\t" line]]
      graphStandaloneForwardOwned = Set.fromList [(path, name, expected, role) | line <- report,
        ["graph-import-standalone-forward-owned", path, name, expected, role] <- [Text.splitOn "\t" line]]
      graphStandaloneUnresolved = Set.fromList [(path, name, reason) | line <- report,
        ["graph-import-standalone-unresolved", path, name, reason] <- [Text.splitOn "\t" line]]
      graphStandaloneRegisteredOnlyUnits = Set.fromList [(path, name, package, unit) | line <- report,
        ["graph-import-standalone-registered-only-unit", path, name, package, unit]
          <- [Text.splitOn "\t" line]]
      graphForwardOwned = Set.fromList [(component, consumer, name, path, role) | line <- report,
        ["graph-import-forward-owned", component, consumer, name, path, role] <- [Text.splitOn "\t" line]]
      graphDeferredSeed = Set.fromList [(component, consumer, name, package, owner) | line <- report,
        ["graph-import-deferred-seed", component, consumer, name, package, owner] <- [Text.splitOn "\t" line]]
      graphInaccessible = Set.fromList [(component, consumer, name, providerComponent, providerPath) | line <- report,
        ["graph-import-inaccessible-internal", component, consumer, name, providerComponent, providerPath] <- [Text.splitOn "\t" line]]
      graphUnscanned = Set.fromList [(path, owner, tag) | line <- report,
        ["graph-unscanned", path, owner, tag] <- [Text.splitOn "\t" line]]
      graphDeclarationGaps = Set.fromList [(path, tag) | line <- report,
        ["graph-unscanned-declaration", path, tag] <- [Text.splitOn "\t" line]]
      graphStages = [stage | line <- report,
        ["graph-stage", stage] <- [Text.splitOn "\t" line]]
      bootstrapCalls = Set.fromList [(owner, call) | line <- report,
        ["bootstrap-call", owner, call] <- [Text.splitOn "\t" line]]
      bootstrapEffects = Set.fromList [(owner, call) | line <- report,
        ["bootstrap-effect", owner, call] <- [Text.splitOn "\t" line]]
      packageOwed = Set.fromList [(source, role) | line <- report,
        ["package-owed", source, role] <- [Text.splitOn "\t" line]]
      packageBuildDependencies = Set.fromList [(component, package) | line <- report,
        ["package-build-dependency", component, package] <- [Text.splitOn "\t" line]]
      standaloneRows = [(path, role) | line <- report,
        ["package-standalone", path, role] <- [Text.splitOn "\t" line]]
      packageStandalone = Set.fromList standaloneRows
      componentImportKeys = Set.fromList
        [(component, path, name)
        | (path, component) <- Set.toList graphComponents
        , (importPath, name) <- Set.toList graphImports, importPath == path]
      internalImportKeys = Set.map (\(component, consumer, _, _, name) -> (component, consumer, name)) graphLinks
      externalImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphExternalImports
      availableImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphAvailableUnits
      forwardImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphForwardOwned
      deferredImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphDeferredSeed
      unresolvedImportKeys = Set.map (\(component, consumer, name, _) -> (component, consumer, name)) graphUnresolved
      expectedForwardOwned = Set.fromList
        [(component, consumer, name, Text.replace "." "/" name <> ".hs", "generated-proto")
        | (consumer, name) <- Set.toList graphImports
        , (path, component) <- Set.toList graphComponents, path == consumer
        , component == "library:pulsar-client"
        , name `elem` ["Proto.PulsarApi", "Proto.PulsarApi_Fields"]]
      -- A source with no component has its imports accounted apart: each is a source
      -- provider, an available registered unit, a recorded owed module, or an open
      -- unresolved import, and an unresolved import is never also accounted otherwise.
      ownedPaths = Set.map fst graphComponents
      standaloneImportKeys = Set.filter (\(path, _) -> Set.notMember path ownedPaths) graphImports
      standaloneModuleNames = Set.map snd graphModules
      standaloneSourceKeys = Set.filter (\(_, name) -> Set.member name standaloneModuleNames) standaloneImportKeys
      standaloneAvailableKeys = Set.map (\(path, name, _, _) -> (path, name)) graphStandaloneAvailableUnits
      standaloneOwedKeys = Set.map (\(path, name, _, _) -> (path, name)) graphStandaloneForwardOwned
      standaloneUnresolvedKeys = Set.map (\(path, name, _) -> (path, name)) graphStandaloneUnresolved
      standaloneAccounted = Set.unions [standaloneSourceKeys, standaloneAvailableKeys, standaloneOwedKeys]
      standalonePartition = standaloneImportKeys == Set.union standaloneAccounted standaloneUnresolvedKeys
        && Set.null (Set.intersection standaloneAccounted standaloneUnresolvedKeys)
        && Set.null (Set.intersection standaloneAvailableKeys standaloneOwedKeys)
      importPartition = componentImportKeys == Set.unions
          [internalImportKeys, externalImportKeys, availableImportKeys,
           forwardImportKeys, deferredImportKeys, unresolvedImportKeys]
        && all (\(left, right) -> Set.null (Set.intersection left right))
          [(internalImportKeys, externalImportKeys), (internalImportKeys, unresolvedImportKeys),
           (internalImportKeys, forwardImportKeys), (externalImportKeys, unresolvedImportKeys),
           (externalImportKeys, forwardImportKeys), (forwardImportKeys, unresolvedImportKeys),
           (availableImportKeys, internalImportKeys), (availableImportKeys, externalImportKeys),
           (availableImportKeys, forwardImportKeys), (availableImportKeys, unresolvedImportKeys),
           (deferredImportKeys, internalImportKeys), (deferredImportKeys, externalImportKeys),
           (deferredImportKeys, availableImportKeys), (deferredImportKeys, forwardImportKeys),
           (deferredImportKeys, unresolvedImportKeys)]
        && all (\(component, _, _, package, unit) ->
             Set.member (component, package) packageBuildDependencies && not (Text.null unit))
          (Set.toList graphExternalImports)
      effectSeeds = Set.fromList
        [(component, path, name) | (path, name, "IO", _) <- Set.toList graphEffectTypeCandidates,
         (componentPath, component) <- Set.toList graphComponents, componentPath == path]
        `Set.union` Set.fromList
        [(component, path, method)
        | (path, _, method, "IO", _) <- Set.toList graphClassEffectTypeCandidates
        , (componentPath, component) <- Set.toList graphComponents
        , componentPath == path]
      aliasImportedTargets = Map.fromListWith Set.union
        [((component, path, owner, site, binder, binderSite, target),
          Set.singleton (targetComponent, provider, callee))
        | (component, path, owner, site, binder, binderSite, target, targetComponent, provider, callee, _) <-
            Set.toList graphAliasImportedCalls]
      aliasUniqueImportedCalls = Set.fromList
        [((component, path, owner), destination)
        | ((component, path, owner, _, _, _, _), destinations) <- Map.toList aliasImportedTargets,
          [destination] <- [Set.toList destinations]]
      expectedEffectRoutes = Set.map (\(component, path, owner) -> (component, path, owner, "IO"))
        (effectRouteClosure (Set.unions [graphUniqueInternalCalls, graphAliasInternalCalls,
          aliasUniqueImportedCalls,
          Set.fromList [((component, path, owner),
            (instanceComponent, instancePath, methodOwner))
          | (component, path, owner, _, _, _, instanceComponent,
             instancePath, _, _, _, methodOwner) <-
              Set.toList graphClassMethodBodyRoutes]]) effectSeeds)
      -- Declaration routes, sinks, and consumers. Each binding reads the report or
      -- recomputes from raw source text through SourceScan; none uses a product module.
      rowsOf kind = [fields | line <- report, (key : fields) <- [Text.splitOn "\t" line], key == kind]
      graphDerivedRoutes = Set.fromList
        [(path, typeName, classText, classHead, strategy, declaredAs, generation, delegate, disposition, provider)
        | [path, typeName, classText, classHead, strategy, declaredAs, generation, delegate, disposition, provider]
            <- rowsOf "graph-derived-route"]
      graphDerivedRouteTargets = Set.fromList
        [(path, typeName, classText, targetPath, targetHead)
        | [path, typeName, classText, targetPath, targetHead] <- rowsOf "graph-derived-route-target"]
      graphStandaloneRoutes = Set.fromList
        [(path, instanceType, classHead, strategy, declaredAs, generation, delegate, disposition, provider)
        | [path, instanceType, classHead, strategy, declaredAs, generation, delegate, disposition, provider]
            <- rowsOf "graph-standalone-deriving-route"]
      graphStandaloneRouteTargets = Set.fromList
        [(path, instanceType, targetPath, targetHead)
        | [path, instanceType, targetPath, targetHead] <- rowsOf "graph-standalone-deriving-route-target"]
      graphInstanceRoutes = Set.fromList
        [(path, headText, className, kind, provider)
        | [path, headText, className, kind, provider] <- rowsOf "graph-instance-route"]
      graphSinkUses = Set.fromList
        [(path, owner, site, target, moduleName, name, kind, via)
        | [path, owner, site, target, moduleName, name, kind, via] <- rowsOf "graph-effect-sink-external"]
      graphConsumers = Set.fromList
        [(path, owner, site, target, moduleName, name, kind, position, literal, role, origin)
        | [path, owner, site, target, moduleName, name, kind, position, literal, role, origin] <- rowsOf "graph-file-consumer"]
      rowCountsByPath kind = Map.fromListWith (+) [(path, 1 :: Int) | (path : _) <- rowsOf kind]
      textCounts count = Map.filter (> 0) (Map.map (count . blankSource) sourceTexts)
      countDifferences left right = take 5
        [(path, Map.lookup path left, Map.lookup path right)
        | path <- Set.toList (Set.union (Map.keysSet left) (Map.keysSet right))
        , Map.lookup path left /= Map.lookup path right]
      isQualifiedName name = maybe False (isUpper . fst) (Text.uncons name) && Text.any (== '.') name
      baseName name = if isQualifiedName name then Text.takeWhileEnd (/= '.') name else name
      stockClassNames = ["Bounded", "Data", "Enum", "Eq", "Foldable", "Functor", "Generic", "Generic1",
                         "Ix", "Lift", "Ord", "Read", "Show", "Traversable"] :: [Text]
      expectedGeneration anyClassOn strategy declaredAs classHead
        | strategy == "stock" = "stock-generated"
        | strategy == "newtype" = "newtype-representation"
        | strategy == "anyclass" = "anyclass-default"
        | strategy == "via" = "via-representation"
        | declaredAs == ("newtype" :: Text) = expectedNewtypeGeneration anyClassOn (baseName classHead)
        | baseName classHead `elem` stockClassNames = "stock-generated"
        | otherwise = "anyclass-default" :: Text
      expectedNewtypeGeneration anyClassOn named
        | named `elem` ["Show", "Read", "Data", "Generic", "Generic1", "Lift", "Traversable"] = "stock-generated"
        | named `elem` ["Eq", "Ord", "Ix", "Bounded"] = "newtype-representation"
        | not anyClassOn = "newtype-representation"
        | named `elem` stockClassNames = "stock-generated"
        | otherwise = "anyclass-default" :: Text
      routeConsistent classHead generation delegate disposition provider targetCount = case generation of
        "stock-generated" -> delegate == "-" && disposition == "generated" && targetCount == (0 :: Int)
        "anyclass-default" -> delegate == baseName classHead && targetCount == 0
          && disposition == (if provider == "local" || "source:" `Text.isPrefixOf` provider
               then "source-class-default" else "external-class-default")
        _ | targetCount > 0 -> disposition == "source-instance" && delegate /= "-"
          | delegate == "-" -> disposition == "delegate-unresolved"
          | maybe False (\(first, _) -> isLower first || first == '_') (Text.uncons delegate) -> disposition == "context-instance"
          | provider == "local" || "source:" `Text.isPrefixOf` provider -> disposition == "delegate-unresolved"
          | otherwise -> disposition == "external-instance"
      externalUnitKeys = Set.fromList
        ([(consumer, name, package, unit) | (_, consumer, name, package, unit) <- Set.toList graphExternalImports]
          <> [(consumer, name, package, unit) | (_, consumer, name, package, unit) <- Set.toList graphAvailableUnits]
          <> Set.toList graphStandaloneAvailableUnits)
      preludeUnitKeys = Set.fromList
        ([(consumer, package, unit) | (_, consumer, package, unit) <- Set.toList graphImplicitPreludeImports]
          <> [(consumer, package, unit) | (_, consumer, package, unit) <- Set.toList graphAvailablePreludeImports]
          <> Set.toList graphStandalonePreludeImports)
      providerAnchored path className provider = case Text.splitOn ":" provider of
        ["local"] -> Set.member (path, baseName className) graphClassDeclarations
        ("source" : rest) ->
          let providerPath = Text.intercalate ":" rest
          in Set.member (providerPath, baseName className) graphClassDeclarations
               && any (\(filePath, moduleName) -> filePath == providerPath && Set.member (path, moduleName) graphImports)
                    (Set.toList graphModules)
        ["external", moduleName, package, unit] ->
          Set.member (path, moduleName) graphImports && Set.member (path, moduleName, package, unit) externalUnitKeys
        ["prelude", package, unit] -> Set.member (path, package, unit) preludeUnitKeys
        _ -> False
      derivedTargetMap = Map.fromListWith (<>)
        [((path, typeName, classText), [(targetPath, targetHead)])
        | (path, typeName, classText, targetPath, targetHead) <- Set.toList graphDerivedRouteTargets]
      standaloneTargetMap = Map.fromListWith (<>)
        [((path, instanceType), [(targetPath, targetHead)])
        | (path, instanceType, targetPath, targetHead) <- Set.toList graphStandaloneRouteTargets]
      targetValid classHead delegate (targetPath, targetHead) =
        any (\(path, headText, className) -> path == targetPath && headText == targetHead
               && baseName className == baseName classHead
               && delegate `elem` Text.words (Text.filter (`notElem` ("()" :: String)) targetHead))
          (Set.toList graphInstanceDeclarations)
          || any (\(path, typeName, _, targetClass, _, _, _, _, _, _) ->
               path == targetPath && typeName == delegate
                 && targetHead == "derived " <> typeName
                 && baseName targetClass == baseName classHead)
               (Set.toList graphDerivedRoutes)
      derivedRuleHolds (path, typeName, classText, classHead, strategy, declaredAs, generation, delegate, disposition, provider) =
          let anyClassOn = maybe False (languagePragmaEnabled "DeriveAnyClass") (Map.lookup path sourceTexts)
              targets = Map.findWithDefault [] (path, typeName, classText) derivedTargetMap
              textDeclared = declaredAsNewtype typeName (maybe "" blankSource (Map.lookup path sourceTexts))
          in generation == expectedGeneration anyClassOn strategy declaredAs classHead
               && maybe True (\isNewtype -> declaredAs == (if isNewtype then "newtype" else "data")) textDeclared
               && (generation /= "newtype-representation" || declaredAs /= "newtype"
                     || maybe True (== delegate) (Map.lookup path sourceTexts >>= newtypeRepresentation typeName . blankSource))
               && routeConsistent classHead generation delegate disposition provider (length targets)
               && all (targetValid classHead delegate) targets
               && providerAnchored path classHead provider
      derivedRuleFailures = [route | route <- Set.toList graphDerivedRoutes, not (derivedRuleHolds route)]
      derivedRulesHold = null derivedRuleFailures
      standaloneRulesHold = all (\(path, instanceType, classHead, strategy, declaredAs, generation, delegate, disposition, provider) ->
          let anyClassOn = maybe False (languagePragmaEnabled "DeriveAnyClass") (Map.lookup path sourceTexts)
              targets = Map.findWithDefault [] (path, instanceType) standaloneTargetMap
          in generation == expectedGeneration anyClassOn strategy declaredAs classHead
               && routeConsistent classHead generation delegate disposition provider (length targets)
               && all (targetValid classHead delegate) targets
               && providerAnchored path classHead provider)
        (Set.toList graphStandaloneRoutes)
      instanceMethodHeads = Set.fromList [(path, headText) | (path, headText, _, _) <- Set.toList graphInstanceMethods]
      instanceRulesHold = all (\(path, headText, className, kind, provider) ->
          kind == (if Set.member (path, headText) instanceMethodHeads then "methods" else "defaults")
            && providerAnchored path className provider)
        (Set.toList graphInstanceRoutes)
      sinkKindsOf moduleName name = [kind | (candidate, entryName, kind, _, _) <- expectedSinkTable
        , candidate == moduleName, entryName == name]
      sinkEntitiesOf moduleName name = [entity | (candidate, entryName, _, entity, _) <- expectedSinkTable
        , candidate == moduleName, entryName == name]
      sinkPairsReported = Set.fromList
        [(path, entity, kind) | (path, _, _, _, moduleName, name, kind, _) <- Set.toList graphSinkUses
        , entity <- sinkEntitiesOf moduleName name]
      sinkPairsExpected = Set.fromList
        [(path, entity, kind)
        | (path, text) <- Map.toList sourceTexts
        , (moduleName, name, kind) <- Set.toList (sinkHits [(m, n, k) | (m, n, k, _, _) <- expectedSinkTable] text (blankSource text))
        , entity <- sinkEntitiesOf moduleName name]
      sinkSlice path site = case (parseSite site, Map.lookup path sourceTexts) of
        (Just bounds, Just text) -> Just (sliceSpan (Text.lines text) bounds)
        _ -> Nothing
      sinkAnchored (path, _, site, target, moduleName, name, kind, via) =
        case sinkSlice path site of
          Just slice -> (target `Text.isPrefixOf` slice || ("`" <> target <> "`") `Text.isInfixOf` slice)
            && baseName target == name && kind `elem` sinkKindsOf moduleName name
            && via == (if slice == target then "reference" else "call")
          Nothing -> False
      sinkUseKeys = Set.fromList
        [(path, owner, site, target, moduleName, name, kind) | (path, owner, site, target, moduleName, name, kind, _) <- Set.toList graphSinkUses]
      consumersByUse = Map.fromListWith Set.union
        [((path, owner, site, target, moduleName, name, kind), Set.singleton (position, literal, role, origin))
        | (path, owner, site, target, moduleName, name, kind, position, literal, role, origin) <- Set.toList graphConsumers]
      -- The consumer rows one use must have, recomputed from the raw text of its own
      -- span and the oracle's own argument positions; Nothing where the text is not
      -- a form the oracle reads.
      expectedConsumersOf (path, _, site, _, moduleName, name, kind, _) = do
        slice <- sinkSlice path site
        applied <- useArguments slice
        let declared = concat [positions | (candidate, entryName, entryKind, _, positions) <- expectedSinkTable
                              , candidate == moduleName, entryName == name, entryKind == kind]
        pure (Set.fromList (concat
          [ case [run | (at, runs) <- applied, at == position, run <- runs, representable (snd run)] of
              [] -> [(Text.pack (show position), "-", "-", "dynamic")]
              runs -> [ (Text.pack (show position), literal, role, origin)
                      | (rooted, literal) <- runs, let (role, origin) = expectedConsumerClass argumentRole rooted literal ]
          | (position, argumentRole) <- declared ]))
      representable literal = not (Text.null literal) && Text.length literal <= 200 && not (Text.any isControl literal)
      consumerVerdicts =
        [ (use, expectedConsumersOf use, Map.findWithDefault Set.empty (useKey use) consumersByUse)
        | use <- Set.toList graphSinkUses ]
      useKey (path, owner, site, target, moduleName, name, kind, _) = (path, owner, site, target, moduleName, name, kind)
      consumerMismatches = [use | (use, Just expected, actual) <- consumerVerdicts, expected /= actual]
      consumerUnread = length [() | (_, Nothing, _) <- consumerVerdicts]
      consumerRowKnown (path, owner, site, target, moduleName, name, kind, position, literal, role, origin) =
        Set.member (path, owner, site, target, moduleName, name, kind) sinkUseKeys
          && (position, literal, role, origin) `Set.member` Map.findWithDefault Set.empty
               (path, owner, site, target, moduleName, name, kind) consumersByUse
      sinkSiteGroups = Map.fromListWith (+)
        [((path, owner, target, entity, fmap fst (parseSite site)), 1 :: Int)
        | (path, owner, site, target, moduleName, name, _, "call") <- Set.toList graphSinkUses
        , entity <- sinkEntitiesOf moduleName name]
      routeChecks =
        [ ("route-derived-coverage",
             Set.map (\(path, typeName, classText, _, strategy, _, _, _, _, _) -> (path, typeName, classText, strategy)) graphDerivedRoutes
               == graphDerivedInstances
               && rowCountsByPath "graph-derived-route" == rowCountsByPath "graph-derived-instance"
               && rowCountsByPath "graph-derived-instance" == textCounts derivedClassCount,
           Text.pack (show (Set.size graphDerivedRoutes, Map.size (textCounts derivedClassCount),
             countDifferences (rowCountsByPath "graph-derived-instance") (textCounts derivedClassCount))))
        , ("route-derived-rules", derivedRulesHold, Text.pack (show (Set.size graphDerivedRoutes, take 3 derivedRuleFailures)))
        , ("route-standalone-coverage",
             Set.map (\(path, instanceType, _, strategy, _, _, _, _, _) -> (path, instanceType, strategy)) graphStandaloneRoutes
               == graphStandaloneDeriving
               && rowCountsByPath "graph-standalone-deriving-route" == rowCountsByPath "graph-standalone-deriving"
               && rowCountsByPath "graph-standalone-deriving" == textCounts standaloneDerivingCount
               && standaloneRulesHold,
           Text.pack (show (Set.size graphStandaloneRoutes)))
        , ("route-instance-coverage",
             Set.map (\(path, headText, className, _, _) -> (path, headText, className)) graphInstanceRoutes
               == graphInstanceDeclarations
               && rowCountsByPath "graph-instance-route" == rowCountsByPath "graph-instance-declaration"
               && rowCountsByPath "graph-instance-declaration" == textCounts instanceDeclarationCount
               && instanceRulesHold,
           Text.pack (show (Set.size graphInstanceRoutes)))
        , ("route-no-open-declaration",
             Set.null graphDeclarationGaps && Set.null graphStandaloneRegisteredOnlyUnits
               && Set.null graphStandaloneRegisteredOnlyCalls,
           Text.pack (show (Set.size graphDeclarationGaps, Set.size graphStandaloneRegisteredOnlyUnits)))
        , ("fork-declared-packages",
             let forkPackageOf moduleName = lookup moduleName
                   [("Control.Monad.Managed", "managed"), ("Control.Concurrent.Chan.Unagi", "unagi-chan"),
                    ("Control.Logging", "logging")]
                 expected = Set.fromList
                   [(Text.pack path, importModule statement, package)
                   | path <- expectedForkPaths
                   , Just text <- [Map.lookup (Text.pack path) sourceTexts]
                   , statement <- importStatements (blankSource text)
                   , Just package <- [forkPackageOf (importModule statement)]]
                 observed = Set.fromList
                   [(path, name, package)
                   | (path, name, package, _) <- Set.toList graphStandaloneAvailableUnits
                   , Just package == forkPackageOf name]
             in not (Set.null expected) && expected == observed,
           Text.pack (show (Set.size graphStandaloneAvailableUnits)))
        , ("sink-catalogue-recomputed", sinkPairsReported == sinkPairsExpected,
           Text.pack (show (Set.size sinkPairsReported, Set.size sinkPairsExpected,
             take 6 (Set.toList (sinkPairsReported `Set.difference` sinkPairsExpected)),
             take 6 (Set.toList (sinkPairsExpected `Set.difference` sinkPairsReported)))))
        , ("sink-use-anchors", all sinkAnchored (Set.toList graphSinkUses),
           Text.pack (show (Set.size graphSinkUses, take 3 [use | use <- Set.toList graphSinkUses, not (sinkAnchored use)])))
        , ("sink-use-single-report", all (== 1) (Map.elems sinkSiteGroups), Text.pack (show (Map.size sinkSiteGroups)))
        , ("consumer-rows", null consumerMismatches && all consumerRowKnown (Set.toList graphConsumers),
           Text.pack (show (Set.size graphConsumers, length consumerVerdicts, take 3 consumerMismatches)))
        , ("consumer-text-read", consumerUnread * 10 <= length consumerVerdicts,
           Text.pack (show (consumerUnread, length consumerVerdicts)))
        , ("consumer-coverage",
             all (\(path, owner, site, target, moduleName, name, kind, _) ->
                    null (concat [positions | (candidate, entryName, entryKind, _, positions) <- expectedSinkTable
                                 , candidate == moduleName, entryName == name, entryKind == kind])
                      || Map.member (path, owner, site, target, moduleName, name, kind) consumersByUse)
               (Set.toList graphSinkUses),
           Text.pack (show (Map.size consumersByUse)))
        , ("fixture-routes", Set.fromList fixtureRoutes == expectedRoutesFixture && length fixtureRoutes == Set.size expectedRoutesFixture,
           Text.pack (show (length fixtureRoutes)))
        , ("fixture-routes-unresolved",
             Set.fromList fixtureRoutesUnresolved == expectedUnresolvedRoutesFixture
               && length fixtureRoutesUnresolved == Set.size expectedUnresolvedRoutesFixture,
           Text.pack (show (length fixtureRoutesUnresolved)))
        , ("fixture-sinks", Set.fromList fixtureSinks == expectedSinksFixture && length fixtureSinks == Set.size expectedSinksFixture,
           Text.pack (show (length fixtureSinks)))
        , ("fixture-stages", Set.fromList fixtureStages == expectedStagesFixture && length fixtureStages == Set.size expectedStagesFixture,
           Text.pack (show (length fixtureStages)))
        , ("fixture-forks", Set.fromList fixtureForks == expectedForksFixture && length fixtureForks == Set.size expectedForksFixture,
           Text.pack (show (length fixtureForks)))
        , ("fixture-findings", fixtureFindings == replicate 9 "0", Text.intercalate "," fixtureFindings)
        ]
      checks =
        [ ("path-set", pathSet == reportSet, Text.pack (show (Set.size reportSet)))
        , ("finding-set", null findings && fullReportOutcome == Just (Right (Right ()))
             && fullSemantic == Right (),
           Text.pack (show (findings, fullReportOutcome)) <> ";" <> staticTextDiagnostic parsedReport)
        , ("fixture-graph-call-inventory",
             fmap (map (\(kind, selected, _) -> (kind, selected))) fixtureGraphCalls == Right expectedFixtureGraphCalls,
           Text.pack (show (fmap (map (\(kind, selected, _) -> (kind, selected))) fixtureGraphCalls)))
        , ("fixture-graph-call-outcomes",
             fixtureGraphCalls == Right [(kind, selected, Right ()) | (kind, selected) <- expectedFixtureGraphCalls],
           Text.pack (show fixtureGraphCalls))
        , ("case:six-metadata-files", length (filter (`elem` metadata) expectedPaths) == 6, Text.pack (show (filter (`elem` metadata) expectedPaths)))
        , ("challenge-set", Set.fromList [(name, tag) | (name, _, tag) <- challengePaths] == Set.fromList expectedChallengeTags,
           Text.pack (show [(name, masked path, tag) | (name, path, tag) <- challengePaths]))
        , ("compiler-parsed-source-set", graphFiles == Set.filter ((== ".hs") . takeExtension) pathSet,
           Text.pack (show (Set.size graphFiles)))
        , ("compiler-import-control", Set.member ("src/Amoebius/Layout/SourceGraph.hs", "GHC.Parser") graphImports,
           Text.pack (show (Set.size graphImports)))
        , ("compiler-module-reexport-control", graphModuleReexports == Set.fromList
               [("src/Amoebius/Dsl/AstCheck.hs", "Admission"),
              ("src/Amoebius/Dsl/SanctionedApi.hs", "Api"),
              ("src/Amoebius/Execution/JobTerminalLive.hs", "Amoebius.Store.ControlPlaneState"),
              ("src/Amoebius/Substrate/Apple.hs", "Amoebius.HostWorker.Capacity"),
              ("src/Amoebius/Substrate/Apple.hs", "Amoebius.Substrate.Lima"),
              ("src/extension-link/Amoebius/Extension/Linked.hs", "Graph"),
              ("src/manifest-render/Amoebius/Manifest/K8sObject.hs", "Amoebius.Manifest.Types"),
              ("src/vendor/Pulsar.hs", "Pulsar.Types")],
           Text.pack (show graphModuleReexports))
        , ("compiler-declaration-control", Set.member ("src/Amoebius/Layout/Report.hs", "runLayoutReport") graphTopLevel,
           Text.pack (show (Set.size graphTopLevel)))
        , ("compiler-class-method-control",
             Set.member ("src/Amoebius/Kernel/ContentAddress.hs", "ContentAddress", "contentAddress") graphClassMethods
               && all (\(path, className, method) ->
                    Set.member (Text.unpack path) graphFiles
                      && not (Text.null className) && not (Text.null method))
                 (Set.toList graphClassMethods),
           Text.pack (show (Set.size graphClassMethods)))
        , ("compiler-class-declaration-control",
             graphClassDeclarations == Set.fromList
               [("src/Amoebius/Calculus/Artifact/Recipe.hs", "Declaration"),
                ("src/Amoebius/Kernel/ContentAddress.hs", "ContentAddress"),
                ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination"),
                ("test/layout/ClassEffectRoute.hs", "RouteAction"),
                ("test/layout/ClassEffectRoute.hs", "DirectIoRoute")]
               && graphClassMethodSignatures == Set.fromList
                 [("src/Amoebius/Calculus/Artifact/Recipe.hs", "Declaration",
                   "declarationBytes", "d -> ByteString"),
                  ("src/Amoebius/Kernel/ContentAddress.hs", "ContentAddress",
                   "contentAddress", "a -> BlobSha"),
                  ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination",
                   "registerConnection", "UiRealtimeEnvelope -> operation ()"),
                  ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination",
                   "publishRoutingHint", "UiRealtimeEnvelope -> operation ()"),
                  ("test/layout/ClassEffectRoute.hs", "RouteAction",
                   "runRoute", "a -> Int"),
                  ("test/layout/ClassEffectRoute.hs", "DirectIoRoute",
                   "runDirectIo", "a -> IO Int")]
               && Set.map (\(path, className, method, _) ->
                    (path, className, method)) graphClassMethodSignatures
                    == graphClassMethods
               && graphClassSuperclasses == Set.singleton
                    ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination",
                     "Monad operation")
               && Set.null graphClassDefaults
               && not (any ((== "ClassDispatch") . snd)
                    (Set.toList graphDeclarationGaps)),
           Text.pack (show (Set.size graphClassDeclarations,
             Set.size graphClassMethodSignatures,
             Set.size graphClassSuperclasses,
             Set.size graphClassDefaults)))
        , ("compiler-class-effect-type-seed-control",
             graphClassEffectTypeCandidates == Set.singleton
               ("test/layout/ClassEffectRoute.hs", "DirectIoRoute",
                "runDirectIo", "IO", "a -> IO Int")
               && Set.member ("test:layout-suite", "test/layout/ClassEffectRoute.hs",
                    "runDirectIo") effectSeeds,
           Text.pack (show (Set.size graphClassEffectTypeCandidates)))
        , ("compiler-instance-declaration-control",
             Set.member ("src/Amoebius/Calculus/Artifact/Region.hs",
                    "Functor (Region s)", "Functor", "fmap") graphInstanceMethods
               && all (\(path, headText, className, method) ->
                    Set.member (path, headText, className) graphInstanceDeclarations
                      && not (Text.null method)) (Set.toList graphInstanceMethods),
           Text.pack (show (Set.size graphInstanceDeclarations,
             Set.size graphInstanceMethods)))
        , ("compiler-instance-source-contract-control",
             Set.member ("src/Amoebius/Kernel/ContentAddress.hs",
               "ContentAddress ByteString", "ContentAddress", "contentAddress",
               "src/Amoebius/Kernel/ContentAddress.hs", "-") graphInstanceSourceContracts
               && Set.member ("test/spec/calculus/ArtifactCorpus.hs",
                 "Declaration Declared", "Declaration", "declarationBytes",
                 "src/Amoebius/Calculus/Artifact/Recipe.hs",
                 "Amoebius.Calculus.Artifact.Recipe") graphInstanceSourceContracts
               && all (\(path, headText, className, method, provider, imported) ->
                    Set.member (path, headText, className, method) graphInstanceMethods
                      && Set.member (provider, className, method) graphClassMethods
                      && (if imported == "-" then provider == path
                          else Set.member (path, imported) graphImports
                            && Set.member (provider, imported) graphModules
                            && (path `Set.member` graphNoComponents
                              || any (\(_, consumer, _, targetPath, name) ->
                                  consumer == path && targetPath == provider
                                    && name == imported) (Set.toList graphLinks))))
                  (Set.toList graphInstanceSourceContracts),
           Text.pack (show (Set.size graphInstanceSourceContracts)))
        , ("compiler-instance-external-contract-control",
             Set.size graphInstanceExternalContracts == 297
               && Set.fromList
                    [(headText, className, method, imported, package, mode)
                    | (path, headText, className, method, imported, package,
                       unit, mode) <- Set.toList graphInstanceExternalContracts
                    , path == "src/validation-kernel/Amoebius/Validation/Authority/Core.hs"
                    , not (Text.null unit)]
                    == Set.fromList
                      [("Show " <> name, "Show", "show", "Prelude", "base", "implicit")
                      | name <- ["RetainedPlanBytes", "NativeStopped", "NativeJournalUnclosed"]]
               && Set.fromList
                    [(headText, className, method, imported, package, mode)
                    | (path, headText, className, method, imported, package,
                       unit, mode) <- Set.toList graphInstanceExternalContracts
                    , path == "src/vocabulary/Amoebius/Vocabulary.hs"
                    , not (Text.null unit)]
                    == Set.fromList
                      [("NFData Detected", "NFData", "rnf", "Control.DeepSeq",
                        "deepseq", "explicit")
                      , ("NFData SubstrateProfile", "NFData", "rnf", "Control.DeepSeq",
                        "deepseq", "explicit")]
               && Set.null uncontractedInstanceMethods
               && methodImportValid
               && "import Data.Aeson (FromJSON (parseJSON),"
                    `Text.isInfixOf` liveGateSource
               && any (\(path, headText, className, method, imported, package,
                          unit, mode) ->
                    path == "app/amoebius/Amoebius/Entry/ControlPlane.hs"
                      && headText == "FromJSON AdminRequest"
                      && className == "FromJSON" && method == "parseJSON"
                      && imported == "Data.Aeson" && package == "aeson"
                      && not (Text.null unit) && mode == "explicit")
                    (Set.toList graphInstanceExternalContracts)
               && any (\(path, headText, className, method, imported, package, _, mode) ->
                    path == "src/Amoebius/Calculus/Artifact/Region.hs"
                      && headText == "Functor (Region s)" && className == "Functor"
                      && method == "fmap" && imported == "Prelude"
                      && package == "base" && mode == "implicit")
                    (Set.toList graphInstanceExternalContracts)
               && any (\(path, headText, className, method, imported, package, _, mode) ->
                    path == "src/vendor/Pulsar/Types.hs"
                      && headText == "IsString Tenant" && className == "IsString"
                      && method == "fromString" && imported == "Data.String"
                      && package == "base" && mode == "explicit")
                    (Set.toList graphInstanceExternalContracts)
               && any (\(path, headText, className, method, imported, package, _, mode) ->
                    path == "test/spec/capability/BindProps.hs"
                      && headText == "Arbitrary GeneratedNeed"
                      && className == "Arbitrary" && method == "arbitrary"
                      && imported == "Test.QuickCheck" && package == "QuickCheck"
                      && mode == "explicit") (Set.toList graphInstanceExternalContracts)
               && all (\(path, headText, className, method, imported, package,
                           unit, mode) ->
                    Set.member (path, headText, className, method) graphInstanceMethods
                      && Set.member (unit, imported,
                           Text.takeWhileEnd (/= '.') className, method)
                         graphModuleInterfaceMembers
                      && (case mode of
                        "explicit" -> Set.member (path, imported) graphImports
                          && (any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphExternalImports)
                            || Set.member (path, imported, package, unit)
                              graphStandaloneAvailableUnits)
                        "implicit" -> imported == "Prelude"
                          && (any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphImplicitPreludeImports)
                            || Set.member (path, package, unit)
                              graphStandalonePreludeImports)
                        _ -> False)) (Set.toList graphInstanceExternalContracts),
           Text.pack (show (Set.size graphInstanceExternalContracts,
             Set.toAscList uncontractedInstanceMethods, methodImportDetail)))
        , ("compiler-class-call-dispatch-control",
             graphClassCallDispatchCandidates == expectedClassCallDispatchCandidates
               && not (Set.null graphClassCallDispatchCandidates)
               && any (\(component, path, owner, _, target, classProvider,
                         instancePath, headText, className, method) ->
                    component == "library:dsl-core"
                      && path == "src/Amoebius/Kernel/Determinism.hs"
                      && owner == "seededStage" && target == "contentAddress"
                      && classProvider == "src/Amoebius/Kernel/ContentAddress.hs"
                      && instancePath == classProvider
                      && headText == "ContentAddress ByteString"
                      && className == "ContentAddress" && method == "contentAddress")
                  (Set.toList graphClassCallDispatchCandidates),
           Text.pack (show (Set.size graphClassCallDispatchCandidates)))
        , ("compiler-class-method-body-route-control",
             graphClassMethodBodyRoutes == expectedClassMethodBodyRoutes
               && Set.size graphClassMethodBodyRoutes == 6
               && Set.member ("test:layout-suite", "test/layout/ClassEffectRoute.hs",
                    "caller", "17:16-17:30", "runRoute",
                    "test/layout/ClassEffectRoute.hs", "test:layout-suite",
                    "test/layout/ClassEffectRoute.hs", "RouteAction Token",
                    "RouteAction", "runRoute",
                    "instance[RouteAction Token].runRoute") graphClassMethodBodyRoutes
               && not (any (\(_, _, _, _, _, _, _, instancePath, _, _, _, _) ->
                    "test/negative/" `Text.isPrefixOf` instancePath)
                    (Set.toList graphClassMethodBodyRoutes)),
           Text.pack (show (Set.size graphClassMethodBodyRoutes,
             Set.size expectedClassMethodBodyRoutes)))
        , ("compiler-type-signature-control", Set.member
             ("src/Amoebius/Layout/Report.hs", "runLayoutReport", "[String] -> IO ()") graphTypeSignatures,
           Text.pack (show (Set.size graphTypeSignatures)))
        , ("compiler-effect-type-seed-control", Set.member
             ("src/Amoebius/Layout/Report.hs", "runLayoutReport", "IO", "[String] -> IO ()") graphEffectTypeCandidates,
           Text.pack (show (Set.size graphEffectTypeCandidates)))
        , ("compiler-effect-route-closure-control", graphEffectRoutes == expectedEffectRoutes
             && Set.member ("library:layout", "src/Amoebius/Layout/Report.hs",
                  "runLayoutReport", "IO") graphEffectRoutes
             && all (`Set.member` graphEffectRoutes)
                  [("test:layout-suite", "test/layout/ClassEffectRoute.hs", owner, "IO")
                  | owner <- ["effectSeed", "instance[RouteAction Token].runRoute",
                      "caller", "runDirectIo", "directCaller"]],
           Text.pack (show (Set.size graphEffectRoutes, Set.size expectedEffectRoutes)))
        , ("compiler-call-site-control", any
             (\(path, owner, site, target) -> path == "src/Amoebius/Layout/Report.hs"
               && owner == "runLayoutReport" && target == "parseOptions" && site /= "unlocated")
             (Set.toList graphCallSites)
             && all (\(_, _, site, _) -> site /= "unlocated") (Set.toList graphCallSites),
           Text.pack (show (Set.size graphCallSites)))
        , ("compiler-call-site-coverage-control",
             graphOpaqueCallSites == expectedOpaqueCallSites
               && graphLexicalCallSites `Set.isSubsetOf` graphCallSites,
           Text.pack (show (Set.size graphOpaqueCallSites, Set.size expectedOpaqueCallSites)))
        , ("compiler-reference-site-control", any
             (\(path, owner, site, target) -> path == "src/Amoebius/Layout/Report.hs"
               && owner == "runLayoutReport" && target == "parseOptions" && site /= "unlocated")
             (Set.toList graphReferenceSites)
             && all (\(_, _, site, _) -> site /= "unlocated") (Set.toList graphReferenceSites),
           Text.pack (show (Set.size graphReferenceSites)))
        , ("compiler-control-edge-control", any
             (\(path, owner, sourceSite, relation, targetSite) ->
               path == "src/Amoebius/Layout/Report.hs" && owner == "acquirePaths"
                 && relation == "case-scrutinee" && sourceSite /= "unlocated"
                 && targetSite /= "unlocated") (Set.toList graphControlEdges)
             && all (\(_, _, sourceSite, _, targetSite) ->
               sourceSite /= "unlocated" && targetSite /= "unlocated") (Set.toList graphControlEdges),
           Text.pack (show (Set.size graphControlEdges)))
        , ("compiler-dynamic-load-control", graphDynamicLoads == Set.fromList
             [("test/fixture/chain_boundary/astcheck/negative_template_haskell.hs",
               "value", "2:9-2:25", "template-haskell-splice", "generateValue"),
              ("src/extension-link/Amoebius/Extension/Linked.hs", "jitBuild", "27:12-27:55", "template-haskell-splice", "admitContribution"),
              ("src/extension-link/Amoebius/Extension/Linked.hs", "coordination", "28:16-28:63", "template-haskell-splice", "admitContribution"),
              ("src/extension-link/Amoebius/Extension/Linked.hs", "infernix", "29:12-29:55", "template-haskell-splice", "admitContribution"),
              ("src/extension-link/Amoebius/Extension/Linked.hs", "jitml", "30:9-30:49", "template-haskell-splice", "admitContribution"),
              ("src/extension-admission/Amoebius/Extension/LinkSeal.hs", "admitContribution", "36:76-36:91", "template-haskell-splice", "pure"),
              ("src/extension-admission/Amoebius/Extension/LinkSeal.hs", "admitContribution", "40:30-40:45", "template-haskell-splice", "varE")],
           Text.pack (show graphDynamicLoads))
        , ("compiler-quotation-controls", Set.fromList quoteRows == Set.fromList
             [ "graph-call-site\tQuoteControl.hs\texpression\t4:17-4:26\tcallee"
             , "graph-reference-site\tQuoteControl.hs\texpression\t4:17-4:23\tcallee"
             , "graph-reference-site\tQuoteControl.hs\texpression\t4:24-4:26\t()"
             , "graph-reference-site\tQuoteControl.hs\tname\t5:8-5:15\tcallee"
             , "graph-call-site\tQuoteControl.hs\tnested\t6:15-6:35\tpure"
             , "graph-call-site\tQuoteControl.hs\tnested\t6:23-6:32\tcallee"
             , "graph-reference-site\tQuoteControl.hs\tnested\t6:15-6:19\tpure"
             , "graph-reference-site\tQuoteControl.hs\tnested\t6:23-6:29\tcallee"
             , "graph-reference-site\tQuoteControl.hs\tnested\t6:30-6:32\t()"
             , "graph-dynamic-load\tQuoteControl.hs\tnested\t6:13-6:36\ttemplate-haskell-splice\tpure"
             , "graph-unscanned\tQuoteControl.hs\tunsupported\tUntypedBracket"
             ] && length quoteRows == 11,
           Text.pack (show quoteRows))
        , ("compiler-record-field-control",
             not (Set.null graphRecordFields)
               && all (\(path, owner, site, receiver, field) ->
                    Set.member (Text.unpack path) graphFiles
                      && not (Text.null owner) && site /= "unlocated"
                      && receiver /= "unlocated" && not (Text.null field))
                 (Set.toList graphRecordFields)
               && all (\(path, owner, site, field) ->
                    Set.member (Text.unpack path) graphFiles
                      && not (Text.null owner) && site /= "unlocated"
                      && not (Text.null field))
                 (Set.toList graphRecordProjections)
               && all (\(component, path, owner, site, kind, field,
                        targetComponent, provider, parent, imported) ->
                    Set.member (provider, parent, field) graphSelectors
                      && Set.member (path, component) graphComponents
                      && Set.member (provider, targetComponent) graphComponents
                      && (if kind == "get" then any (\(sourcePath, sourceOwner, sourceSite, _, sourceField) ->
                            sourcePath == path && sourceOwner == owner && sourceSite == site
                              && sourceField == field) (Set.toList graphRecordFields)
                          else Set.member (path, owner, site, field) graphRecordProjections)
                      && (imported == "local" && component == targetComponent && path == provider
                        || any (\(sourceComponent, sourcePath, _, _, importName) ->
                            sourceComponent == component && sourcePath == path && importName == imported)
                          (Set.toList graphLinks)))
                 (Set.toList graphRecordSelectorCandidates),
           Text.pack (show (Set.size graphRecordFields, Set.size graphRecordProjections,
             Set.size graphRecordSelectorCandidates)))
        , ("compiler-foreign-boundary-control", graphForeignSymbols == Set.singleton
             ("test/fixture/chain_boundary/astcheck/negative_foreign.hs",
              "foreignValue", "import", "foreign_value", "2:1-2:57")
               && graphForeignSinks == graphForeignSymbols
               && "foreign import ccall \"foreign_value\" foreignValue :: Int"
                    `Text.isInfixOf` foreignSource
               && not (any ((== "Foreign") . snd) (Set.toList graphDeclarationGaps)),
           Text.pack (show (graphForeignSymbols, graphForeignSinks)))
        , ("compiler-type-family-boundary-control",
             Map.keysSet expectedFamilyStarts == Set.fromList
               ["Remove", "Append", "Disjoint", "NotElem"]
               && Set.map (\(path, name, _, role) -> (path, name, role)) graphTypeFamilies
                    == Set.fromList
                      [("src/Amoebius/Calculus/Workflow/Obligation.hs", name,
                        "type-level-only")
                      | name <- ["Remove", "Append", "Disjoint", "NotElem"]]
               && Set.size graphTypeFamilies == 4
               && all (\(_, name, site, _) -> case parseSite site of
                    Just ((line, column), _) ->
                      column == 1 && Map.lookup name expectedFamilyStarts == Just line
                    Nothing -> False) (Set.toList graphTypeFamilies)
               && not (any ((== "TypeFamily") . snd) (Set.toList graphDeclarationGaps)),
           Text.pack (show (Set.size graphTypeFamilies,
             Set.toAscList (Map.keysSet expectedFamilyStarts))))
        , ("compiler-derived-instance-control", all (`Set.member` graphDerivedInstances)
             [("src/Amoebius/Layout/Classify.hs", "PathClass", "Eq", "inferred"),
              ("src/Amoebius/Layout/Classify.hs", "PathClass", "Ord", "inferred"),
              ("src/Amoebius/Layout/Classify.hs", "PathClass", "Show", "inferred")],
           Text.pack (show (Set.size graphDerivedInstances)))
        , ("compiler-derived-class-head-control",
             Set.map (\(path, typeName, className, _, strategy) ->
               (path, typeName, className, strategy)) graphDerivedClassHeads
               == graphDerivedInstances
               && all (\(_, _, className, classHead, _) ->
                    classHead /= "unresolved"
                      && classHead == Text.takeWhile (/= ' ') className)
                  (Set.toList graphDerivedClassHeads)
               && Set.member ("src/vendor/Pulsar/Internal/Core.hs", "Pulsar",
                    "MonadReader PulsarCtx", "MonadReader", "inferred") graphDerivedClassHeads,
           Text.pack (show (Set.size graphDerivedClassHeads)))
        , ("compiler-derived-class-member-control",
             not (Set.null graphDerivedClassMembers)
               && all (\(path, typeName, className, classHead, strategy,
                        imported, package, unit, member, mode) ->
                    Set.member (path, typeName, className, classHead, strategy)
                      graphDerivedClassHeads
                      && Set.member (unit, imported,
                           Text.takeWhileEnd (/= '.') classHead, member)
                        graphModuleInterfaceMembers
                      && (case mode of
                        "explicit" -> Set.member (path, imported) graphImports
                          && (any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphExternalImports)
                            || any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailableUnits)
                            || Set.member (path, imported, package, unit)
                              graphStandaloneAvailableUnits)
                        "implicit" -> imported == "Prelude"
                          && (any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphImplicitPreludeImports)
                            || any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailablePreludeImports)
                            || Set.member (path, package, unit)
                              graphStandalonePreludeImports)
                        _ -> False)) (Set.toList graphDerivedClassMembers)
               && any (\(path, typeName, className, classHead, _, imported,
                         package, _, member, mode) ->
                    path == "src/Amoebius/Layout/Classify.hs"
                      && typeName == "PathClass" && className == "Eq"
                      && classHead == "Eq" && imported == "Prelude"
                      && package == "base" && member == "==" && mode == "implicit")
                  (Set.toList graphDerivedClassMembers),
           Text.pack (show (Set.size graphDerivedClassMembers)))
        , ("compiler-standalone-deriving-control", Set.member
             ("src/Amoebius/Calculus/Artifact/Target.hs", "Eq (Target k)", "stock")
             graphStandaloneDeriving,
           Text.pack (show (Set.size graphStandaloneDeriving)))
        , ("compiler-standalone-deriving-member-control",
             Set.map (\(path, instanceType, _, strategy) -> (path, instanceType, strategy))
               graphStandaloneDerivingHeads == graphStandaloneDeriving
               && all (\(_, instanceType, classHead, _) ->
                    classHead /= "unresolved"
                      && classHead == Text.takeWhile (/= ' ') instanceType)
                  (Set.toList graphStandaloneDerivingHeads)
               && not (Set.null graphStandaloneDerivingMembers)
               && Set.map (\(path, instanceType, classHead, strategy,
                            _, _, _, _, _) -> (path, instanceType, classHead, strategy))
                    graphStandaloneDerivingMembers == graphStandaloneDerivingHeads
               && all (\(path, instanceType, classHead, strategy,
                        imported, package, unit, member, mode) ->
                    Set.member (path, instanceType, classHead, strategy)
                      graphStandaloneDerivingHeads
                      && Set.member (unit, imported,
                           Text.takeWhileEnd (/= '.') classHead, member)
                        graphModuleInterfaceMembers
                      && (case mode of
                        "explicit" -> Set.member (path, imported) graphImports
                          && (any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphExternalImports)
                            || any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailableUnits)
                            || Set.member (path, imported, package, unit)
                              graphStandaloneAvailableUnits)
                        "implicit" -> imported == "Prelude"
                          && (any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphImplicitPreludeImports)
                            || any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailablePreludeImports)
                            || Set.member (path, package, unit)
                              graphStandalonePreludeImports)
                        _ -> False)) (Set.toList graphStandaloneDerivingMembers)
               && Set.member ("src/Amoebius/Calculus/Artifact/Target.hs", "Eq (Target k)",
                    "Eq", "stock", "Prelude", "base")
                    (Set.map (\(path, instanceType, classHead, strategy,
                               imported, package, _, _, _) ->
                       (path, instanceType, classHead, strategy, imported, package))
                      graphStandaloneDerivingMembers),
           Text.pack (show (Set.size graphStandaloneDerivingHeads,
             Set.size graphStandaloneDerivingMembers)))
        , ("compiler-data-symbol-control",
             Set.member ("src/Amoebius/Layout/Report.hs", "Options") graphData
               && Set.member ("src/Amoebius/Layout/Report.hs", "Options", "Options") graphConstructors
               && Set.member ("src/Amoebius/Layout/Report.hs", "Options", "optionRoot") graphSelectors,
           Text.pack (show (Set.size graphData, Set.size graphConstructors, Set.size graphSelectors)))
        , ("compiler-data-declaration-gap-control",
             graphDerivedTypes == Set.map (\(path, _, _, _, _, _, _, _, _, _) -> path) graphDerivedRoutes
               && Set.null graphDeclarationGaps,
           Text.pack (show (Set.size graphDerivedTypes)))
        , ("compiler-local-call-candidate-control", Set.member
             ("library:layout", "src/Amoebius/Layout/Report.hs", "runLayoutReport", "library:layout", "src/Amoebius/Layout/Report.hs", "parseOptions") graphLocalCallCandidates,
           Text.pack (show (Set.size graphLocalCallCandidates)))
        , ("compiler-standalone-local-call-control",
             not (Set.null graphStandaloneLocalCalls)
               && all (\(path, owner, site, target) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.notMember (path, owner, site, target) graphLexicalCallSites
                      && (Set.member (path, target) graphTopLevel
                        || any (\(provider, _, name) -> provider == path && name == target)
                          (Set.toList graphConstructors)
                        || any (\(provider, _, name) -> provider == path && name == target)
                          (Set.toList graphSelectors)
                        || any (\(provider, _, name) -> provider == path && name == target)
                          (Set.toList graphClassMethods)
                        || any (\(provider, name, _, _, _) -> provider == path && name == target)
                          (Set.toList graphForeignSymbols)))
                  (Set.toList graphStandaloneLocalCalls),
           Text.pack (show (Set.size graphStandaloneLocalCalls)))
        , ("compiler-standalone-lexical-call-control",
             not (Set.null graphStandaloneLexicalCalls)
               && all (\(path, owner, site, target, binderSite) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, owner, site, target) graphLexicalCallSites
                      && (Set.member (path, owner, target, binderSite) graphLocalBinders
                        || Set.member (path, owner, target, binderSite) graphParameterBinders))
                  (Set.toList graphStandaloneLexicalCalls),
           Text.pack (show (Set.size graphStandaloneLexicalCalls)))
        , ("compiler-standalone-imported-call-control",
             not (Set.null graphStandaloneImportedCalls)
               && all (\(path, owner, site, target, imported, provider, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.notMember (path, owner, site, target) graphLexicalCallSites
                      && Set.member (path, imported) graphImports
                      && provider `Set.member` sourceReach Set.empty [imported]
                      && length [source | (source, name) <- Set.toList graphModules,
                        name == imported] == 1
                      && (Set.member (provider, callee) graphTopLevel
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphConstructors)
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphSelectors)
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphClassMethods)
                        || any (\(source, name, _, _, _) -> source == provider && name == callee)
                          (Set.toList graphForeignSymbols)))
                  (Set.toList graphStandaloneImportedCalls),
           Text.pack (show (Set.size graphStandaloneImportedCalls)))
        , ("standalone-reexport-boundary",
             Set.fromList [fields | row <- standaloneExports,
               let fields = Text.splitOn "\t" row,
               take 1 fields == ["graph-call-standalone-imported-candidate"]]
               == Set.fromList
                 [ ["graph-call-standalone-imported-candidate", "StandaloneReexport.hs", "construct", "3:13-3:20", "Item", "StandaloneFacade", "Duplicate.hs", "Item"]
                 , ["graph-call-standalone-imported-candidate", "StandaloneReexport.hs", "selector", "4:18-4:33", "itemField", "StandaloneFacade", "Duplicate.hs", "itemField"]
                 , ["graph-call-standalone-imported-candidate", "StandaloneSelectiveUse.hs", "construct", "3:13-3:20", "Item", "StandaloneSelective", "Duplicate.hs", "Item"] ]
               && Set.fromList [fields | row <- standaloneExports,
                    let fields = Text.splitOn "\t" row, take 1 fields == ["graph-call-site-opaque"]]
                  == Set.fromList
                    [ ["graph-call-site-opaque", "-", "StandaloneReexport.hs", "hidden", "5:10-5:19", "Hidden", "standalone"]
                    , ["graph-call-site-opaque", "-", "StandaloneSelectiveUse.hs", "selector", "4:18-4:33", "itemField", "standalone"] ],
           "re-exported constructors and selectors; hidden members stay opaque")
        , ("compiler-standalone-source-denied-control",
             not (Set.null graphStandaloneDeniedSourceCalls)
               && all (\(path, owner, site, target, imported, provider, callee, reason) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (provider, imported) graphModules
                      && (Set.member (provider, callee) graphTopLevel
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphConstructors)
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphSelectors))
                      && reason `elem` ["provider-not-exported", "import-list-excludes"]
                      && (any (\(component, source, callOwner, callSite, callTarget, _) ->
                            component == "-" && source == path && callOwner == owner
                              && callSite == site && callTarget == target)
                            (Set.toList graphOpaqueCallSites)
                        || Set.member ("-", path, owner, site, target) rejectedCallKeys)
                      && not (any (\(source, callOwner, callSite, callTarget, _, _, _) ->
                           source == path && callOwner == owner && callSite == site
                             && callTarget == target) (Set.toList graphStandaloneImportedCalls)))
                  (Set.toList graphStandaloneDeniedSourceCalls)
               && any (\(path, _, _, target, _, provider, callee, reason) ->
                    path == "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
                      && target == "Grant" && provider == "src/Amoebius/Calculus/Budget/Grant.hs"
                      && callee == "Grant" && reason == "provider-not-exported")
                  (Set.toList graphStandaloneDeniedSourceCalls),
           Text.pack (show (Set.size graphStandaloneDeniedSourceCalls)))
        , ("compiler-rejected-source-call-control",
             all (\(_, _, _, _, _, valid) -> valid) denialObservations
               && all (\(_, _, _, _, _, _, valid) -> valid) scopeObservations
               && all (\(path, owner, target, rootSite, _, _) ->
                    Set.member (path, owner, rootSite, target) graphCallSites) denialObservations
               && Set.fromList [path | (path, _, _, _, _, _, _, _) <-
                    Set.toList graphStandaloneDeniedSourceCalls]
                    `Set.isSubsetOf` Set.fromList [path | (path, _, _, _, _, _) <- denialObservations]
               && graphCompilerRejectedCalls ==
                    (expectedCompilerRejectedCalls `Set.union` expectedScopeRejectedCalls)
               && Set.size graphCompilerRejectedCalls == 39,
           Text.pack (show (Set.size graphCompilerRejectedCalls,
             Set.size expectedCompilerRejectedCalls, Set.size expectedScopeRejectedCalls,
             [(path, valid) | (path, _, _, _, _, valid) <- denialObservations],
             [(path, valid) | (path, _, _, _, _, _, valid) <- scopeObservations],
             graphCompilerRejectedCalls `Set.difference` (expectedCompilerRejectedCalls `Set.union` expectedScopeRejectedCalls),
             (expectedCompilerRejectedCalls `Set.union` expectedScopeRejectedCalls) `Set.difference` graphCompilerRejectedCalls)))
        , ("compiler-standalone-closed-export-refusal-control",
             closedExportSourceProof
               && Set.size expectedClosedExportRefusals == 3
               && graphClosedExportRefusals == expectedClosedExportRefusals
               && Set.member ("src/Amoebius/Pulsar/Internal/Types.hs", "Topic", "Topic")
                    graphConstructors
               && all (\(path, owner, site, target, imported, provider, _) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (provider, imported) graphModules
                      && not (any (\(source, callOwner, callSite, callTarget, _, _, _) ->
                        source == path && callOwner == owner && callSite == site
                          && callTarget == target) (Set.toList graphStandaloneImportedCalls)))
                    (Set.toList graphClosedExportRefusals),
           Text.pack (show (Set.size graphClosedExportRefusals,
             Set.size expectedClosedExportRefusals)))
        , ("compiler-grant-rejection-control",
             grantCompilerValid
               && any (\(path, _, _, target, imported, provider, callee, reason) ->
                    path == "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
                      && target == "Grant"
                      && imported == "Amoebius.Calculus.Budget.Grant"
                      && provider == "src/Amoebius/Calculus/Budget/Grant.hs"
                      && callee == "Grant" && reason == "provider-not-exported")
                 (Set.toList graphStandaloneDeniedSourceCalls),
           grantCompilerDetail)
        , ("compiler-standalone-external-call-control",
             any (\(path, owner, _, target, imported, package, _, callee) ->
                    path == "src/vendor/Pulsar/Connection.hs" && owner == "connect"
                      && target == "async" && imported == "Control.Concurrent.Async"
                      && package == "async" && callee == "async")
                  (Set.toList graphStandaloneExternalCalls)
               && all (\(path, owner, site, target, imported, package, unit, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (path, imported, package, unit) graphStandaloneAvailableUnits
                      && not (any ((== imported) . snd) (Set.toList graphModules))
                      && not (Text.null package) && not (Text.null callee)
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                        interfaceUnit == unit && interfaceName == imported) graphModuleInterfaceRows)
                  (Set.toList graphStandaloneExternalCalls),
           Text.pack (show (Set.size graphStandaloneExternalCalls)))
        , ("compiler-standalone-registered-only-control",
             all (\(path, owner, site, target, imported, package, unit, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported, package, unit)
                        graphStandaloneRegisteredOnlyUnits
                      && any (\(component, source, callOwner, callSite, callTarget, _) ->
                           component == "-" && source == path && callOwner == owner
                             && callSite == site && callTarget == target)
                        (Set.toList graphOpaqueCallSites)
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                           interfaceUnit == unit && interfaceName == imported)
                        graphModuleInterfaceRows
                      && not (Text.null callee))
                  (Set.toList graphStandaloneRegisteredOnlyCalls)
               && all (\(path, imported, package, unit) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, imported) graphImports
                      && not (Text.null package)
                      && not (Set.member (path, imported, package, unit)
                        graphStandaloneAvailableUnits))
                  (Set.toList graphStandaloneRegisteredOnlyUnits),
           Text.pack (show (Set.size graphStandaloneRegisteredOnlyUnits,
             Set.size graphStandaloneRegisteredOnlyCalls)))
        , ("compiler-standalone-external-member-control",
             all (\(path, owner, site, target, imported, package, unit, parent, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (path, imported, package, unit) graphStandaloneAvailableUnits
                      && not (Text.null package)
                      && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
                  (Set.toList graphStandaloneExternalMemberCalls),
           Text.pack (show (Set.size graphStandaloneExternalMemberCalls)))
        , ("compiler-imported-call-candidate-control", Set.member
             ("executable:amoebius", "app/amoebius/Main.hs", "dispatch", "executable:amoebius", "app/amoebius/Amoebius/Entry/ControlPlane.hs", "runControlPlaneDaemon", "Amoebius.Entry.ControlPlane") graphCallCandidates,
           Text.pack (show (Set.size graphCallCandidates)))
        , ("compiler-local-import-control", Set.member
             ("library:layout", "src/Amoebius/Layout/SourceGraph.hs", "library:layout", "src/Amoebius/Layout/Classify.hs", "Amoebius.Layout.Classify") graphLinks,
           Text.pack (show (Set.size graphLinks)))
        , ("compiler-dependency-import-control", Set.member
             ("executable:amoebius", "app/amoebius/Main.hs", "library:layout", "src/Amoebius/Layout/Report.hs", "Amoebius.Layout.Report") graphLinks,
           Text.pack (show (Set.size graphLinks)))
        , ("compiler-component-control", Set.member
             ("src/Amoebius/Layout/SourceGraph.hs", "library:layout") graphComponents,
           Text.pack (show (Set.size graphComponents)))
        , ("compiler-cabal-dependency-control",
             all (`Set.member` packageBuildDependencies)
               [("library:layout", "ghc"), ("library:layout", "Cabal-syntax"),
                ("executable:amoebius", "aeson")]
               && all (not . Text.null . snd) (Set.toList packageBuildDependencies),
           Text.pack (show (Set.size packageBuildDependencies)))
        , ("compiler-standalone-import-partition", standalonePartition,
           Text.pack (show (Set.size standaloneImportKeys, Set.size standaloneSourceKeys,
             Set.size standaloneAvailableKeys, Set.size standaloneOwedKeys, Set.size standaloneUnresolvedKeys)))
        , ("compiler-import-partition-control", importPartition,
           Text.pack (show (Set.size componentImportKeys, Set.size internalImportKeys,
             Set.size externalImportKeys, Set.size forwardImportKeys, Set.size unresolvedImportKeys)))
        , ("compiler-constructor-reexport-control",
             Set.fromList [(path, site) | (_, path, _, site, _, _, _, _, _, _, _, _) <- Set.toList graphConstructorReexports]
               == Set.fromList
                 [("src/extension-contributions/Amoebius/Extension/Contributed/" <> name <> ".hs", site)
                 | (name, site) <- [("Coordination", "11:6-11:24"), ("Infernix", "11:6-11:24"),
                     ("JitBuild", "11:6-11:24"), ("JitML", "11:6-11:47")]]
               && Set.size graphConstructorReexports == 4
               && all (\(component, path, owner, site, target, facadeComponent, facadePath, imported, package, unit, parent, callee) ->
                    component == "library:extension-contributions" && owner == "contribution" && target == "S.:|"
                      && facadeComponent == "library:extension-surface"
                      && facadePath == "src/extension-surface/Amoebius/Extension/Surface.hs"
                      && imported == "Data.List.NonEmpty" && package == "base" && parent == "NonEmpty" && callee == ":|"
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (facadeComponent, facadePath, imported, package, unit) graphExternalImports
                      && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
                 (Set.toList graphConstructorReexports),
           Text.pack (show graphConstructorReexports))
        , ("compiler-constructor-reexport-pairs",
             Set.fromList [fields | row <- constructorReexportRows,
               "graph-call-constructor-reexport-candidate" : fields <- [Text.splitOn "\t" row]]
               == Set.fromList
                 [["test:consumer", "UseExternalFacades.hs", owner, site, target, "test:consumer", facade,
                    "Example.Provider", "provider", "provider-unit", "Thing", "Thing"]
                 | (owner, site, target, facade) <-
                     [("good", "8:8-8:18", "F.Thing", "ExternalFacade.hs"),
                      ("named", "11:9-11:19", "N.Thing", "ExternalNamed.hs"),
                      ("relayed", "12:11-12:21", "R.Thing", "ExternalFacade.hs")]]
               && Set.fromList [(owner, target) | row <- constructorReexportRows,
                    ["graph-call-site-opaque", "test:consumer", "UseExternalFacades.hs", owner, _, target, "unattributed"]
                      <- [Text.splitOn "\t" row]]
                    == Set.fromList [("abstract", "A.Thing"), ("hidden", "H.Thing"), ("cycle", "C.Thing")],
           Text.pack (show [row | row <- constructorReexportRows,
             "graph-call-" `Text.isPrefixOf` row && not ("graph-call-site\t" `Text.isPrefixOf` row)]))
        , ("compiler-external-call-candidate-control",
             not (Set.null graphExternalCallCandidates)
               && all (\(component, path, owner, site, target, imported, package, unit, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphExternalImports
                   && not (Text.null callee))
                 (Set.toList graphExternalCallCandidates),
           Text.pack (show (Set.size graphExternalCallCandidates)))
        , ("compiler-external-member-call-control",
             all (\(component, path, owner, site, target, imported, package, unit, parent, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphExternalImports
                   && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
               (Set.toList graphExternalMemberCallCandidates),
           Text.pack (show (Set.size graphExternalMemberCallCandidates)))
        , ("compiler-available-call-candidate-control",
             all (\(component, path, owner, site, target, imported, package, unit, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphAvailableUnits
                   && any (\(interfaceUnit, interfaceName, _, _) ->
                      interfaceUnit == unit && interfaceName == imported) graphModuleInterfaceRows
                   && not (Text.null callee))
               (Set.toList graphAvailableCallCandidates),
           Text.pack (show (Set.size graphAvailableCallCandidates)))
        , ("compiler-available-member-call-control",
             all (\(component, path, owner, site, target, imported, package, unit, parent, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphAvailableUnits
                   && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
               (Set.toList graphAvailableMemberCallCandidates),
           Text.pack (show (Set.size graphAvailableMemberCallCandidates)))
        , ("compiler-deferred-seed-call-control",
             not (Set.null graphDeferredSeedCallCandidates)
               && all (\(component, path, owner, site, target, imported, package, role, callee) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (component, path, imported, package, role) graphDeferredSeed
                      && callee == Text.takeWhileEnd (/= '.') target)
                  (Set.toList graphDeferredSeedCallCandidates),
           Text.pack (show (Set.size graphDeferredSeedCallCandidates)))
        , ("compiler-prelude-interface-control",
             Set.size graphPreludeInterfaces == 1
               && all (\(unit, digest, count) -> Text.length digest == 64
                 && count == "259"
                 && any (\(_, _, name, package, externalUnit) ->
                   name == "Prelude" && package == "base" && externalUnit == unit)
                   (Set.toList graphExternalImports)) (Set.toList graphPreludeInterfaces)
               && all (\(component, path, owner, site, target, package, unit) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, package, unit) graphImplicitPreludeImports
                   && package == "base") (Set.toList graphPreludeCallCandidates)
               && all (\name -> any (\(_, _, _, _, target, _, _) -> target == name)
                   (Set.toList graphPreludeCallCandidates)) ["map", "pure", "Left", "<>", "."]
               && all (\(component, path, package, unit) ->
                 Set.member (path, component) graphComponents
                   && package == "base"
                   && any (\(interfaceUnit, _, _) -> interfaceUnit == unit)
                     (Set.toList graphPreludeInterfaces))
                 (Set.toList graphImplicitPreludeImports),
           Text.pack (show (Set.size graphImplicitPreludeImports, Set.size graphPreludeCallCandidates)))
        , ("compiler-available-prelude-control",
             all (\(component, path, package, unit) ->
                 Set.member (path, component) graphComponents
                   && Set.member (component, package) packageBuildDependencies
                   && package == "base"
                   && any (\(interfaceUnit, _, _) -> interfaceUnit == unit)
                     (Set.toList graphPreludeInterfaces))
               (Set.toList graphAvailablePreludeImports)
               && all (\(component, path, owner, site, target, package, unit) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (component, path, package, unit) graphAvailablePreludeImports)
                  (Set.toList graphAvailablePreludeCallCandidates),
           Text.pack (show (Set.size graphAvailablePreludeImports,
             Set.size graphAvailablePreludeCallCandidates)))
        , ("compiler-standalone-prelude-control",
             not (Set.null graphStandalonePreludeImports)
               && all (\(path, package, unit) ->
                    path `Set.member` graphNoComponents && package == "base"
                      && any (\(interfaceUnit, _, _) -> interfaceUnit == unit)
                        (Set.toList graphPreludeInterfaces))
                  (Set.toList graphStandalonePreludeImports)
               && all (\(path, owner, site, target, package, unit) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.notMember (path, owner, site, target) graphLexicalCallSites
                      && Set.member (path, package, unit) graphStandalonePreludeImports
                      && package == "base")
                  (Set.toList graphStandalonePreludeCallCandidates),
           Text.pack (show (Set.size graphStandalonePreludeImports,
             Set.size graphStandalonePreludeCallCandidates)))
        , ("compiler-wired-cons-control",
             not (Set.null graphWiredConsCandidates)
               && all (\(component, path, owner, site, target, provider, unit) ->
                    target == ":" && provider == "GHC.Types" && unit == "ghc-prim"
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, component) graphComponents)
                    (Set.toList graphWiredConsCandidates),
           Text.pack (show (Set.size graphWiredConsCandidates)))
        , ("compiler-standalone-wired-cons-control",
             not (Set.null graphStandaloneWiredConsCandidates)
               && all (\(path, owner, site, target, provider, unit) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && target == ":" && provider == "GHC.Types" && unit == "ghc-prim")
                  (Set.toList graphStandaloneWiredConsCandidates),
           Text.pack (show (Set.size graphStandaloneWiredConsCandidates)))
        , ("compiler-wired-tuple-control",
             all (\(component, path, owner, site, target, provider, unit) ->
                    target == "(,)" && provider == "GHC.Tuple" && unit == "ghc-prim"
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, component) graphComponents)
                 (Set.toList graphWiredTupleCandidates),
           Text.pack (show (Set.size graphWiredTupleCandidates)))
        , ("compiler-lexical-binding-control",
             not (Set.null graphLexicalBindingCandidates)
               && all (\(component, path, owner, site, target, binderSite) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, owner, site, target) graphLexicalCallSites
                      && Set.member (path, component) graphComponents
                      && (Set.member (path, owner, target, binderSite) graphLocalBinders
                        || Set.member (path, owner, target, binderSite) graphParameterBinders)
                      && binderSite /= "unlocated" && binderSite /= site)
                    (Set.toList graphLexicalBindingCandidates),
           Text.pack (show (Set.size graphLexicalBindingCandidates)))
        , ("compiler-parameter-binder-control",
             not (Set.null graphParameterBinders)
               && all (\(path, owner, name, binderSite) ->
                    Set.member (Text.unpack path) graphFiles && not (Text.null owner)
                      && not (Text.null name) && binderSite /= "unlocated")
                 (Set.toList graphParameterBinders),
           Text.pack (show (Set.size graphParameterBinders)))
        , ("compiler-local-alias-control",
             all (\(path, owner, name, binderSite, target, targetKind) ->
               Set.member (path, owner, name, binderSite) graphLocalBinders
                 && not (Text.null target)
                 && targetKind `elem` ["unqualified", "qualified", "parameter", "local-binder"])
               (Set.toList graphLocalAliases)
               && all (\(component, path, owner, site, binder, binderSite, target, targetKind) ->
                 Set.member (path, owner, binder, binderSite, target, targetKind) graphLocalAliases
                   && Set.member (component, path, owner, site, binder, binderSite) graphLexicalBindingCandidates)
                 (Set.toList graphLexicalAliasRoutes)
               && all (\((component, path, owner), (targetComponent, targetPath, callee)) ->
                 component == targetComponent && path == targetPath
                   && any (\(sourceComponent, sourcePath, sourceOwner, _, _, _, target, targetKind) ->
                      sourceComponent == component && sourcePath == path && sourceOwner == owner
                        && target == callee && targetKind == "unqualified")
                     (Set.toList graphLexicalAliasRoutes))
                 (Set.toList graphAliasInternalCalls),
           Text.pack (show (Set.size graphLocalAliases, Set.size graphLexicalAliasRoutes,
             Set.size graphAliasInternalCalls)))
        , ("compiler-alias-external-control",
             all (\(component, path, owner, site, binder, binderSite, target, imported, package, unit, callee) ->
               Set.member (component, path, imported, package, unit) graphExternalImports
                 && any (\(sourceComponent, sourcePath, sourceOwner, sourceSite,
                          sourceBinder, sourceBinderSite, sourceTarget, targetKind) ->
                   sourceComponent == component && sourcePath == path && sourceOwner == owner
                     && sourceSite == site && sourceBinder == binder
                     && sourceBinderSite == binderSite && sourceTarget == target
                     && targetKind `elem` ["qualified", "unqualified"])
                   (Set.toList graphLexicalAliasRoutes)
                 && not (Text.null callee)
                 && any (\(interfaceUnit, interfaceName, _, _) ->
                   interfaceUnit == unit && interfaceName == imported) graphModuleInterfaceRows)
               (Set.toList graphAliasExternalCalls),
           Text.pack (show (Set.size graphAliasExternalCalls)))
        , ("compiler-alias-imported-control",
             all (\(component, path, owner, site, binder, binderSite, target,
                     targetComponent, provider, callee, imported) ->
               Set.member (component, path, targetComponent, provider, imported) graphLinks
                 && any (\(sourceComponent, sourcePath, sourceOwner, sourceSite,
                          sourceBinder, sourceBinderSite, sourceTarget, targetKind) ->
                   sourceComponent == component && sourcePath == path && sourceOwner == owner
                     && sourceSite == site && sourceBinder == binder
                     && sourceBinderSite == binderSite && sourceTarget == target
                     && targetKind `elem` ["qualified", "unqualified"])
                   (Set.toList graphLexicalAliasRoutes)
                 && (Set.member (provider, callee) graphTopLevel
                   || any (\(declarationPath, _, member) ->
                       declarationPath == provider && member == callee) (Set.toList graphConstructors)
                   || any (\(declarationPath, _, member) ->
                       declarationPath == provider && member == callee) (Set.toList graphSelectors)
                   || any (\(declarationPath, _, member) ->
                       declarationPath == provider && member == callee) (Set.toList graphClassMethods)))
               (Set.toList graphAliasImportedCalls),
           Text.pack (show (Set.size graphAliasImportedCalls)))
        , ("compiler-external-interface-control",
             length graphModuleInterfaceRows == Set.size graphModuleInterfaces
               && Set.fromList [(unit, name) | (unit, name, _, _) <- graphModuleInterfaceRows]
                    == Set.fromList
                      ([(unit, name) | (_, _, name, _, unit) <- Set.toList graphExternalImports]
                        <> [(unit, name) | (_, _, name, _, unit) <- Set.toList graphUnselectedCandidates]
                        <> [(unit, name) | (_, name, _, unit) <- Set.toList graphStandaloneAvailableUnits]
                        <> [(unit, name) | (_, name, _, unit) <- Set.toList graphStandaloneRegisteredOnlyUnits])
               && all (\(path, name, package, unit) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, name) graphImports
                      && not (Text.null package)
                      && not (any ((== name) . snd) (Set.toList graphModules))
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                        interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows)
                  (Set.toList graphStandaloneAvailableUnits)
               && all (\(unit, name, digest, count) ->
                    Text.length digest == 64 && not (Text.null unit)
                      && not (Text.null name) && not (Text.null count)) graphModuleInterfaceRows
               && all (\(_, _, _, _, _, imported, _, unit, _) ->
                    any (\(interfaceUnit, name, _, _) -> interfaceUnit == unit && name == imported)
                      graphModuleInterfaceRows) (Set.toList graphExternalCallCandidates),
           Text.pack (show (length graphModuleInterfaceRows)))
        , ("compiler-interface-member-control",
             all (\(unit, name, parent, member) ->
                  not (Text.null parent) && not (Text.null member)
                    && any (\(interfaceUnit, interfaceName, _, _) ->
                        interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows)
               (Set.toList graphModuleInterfaceMembers),
           Text.pack (show (Set.size graphModuleInterfaceMembers)))
        , ("compiler-forward-owned-import-control", graphForwardOwned == expectedForwardOwned
             && Set.size graphForwardOwned == 11,
           Text.pack (show (Set.size graphForwardOwned, Set.size expectedForwardOwned)))
        , ("compiler-deferred-seed-import-control",
             graphDeferredSeed == Set.fromList
               [("library:infernix", "src/Infernix/Adapter/Core.hs", "Infernix.Topic.Metadata",
                 "infernix", "infernix-rederivation"),
                ("test:jitml-cuda-artifact-lift-contract", "test/spec/kernel/JitMLCudaArtifactContractSpec.hs",
                 "JitML.Codegen.RuntimeOperationsCuda", "jitml", "jitml-rederivation")]
               && all (\(component, consumer, name, package, _) ->
                    (Set.member (component, package) packageBuildDependencies
                      || (component == "test:jitml-cuda-artifact-lift-contract"
                        && package == "jitml"
                        && Set.member ("library:jitml", package) packageBuildDependencies
                        && any (\(sourceComponent, sourcePath, targetComponent, _, _) ->
                            sourceComponent == component && sourcePath == consumer
                              && targetComponent == "library:jitml") (Set.toList graphLinks)))
                      && Set.member (consumer, name) graphImports
                      && Set.member (consumer, component) graphComponents)
                  (Set.toList graphDeferredSeed),
           Text.pack (show (Set.size graphDeferredSeed)))
        , ("compiler-unselected-unit-candidate-control",
             all (\(component, consumer, name, package, unit) ->
               (Set.member (component, consumer, name, "component-not-in-plan") graphUnresolved
                 || Set.member (component, consumer, name, package, unit) graphAvailableUnits)
                 && Set.member (component, package) packageBuildDependencies
                 && not (Text.null unit)
                 && any (\(interfaceUnit, interfaceName, _, _) ->
                      interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows
                 && Set.notMember (component, consumer, name) externalImportKeys)
               (Set.toList graphUnselectedCandidates),
           Text.pack (show (Set.size graphUnselectedCandidates)))
        , ("compiler-available-unit-control",
             Set.size graphAvailableUnits == Set.size availableImportKeys
               && all (\row@(_, _, name, _, unit) ->
                    Set.member row graphUnselectedCandidates
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                          interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows)
                  (Set.toList graphAvailableUnits),
           Text.pack (show (Set.size graphAvailableUnits)))
        , ("compiler-residual-ownership-control",
             all (\(component, _, name, reason) -> case reason of
               "external-or-unknown" -> component == "library:pulsar-client"
                 && name `elem` ["Proto.PulsarApi", "Proto.PulsarApi_Fields"]
               "component-not-in-plan" -> component `elem`
                 ["library:infernix", "library:infernix-ui", "library:jitml", "library:jitml-ui",
                  "test:infernix-core-artifact-lift-contract", "test:infernix-native-driver",
                  "test:infernix-ui-lift-contract", "test:jitml-cuda-artifact-lift-contract",
                  "test:jitml-ui-lift-contract"]
               _ -> False) (Set.toList graphUnresolved),
           Text.pack (show (Set.size graphUnresolved)))
        , ("compiler-source-role-coverage",
             graphFiles == Set.map Text.unpack (Set.union (Set.map fst graphComponents) graphNoComponents)
               && Set.null (Set.intersection (Set.map fst graphComponents) graphNoComponents),
           Text.pack (show (Set.size graphNoComponents)))
        , ("compiler-standalone-role-coverage",
             Set.map fst packageStandalone == graphNoComponents
               && length standaloneRows == Set.size packageStandalone
               && all (\(path, role) -> expectedStandaloneRole path == Just role) standaloneRows,
           Text.pack (show (Set.size packageStandalone)))
        , ("compiler-import-classification-control", Set.member
             ("library:layout", "src/Amoebius/Layout/SourceGraph.hs", "GHC.Parser", "external-or-unknown") graphUnresolved
             || any (\(component, consumer, name, package, unit) ->
                  component == "library:layout" && consumer == "src/Amoebius/Layout/SourceGraph.hs"
                    && name == "GHC.Parser" && package == "ghc" && not (Text.null unit))
                  (Set.toList graphExternalImports),
           Text.pack (show (Set.size graphUnresolved, Set.size graphExternalImports)))
        , ("compiler-inaccessible-internal-control",
             Set.fromList [(component, consumer, name) | (component, consumer, name, reason) <- Set.toList graphUnresolved,
               reason == "internal-not-declared"]
               == Set.fromList [(component, consumer, name) | (component, consumer, name, _, _) <- Set.toList graphInaccessible]
               && all (\(component, _, _, _, _) -> component /= "executable:amoebius") (Set.toList graphInaccessible),
           Text.pack (show (Set.size graphInaccessible)))
        , ("case:graph-qualified",
             graphStages == ["resolved"] && importPartition && Set.null graphUnresolved
               && standalonePartition && Set.null graphStandaloneUnresolved
               && Set.null graphUnscanned && Set.null graphDeclarationGaps
               && Set.null graphOpaqueCallSites
               && graphForwardOwned == expectedForwardOwned
               && graphEffectRoutes == expectedEffectRoutes
               && any (\(component, consumer, name, package, unit) ->
                    component == "library:layout" && consumer == "src/Amoebius/Layout/SourceGraph.hs"
                      && name == "GHC.Parser" && package == "ghc" && not (Text.null unit))
                    (Set.toList graphExternalImports),
           Text.pack (show (graphStages, Set.size graphUnresolved,
             Set.size graphUnscanned, Set.size graphDeclarationGaps,
             Set.size graphOpaqueCallSites, Set.size graphExternalImports)))
        , ("bootstrap-call-sites", bootstrapCalls == Set.fromList expectedBootstrapCalls,
           Text.pack (show (Set.toAscList bootstrapCalls)))
        , ("bootstrap-effect-sites", bootstrapEffects == Set.fromList expectedBootstrapEffects,
           Text.pack (show (Set.toAscList bootstrapEffects)))
        , ("forward-owned-generated-proto", packageOwed == Set.fromList
             [("library:pulsar-client:Proto/PulsarApi.hs", "generated-proto"),
              ("library:pulsar-client:Proto/PulsarApi_Fields.hs", "generated-proto")],
           Text.pack (show packageOwed))
        ]
          <> routeChecks
          <> packageChecks
          <> testChecks
          <> testSourceExampleChecks report
          <> toolChecks
          <> toolSourceExampleChecks report
          <> pulumiChecks
          <> pulumiSourceExampleChecks report
          <> runtimeChecks
          <> runtimeIdentityExampleChecks report
          <> ignoreChecks
          <> ignoreContextExampleChecks report
          <> sourceChecks
          <> sourceGraphExampleChecks report
          <> bootstrapChecks
          <> bootstrapSourceExampleChecks report
          <> staticChecks
          <> staticTextExampleChecks report
          <> lexicalChecks
          <> lexicalCompatibilityExampleChecks report
          <> opaqueChecks
          <> surfaceExampleChecks report
          <> [ ("path:" <> Text.pack path, Map.lookup path observedPaths == Just className, maybe "absent" id (Map.lookup path observedPaths))
             | path <- expectedPaths
             , let className = expectedClass path
             ]
          <> [("case:" <> name, Map.lookup name cases == Just wanted
                 && maybe True exactUnavailableStaticText (Map.lookup name graphlessByCase),
               maybe "absent" id (Map.lookup name cases)
                 <> maybe "" ((";" <>) . staticTextDiagnostic) (Map.lookup name graphlessByCase)) | (name, wanted) <- expectedCases]
          <> [("challenge-finding:" <> name,
               pathMatches name path && maybe False (\wanted -> sort found == sort
                 (["finding\t" <> wanted <> "\t" <> path <> (if name == "ordinal" then ":2" else "")]
                   <> ["finding\tUnmappedHaskellSource\t" <> path | name == "ordinal"])) (lookup name expectedChallengeTags)
                 && (if name == "syntax" then syntaxSemantic == Right ()
                     else exactUnavailableStaticText parsed),
               Text.intercalate "," (map masked found) <> ";" <> masked (staticTextDiagnostic parsed))
             | (name, path, _, found, parsed) <- challengeFindings]
  pure checks

data CompilerDiagnostic = CompilerDiagnostic Text Text Int FilePath Int Int [Text]

parseCompilerDiagnostic :: Value -> Parser CompilerDiagnostic
parseCompilerDiagnostic = withObject "CompilerDiagnostic" $ \record -> do
    compilerVersion <- record .: "ghcVersion"
    severity <- record .: "severity"
    diagnosticCode <- record .: "code"
    messages <- record .: "message"
    located <- record .: "span"
    (path, diagnosticLine, diagnosticColumn) <- withObject "CompilerSpan" (\spanRecord -> do
      path <- spanRecord .: "file"
      start <- spanRecord .: "start"
      (diagnosticLine, diagnosticColumn) <- withObject "CompilerStart" (\position ->
        (,) <$> position .: "line" <*> position .: "column") start
      pure (path, diagnosticLine, diagnosticColumn)) located
    pure (CompilerDiagnostic compilerVersion severity diagnosticCode path
      diagnosticLine diagnosticColumn messages)

parseCompilerLines :: String -> Either String [CompilerDiagnostic]
parseCompilerLines output = traverse
  (\line -> eitherDecodeStrict' (TextEncoding.encodeUtf8 line)
    >>= parseEither parseCompilerDiagnostic)
  (filter (not . Text.null) (Text.lines (Text.pack output)))

observeGrantTwin :: FilePath -> IO (Bool, Text)
observeGrantTwin directory = do
  version <- invoke ["--numeric-version"]
  legal <- compile "grant-legal" legalPath
  illegal <- compile "grant-illegal" illegalPath
  let versionValid = case version of
        Right (ExitSuccess, output, _) -> Text.strip (Text.pack output) == "9.12.4"
        _ -> False
      legalValid = case legal of
        Right (ExitSuccess, _, stderrText) ->
          case parseCompilerLines stderrText of
            Right observed -> null [() | CompilerDiagnostic _ severity _ _ _ _ _ <- observed,
              severity == "Error"]
            Left _ -> False
        _ -> False
      illegalValid = case illegal of
        Right (ExitFailure _, _, stderrText) -> case parseCompilerLines stderrText of
          Right [CompilerDiagnostic "ghc-9.12.4" "Error" 1928 path 31 3 messages] ->
            path == illegalPath
              && all (`Text.isInfixOf` Text.intercalate "\n" messages)
                   ["Illegal term-level use", "Grant", "src/Amoebius/Calculus/Budget/Grant.hs"]
          _ -> False
        _ -> False
  pure (versionValid && legalValid && illegalValid,
    Text.pack (show (versionValid, legalValid, illegalValid)))
 where
  legalPath = "test/negative/compile_fail/budget_calculus/grant_comes_from_the_issuer.hs"
  illegalPath = "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
  invoke args = trySynchronous (readProcessWithExitCode "ghc" args "")
    :: IO (Either SomeException (ExitCode, String, String))
  compile label source = do
    let outputDir = directory </> "compiler-negative" </> label
    createDirectoryIfMissing True outputDir
    invoke ["-j1", "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024",
      "-isrc/calculus-composition", "-isrc/capacity-topology", "-isrc",
      "-outputdir", outputDir, "-package", "base", "-package", "bytestring",
      "-package", "containers", "-package", "deepseq", "-package", "text", source]

observeMethodImportTwin :: FilePath -> IO (Bool, Text)
observeMethodImportTwin directory = do
  let outputDir = directory </> "compiler-negative" </> "instance-method-import"
      legalPath = outputDir </> "VisibleMethod.hs"
      illegalPath = outputDir </> "HiddenMethod.hs"
      source moduleName importLine = Text.unlines
        ["module " <> moduleName <> " where", importLine, "data X = X",
         "instance FromJSON X where", "  parseJSON _ = pure X"]
  createDirectoryIfMissing True outputDir
  TextIO.writeFile legalPath (source "VisibleMethod"
    "import Data.Aeson (FromJSON (parseJSON))")
  TextIO.writeFile illegalPath (source "HiddenMethod"
    "import Data.Aeson (FromJSON)")
  legal <- compile outputDir legalPath
  illegal <- compile outputDir illegalPath
  let legalValid = case legal of
        Right (ExitSuccess, _, stderrText) ->
          either (const False) (null . filter compilerError)
            (parseCompilerLines stderrText)
        _ -> False
      illegalValid = case illegal of
        Right (ExitFailure _, _, stderrText) -> case parseCompilerLines stderrText of
          Right [CompilerDiagnostic "ghc-9.12.4" "Error" 54721 path 5 3 messages] ->
            normalise path == normalise illegalPath
              && "parseJSON" `Text.isInfixOf` Text.intercalate "\n" messages
              && "visible" `Text.isInfixOf` Text.intercalate "\n" messages
          _ -> False
        _ -> False
  pure (legalValid && illegalValid,
    Text.pack (show (legalValid, illegalValid)))
 where
  compilerError (CompilerDiagnostic _ severity _ _ _ _ _) = severity == "Error"
  compile outputDir source =
    trySynchronous (readProcessWithExitCode "cabal"
      ["exec", "--jobs=1", "--builddir=.build/dist-native", "--", "ghc", "-j1", "-fdiagnostics-as-json",
       "-fno-code", "-fforce-recomp", "-XGHC2024", "-outputdir", outputDir, source] "")
      :: IO (Either SomeException (ExitCode, String, String))

deniedConstructorExpectations :: [(FilePath, Text, Text, Text, Int, Int, FilePath)]
deniedConstructorExpectations =
  [ ("test/fixture/chain_boundary/compilefail/checked_ctor_illegal.hs",
      "illegal", "CheckedExtensionSource", "5:11-5:45", 5, 11,
      "src/extension-admission/Amoebius/Extension/AstCheck.hs")
  , ("test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs",
      "forged", "Grant", "31:3-34:67", 31, 3,
      "src/Amoebius/Calculus/Budget/Grant.hs")
  , ("test/negative/compile_fail/budget_calculus/grant_forged_unbounded_budget_calculus_grant_constructors_exposed_mutant.hs",
      "forged", "Grant", "31:3-34:67", 31, 3,
      "src/Amoebius/Calculus/Budget/Grant.hs")
  , ("test/negative/compile_fail/determinism_jitcache/forge_blobsha.hs",
      "forged", "BlobSha", "6:10-6:28", 6, 10,
      "src/Amoebius/Kernel/ContentAddress.hs")
  , ("test/negative/compile_fail/extension_conformance/illegal/extension_conformance_forge_verdict.hs",
      "forgeVerdict", "ConformanceVerdict", "17:16-17:81", 17, 16,
      "src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs")
  , ("test/negative/compile_fail/infernix_lift/forge_ready_handle.hs",
      "forged", "ReadyArtifactHandle", "6:10-6:48", 6, 10,
      "src/Infernix/Adapter/Store.hs")
  , ("test/negative/compile_fail/lift_calculus/witness_asserted.hs",
      "entering", "Witness", "18:12-18:30", 18, 12,
      "src/Amoebius/Calculus/Lift/Witness.hs")
  , ("test/negative/compile_fail/lift_calculus/witness_asserted_lift_calculus_witness_constructor_exposed_mutant.hs",
      "entering", "Witness", "18:12-18:30", 18, 12,
      "src/Amoebius/Calculus/Lift/Witness.hs")
  , ("test/negative/compile_fail/scope_index/forge_request_scope_illegal.hs",
      "illegal", "RequestScope", "4:37-4:75", 4, 37,
      "src/scope-index/Amoebius/Scope/Attested.hs")
  , ("test/negative/compile_fail/scope_index/raw_resource_id_illegal.hs",
      "illegal", "ResourceId", "5:11-5:41", 5, 11,
      "src/scope-index/Amoebius/Scope/Attested.hs")
  , ("test/negative/determinism_jitcache/freestring_key.hs",
      "forged", "CacheKey", "6:10-6:51", 6, 10,
      "src/Amoebius/Jit/Cache.hs")
  ]

observeDeniedConstructor :: FilePath
  -> (FilePath, Text, Text, Text, Int, Int, FilePath)
  -> IO (Text, Text, Text, Text, Text, Bool)
observeDeniedConstructor directory (path, owner, target, rootSite, line, column, provider) = do
  let outputDir = directory </> "compiler-negative" </> "denied"
        </> Text.unpack (sha256Text (TextEncoding.encodeUtf8 (Text.pack path)))
      arguments = ["exec", "--jobs=1", "--builddir=.build/dist-native", "--", "ghc", "-j1",
        "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"]
        <> ["-i" <> sourceDir | sourceDir <- sourceDirs]
        <> ["-outputdir", outputDir, path]
  before <- trySynchronous (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  createDirectoryIfMissing True outputDir
  attempted <- trySynchronous (readProcessWithExitCode "cabal" arguments "")
    :: IO (Either SomeException (ExitCode, String, String))
  after <- trySynchronous (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  let digest = either (const "") sha256Text before
      valid = case (before, attempted, after) of
        (Right first, Right (ExitFailure _, _, stderrText), Right lastBytes)
          | first == lastBytes
          , Right [CompilerDiagnostic "ghc-9.12.4" "Error" 1928 source diagnosticLine
              diagnosticColumn messages] <- parseCompilerLines stderrText ->
              source == path && diagnosticLine == line && diagnosticColumn == column
                && siteStartsAt (line, column) rootSite
                && all (`Text.isInfixOf` Text.intercalate "\n" messages)
                     ["type constructor `" <> target <> "'", Text.pack provider]
        _ -> False
  pure (Text.pack path, owner, target, rootSite, digest, valid)
 where
  sourceDirs =
    ["src", "src/scope-index", "src/binding-subject", "src/extension-admission",
     "src/extension-graph", "src/extension-spec", "src/extension-capabilities",
     "src/calculus-composition", "src/capacity-topology", "src/vocabulary",
     "src/extension-conformance-gate", "src/extension-declaration",
     "src/extension-laws-compositional", "src/extension-laws",
     "src/extension-security-laws"]

scopeRejectionExpectations :: [(FilePath, Text, Text, Text, Int, Int, Int, Text)]
scopeRejectionExpectations =
  [ ("test/negative/compile_fail/ChildInForceSpec/NegativeAncestor.hs",
      "main", "childAncestorOnlyPayload", "10:25-10:55", 10, 25, 88464,
      "Variable not in scope")
  , ("test/negative/compile_fail/ChildInForceSpec/NegativeSibling.hs",
      "main", "childSiblingBranches", "10:25-10:51", 10, 25, 88464,
      "Variable not in scope")
  , ("test/negative/compile_fail/infernix_lift/url_engine_arm.hs",
      "downloadFromCallerUrl", "Url", "6:25-6:60", 6, 25, 88464,
      "Data constructor not in scope")
  , ("test/negative/compile_fail/scope_index/declassify_illegal.hs",
      "illegal", "declassify", "4:24-4:47", 4, 24, 88464,
      "Variable not in scope")
  , ("test/negative/compile_fail/transaction_vocabulary/illegal/transaction_vocabulary_predicate.hs",
      "program", "Vocabulary.predicate", "24:5-24:52", 24, 5, 76037,
      "does not export `predicate'")
  , ("test/negative/compile_fail/transaction_vocabulary/illegal/transaction_vocabulary_raw_query.hs",
      "program", "Vocabulary.rawStatement", "24:5-24:60", 24, 5, 76037,
      "does not export `rawStatement'")
  , ("test/negative/determinism_jitcache/url_arm.hs",
      "authored", "Url", "6:12-6:48", 6, 12, 88464,
      "Data constructor not in scope")
  , ("test/spec/dsl/capacity_topology_compile_fail/quorum_illegal.hs",
      "quorum", "Two", "4:10-4:17", 4, 10, 88464,
      "Data constructor not in scope")
  ]

observeScopeRejection :: FilePath
  -> (FilePath, Text, Text, Text, Int, Int, Int, Text)
  -> IO (Text, Text, Text, Text, Int, Text, Bool)
observeScopeRejection directory (path, owner, target, rootSite, line, column, code, fragment) = do
  let outputDir = directory </> "compiler-negative" </> "scope"
        </> Text.unpack (sha256Text (TextEncoding.encodeUtf8 (Text.pack path)))
      arguments = ["exec", "--jobs=1", "--builddir=.build/dist-native", "--", "ghc", "-j1",
        "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"]
        <> ["-i" <> sourceDir | sourceDir <- sourceDirs]
        <> ["-outputdir", outputDir, path]
  before <- trySynchronous (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  createDirectoryIfMissing True outputDir
  attempted <- trySynchronous (readProcessWithExitCode "cabal" arguments "")
    :: IO (Either SomeException (ExitCode, String, String))
  after <- trySynchronous (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  let digest = either (const "") sha256Text before
      valid = case (before, attempted, after) of
        (Right first, Right (ExitFailure _, _, stderrText), Right lastBytes)
          | first == lastBytes
          , Right [CompilerDiagnostic "ghc-9.12.4" "Error" observedCode source
              diagnosticLine diagnosticColumn messages] <- parseCompilerLines stderrText ->
              source == path && observedCode == code
                && diagnosticLine == line && diagnosticColumn == column
                && siteStartsAt (line, column) rootSite
                && target `Text.isInfixOf` Text.intercalate "\n" messages
                && fragment `Text.isInfixOf` Text.intercalate "\n" messages
        _ -> False
  pure (Text.pack path, owner, target, rootSite, code, digest, valid)
 where
  sourceDirs =
    ["src", "src/scope-index", "src/binding-subject", "src/extension-admission",
     "src/extension-graph", "src/extension-spec", "src/extension-capabilities",
     "src/transaction-vocabulary", "src/test-scope-support", "src/calculus-composition",
     "src/capacity-topology", "src/vocabulary", "src/extension-conformance-gate",
     "src/extension-declaration", "src/extension-laws-compositional",
     "src/extension-laws", "src/extension-security-laws"]

sha256Text :: ByteString.ByteString -> Text
sha256Text = Text.pack . concatMap (\byte ->
  [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)])
  . ByteString.unpack . SHA256.hash

siteStartsAt :: (Int, Int) -> Text -> Bool
siteStartsAt position site = case parseSite site of
  Just (start, _) -> start == position
  Nothing -> False

siteContainedBy :: Text -> Text -> Bool
siteContainedBy site rootSite = case (parseSite site, parseSite rootSite) of
  (Just (start, end), Just (rootStart, rootEnd)) -> rootStart <= start && end <= rootEnd
  _ -> False

parseSite :: Text -> Maybe ((Int, Int), (Int, Int))
parseSite site = case Text.splitOn "-" site of
  [start, end] -> (,) <$> parsePosition start <*> parsePosition end
  _ -> Nothing
 where
  parsePosition position = case Text.splitOn ":" position of
    [line, column] -> (,) <$> readInt line <*> readInt column
    _ -> Nothing
  readInt value = case reads (Text.unpack value) of
    [(number, "")] -> Just number
    _ -> Nothing

metadata :: [FilePath]
metadata = [".gitignore", ".dockerignore", "amoebius.cabal", "cabal.project", "probe/probe.cabal", "LICENSE"]

expectedChallengeTags :: [(Text, Text)]
expectedChallengeTags =
  [ ("python", "NonHaskellSource")
  , ("dhall", "ForeignSourceOwed")
  , ("pulumi", "TrackedPulumiProgram")
  , ("ordinal", "OrdinalRuntimeIdentity")
  , ("unmapped", "UnmappedHaskellSource")
  , ("vendor", "UnmappedHaskellSource")
  , ("syntax", "HaskellSourceUnparsable")
  ]

-- Independently close the reported unique call edges back from parsed IO seeds.
effectRouteClosure :: Ord node => Set.Set (node, node) -> Set.Set node -> Set.Set node
effectRouteClosure edges seeds = walk seeds (Set.toList seeds)
 where
  reverseEdges = Map.fromListWith Set.union
    [(callee, Set.singleton caller) | (caller, callee) <- Set.toList edges]
  walk visited [] = visited
  walk visited (callee : remaining) =
    let next = Map.findWithDefault Set.empty callee reverseEdges `Set.difference` visited
    in walk (Set.union visited next) (Set.toList next <> remaining)

componentClosureFromLinks :: Map Text (Set.Set Text) -> Text -> Set.Set Text
componentClosureFromLinks links start = walk Set.empty [start]
 where
  walk visited [] = visited
  walk visited (component : rest)
    | component `Set.member` visited = walk visited rest
    | otherwise = walk (Set.insert component visited)
        (Set.toList (Map.findWithDefault Set.empty component links) <> rest)

pathMatches :: Text -> Text -> Bool
pathMatches name path = case name of
  "python" -> "src/Challenge" `Text.isPrefixOf` path && ".py" `Text.isSuffixOf` path
  "dhall" -> "dhall/Challenge" `Text.isPrefixOf` path && ".dhall" `Text.isSuffixOf` path
  "pulumi" -> "pulumi/Pulumi" `Text.isPrefixOf` path && ".yaml" `Text.isSuffixOf` path
  "ordinal" -> "src/Amoebius/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  "unmapped" -> "src/Amoebius/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  "vendor" -> "src/vendor/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  "syntax" -> "test/negative/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  _ -> False

expectedClass :: FilePath -> Text
expectedClass path
  | path `elem` ["amoebius.cabal", "cabal.project", "probe/probe.cabal"] = "build-metadata"
  | path `elem` [".gitignore", ".dockerignore", "LICENSE"] = "repository-metadata"
  | path == "pb/__main__.py" = "bootstrap-source"
  | path `elem` ["AGENTS.md", "CLAUDE.md", "README.md"] = "governance-document"
  | headFolder path `elem` ["DEVELOPMENT_PLAN", "documents"] && takeExtension path == ".md" = "governance-document"
  | headFolder path `elem` ["src", "app", "test", "probe"] && takeExtension path == ".hs" = "haskell-source"
  | otherwise = "unclassified"

headFolder :: FilePath -> FilePath
headFolder = takeWhile (/= '/')

expectedCases :: [(Text, Text)]
expectedCases =
  [ ("positive.test-module", "haskell-source")
  , ("positive.probe-package", "build-metadata")
  , ("positive.bootstrap", "admitted")
  , ("positive.archive", "historical-evidence")
  , ("negative.test-script", "NonHaskellTestInput")
  , ("negative.test-table", "NonHaskellTestInput")
  , ("negative.python", "NonHaskellSource")
  , ("negative.dhall", "ForeignSourceOwed")
  , ("negative.pulumi", "TrackedPulumiProgram")
  , ("negative.tool", "TrackedToolRoot")
  , ("negative.archive", "UnexpectedValidationRecord")
  , ("negative.ordinal", "OrdinalRuntimeIdentity")
  , ("negative.absolute", "NonCanonicalPath")
  , ("positive.void", "historical-evidence")
  , ("negative.void-extra", "UnexpectedValidationRecord")
  , ("negative.bootstrap-change", "BootstrapDigestMismatch")
  , ("negative.bootstrap-import", "BootstrapImportRefusal")
  , ("negative.bootstrap-syntax", "BootstrapSyntaxRefusal")
  , ("negative.bootstrap-indentation", "BootstrapSyntaxRefusal")
  , ("negative.bootstrap-control", "BootstrapControlFlowRefusal")
  , ("negative.bootstrap-dynamic", "BootstrapDynamicCall")
  , ("negative.bootstrap-call", "BootstrapUnresolvedCall")
  , ("negative.bootstrap-indirect", "BootstrapUnresolvedCall")
  , ("negative.bootstrap-comprehension", "BootstrapSyntaxRefusal")
  , ("negative.bootstrap-effect", "BootstrapEffectOutsideAdapter")
  , ("negative.bootstrap-nested-effect", "BootstrapEffectOutsideAdapter")
  , ("negative.bootstrap-effect-string", "BootstrapDigestMismatch")
  , ("negative.ignore-root", "RetiredIgnoreRoot")
  , ("negative.ignore-source", "UnexpectedIgnorePattern")
  , ("report.bad-options", "exit-2")
  , ("report.nested-output", "exit-1")
  , ("report.shebang-exit", "exit-1")
  , ("report.default-exit", "exit-1")
  , ("report.paths-file-missing", "exit-2")
  , ("report.inventory-failure", "exit-2")
  , ("report.no-graph", "not-computed")
  , ("package.absent-module-reported", "missing")
  , ("package.absent-module-not-owed", "not-forward-owned")
  , ("package.unselected-module-membership", "([(\"provider\",\"provider-unit\")],[])")
  , ("graph.local-link", "linked")
  , ("graph.ambiguous-import", "refused")
  , ("graph.component-select", "selected")
  , ("graph.dependency-link", "linked")
  , ("graph.unlisted-dependency", "refused")
  , ("graph.inaccessible-internal", "located")
  , ("graph.package-qualified", "external")
  , ("graph.external-unit", "resolved")
  , ("graph.external-call-candidate", "candidate")
  , ("graph.external-member-parent", "matched")
  , ("graph.available-member-parent", "matched")
  , ("graph.external-open-import-call", "unattributed")
  , ("graph.implicit-prelude-export", "candidate")
  , ("graph.available-prelude-export", "candidate")
  , ("graph.standalone-prelude-export", "candidate")
  , ("graph.standalone-wired-cons", "candidate")
  , ("graph.open-import-interface-export", "filtered")
  , ("graph.external-hiding-import", "filtered")
  , ("graph.no-implicit-prelude", "suppressed")
  , ("graph.wired-cons-no-prelude", "candidate")
  , ("graph.wired-tuple-constructor", "candidate")
  , ("graph.open-import-call-opaque", "accounted")
  , ("graph.unplanned-component", "located")
  , ("graph.forward-owned-import", "owned")
  , ("graph.unselected-unit-candidate", "candidate")
  , ("graph.available-unit-interface", "resolved")
  , ("graph.available-unit-call", "exported")
  , ("graph.deferred-seed-import", "owned")
  , ("graph.deferred-seed-call", "bounded")
  , ("graph.deferred-seed-owner-filter", "filtered")
  , ("graph.deferred-seed-indirect-owner", "bound")
  , ("graph.package-plan-mismatch", "refused")
  , ("graph.package-unit-missing", "refused")
  , ("graph.imported-call-candidate", "candidate")
  , ("graph.class-method-import", "bound")
  , ("graph.instance-source-contract", "bound")
  , ("graph.class-call-dispatch", "potential")
  , ("graph.record-dot-selector", "projected")
  , ("graph.module-reexport-call", "traced")
  , ("graph.alias-reexport-call", "traced")
  , ("graph.qualified-reexport-filter", "filtered")
  , ("graph.explicit-reexport-call", "traced")
  , ("graph.explicit-data-reexport", "traced")
  , ("graph.hidden-reexport-filter", "selective")
  , ("graph.direct-hiding-selective", "selective")
  , ("graph.hiding-type-constructor", "filtered")
  , ("graph.unique-internal-call", "unique")
  , ("graph.ambiguous-internal-call", "ambiguous")
  , ("graph.shadow-no-internal-call", "absent")
  , ("graph.alias-call-candidate", "candidate")
  , ("graph.alias-imported-call", "linked")
  , ("graph.alias-imported-effect-route", "potential")
  , ("graph.filtered-call", "absent")
  , ("graph.no-component", "accounted")
  , ("graph.standalone-local-call", "candidate")
  , ("graph.standalone-lexical-call", "bound")
  , ("graph.standalone-imported-call", "exported")
  , ("graph.standalone-source-denied", "provisional")
  , ("graph.standalone-external-call", "exported")
  , ("graph.standalone-registered-only", "provisional")
  , ("graph.standalone-external-member", "matched")
  , ("graph.module-path-mismatch", "refused")
  , ("graph.local-call", "candidate")
  , ("graph.local-alias-route", "linked")
  , ("graph.alias-parameter-route", "bounded")
  , ("graph.alias-pattern-filter", "bounded")
  , ("graph.alias-qualified-route", "bounded")
  , ("graph.alias-external-interface", "filtered")
  , ("graph.type-signature", "located")
  , ("graph.effect-type-seed", "potential")
  , ("graph.effect-route-candidate", "potential")
  , ("graph.distinct-call-sites", "distinct")
  , ("graph.local-binding-call", "candidate")
  , ("graph.shadowed-call", "lexical")
  , ("graph.lexical-local-binding", "bound")
  , ("graph.lexical-parameter-binding", "bound")
  , ("graph.parameter-shadow", "lexical")
  , ("graph.case-shadow", "lexical")
  , ("graph.if-control-edges", "linked")
  , ("graph.case-control-edges", "linked")
  , ("graph.do-control-edges", "linked")
  , ("graph.guard-control-edges", "linked")
  , ("graph.do-shadow", "lexical")
  , ("graph.guard-shadow", "lexical")
  , ("graph.nested-call-coverage", "accounted")
  , ("graph.implicit-sequence-call", "projected")
  , ("graph.pattern-binding", "accounted")
  , ("graph.declaration-gap", "accounted")
  , ("package.fork-missing", "ForkDependencyUnregistered logging-3.0.6")
  , ("package.fork-complete", "accepted")
  , ("package.fork-duplicate", "ForkDependencyUnregistered managed-1.0.11")
  , ("package.fork-other-version", "ForkDependencyUnregistered managed-1.0.11")
  , ("package.fork-store-growth", "accepted")
  , ("package.fork-opaque-unit-id", "accepted")
  , ("package.fork-version-spoof", "ForkDependencyUnregistered logging-3.0.6")
  , ("package.fork-version-missing", "ForkDependencyUnregistered logging-3.0.6")

  , ("graph.plain-data-declaration", "projected")
  , ("graph.class-default-call", "accounted")
  , ("graph.instance-method-call", "accounted")
  , ("graph.instance-declaration", "projected")
  , ("graph.data-symbols", "accounted")
  , ("graph.derived-class-head", "projected")
  , ("graph.derived-interface-members", "bounded")
  , ("graph.data-call-candidates", "candidate")
  , ("graph.record-constructor-call", "candidate")
  , ("graph.higher-order-reference", "accounted")
  , ("graph.explicit-member-import", "candidate")
  , ("graph.explicit-member-filter", "filtered")
  , ("graph.unexported-member", "absent")
  , ("graph.imported-value-reference", "candidate")
  , ("graph.expression-splice", "located")
  , ("graph.declaration-splice", "located")
  , ("graph.foreign-boundary", "located")
  , ("graph.standalone-deriving", "accounted")
  , ("graph.standalone-deriving-member", "bounded")
  , ("challenge.python", "exit-1")
  , ("challenge.dhall", "exit-1")
  , ("challenge.pulumi", "exit-1")
  , ("challenge.ordinal", "exit-1")
  , ("challenge.unmapped", "exit-1")
  , ("challenge.vendor", "exit-1")
  , ("challenge.syntax", "exit-1")
  , ("owner.dhall", "typed_spine")
  , ("owner.proto", "typed_spine")
  , ("owner.ui-language", "ui_program_language_binding")
  , ("owner.ui-artifact", "ui_program_release")
  , ("identity.layout", "2")
  , ("fork.paths", Text.intercalate "," (map Text.pack (sort expectedForkPaths)))
  , ("fork.provenance", "matched")
  ]

expectedForkPaths :: [FilePath]
expectedForkPaths = map ("src/vendor/" <>)
  ["Control/Category/Dual.hs", "Data/Bifunctor/Flip.hs", "Pulsar.hs",
   "Pulsar/AppState.hs", "Pulsar/Connection.hs", "Pulsar/Consumer.hs",
   "Pulsar/Core.hs", "Pulsar/Internal/Core.hs", "Pulsar/Internal/Logger.hs",
   "Pulsar/Internal/TCPClient.hs", "Pulsar/Producer.hs", "Pulsar/Protocol/CheckSum.hs",
   "Pulsar/Protocol/Commands.hs", "Pulsar/Protocol/Decoder.hs", "Pulsar/Protocol/Encoder.hs",
   "Pulsar/Protocol/Frame.hs", "Pulsar/Types.hs"]

expectedStandaloneRole :: Text -> Maybe Text
expectedStandaloneRole path
  | Text.unpack path `elem` expectedForkPaths = Just "maintained-fork"
  | "test/negative/" `Text.isPrefixOf` path = Just "compile-negative"
  | "test/fixture/" `Text.isPrefixOf` path = Just "fixture"
  | "test/mutant/" `Text.isPrefixOf` path = Just "mutant-source"
  | "test/spec/dsl/compile/" `Text.isPrefixOf` path = Just "compile-positive"
  | "test/spec/dsl/compilefail/" `Text.isPrefixOf` path = Just "compile-negative"
  | "test/spec/dsl/capacity_topology_compile_fail/" `Text.isPrefixOf` path = Just "compile-negative"
  | path == "test/spec/formal/refinement/RefinementModelProjection.hs" = Just "model-projection"
  | path == "test/spec/formal/symbolic/FakeSmtSolver.hs" = Just "fake-boundary"
  | otherwise = Nothing

parsePairs :: Text -> Map Text Text
parsePairs contents = Map.fromList [(name, Text.intercalate "\t" rest) | line <- Text.lines contents, (name : rest) <- [Text.splitOn "\t" line]]

parseChallenges :: Text -> [(Text, Text, Text)]
parseChallenges contents = [(name, path, tag) | line <- Text.lines contents, [name, path, tag] <- [Text.splitOn "\t" line]]

-- | The suite plants every challenge under a fresh nonce, so a ledger that printed the planted paths could never
-- be derived twice. The ledger records them with the nonce replaced; the verdicts still judge the real paths.
challengeNonce :: [(Text, Text, Text)] -> Text
challengeNonce challenges = case [nonce | ("python", path, _) <- challenges, Just nonce <- [Text.stripPrefix "src/Challenge" path >>= Text.stripSuffix ".py"]] of
  nonce : _ -> nonce
  [] -> ""

maskNonce :: Text -> Text -> Text
maskNonce nonce text = if Text.null nonce then text else Text.replace nonce "<nonce>" text

readChallengeFinding :: FilePath -> (Text, Text, Text)
  -> IO (Text, Text, Text, [Text], Either Text StaticTextReport)
readChallengeFinding directory (name, path, tag) = do
  parsed <- (>>= parseStaticTextReport) <$> readReportText (directory </> "challenge-" <> Text.unpack name <> ".tsv")
  pure (name, path, tag, either (const []) (filter ("finding\t" `Text.isPrefixOf`) . staticTextOldRows) parsed, parsed)

-- The old prefix remains subject to every pre-existing discovery/finding rule.
-- New records are complete ordered data, never qualified source/AST authority.
data StaticTextReport = StaticTextReport [Text] [(Text, Text, Text)] [(Text, Text)]
  deriving (Eq, Show)

readReportText :: FilePath -> IO (Either Text Text)
readReportText path = do
  attempted <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  case attempted of
    Right bytes -> pure (either (const (Left "StaticTextReportInvalidUtf8")) Right (TextEncoding.decodeUtf8' bytes))
    Left problem | isDoesNotExistError problem -> pure (Left "StaticTextReportAbsent")
    Left problem -> throwIO problem

staticTextOldRows :: StaticTextReport -> [Text]
staticTextOldRows (StaticTextReport rows _ _) = rows

permanentStaticTextFinding :: (Text, Text, Text)
permanentStaticTextFinding =
  ("StaticTextBoundaryUnavailable", "layout-report",
   "Complete source capture, closing recheck, native syntax/byte observation and independent qualification remain unavailable.")

canonicalQuoted :: (Read value, Show value) => Text -> Either Text value
canonicalQuoted input = case readMaybe (Text.unpack input) of
  Just value | Text.pack (show value) == input -> Right value
  _ -> Left "MalformedStaticTextQuotedField"

parseStaticTextReport :: Text -> Either Text StaticTextReport
parseStaticTextReport contents
  | not ("\n" `Text.isSuffixOf` contents) = Left "StaticTextReportMissingFinalLF"
  | otherwise = expandLayoutReport contents >>= parseExpandedStaticTextReport

parseExpandedStaticTextReport :: Text -> Either Text StaticTextReport
parseExpandedStaticTextReport contents = do
      let rows = init (Text.splitOn "\n" contents)
          (oldRows, suffix) = break ("static-text-check\t" `Text.isPrefixOf`) rows
      unless (not (any (\row -> ("static-text-" `Text.isPrefixOf` row
          && not (any (`Text.isPrefixOf` row) ["static-text-example\t","static-text-capture-example\t"]))
          || "finding\t\"" `Text.isPrefixOf` row) oldRows)
        && (null oldRows || not (Text.null (last oldRows)))) (Left "MisplacedStaticTextRecord")
      afterCheck <- case suffix of
        check : rest -> case Text.splitOn "\t" check of
          ["static-text-check", encoded] -> do
            name <- canonicalQuoted encoded
            unless (name == ("layout-static-text" :: Text)) (Left "UnexpectedStaticTextCheckName")
            pure rest
          _ -> Left "MalformedStaticTextCheck"
        [] -> Left "StaticTextCheckMissing"
      let (findingRows, observationRows) = span ("finding\t" `Text.isPrefixOf`) afterCheck
      newFindings <- traverse parseFinding findingRows
      newObservations <- traverse parseObservation observationRows
      pure (StaticTextReport oldRows newFindings newObservations)
 where
  parseFinding row = case Text.splitOn "\t" row of
    ["finding", code, subject, detail] -> (,,) <$> canonicalQuoted code <*> canonicalQuoted subject <*> canonicalQuoted detail
    _ -> Left "MalformedStaticTextFinding"
  parseObservation row = case Text.splitOn "\t" row of
    ["static-text-observation", encoded] -> canonicalQuoted encoded
    _ -> Left "UnknownOrMisorderedStaticTextRow"

exactUnavailableStaticText :: Either Text StaticTextReport -> Bool
exactUnavailableStaticText parsed = case parsed of
  Right (StaticTextReport rows findings observations) ->
    findings == [permanentStaticTextFinding] && null observations
      && "graph-stage\tnot-computed" `elem` rows
      && not (any ("graph-file\t" `Text.isPrefixOf`) rows)
  Left _ -> False

-- The reference opens and rechecks the physical tree independently. Matching
-- serialized observations alone cannot qualify a missing capture boundary.
staticTextSemanticExpectation :: FilePath -> [FilePath] -> StaticTextReport -> IO (Either Text ())
staticTextSemanticExpectation root paths (StaticTextReport _ findings observations) = do
  expected <- staticTextReference expectedSinkTable root paths
  pure $ do
    (wantedFindings,wantedObservations) <- expected
    unless (findings == wantedFindings) (Left "StaticTextFindingMismatch")
    unless (observations == wantedObservations) (Left "StaticTextObservationMismatch")

staticTextDiagnostic :: Either Text StaticTextReport -> Text
staticTextDiagnostic parsed = case parsed of
  Left problem -> problem
  Right (StaticTextReport _ findings observations) ->
    "static-text-payload.v1;" <> compactStaticTextDiagnostic (Text.pack (show (findings, observations)))

-- Keep the complete diagnostic recoverable within the existing archive bound.
-- This changes only its retained encoding, not any semantic judgment or input.
compactStaticTextDiagnostic :: Text -> Text
compactStaticTextDiagnostic contents
  | ByteString.length encoded <= 1024 * 1024 = contents
  | otherwise = "interned-gzip-utf8-hex.v1:" <> Text.pack (concatMap hexByte (ByteString.unpack compressed))
 where
  encoded = TextEncoding.encodeUtf8 contents
  tokens = Text.groupBy (\left right -> isAlphaNum left == isAlphaNum right) contents
  names = Set.toAscList (Set.fromList tokens)
  dictionary = Map.fromList (zip names [0 :: Int ..])
  retained = TextEncoding.encodeUtf8 (Text.pack (show (names,[dictionary Map.! token | token <- tokens])))
  compressed = LazyBytes.toStrict (GZip.compress (LazyBytes.fromStrict retained))
  hexByte byte = [intToDigit (fromIntegral byte `div` 16),intToDigit (fromIntegral byte `mod` 16)]

renderCheck :: (Text, Bool, Text) -> Text
renderCheck (name, green, observed) = Text.intercalate "\t" [name, if green then "green" else "red", observed]

-- | The oracle's own catalogue of external effect primitives: for each kind and module,
-- the names that reach outside the process with the argument positions that carry a
-- path, an executable, or a command line. A primitive with no position takes no path.
expectedSinkEntries :: [(Text, Text, [(Int, Text)], [Text])]
expectedSinkEntries =
  [ ("process-exec", "System.Process", executable0,
      ["proc", "callProcess", "spawnProcess", "readProcess", "readProcessWithExitCode", "rawSystem",
       "runProcess", "runInteractiveProcess"])
  , ("process-exec", "System.Process", commandLine0,
      ["shell", "callCommand", "spawnCommand", "system", "runCommand", "runInteractiveCommand"])
  , ("process-exec", "System.Process", [],
      ["createProcess", "createProcess_", "withCreateProcess", "readCreateProcess", "readCreateProcessWithExitCode"])
  , ("process-exec", "System.Process.Typed", executable0, ["proc"])
  , ("process-exec", "System.Process.Typed", commandLine0, ["shell"])
  , ("process-exec", "System.Process.Typed", [],
      ["runProcess", "runProcess_", "readProcess", "readProcess_", "readProcessStdout", "readProcessStdout_",
       "startProcess", "withProcessWait", "withProcessTerm", "withProcessWait_", "withProcessTerm_",
       "readProcessInterleaved", "readProcessInterleaved_"])
  , ("process-exec", "System.Posix.Process", executable0, ["executeFile"])
  , ("process-exec", "System.Posix.Process", [], ["forkProcess"])
  ]
  <> concat
    [ [("file-read", moduleName, path0, ["readFile"]), ("file-write", moduleName, path0, ["writeFile", "appendFile"])]
    | moduleName <- ["Prelude", "System.IO"] <> contentModules ]
  <>
  [ ("file-read", "System.IO", path0, ["readFile'"])
  , ("file-open", "System.IO", path0,
      ["openFile", "withFile", "openBinaryFile", "withBinaryFile", "openTempFile", "openBinaryTempFile",
       "openTempFileWithDefaultPermissions", "openBinaryTempFileWithDefaultPermissions"])
  , ("file-write", "Data.ByteString.Builder", path0, ["writeFile"])
  , ("file-write", "System.IO.Temp", [], ["withSystemTempDirectory", "withSystemTempFile", "writeSystemTempFile"])
  , ("file-write", "System.IO.Temp", path0, ["withTempDirectory", "withTempFile", "createTempDirectory", "writeTempFile"])
  , ("file-read", "GHC.Data.StringBuffer", path0, ["hGetStringBuffer"])
  , ("file-read", "Data.Aeson", path0,
      ["eitherDecodeFileStrict", "eitherDecodeFileStrict'", "decodeFileStrict", "decodeFileStrict'"])
  , ("file-write", "Data.Aeson", path0, ["encodeFile"])
  , ("file-read", "Dhall", [(1, "path")], ["inputFile", "input"])
  , ("file-read", "Dhall", [(2, "path")], ["inputFileWithSettings", "inputWithSettings"])
  , ("file-read", "Dhall", path0, ["inputExpr"])
  , ("file-read", "Dhall", [(1, "path")], ["inputExprWithSettings"])
  , ("file-write", "Control.Logging", path0, ["withFileLogging"])
  , ("file-write", "System.Directory", path0,
      ["removeFile", "removeDirectory", "removeDirectoryRecursive", "removePathForcibly", "createDirectory",
       "removeDirectoryLink", "setPermissions", "setModificationTime", "setAccessTime", "setCurrentDirectory",
       "withCurrentDirectory"])
  , ("file-write", "System.Directory", [(0, "path"), (1, "path")],
      ["copyFile", "copyFileWithMetadata", "renameFile", "renameDirectory", "renamePath", "createFileLink",
       "createDirectoryLink", "copyPermissions"])
  , ("file-write", "System.Directory", [(1, "path")], ["createDirectoryIfMissing"])
  , ("file-query", "System.Directory", path0,
      ["doesFileExist", "doesDirectoryExist", "doesPathExist", "listDirectory", "getDirectoryContents",
       "getFileSize", "getModificationTime", "getAccessTime", "getPermissions", "canonicalizePath", "makeAbsolute",
       "makeRelativeToCurrentDirectory", "pathIsSymbolicLink", "getSymbolicLinkTarget"])
  , ("file-query", "System.Directory", executable0, ["findExecutable", "findExecutables"])
  , ("file-query", "System.Directory", [(1, "path")], ["findFile", "findFiles", "findFileWith"])
  , ("environment", "System.Directory", [],
      ["getCurrentDirectory", "getHomeDirectory", "getTemporaryDirectory", "getXdgDirectory",
       "getUserDocumentsDirectory", "getAppUserDataDirectory"])
  , ("file-write", "System.Posix.Files", path0,
      ["setFileMode", "removeLink", "setOwnerAndGroup", "setFileTimes", "touchFile", "createNamedPipe"])
  , ("file-write", "System.Posix.Files", [(0, "path"), (1, "path")], ["createSymbolicLink", "rename", "createLink"])
  , ("file-query", "System.Posix.Files", path0,
      ["getFileStatus", "getSymbolicLinkStatus", "fileExist", "readSymbolicLink"])
  , ("file-query", "System.PosixCompat.Files", path0, ["getSymbolicLinkStatus"])
  , ("file-query", "Data.Streaming.Filesystem", path0, ["openDirStream"])
  , ("file-query", "Data.Streaming.Filesystem", [], ["readDirStream", "closeDirStream"])
  , ("file-write", "System.Posix.Directory", path0, ["createDirectory", "removeDirectory", "changeWorkingDirectory"])
  , ("file-query", "System.Posix.Directory", path0, ["openDirStream"])
  , ("file-query", "System.Posix.Directory", [], ["readDirStream"])
  , ("environment", "System.Environment", [],
      ["getEnv", "lookupEnv", "getEnvironment", "setEnv", "unsetEnv", "getExecutablePath", "getArgs", "getProgName"])
  , ("network", "Network.Socket", [], ["socket", "connect", "bind", "listen", "accept", "getAddrInfo", "openSocket"])
  , ("network", "Network.Socket.ByteString", [], ["sendAll", "send", "recv"])
  , ("network", "Network.Socket.ByteString.Lazy", [], ["sendAll", "send", "recv"])
  , ("network", "Network.HTTP.Client", [], ["httpLbs", "httpNoBody", "withResponse", "newManager"])
  , ("network", "Network.HTTP.Client.TLS", [], ["newTlsManager", "tlsManagerSettings"])
  , ("dynamic-load", "Language.Haskell.TH", [], ["runIO"])
  , ("dynamic-load", "Language.Haskell.TH.Syntax", [], ["runIO"])
  , ("dynamic-load", "System.Posix.DynamicLinker", [], ["dlopen", "dlsym"])
  ]
  <> [ ("unsafe-effect", moduleName, [], ["unsafePerformIO", "unsafeInterleaveIO", "unsafeDupablePerformIO"])
     | moduleName <- ["System.IO.Unsafe", "GHC.IO", "GHC.IO.Unsafe"] ]
 where
  path0 = [(0, "path")]
  executable0 = [(0, "executable")]
  commandLine0 = [(0, "command-line")]
  contentModules = ["Data.Text.IO", "Data.Text.Lazy.IO", "Data.ByteString", "Data.ByteString.Char8",
                    "Data.ByteString.Lazy", "Data.ByteString.Lazy.Char8"]

-- | The catalogue one name at a time: module, name, kind, the function the name denotes
-- (a module that re-exports another's function names the same function), and the
-- argument positions with their roles.
expectedSinkTable :: [(Text, Text, Text, Text, [(Int, Text)])]
expectedSinkTable =
  [(moduleName, name, kind, home moduleName <> "." <> name, arguments)
  | (kind, moduleName, arguments, names) <- expectedSinkEntries, name <- names]
 where
  home moduleName = case moduleName of
    "Prelude" -> "System.IO"
    "Data.ByteString.Char8" -> "Data.ByteString"
    "Data.ByteString.Lazy.Char8" -> "Data.ByteString.Lazy"
    "Language.Haskell.TH.Syntax" -> "Language.Haskell.TH"
    "GHC.IO" -> "System.IO.Unsafe"
    "GHC.IO.Unsafe" -> "System.IO.Unsafe"
    _ -> moduleName

-- | The role and origin of a consumed argument, by the argument's role, whether the
-- literal begins the argument's own path expression, and the literal.
expectedConsumerClass :: Text -> Bool -> Text -> (Text, Text)
expectedConsumerClass argumentRole rooted literal = case argumentRole of
  "executable" -> ("executable", if not rooted then "dynamic-root"
                                  else if "/" `Text.isInfixOf` literal then expectedOrigin literal else "path-lookup")
  "command-line" -> ("command-line", if rooted then "shell" else "dynamic-root")
  _ -> (expectedRole literal, if rooted then expectedOrigin literal else "dynamic-root")

-- | The content role of a literal path fragment, by the extension of its last component.
expectedRole :: Text -> Text
expectedRole literal
  | Just role <- lookup extension
      [ (".hs", "haskell-source"), (".lhs", "haskell-source"), (".hsc", "haskell-source")
      , (".md", "documentation"), (".cabal", "package-metadata")
      , (".py", "foreign-source"), (".sh", "foreign-source"), (".js", "foreign-source")
      , (".purs", "foreign-source"), (".dhall", "foreign-source"), (".proto", "foreign-source")
      , (".yaml", "foreign-source"), (".yml", "foreign-source"), (".sql", "foreign-source")
      , (".tla", "foreign-source"), (".cfg", "foreign-source")
      , (".tsv", "data"), (".csv", "data"), (".json", "data"), (".txt", "data")
      , (".o", "artifact"), (".hi", "artifact"), (".a", "artifact"), (".so", "artifact")
      , (".tar", "artifact"), (".xz", "artifact"), (".gz", "artifact"), (".sig", "artifact") ] = role
  | Just role <- lookup lastComponent
      [ ("cabal.project", "package-metadata"), (".gitignore", "ignore-metadata")
      , (".dockerignore", "ignore-metadata"), ("LICENSE", "licence"), ("Dockerfile", "foreign-source") ] = role
  | otherwise = "unclassified"
 where
  lastComponent = Text.takeWhileEnd (/= '/') literal
  extension = case Text.breakOnEnd "." lastComponent of
    (before, after) | not (Text.null before), not (Text.null after) -> "." <> after
    _ -> ""

-- | Where a literal path lives, by its leading component.
expectedOrigin :: Text -> Text
expectedOrigin literal
  | leading == ".build" = "generated"
  | leading `elem` [".data", ".test_data"] = "state"
  | "/" `Text.isPrefixOf` literal || "~" `Text.isPrefixOf` literal = "external"
  | leading `elem` [ "src", "app", "test", "probe", "pb", "documents", "DEVELOPMENT_PLAN", "validation-records"
                   , "README.md", "AGENTS.md", "CLAUDE.md", "LICENSE", "amoebius.cabal", "cabal.project"
                   , ".gitignore", ".dockerignore" ] = "tracked"
  | otherwise = "unclassified"
 where
  leading = Text.takeWhile (/= '/') literal

expectedRow :: [Text] -> Text
expectedRow = Text.intercalate "\t"

-- | The rows the route fixture must produce, written from the fixture's source text.
expectedRoutesFixture :: Set.Set Text
expectedRoutesFixture = Set.fromList (map expectedRow
  [ ["graph-stage", "resolved"]
  , ["graph-derived-route", "Routes.hs", "Inferred", "Eq", "Eq", "inferred", "data", "stock-generated", "-", "generated", prelude]
  , ["graph-derived-route", "Routes.hs", "Inferred", "Show", "Show", "inferred", "data", "stock-generated", "-", "generated", prelude]
  , ["graph-derived-route", "Routes.hs", "External", "Show", "Show", "anyclass", "data", "anyclass-default", "Show", "external-class-default", prelude]
  , ["graph-derived-route", "Routes.hs", "Counter", "Eq", "Eq", "inferred", "newtype", "newtype-representation", "Int", "external-instance", prelude]
  , ["graph-derived-route", "Routes.hs", "Counter", "Ord", "Ord", "inferred", "newtype", "newtype-representation", "Int", "external-instance", prelude]
  , ["graph-derived-route", "Routes.hs", "Counter", "Show", "Show", "inferred", "newtype", "stock-generated", "-", "generated", prelude]
  , ["graph-derived-route", "Routes.hs", "Listed", "Functor", "Functor", "inferred", "newtype", "stock-generated", "-", "generated", prelude]
  , ["graph-derived-route", "Routes.hs", "Paired", "Eq", "Eq", "inferred", "newtype", "newtype-representation", "(,)", "external-instance", prelude]
  , ["graph-derived-route", "Routes.hs", "Poly", "Eq", "Eq", "newtype", "newtype", "newtype-representation", "f", "context-instance", prelude]
  , ["graph-derived-route", "Routes.hs", "Outer", "Marker", "Marker", "newtype", "newtype", "newtype-representation", "Inner", "source-instance", "local"]
  , ["graph-derived-route", "Routes.hs", "Plain", "Marker", "Marker", "anyclass", "data", "anyclass-default", "Marker", "source-class-default", "local"]
  , ["graph-derived-route", "Routes.hs", "Stock", "Eq", "Eq", "stock", "data", "stock-generated", "-", "generated", prelude]
  , ["graph-derived-route", "Routes.hs", "Wrapped", "Marker", "Marker", "via", "newtype", "via-representation", "Inner", "source-instance", "local"]
  , ["graph-derived-route-target", "Routes.hs", "Outer", "Marker", "Routes.hs", "Marker Inner"]
  , ["graph-derived-route-target", "Routes.hs", "Wrapped", "Marker", "Routes.hs", "Marker Inner"]
  , ["graph-standalone-deriving-route", "Routes.hs", "Eq Tagged", "Eq", "stock", "data", "stock-generated", "-", "generated", prelude]
  , ["graph-standalone-deriving-route", "Routes.hs", "Marker Loose", "Marker", "newtype", "newtype", "newtype-representation", "Inner", "source-instance", "local"]
  , ["graph-standalone-deriving-route-target", "Routes.hs", "Marker Loose", "Routes.hs", "Marker Inner"]
  , ["graph-instance-route", "Routes.hs", "Eq Manual", "Eq", "defaults", prelude]
  , ["graph-instance-route", "Routes.hs", "Marker Inner", "Marker", "methods", "local"]
  , ["graph-instance-route", "Routes.hs", "Marker Manual", "Marker", "methods", "local"]
  ])
 where
  prelude = "prelude:base:base-unit"

-- | The rows the unresolved-class fixture must produce: no route, and one named gap
-- per family, with the stage left partial.
expectedUnresolvedRoutesFixture :: Set.Set Text
expectedUnresolvedRoutesFixture = Set.fromList (map expectedRow
  [ ["graph-stage", "partial-calls"]
  , ["graph-derived-route", "RoutesUnresolved.hs", "Own", "Marker", "Marker", "newtype", "newtype", "newtype-representation", "Mystery", "delegate-unresolved", "local"]
  , ["graph-unscanned-declaration", "RoutesUnresolved.hs", "DerivedDelegateUnresolved"]
  , ["graph-unscanned-declaration", "RoutesUnresolved.hs", "DerivedClassUnresolved"]
  , ["graph-unscanned-declaration", "RoutesUnresolved.hs", "InstanceClassUnresolved"]
  , ["graph-unscanned-declaration", "RoutesUnresolved.hs", "StandaloneDerivingClassUnresolved"]
  ])

-- | The sink and consumer rows the sink fixture must produce. Shadowed names
-- (a parameter and a local binding called @readFile@) produce none.
expectedSinksFixture :: Set.Set Text
expectedSinksFixture = Set.fromList (map expectedRow
  [ ["graph-effect-sink-external", "Sinks.hs", "fetchNamed", "8:19-8:62", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "fetchLiteral", "9:16-9:48", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "storeGenerated", "10:23-10:68", "TextIO.writeFile", "Data.Text.IO", "writeFile", "file-write", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "copyBoth", "11:12-11:45", "copyFile", "System.Directory", "copyFile", "file-write", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "dollarForm", "12:14-12:57", "ByteString.readFile", "Data.ByteString", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "dollarChain", "13:15-13:60", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "dollarDynamic", "14:22-14:55", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "backtick", "15:12-15:47", "copyFile", "System.Directory", "copyFile", "file-write", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "referenceOnly", "16:28-16:43", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "reference"]
  , ["graph-effect-sink-external", "Sinks.hs", "processCommand", "19:18-19:49", "readProcess", "System.Process", "readProcess", "process-exec", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "exists", "20:10-20:37", "doesFileExist", "System.Directory", "doesFileExist", "file-query", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "environment", "21:15-21:31", "lookupEnv", "System.Environment", "lookupEnv", "environment", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "implicitPrelude", "22:19-22:37", "readFile", "Prelude", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "absolute", "23:12-23:36", "readFile", "Prelude", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "contentOnly", "24:20-24:107", "TextIO.writeFile", "Data.Text.IO", "writeFile", "file-write", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "nestedProcess", "25:26-25:100", "readCreateProcessWithExitCode", "System.Process", "readCreateProcessWithExitCode", "process-exec", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "nestedProcess", "25:57-25:96", "proc", "System.Process", "proc", "process-exec", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "dynamicMiddle", "26:21-26:54", "readFile", "Prelude", "readFile", "file-read", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "joined", "27:17-27:77", "writeFile", "Prelude", "writeFile", "file-write", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "commandLine", "28:15-28:39", "callCommand", "System.Process", "callCommand", "process-exec", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "controlLiteral", "29:18-29:46", "callCommand", "System.Process", "callCommand", "process-exec", "call"]
  , ["graph-effect-sink-external", "Sinks.hs", "ambient", "30:11-30:30", "getCurrentDirectory", "System.Directory", "getCurrentDirectory", "environment", "reference"]
  , ["graph-file-consumer", "Sinks.hs", "fetchNamed", "8:19-8:62", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "0", "amoebius.cabal", "package-metadata", "dynamic-root"]
  , ["graph-file-consumer", "Sinks.hs", "fetchLiteral", "9:16-9:48", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "0", "pb/__main__.py", "foreign-source", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "storeGenerated", "10:23-10:68", "TextIO.writeFile", "Data.Text.IO", "writeFile", "file-write", "0", ".build/out/report.tsv", "data", "generated"]
  , ["graph-file-consumer", "Sinks.hs", "copyBoth", "11:12-11:45", "copyFile", "System.Directory", "copyFile", "file-write", "0", "src/A.hs", "haskell-source", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "copyBoth", "11:12-11:45", "copyFile", "System.Directory", "copyFile", "file-write", "1", ".build/A.hs", "haskell-source", "generated"]
  , ["graph-file-consumer", "Sinks.hs", "dollarForm", "12:14-12:57", "ByteString.readFile", "Data.ByteString", "readFile", "file-read", "0", "documents/README.md", "documentation", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "dollarChain", "13:15-13:60", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "0", "documents/README.md", "documentation", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "dollarDynamic", "14:22-14:55", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "0", "x.hs", "haskell-source", "dynamic-root"]
  , ["graph-file-consumer", "Sinks.hs", "backtick", "15:12-15:47", "copyFile", "System.Directory", "copyFile", "file-write", "0", "src/A.hs", "haskell-source", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "backtick", "15:12-15:47", "copyFile", "System.Directory", "copyFile", "file-write", "1", ".build/B.hs", "haskell-source", "generated"]
  , ["graph-file-consumer", "Sinks.hs", "referenceOnly", "16:28-16:43", "TextIO.readFile", "Data.Text.IO", "readFile", "file-read", "0", "-", "-", "dynamic"]
  , ["graph-file-consumer", "Sinks.hs", "processCommand", "19:18-19:49", "readProcess", "System.Process", "readProcess", "process-exec", "0", "git", "executable", "path-lookup"]
  , ["graph-file-consumer", "Sinks.hs", "exists", "20:10-20:37", "doesFileExist", "System.Directory", "doesFileExist", "file-query", "0", "src/Main.hs", "haskell-source", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "implicitPrelude", "22:19-22:37", "readFile", "Prelude", "readFile", "file-read", "0", "LICENSE", "licence", "tracked"]
  , ["graph-file-consumer", "Sinks.hs", "absolute", "23:12-23:36", "readFile", "Prelude", "readFile", "file-read", "0", "/proc/meminfo", "unclassified", "external"]
  , ["graph-file-consumer", "Sinks.hs", "contentOnly", "24:20-24:107", "TextIO.writeFile", "Data.Text.IO", "writeFile", "file-write", "0", "-", "-", "dynamic"]
  , ["graph-file-consumer", "Sinks.hs", "nestedProcess", "25:57-25:96", "proc", "System.Process", "proc", "process-exec", "0", "-", "-", "dynamic"]
  , ["graph-file-consumer", "Sinks.hs", "dynamicMiddle", "26:21-26:54", "readFile", "Prelude", "readFile", "file-read", "0", "a", "unclassified", "unclassified"]
  , ["graph-file-consumer", "Sinks.hs", "dynamicMiddle", "26:21-26:54", "readFile", "Prelude", "readFile", "file-read", "0", "b.hs", "haskell-source", "dynamic-root"]
  , ["graph-file-consumer", "Sinks.hs", "joined", "27:17-27:77", "writeFile", "Prelude", "writeFile", "file-write", "0", "pass-", "unclassified", "dynamic-root"]
  , ["graph-file-consumer", "Sinks.hs", "joined", "27:17-27:77", "writeFile", "Prelude", "writeFile", "file-write", "0", "-ledger.tsv", "data", "dynamic-root"]
  , ["graph-file-consumer", "Sinks.hs", "commandLine", "28:15-28:39", "callCommand", "System.Process", "callCommand", "process-exec", "0", "git status", "command-line", "shell"]
  , ["graph-file-consumer", "Sinks.hs", "controlLiteral", "29:18-29:46", "callCommand", "System.Process", "callCommand", "process-exec", "0", "-", "-", "dynamic"]
  ])

-- | The stage and the open rows each stage fixture must produce, written from the
-- fixtures' source text: a clean module is resolved, and each fixture with exactly one
-- kind of open item is not.
expectedStagesFixture :: Set.Set Text
expectedStagesFixture = Set.fromList (map expectedRow
  [ ["clean", "graph-stage", "resolved"]
  , ["import", "graph-stage", "partial-calls"]
  , ["import", "graph-import-unresolved", "test:graph", "StageImport.hs", "Missing.Module", "component-not-in-plan"]
  , ["standalone", "graph-stage", "partial-calls"]
  , ["standalone", "graph-import-standalone-unresolved", "StageStandalone.hs", "Missing.Standalone", "standalone-unresolved"]
  , ["opaque", "graph-stage", "partial-calls"]
  , ["opaque", "graph-call-site-opaque", "test:graph", "StageOpaque.hs", "use", "2:7-2:16", "helper", "unattributed"]
  , ["expression", "graph-stage", "partial-calls"]
  , ["expression", "graph-unscanned", "StageExpression.hs", "hole", "UnboundVar"]
  , ["declaration", "graph-stage", "partial-calls"]
  , ["declaration", "graph-unscanned-declaration", "StageDeclaration.hs", "Annotation"]
  ])

-- | A standalone source importing a fork package's module is an available unit when the
-- catalogue declares the fork at its pinned version, and an open unresolved import when
-- it declares none: the declaration, not the registration alone, decides.
expectedForksFixture :: Set.Set Text
expectedForksFixture = Set.fromList (map expectedRow
  [ ["declared", "graph-import-standalone-available-unit", "ForkUser.hs", "Control.Logging", "logging", "logging-3.0.6-aa"]
  , ["undeclared", "graph-import-standalone-unresolved", "ForkUser.hs", "Control.Logging", "standalone-unresolved"]
  ])

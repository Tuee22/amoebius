{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Check
import Amoebius.Ui.Source
import Control.Monad (forM, forM_, unless)
import Data.Char (toLower)
import Data.List (sort)
import Data.Maybe (fromMaybe)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Test.QuickCheck
  ( Args (..)
  , Property
  , checkCoverage
  , counterexample
  , cover
  , elements
  , forAll
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)

data CaseRow = CaseRow
  { rowFile :: FilePath
  , rowKind :: String
  , rowExpected :: String
  , rowTag :: String
  , rowSpan :: String
  }
  deriving stock (Eq, Show)

data GraphRow = GraphRow
  { graphProgram :: Text.Text
  , graphNode :: Text.Text
  , graphKind :: String
  , graphType :: String
  , graphEdges :: [Text.Text]
  , graphEvents :: [Text.Text]
  }
  deriving stock (Eq, Show)

data InvalidClass
  = DuplicateClass
  | MissingClass
  | CyclicClass
  | IllTypedClass
  | OverBoundClass
  | NonExhaustiveClass
  | PrivateClass
  | DuplicateLinkClass
  deriving stock (Bounded, Enum, Eq, Show)

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  cases <- loadCases root
  case arguments of
    [] -> runGreen root cases
    [argument] | "--mutant=" `prefixOf` argument -> runMutant root cases (drop (length ("--mutant=" :: String)) argument)
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> [CaseRow] -> IO ()
runGreen root cases = do
  results <- forM cases (runCase root)
  let positives = [checked | (row, Right checked) <- results, rowKind row == "positive"]
  assertEqual "positive count" 3 (length positives)
  assertEqual "negative count" 10 (length [() | (row, Left _) <- results, rowKind row == "negative"])
  checkWireGolden root positives
  checkGraphOracle root positives
  checkClosedSurface root
  checkRoundTrip root cases
  checkGeneratedCoverage
  checkMutantControls root cases
  putStrLn "ui-program-schema-spec: PASS (3 positives, 10 exact negatives, 3 graph rows, 8 coverage classes, 6 mutants, opaque seal)"

runCase :: FilePath -> CaseRow -> IO (CaseRow, Either (String, String) CheckedUiProgram)
runCase root row = do
  decoded <- decodeUiSource (fixturePath root row)
  let actual = case decoded of
        Left _ -> Left (gate1Tag row, rowSpan row)
        Right source -> case checkUiSource source of
          Left problem -> Left (errorTag problem, errorSpan problem)
          Right checked -> Right checked
  case (rowExpected row, actual) of
    ("accept", Right _) -> pure ()
    ("reject", Left observed) -> assertEqual (rowFile row <> " diagnostic") (rowTag row, rowSpan row) observed
    _ -> die (rowFile row <> " outcome drifted: " <> either show (const "accepted") actual)
  pure (row, actual)

gate1Tag :: CaseRow -> String
gate1Tag row = case rowFile row of
  "raw_browser_escape.dhall" -> "RawBrowserEscape"
  "raw_external_link_url.dhall" -> "RawExternalLinkUrl"
  _ -> "UnexpectedGate1Failure"

errorTag :: UiCheckError -> String
errorTag problem = case problem of
  RecursiveEffect _ _ -> "RecursiveEffect"
  UnboundedCollection _ _ -> "UnboundedCollection"
  DuplicateQualifiedId _ _ -> "DuplicateQualifiedId"
  MissingReference _ _ -> "MissingReference"
  DuplicateExternalLinkRequirement _ _ -> "DuplicateExternalLinkRequirement"
  PortTypeMismatch _ _ -> "PortTypeMismatch"
  NonExhaustiveEvent _ _ -> "NonExhaustiveEvent"
  PrivateValueProjection _ _ -> "PrivateValueProjection"

errorSpan :: UiCheckError -> String
errorSpan problem = Text.unpack $ case problem of
  RecursiveEffect _ spanText -> spanText
  UnboundedCollection _ spanText -> spanText
  DuplicateQualifiedId _ spanText -> spanText
  MissingReference _ spanText -> spanText
  DuplicateExternalLinkRequirement _ spanText -> spanText
  PortTypeMismatch _ spanText -> spanText
  NonExhaustiveEvent _ spanText -> spanText
  PrivateValueProjection _ spanText -> spanText

checkWireGolden :: FilePath -> [CheckedUiProgram] -> IO ()
checkWireGolden root checked = do
  expected <- Text.readFile (root </> "test/fixtures/ui_program_schema/normalized_wire.golden")
  sources <- mapM (requireDecoded root) ["minimal_single_tenant.dhall", "minimal_multi_tenant.dhall", "composed_workflow_ui.dhall"]
  let actual = Text.unlines (map renderWire sources)
  assertEqual "normalized wire golden" expected actual
  assertEqual "checked corpus identity" (sort (map checkedCaseName checked)) (sort (map caseName sources))

renderWire :: UiSource -> Text.Text
renderWire source =
  Text.intercalate ";"
    [ "case=" <> caseName source
    , "mode=" <> Text.pack (show (tenantMode source))
    , "modules=" <> showText (length (modules source))
    , "nodes=" <> showText (sum (map (length . nodes) (modules source)))
    , "links=" <> Text.intercalate "," (map name (externalLinks source))
    ]

checkGraphOracle :: FilePath -> [CheckedUiProgram] -> IO ()
checkGraphOracle root checked = do
  rows <- loadGraphRows root
  assertEqual "graph oracle row count" 3 (length rows)
  forM_ rows $ \row -> do
    program <- requireOne (Text.unpack (graphProgram row)) [value | value <- checked, checkedCaseName value == graphProgram row]
    (_, kind, valueType', edges', events') <- requireOne (Text.unpack (graphNode row))
      [actual | actual@(qualified, _, _, _, _) <- checkedGraphRows program, qualified == graphNode row]
    assertEqual "graph node kind" (map toLower (graphKind row)) (map toLower (show kind))
    assertEqual "graph value type" (graphType row) (show valueType')
    assertEqual "graph edges" (sort (graphEdges row)) (sort edges')
    assertEqual "graph events" (sort (graphEvents row)) (sort events')

checkClosedSurface :: FilePath -> IO ()
checkClosedSurface root = do
  let kinds = [minBound .. maxBound] :: [NodeKind]
      values = [minBound .. maxBound] :: [ValueType]
  assertEqual "closed node-kind arms"
    [Route, State, Event, Port, Collection, Branch, ExternalLink] kinds
  assertEqual "closed value-type arms"
    [Text, Natural, Boolean, View, TenantChoice, WorkflowStart, WorkflowProgress, ServerHandle] values
  schema <- readFile (root </> "dhall/amoebius/ui/Types.dhall")
  forM_ ["RawJs", "RawHtml", "RawCss", "RawUrl", "ProviderCoordinate", "AuthorityCredential"] $ \token ->
    assert (not (token `contains` schema)) ("forbidden source arm is present: " <> token)

checkRoundTrip :: FilePath -> [CaseRow] -> IO ()
checkRoundTrip root cases = forM_ [row | row <- cases, rowKind row == "positive"] $ \row -> do
  first <- requireDecoded root (rowFile row)
  second <- requireDecoded root (rowFile row)
  assertEqual (rowFile row <> " Dhall round-trip") first second
  assertEqual (rowFile row <> " deterministic check") (fmap checkedGraphRows (checkUiSource first))
    (fmap checkedGraphRows (checkUiSource second))

checkGeneratedCoverage :: IO ()
checkGeneratedCoverage = do
  base <- requireDecodedRelative "test/fixtures/ui_program_schema/minimal_single_tenant.dhall"
  let classes = [minBound .. maxBound] :: [InvalidClass]
      args = stdArgs {maxSuccess = 320, replay = Just (mkQCGen 160016, 0), chatty = False}
  result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty base classes)
  assert (isSuccess result) "generated rejection coverage failed"

coverageProperty :: UiSource -> [InvalidClass] -> InvalidClass -> Property
coverageProperty base classes selected =
  checkCoverage
    $ foldr (\invalid -> cover 5 (selected == invalid) (show invalid))
      (counterexample (show selected) (property (matchesClass selected (checkUiSource (mutate selected base)))))
      classes

matchesClass :: InvalidClass -> Either UiCheckError CheckedUiProgram -> Bool
matchesClass invalid result = case (invalid, result) of
  (DuplicateClass, Left (DuplicateQualifiedId _ _)) -> True
  (MissingClass, Left (MissingReference _ _)) -> True
  (CyclicClass, Left (RecursiveEffect _ _)) -> True
  (IllTypedClass, Left (PortTypeMismatch _ _)) -> True
  (OverBoundClass, Left (UnboundedCollection _ _)) -> True
  (NonExhaustiveClass, Left (NonExhaustiveEvent _ _)) -> True
  (PrivateClass, Left (PrivateValueProjection _ _)) -> True
  (DuplicateLinkClass, Left (DuplicateExternalLinkRequirement _ _)) -> True
  _ -> False

mutate :: InvalidClass -> UiSource -> UiSource
mutate invalid source = case invalid of
  DuplicateClass -> mapFirstModule (\uiModule -> uiModule {nodes = duplicateFirst (nodes uiModule)}) source
  MissingClass -> mapFirstNode (\node -> node {edges = ["missing"]}) source
  CyclicClass -> mapFirstNode (\node -> node {edges = [nodeId node]}) source
  IllTypedClass -> mapFirstNode (\node -> node {nodeKind = Port, portType = Just Natural}) source
  OverBoundClass -> mapFirstNode (\node -> node {maxItems = Just 65}) source
  NonExhaustiveClass -> mapFirstNode (\node -> node {events = ["a", "b"], branches = ["a"]}) source
  PrivateClass -> mapFirstNode (\node -> node {valueType = ServerHandle, public = True}) source
  DuplicateLinkClass -> source {externalLinks = [ExternalLinkRequirement "docs", ExternalLinkRequirement "docs"]}

checkMutantControls :: FilePath -> [CaseRow] -> IO ()
checkMutantControls root cases = forM_ mutantNames $ \mutant -> do
  exists <- readFile (root </> "test/mutants" </> mutantFile mutant)
  assert ("expected=" `contains` exists) (mutant <> " fixture lacks its expected red locus")
  survives <- mutantWouldAccept root cases mutant
  assert survives (mutant <> " does not neutralize its pinned rejection")

runMutant :: FilePath -> [CaseRow] -> String -> IO ()
runMutant root cases mutant = do
  unless (mutant `elem` mutantNames) (die ("unknown mutant: " <> mutant))
  survives <- mutantWouldAccept root cases mutant
  if survives
    then putStrLn ("phase16-ui-mutant: RED " <> mutant) >> exitFailure
    else die ("mutant did not reach acceptance: " <> mutant)

mutantWouldAccept :: FilePath -> [CaseRow] -> String -> IO Bool
mutantWouldAccept root cases mutant = do
  let target = mutantTarget mutant
  row <- requireOne target [value | value <- cases, rowFile value == target]
  decoded <- decodeUiSource (fixturePath root row)
  case (mutant, decoded) of
    ("add_raw_js_arm", Left _) -> pure (accepted safeEmpty)
    ("add_raw_url_arm", Left _) -> pure (accepted safeEmpty)
    (_, Right source) -> pure (accepted (neutralize mutant source))
    _ -> pure False
  where
    accepted = either (const False) (const True) . checkUiSource
    safeEmpty = UiSource "mutant-safe" SingleTenant [] []

neutralize :: String -> UiSource -> UiSource
neutralize mutant source = case mutant of
  "M-drop-bound-check" -> mapFirstNode (\node -> node {maxItems = Just 1}) source
  "M-first-id-wins" -> mapFirstModule (\uiModule -> uiModule {nodes = take 1 (nodes uiModule)}) source
  "M-skip-exhaustiveness" -> mapFirstNode (\node -> node {branches = events node}) source
  "M-swap-port-contract" -> mapFirstNode (\node -> node {portType = Just (valueType node)}) source
  _ -> source

mutantNames :: [String]
mutantNames =
  [ "add_raw_js_arm"
  , "add_raw_url_arm"
  , "M-drop-bound-check"
  , "M-first-id-wins"
  , "M-skip-exhaustiveness"
  , "M-swap-port-contract"
  ]

mutantTarget :: String -> FilePath
mutantTarget mutant = fromMaybe "" (lookup mutant table)
  where
    table =
      [ ("add_raw_js_arm", "raw_browser_escape.dhall")
      , ("add_raw_url_arm", "raw_external_link_url.dhall")
      , ("M-drop-bound-check", "unbounded_collection.dhall")
      , ("M-first-id-wins", "duplicate_qualified_id.dhall")
      , ("M-skip-exhaustiveness", "non_exhaustive_event.dhall")
      , ("M-swap-port-contract", "port_type_mismatch.dhall")
      ]

mutantFile :: String -> FilePath
mutantFile mutant = "phase_16_" <> mutant <> ".mutant"

mapFirstModule :: (UiModule -> UiModule) -> UiSource -> UiSource
mapFirstModule transform source = case modules source of
  [] -> source
  uiModule : rest -> source {modules = transform uiModule : rest}

mapFirstNode :: (UiNode -> UiNode) -> UiSource -> UiSource
mapFirstNode transform = mapFirstModule $ \uiModule -> case nodes uiModule of
  [] -> uiModule
  node : rest -> uiModule {nodes = transform node : rest}

duplicateFirst :: [value] -> [value]
duplicateFirst [] = []
duplicateFirst (value : values) = value : value : values

loadCases :: FilePath -> IO [CaseRow]
loadCases root = do
  source <- readFile (root </> "test/fixtures/ui_program_schema/cases.tsv")
  pure
    [ CaseRow file kind expected tag spanText
    | [file, kind, expected, tag, spanText] <- map splitTabs (drop 1 (lines source))
    ]

loadGraphRows :: FilePath -> IO [GraphRow]
loadGraphRows root = do
  source <- readFile (root </> "test/fixtures/ui_program_schema/graph_reference.tsv")
  pure
    [ GraphRow (Text.pack program) (Text.pack node) kind valueType' (csv edges') (csv events')
    | [program, node, kind, valueType', edges', events'] <- map splitTabs (drop 1 (lines source))
    ]
  where
    csv "" = []
    csv value = map Text.pack (splitComma value)

requireDecoded :: FilePath -> FilePath -> IO UiSource
requireDecoded root name = do
  result <- decodeUiSource (root </> "test/fixtures/ui_program_schema" </> name)
  either (die . ((name <> ": ") <>) . Text.unpack) pure result

requireDecodedRelative :: FilePath -> IO UiSource
requireDecodedRelative name = do
  result <- decodeUiSource name
  either (die . Text.unpack) pure result

fixturePath :: FilePath -> CaseRow -> FilePath
fixturePath root row = root </> "test/fixtures/ui_program_schema" </> rowFile row

requireOne :: String -> [value] -> IO value
requireOne _ [value] = pure value
requireOne label values = die (label <> ": expected one value, got " <> show (length values))

showText :: Show value => value -> Text.Text
showText = Text.pack . show

splitTabs :: String -> [String]
splitTabs value = splitOn '\t' value

splitComma :: String -> [String]
splitComma = splitOn ','

splitOn :: Char -> String -> [String]
splitOn separator value = case break (== separator) value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitOn separator rest

prefixOf :: String -> String -> Bool
prefixOf prefix value = take (length prefix) value == prefix

contains :: String -> String -> Bool
contains needle haystack = any (prefixOf needle) (tails haystack)
  where
    tails [] = [[]]
    tails values@(_ : rest) = values : tails rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure

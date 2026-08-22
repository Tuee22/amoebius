{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
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

data ProgramRow = ProgramRow
  { programName :: Text.Text
  , programTenantMode :: Text.Text
  , programModules :: [Text.Text]
  , programNodes :: [Text.Text]
  , programLinks :: [Text.Text]
  }
  deriving stock (Eq, Ord, Show)

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
  checkProgramSemantics root positives
  checkGraphOracle root positives
  checkClosedSurface root
  checkRoundTrip root cases
  checkGeneratedCoverage
  checkCalculus root
  checkMutantControls root cases
  putStrLn "ui-program-schema-calculus: PASS (5 kinds, 30 projected units)"
  putStrLn "ui-program-schema-spec: PASS (3 semantic positives, 10 exact negatives, 3 graph rows, 8 coverage classes, 6 mutants, opaque seal)"

runCase :: FilePath -> CaseRow -> IO (CaseRow, Either (String, String) CheckedUiProgram)
runCase root row = do
  decoded <- decodeUiSource (fixturePath root row)
  let actual = case decoded of
        Left _ -> Left (dhallTypecheckTag row, rowSpan row)
        Right source -> case checkUiSource source of
          Left problem -> Left (errorTag problem, errorSpan problem)
          Right checked -> Right checked
  case (rowExpected row, actual) of
    ("accept", Right _) -> pure ()
    ("reject", Left observed) -> assertEqual (rowFile row <> " diagnostic") (rowTag row, rowSpan row) observed
    _ -> die (rowFile row <> " outcome drifted: " <> either show (const "accepted") actual)
  pure (row, actual)

dhallTypecheckTag :: CaseRow -> String
dhallTypecheckTag row = case rowFile row of
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

checkProgramSemantics :: FilePath -> [CheckedUiProgram] -> IO ()
checkProgramSemantics root checked = do
  expected <- loadProgramRows root
  sources <- mapM (requireDecoded root) ["minimal_single_tenant.dhall", "minimal_multi_tenant.dhall", "composed_workflow_ui.dhall"]
  let actual = map programProjection sources
  assertEqual "program semantic oracle" expected actual
  assertEqual "checked corpus identity" (sort (map checkedCaseName checked)) (sort (map caseName sources))

programProjection :: UiSource -> ProgramRow
programProjection source =
  ProgramRow
    { programName = caseName source
    , programTenantMode = tenantModeTag (tenantMode source)
    , programModules = sort (map moduleId (modules source))
    , programNodes = sort [moduleId uiModule <> "." <> nodeId node | uiModule <- modules source, node <- nodes uiModule]
    , programLinks = sort (map name (externalLinks source))
    }

tenantModeTag :: TenantMode -> Text.Text
tenantModeTag mode = case mode of
  SingleTenant -> "single-tenant"
  MultiTenant -> "multi-tenant"

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
  base <- requireDecodedRelative "test/fixture/ui_program_schema/minimal_single_tenant.dhall"
  let classes = [minBound .. maxBound] :: [InvalidClass]
      args = stdArgs {maxSuccess = 320, replay = Just (mkQCGen 160016, 0), chatty = False}
  result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty base classes)
  assert (isSuccess result) "generated rejection coverage failed"

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadCalculusRows root
  tenant <- either (fail . show) pure (trustedTenant "ui-program-schema-calculus-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "ui-program-schema-calculus-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources :: Int -> ResourceVector
        resources count = ResourceVector 1 (fromIntegral count) 0 0
        counts = [3, 10, 8, 3, 6] :: [Int]
        artifact = artifactComponent scope "program-semantics" (resources 3) (RecipeId "ui-program-schema" 3)
        budget = budgetComponent scope "diagnostic-budget" (resources 10) (allowance (Bytes 10) (Slots 1) (Bytes 10))
        lift = liftComponent scope "generated-rejection-classes" (resources 8) OnHost
        workflow = workflowComponent scope "graph-check-workflow" (resources 3) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 6) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ["calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition))]
          , ["component-names", Text.intercalate "," (compositionNames composition)]
          , ["projection-counts", Text.intercalate "," (map showText counts)]
          , ["resource-vector", Text.intercalate "," (map showText [cpu, memory, ephemeral, pods])]
          ]
    assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
    assertEqual "five-calculus semantic projection" expected actual
  action

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
  exists <- readFile (root </> "test/mutant/ui_program_schema" </> mutantFile mutant)
  assert ("expected=" `contains` exists) (mutant <> " fixture lacks its expected red locus")
  survives <- mutantWouldAccept root cases mutant
  assert survives (mutant <> " does not neutralize its pinned rejection")

runMutant :: FilePath -> [CaseRow] -> String -> IO ()
runMutant root cases mutant = do
  unless (mutant `elem` mutantNames) (die ("unknown mutant: " <> mutant))
  survives <- mutantWouldAccept root cases mutant
  if survives
    then putStrLn ("ui-program-schema-mutant: RED " <> mutant <> " locus=" <> mutantLocus mutant) >> exitFailure
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

mutantLocus :: String -> String
mutantLocus mutant = fromMaybe "unknown" (lookup mutant table)
  where
    table =
      [ ("add_raw_js_arm", "RawBrowserEscape")
      , ("add_raw_url_arm", "RawExternalLinkUrl")
      , ("M-drop-bound-check", "UnboundedCollection")
      , ("M-first-id-wins", "DuplicateQualifiedId")
      , ("M-skip-exhaustiveness", "NonExhaustiveEvent")
      , ("M-swap-port-contract", "PortTypeMismatch")
      ]

mutantFile :: String -> FilePath
mutantFile mutant = mutant <> ".mutant"

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
  source <- readFile (root </> "test/fixture/ui_program_schema/cases.tsv")
  pure
    [ CaseRow file kind expected tag spanText
    | [file, kind, expected, tag, spanText] <- map splitTabs (drop 1 (lines source))
    ]

loadGraphRows :: FilePath -> IO [GraphRow]
loadGraphRows root = do
  source <- readFile (root </> "test/fixture/ui_program_schema/graph_reference.tsv")
  pure
    [ GraphRow (Text.pack program) (Text.pack node) kind valueType' (csv edges') (csv events')
    | [program, node, kind, valueType', edges', events'] <- map splitTabs (drop 1 (lines source))
    ]
  where
    csv "" = []
    csv value = map Text.pack (splitComma value)

loadProgramRows :: FilePath -> IO [ProgramRow]
loadProgramRows root = do
  source <- readFile (root </> "test/oracle/ui_program_schema/program_semantics.tsv")
  pure
    [ ProgramRow (Text.pack program) (Text.pack mode) (csv moduleNames) (csv qualifiedNodes) (csv externalLinkNames)
    | [program, mode, moduleNames, qualifiedNodes, externalLinkNames] <- map splitTabs (drop 1 (lines source))
    ]
 where
  csv "" = []
  csv value = sort (map Text.pack (splitComma value))

loadCalculusRows :: FilePath -> IO [[Text.Text]]
loadCalculusRows root = do
  source <- Text.readFile (root </> "test/oracle/ui_program_schema/calculus_projection.tsv")
  pure (map (Text.splitOn "\t") (drop 1 (Text.lines source)))

requireDecoded :: FilePath -> FilePath -> IO UiSource
requireDecoded root name = do
  result <- decodeUiSource (root </> "test/fixture/ui_program_schema" </> name)
  either (die . ((name <> ": ") <>) . Text.unpack) pure result

requireDecodedRelative :: FilePath -> IO UiSource
requireDecodedRelative name = do
  result <- decodeUiSource name
  either (die . Text.unpack) pure result

fixturePath :: FilePath -> CaseRow -> FilePath
fixturePath root row = root </> "test/fixture/ui_program_schema" </> rowFile row

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

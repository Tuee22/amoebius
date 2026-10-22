{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the existing parked-checker examples.
-- This component diagnostic neither imports a checker nor supplies gate evidence.
module SolverDemotion (solverDemotionChecks, solverApiChecks, solverReintroductionChecks, solverSourceChecks, solverQualificationChecks) where

import Control.Monad (forM)
import Data.List (sort, nub)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesFileExist)
import System.Directory (doesPathExist)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import NativeApi (nativeApiChecks)
import Text.Read (readMaybe)

solverQualificationChecks :: FilePath -> FilePath -> IO [(Text, Bool, Text)]
solverQualificationChecks directory sourceRoot = do
  scope <- TextIO.readFile (directory </> "scope.data")
  cases <- readMaybe . Text.unpack <$> TextIO.readFile (directory </> "solver-inputs.data")
  output <- readMaybe . Text.unpack <$> TextIO.readFile (directory </> "solver-output.data")
  let left = "src/symbolic-checker/Amoebius/Checker/Symbolic.hs"
      right = "src/refinement-checker/Amoebius/Checker/Refinement.hs"
  symbolic <- TextIO.readFile (sourceRoot </> left)
  refinement <- TextIO.readFile (sourceRoot </> right)
  let originals = [(left, symbolic), (right, refinement)]
      definitions = [("fake-inductive", left, "data SymbolicResult", "  | Inconclusive ObligationKind String\n", "  | Inconclusive ObligationKind String\n  | Inductive [(ObligationKind, String)]\n")
        ,("fake-proved", right, "data RefinementStatus", "  = Inconclusive\n", "  = Inconclusive\n  | Proved\n")]
      expectedPairs = sort [(key, role) | (key, _, _, _, _) <- definitions, role <- ["positive", "negative"]]
      inputs = case cases :: Maybe (Int, [(Text, Text, [(FilePath, Text)])]) of Just (_, values) -> values; _ -> []
      results = maybe [] id (output :: Maybe [(Text, Text, Either Text [(Text, FilePath, Text)])])
      observed key role = [value | (name, control, value) <- results, name == key, control == role]
      supplied key role = [sort value | (name, control, value) <- inputs, name == key, control == role]
  runtime <- solverReintroductionChecks (directory </> "solver-runtime")
  let checks = concat [[("solver." <> key <> ".positive", observed key "positive" == [Right []], Text.pack (show (observed key "positive")))
        ,("solver." <> key <> ".negative", observed key "negative" == [Right [("SolverResultShape", target, locus)]], Text.pack (show (observed key "negative")))
        ,("solver." <> key <> ".delta", Text.count needle body == 1 && supplied key "positive" == [sort originals]
          && supplied key "negative" == [sort [(file, if file == target then Text.replace needle replacement value else value) | (file, value) <- originals]], "complete independent constructor projections")]
        | (key, target, marker, needle, replacement) <- definitions, Just body <- [lookup target originals]
        , let locus = case [Text.pack (show line) <> ":1" | (line, value) <- zip [1 :: Int ..] (Text.lines body), value == marker] of [found] -> found; _ -> "missing"]
  pure (("solver.discovery", scope == "snapshot" && sort [(key, role) | (key, role, _) <- inputs] == expectedPairs
    && sort [(key, role) | (key, role, _) <- results] == expectedPairs && length checks == 6, "exact independently named source controls") : checks <> runtime)

solverSourceChecks :: FilePath -> IO [(Text, Bool, Text)]
solverSourceChecks directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "solver-source.tsv")
  symbolic <- TextIO.readFile "src/symbolic-checker/Amoebius/Checker/Symbolic.hs"
  refinement <- TextIO.readFile "src/refinement-checker/Amoebius/Checker/Refinement.hs"
  removed <- not <$> doesPathExist (directory </> "source")
  let leftPath = "src/symbolic-checker/Amoebius/Checker/Symbolic.hs"
      rightPath = "src/refinement-checker/Amoebius/Checker/Refinement.hs"
      locus marker body = case [Text.pack (show number) <> ":1" | (number, line) <- zip [1 :: Int ..] (Text.lines body), line == marker] of [value] -> value; _ -> "missing"
      finding = Text.pack (show [("SolverResultShape" :: Text, leftPath, locus "data SymbolicResult" symbolic)])
      rightFinding = Text.pack (show [("SolverResultShape" :: Text, rightPath, locus "data RefinementStatus" refinement)])
      cases =
        [("baseline", symbolic, refinement, "findings", "[]")
        ,("inductive", Text.replace "  | Inconclusive ObligationKind String\n" "  | Inconclusive ObligationKind String\n  | Inductive [(ObligationKind, String)]\n" symbolic, refinement, "findings", finding)
        ,("renamed-positive", Text.replace "  | Inconclusive ObligationKind String\n" "  | Inconclusive ObligationKind String\n  | Certified\n" symbolic, refinement, "findings", finding)
        ,("proved", symbolic, Text.replace "  = Inconclusive\n" "  = Inconclusive\n  | Proved\n" refinement, "findings", rightFinding)
        ,("quoted", symbolic <> "\n-- Inductive is not an admitted constructor\nsolverDiagnostic = \"data SymbolicResult = Inductive\"\n", refinement, "findings", "[]")
        ,("missing-declaration", Text.replace "data SymbolicResult\n" "data ParkedResult\n" symbolic, refinement, "unavailable", "SolverResultDeclarationUnscanned:" <> leftPath)
        ,("missing-constructor", Text.replace "  | Unsupported [UnsupportedFeature]\n" "" symbolic, refinement, "findings", finding)
        ,("duplicate-declaration", symbolic <> "\ndata SymbolicResult = Duplicate\n", refinement, "unavailable", "SolverResultDeclarationUnscanned:" <> leftPath)
        ,("malformed", symbolic <> "\nunfinished = (\n", refinement, "unavailable", "SourceUnscanned:" <> leftPath)
        ,("missing-file", symbolic, "", "unavailable", "SolverSourceMissing:" <> rightPath)]
  controls <- forM cases $ \(name, left, right, state, expected) -> do
    observedLeft <- TextIO.readFile (directory </> "inputs" </> Text.unpack name </> "Symbolic.hs")
    observedRight <- TextIO.readFile (directory </> "inputs" </> Text.unpack name </> "Refinement.hs")
    let observed = [(kind, value) | [key, kind, value, _] <- rows, key == name]
    pure [("solver-source." <> name <> ".projection", observedLeft == left && observedRight == right, "complete independently specified source projection")
         ,("solver-source." <> name <> ".observation", observed == [(state, expected)], Text.pack (show observed))]
  pure ([("solver-source.discovery", sort [key | [key, _, _, _] <- rows] == sort [name | (name, _, _, _, _) <- cases] && all ((== 4) . length) rows, Text.pack (show rows))
        ,("solver-source.teardown", removed, Text.pack (show removed))
        ,("solver-source.identities", all (\row -> case row of [_, _, _, digest] -> Text.length digest == 64; _ -> False) rows && length [digest | [_, _, _, digest] <- rows] == length (nub [digest | [_, _, _, digest] <- rows]), "distinct captured source identities")]
    <> concat controls)

solverReintroductionChecks :: FilePath -> IO [(Text, Bool, Text)]
solverReintroductionChecks directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "solver-reintroduction.tsv")
  baselineRuntime <- ledger "clean" "runtime-ledger.tsv"
  baselineApi <- ledger "clean" "api-ledger.tsv"
  baselineIdentity <- identity "clean"
  controls <- forM ["clean", "fake-inductive", "fake-proved"] $ \name -> do
    runtime <- ledger name "runtime-ledger.tsv"
    api <- ledger name "api-ledger.tsv"
    observedIdentity <- identity name
    removed <- not <$> doesPathExist (directory </> Text.unpack name </> "source")
    source <- if name == "clean" then pure True else sourceDelta name
    let runtimeRed = case name of
          "fake-inductive" -> concat [["solver-demotion.symbolic." <> example <> ".grade", "symbolic." <> example <> ".authority"] | example <- ["inductive-counter", "coupled-invariants", "guarded-boolean"]]
          "fake-proved" -> ["solver-demotion.refinement." <> example <> "." <> field | example <- ["Increment", "Decrement", "Sum"], field <- ["grade", "reason"]]
          _ -> []
        apiRed = case name of "fake-inductive" -> ["solver-api.inductive"]; "fake-proved" -> ["solver-api.proved"]; _ -> []
        matches expected baseline observed = length observed == length baseline
          && sort [key | [key, _, _] <- observed] == sort [key | [key, _, _] <- baseline]
          && sort [key | [key, state, _] <- observed, state == "red"] == sort expected
          && all (\row -> case row of [_, state, _] -> state `elem` ["red", "green"]; _ -> False) observed
        exited = if name == "clean" then ExitSuccess else ExitFailure 1
        fields = [values | key : values <- rows, key == name]
        imagesOkay = case (baselineIdentity, observedIdentity) of
          (Just (baseSource, baseImages), Just (currentSource, images)) -> length images == 4
            && all (\(_, before, after) -> Text.length before == 64 && before == after) images
            && (name == "clean" || baseSource /= currentSource && case (drop (if name == "fake-inductive" then 0 else 1) baseImages, drop (if name == "fake-inductive" then 0 else 1) images) of
              ((_, a, _) : _, (_, b, _) : _) -> a /= b; _ -> False)
          _ -> False
    pure [("solver-reintroduction." <> name <> ".runtime", matches runtimeRed baselineRuntime runtime, Text.pack (show runtime))
         ,("solver-reintroduction." <> name <> ".api", matches apiRed baselineApi api, Text.pack (show api))
         ,("solver-reintroduction." <> name <> ".execution", fields == [[Text.pack (show ([ExitSuccess, ExitSuccess], exited, exited)), "True"]], Text.pack (show fields))
         ,("solver-reintroduction." <> name <> ".source", source, "complete independently specified product rewrite")
         ,("solver-reintroduction." <> name <> ".images", imagesOkay, Text.pack (show observedIdentity))
         ,("solver-reintroduction." <> name <> ".teardown", removed, Text.pack (show removed))]
  pure ([("solver-reintroduction.discovery", sort [key | [key, _, _] <- rows] == ["clean", "fake-inductive", "fake-proved"], Text.pack (show rows))
        ,("solver-reintroduction.baseline", length baselineRuntime == 74 && length baselineApi == 2 && all (\row -> case row of [_, "green", _] -> True; _ -> False) (baselineRuntime <> baselineApi), "74 runtime and two API rows")]
    <> concat controls)
 where
  ledger name file = map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> Text.unpack name </> file)
  identity name = readMaybe . Text.unpack <$> TextIO.readFile (directory </> Text.unpack name </> "identities.data") :: IO (Maybe (Text, [(FilePath, Text, Text)]))
  sourceDelta name = do
    contents <- TextIO.readFile (directory </> Text.unpack name </> "source-witness.data")
    let (target, edits) = if name == "fake-inductive" then
          ("src/symbolic-checker/Amoebius/Checker/Symbolic.hs",
            [("  | Inconclusive ObligationKind String\n", "  | Inconclusive ObligationKind String\n  | Inductive [(ObligationKind, String)]\n")
            ,("runObligations _ passed [] = pure (Right (case reverse passed of\n  (kind, _) : _ -> Inconclusive kind \"UNADMITTED-SOLVER: unsat responses do not establish induction\"\n  [] -> Unsupported [NoSafetyInvariants]))", "runObligations _ passed [] = pure (Right (Inductive (reverse passed)))")])
          else ("src/refinement-checker/Amoebius/Checker/Refinement.hs",
            [("  = Inconclusive\n", "  = Inconclusive\n  | Proved\n")
            ,("Right (makeResult Inconclusive \"UNADMITTED-SOLVER: unsat responses do not establish preservation or correspondence\" \"\")", "Right (makeResult Proved \"qualification reintroduction\" \"\")")])
    original <- TextIO.readFile target
    let expected = foldl (\body (needle, replacement) -> body >>= \value -> if Text.count needle value == 1 then Just (Text.replace needle replacement value) else Nothing) (Just original) edits
    pure (case readMaybe (Text.unpack contents) :: Maybe (FilePath, Text, Text) of
      Just (path, before, after) -> path == target && before == original && expected == Just after && after /= before
      _ -> False)

-- Component-only API twins; no numbered gate consumes the parked libraries.
solverApiChecks :: FilePath -> IO [(Text, Bool, Text)]
solverApiChecks directory = do
  symbolic <- nativeApiChecks directory [] ["src/symbolic-checker", "src"]
    ["import Amoebius.Checker.Symbolic", ""]
    [("solver-api.inductive", "SymbolicResult", "Inconclusive (BaseCase \"diagnostic\") \"unadmitted\"", "Inductive undefined", 7,
      ["[GHC-88464]", "Data constructor not in scope", "Inductive"])]
  refinement <- nativeApiChecks directory [] ["src/refinement-checker"]
    ["import Amoebius.Checker.Refinement", ""]
    [("solver-api.proved", "RefinementStatus", "Inconclusive", "Proved", 7,
      ["[GHC-88464]", "Data constructor not in scope", "Proved"])]
  pure (symbolic <> refinement)

solverDemotionChecks :: FilePath -> IO [(Text, Bool, Text)]
solverDemotionChecks directory = do
  symbolic <- rows <$> TextIO.readFile (directory </> "symbolic.tsv")
  refinement <- rows <$> TextIO.readFile (directory </> "refinement.tsv")
  invocationRows <- forM invocationCases $ \(family, name, required) -> do
    let path = directory </> Text.unpack family </> Text.unpack name </> "fake-smt-solver.transcript"
    present <- doesFileExist path
    contents <- if present then Text.lines <$> TextIO.readFile path else pure []
    let decoded = map (readMaybe . Text.unpack) contents :: [Maybe (String, String)]
        valid (Just (query, response)) = "(check-sat)" `Text.isInfixOf` Text.pack query
          && takeWhile (/= '\n') response `elem` ["sat", "unsat"]
        valid Nothing = False
        green = if required then present && not (null decoded) && all valid decoded else not present
    pure ("solver-demotion.invocation." <> family <> "." <> name, green, Text.pack (show (present, length contents)))
  pure (judge symbolic refinement <> invocationRows)
 where
  rows = map (Text.splitOn "\t") . Text.lines

invocationCases :: [(Text, Text, Bool)]
invocationCases =
  [("symbolic", name, name /= "unsupported-set") | (name, _) <- symbolicCases]
  <> [("refinement", name, name /= "Unknown") | (name, _, _, _, _) <- refinementCases]
  <> [("refinement-negative", "unbound-expression", False), ("refinement-negative", "ill-sorted-expression", False)]

judge :: [[Text]] -> [[Text]] -> [(Text, Bool, Text)]
judge symbolic refinement =
  [ equal "symbolic.discovery" (names (map fst symbolicCases)) (names (keys "symbolic" symbolic))
  , equal "refinement.discovery" (names (map first refinementCases)) (names (keys "refinement" refinement))
  , equal "symbolic.row-count" "8" (shown (length symbolic))
  , equal "refinement.row-count" "9" (shown (length refinement))
  , equal "symbolic.relative" "Left (SolverPathNotAbsolute \"z3\")" (field "solver" "symbolic-relative" 0 symbolic)
  , equal "refinement.relative" "Left (SolverPathNotAbsolute \"relative-solver\")" (field "solver" "refinement-relative" 0 refinement)
  , equal "refinement.unbound" "UnboundRefinementVariable \"missing\"" (field "refinement-negative" "unbound-expression" 0 refinement)
  , equal "refinement.ill-sorted" "RefinementSortMismatch \"and\" \"BooleanSort\" \"IntegerSort\"" (field "refinement-negative" "ill-sorted-expression" 0 refinement)
  ]
  <> concat
    [ [ equal ("symbolic." <> name <> ".grade") grade (field "symbolic" name 0 symbolic)
      , equal ("symbolic." <> name <> ".planned-obligations") obligations (field "symbolic" name 4 symbolic)
      , let observed = field "symbolic" name 1 symbolic
         in ("symbolic." <> name <> ".authority", grade == "Unsupported" || "UNADMITTED-SOLVER:" `Text.isInfixOf` observed, observed)
      ]
    | (name, obligations) <- symbolicCases
    , let grade = if name == "unsupported-set" then "Unsupported" else "Inconclusive"
    ]
  <> concat
    [ [ equal ("refinement." <> name <> ".grade") grade (field "refinement" name 0 refinement)
      , equal ("refinement." <> name <> ".reason") reason (field "refinement" name 1 refinement)
      , equal ("refinement." <> name <> ".function") function (field "refinement" name 2 refinement)
      , equal ("refinement." <> name <> ".source-line") "13" (field "refinement" name 3 refinement)
      , equal ("refinement." <> name <> ".source-digest") digest (field "refinement" name 4 refinement)
      ]
    | (name, function, grade, reason, digest) <- refinementCases
    ]
 where
  names = Text.intercalate "," . sort
  keys kind input = [name | tag : name : _ <- input, tag == kind]
  field kind name index input = case [drop 2 row | row@(tag : key : _) <- input, tag == kind, key == name] of
    [values] -> case drop index values of value : _ -> value; [] -> "missing-field"
    _ -> "missing-or-duplicate-row"
  equal name expected observed = ("solver-demotion." <> name, expected == observed, observed)
  shown = Text.pack . show
  first (value, _, _, _, _) = value

symbolicCases :: [(Text, Text)]
symbolicCases =
  [ ("inductive-counter", "2"), ("base-failure", "1"), ("step-failure", "2")
  , ("safe-noninductive", "3"), ("coupled-invariants", "4"), ("guarded-boolean", "2")
  , ("unsupported-set", "0")
  ]

refinementCases :: [(Text, Text, Text, Text, Text)]
refinementCases =
  [ ("Increment", "increment", "Inconclusive", unproved,
      "e6a45a39b182def55acb07935f89fe7320d585f22fd2e62333a12675aab6a875")
  , ("Decrement", "decrement", "Inconclusive", unproved,
      "9586a7905027e5aa0e4f0c70f48544e1e4751dc972323c726dc097eaef3ce0ac")
  , ("Sum", "sumNonNegative", "Inconclusive", unproved,
      "295f1e448cfdb630e22923854a75404b631cb4f9cc8aac13202ba7923bff2246")
  , ("Broken", "brokenDecrement", "Inconclusive",
      "UNADMITTED-SOLVER: sat response is an unverified postcondition counterexample",
      "1648f17f11b15efaac2e49617c1b494ff10434cd9e8d3ef901281a26ea48b9b3")
  , ("Mismatch", "negativeIdentity", "Inconclusive",
      "UNADMITTED-SOLVER: sat response is an unverified correspondence counterexample",
      "a465d0abf92906240933024d106d25592f8cfdc8aaaf2b015f06eb3f85c3f361")
  , ("Unknown", "unknownMapping", "UnknownInvariant",
      "annotation names no registered model invariant",
      "2046cfe0f35f3e840fac52a9be8f34d7bb9d9045807d89469def68d2d22191d0")
  ]
 where
  unproved = "UNADMITTED-SOLVER: unsat responses do not establish preservation or correspondence"

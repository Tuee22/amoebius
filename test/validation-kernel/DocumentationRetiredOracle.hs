{-# LANGUAGE OverloadedStrings #-}

module DocumentationRetiredOracle
  ( documentationRetiredControlProblems
  , documentationRetiredSelectorMatrixRows
  , documentationRetiredTargetProblems
  ) where

-- Independently literal component cases only. This module does not discover
-- production selectors, generate expectations, qualify a harness, or confer
-- a phase-gate pass.

import Amoebius.Validation.Documentation (documentationStructureDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Data.Text (Text)
import Data.Text qualified as Text

documentationRetiredSelectorMatrixRows :: [(String, String, [String], String)]
documentationRetiredSelectorMatrixRows =
  [ row "VALIDATION_DOCUMENT_RETIRED_CHECKED_IN_PREFIX_OMISSION_MUTANT" "retired checked-in prefix"
  , row "VALIDATION_DOCUMENT_RETIRED_COMMENT_LINE_ROUTE_OMISSION_MUTANT" "comment-elided single-line retired path"
  , row "VALIDATION_DOCUMENT_RETIRED_COMMITTED_PREFIX_OMISSION_MUTANT" "retired committed prefix"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_ALPHANUMERIC_OMISSION_MUTANT" "exact Haskell path alphanumeric alternative"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_CURRENT_SEGMENT_BYPASS_MUTANT" "exact Haskell path current-segment refusal"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_DOT_OMISSION_MUTANT" "exact Haskell path dot alternative"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_EMPTY_SEGMENT_BYPASS_MUTANT" "exact Haskell path empty-segment refusal"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_EMPTY_STEM_BYPASS_MUTANT" "exact Haskell path empty-stem refusal"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_HYPHEN_OMISSION_MUTANT" "exact Haskell path hyphen alternative"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_PARENT_SEGMENT_BYPASS_MUTANT" "exact Haskell path parent-segment refusal"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_SLASH_OMISSION_MUTANT" "exact Haskell path slash alternative"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_SUFFIX_BYPASS_MUTANT" "exact Haskell path suffix refusal"
  , row "VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_UNDERSCORE_OMISSION_MUTANT" "exact Haskell path underscore alternative"
  , row "VALIDATION_DOCUMENT_RETIRED_EXCLAMATION_CLAUSE_BOUNDARY_OMISSION_MUTANT" "retired phrase exclamation boundary"
  , row "VALIDATION_DOCUMENT_RETIRED_FIXTURES_ROOT_OMISSION_MUTANT" "retired fixtures root"
  , row "VALIDATION_DOCUMENT_RETIRED_FIXTURES_WORD_OMISSION_MUTANT" "retired fixtures word"
  , row "VALIDATION_DOCUMENT_RETIRED_FIXTURE_ROOT_OMISSION_MUTANT" "retired fixture root"
  , row "VALIDATION_DOCUMENT_RETIRED_FIXTURE_WORD_OMISSION_MUTANT" "retired fixture word"
  , row "VALIDATION_DOCUMENT_RETIRED_GOLDENS_ROOT_OMISSION_MUTANT" "retired goldens root"
  , row "VALIDATION_DOCUMENT_RETIRED_GOLDENS_WORD_OMISSION_MUTANT" "retired goldens word"
  , row "VALIDATION_DOCUMENT_RETIRED_GOLDEN_ROOT_OMISSION_MUTANT" "retired golden root"
  , row "VALIDATION_DOCUMENT_RETIRED_GOLDEN_WORD_OMISSION_MUTANT" "retired golden word"
  , row "VALIDATION_DOCUMENT_RETIRED_MUTANTS_ROOT_OMISSION_MUTANT" "retired mutants root"
  , row "VALIDATION_DOCUMENT_RETIRED_MUTANTS_WORD_OMISSION_MUTANT" "retired mutants word"
  , row "VALIDATION_DOCUMENT_RETIRED_MUTANT_ROOT_OMISSION_MUTANT" "retired mutant root"
  , row "VALIDATION_DOCUMENT_RETIRED_MUTANT_WORD_OMISSION_MUTANT" "retired mutant word"
  , row "VALIDATION_DOCUMENT_RETIRED_NEGATIVE_ROOT_OMISSION_MUTANT" "retired negative root"
  , row "VALIDATION_DOCUMENT_RETIRED_ORACLES_ROOT_OMISSION_MUTANT" "retired oracles root"
  , row "VALIDATION_DOCUMENT_RETIRED_ORACLES_WORD_OMISSION_MUTANT" "retired oracles word"
  , row "VALIDATION_DOCUMENT_RETIRED_ORACLE_ROOT_OMISSION_MUTANT" "retired oracle root"
  , row "VALIDATION_DOCUMENT_RETIRED_ORACLE_WORD_OMISSION_MUTANT" "retired oracle word"
  , row "VALIDATION_DOCUMENT_RETIRED_PERIOD_CLAUSE_BOUNDARY_OMISSION_MUTANT" "retired phrase period boundary"
  , row "VALIDATION_DOCUMENT_RETIRED_PHRASE_COMMENT_ROUTE_OMISSION_MUTANT" "comment-elided retired phrase"
  , row "VALIDATION_DOCUMENT_RETIRED_PHRASE_RAW_ROUTE_OMISSION_MUTANT" "raw retired phrase"
  , row "VALIDATION_DOCUMENT_RETIRED_QUESTION_CLAUSE_BOUNDARY_OMISSION_MUTANT" "retired phrase question boundary"
  , row "VALIDATION_DOCUMENT_RETIRED_RAW_LINE_ROUTE_OMISSION_MUTANT" "raw single-line retired path"
  , row "VALIDATION_DOCUMENT_RETIRED_ROOT_CASE_FOLD_OMISSION_MUTANT" "case-folded retired root"
  , row "VALIDATION_DOCUMENT_RETIRED_SEMICOLON_CLAUSE_BOUNDARY_OMISSION_MUTANT" "retired phrase semicolon boundary"
  , row "VALIDATION_DOCUMENT_RETIRED_WRAPPED_COMMENT_ROUTE_OMISSION_MUTANT" "comment-elided wrapped retired path"
  , row "VALIDATION_DOCUMENT_RETIRED_WRAPPED_RAW_ROUTE_OMISSION_MUTANT" "raw wrapped retired path"
  ]
 where
  row selector target = (selector, target, [selector], "retired-syntax harmless control")

documentationRetiredTargetProblems :: String -> Maybe [String]
documentationRetiredTargetProblems selector = do
  target <- lookupTarget selector
  pure (targetProblems target)

documentationRetiredControlProblems :: String -> Maybe [String]
documentationRetiredControlProblems selector = do
  _ <- lookupTarget selector
  pure
    ( expectExactRetired
        "retired-syntax harmless control"
        []
        (documentationStructureDiagnostic [(retiredSubject, "Ordinary documentation prose.\n")])
    )

lookupTarget :: String -> Maybe String
lookupTarget selector =
  case [target | (candidate, target, _, _) <- documentationRetiredSelectorMatrixRows, candidate == selector] of
    [target] -> Just target
    _ -> Nothing

targetProblems :: String -> [String]
targetProblems target = case target of
  "retired checked-in prefix" -> phraseAttack "checked-in" "fixture" "The checked in fixture is retained.\n"
  "comment-elided single-line retired path" ->
    exactPathAttack
      "comment-elided single-line retired path"
      "test/fixture/example.json"
      "test/fi<!-- concealed -->xture/example.json\n"
      "line 1 uses a retired tracked-artifact path: test/fixture/example.json"
  "retired committed prefix" -> phraseAttack "committed" "fixture" "The committed fixture is retained.\n"
  "exact Haskell path alphanumeric alternative" -> exactPathAdmission "test/fixture/Example1.hs"
  "exact Haskell path current-segment refusal" -> oneLinePathAttack "test/fixture/./Example.hs"
  "exact Haskell path dot alternative" -> exactPathAdmission "test/fixture/Example.hs"
  "exact Haskell path empty-segment refusal" -> oneLinePathAttack "test/fixture/sub//Example.hs"
  "exact Haskell path empty-stem refusal" -> oneLinePathAttack "test/fixture/.hs"
  "exact Haskell path hyphen alternative" -> exactPathAdmission "test/fixture/example-name.hs"
  "exact Haskell path parent-segment refusal" -> oneLinePathAttack "test/fixture/sub/../Example.hs"
  "exact Haskell path slash alternative" -> exactPathAdmission "test/fixture/sub/Example.hs"
  "exact Haskell path suffix refusal" -> oneLinePathAttack "test/fixture/Example.json"
  "exact Haskell path underscore alternative" -> exactPathAdmission "test/fixture/example_name.hs"
  "retired phrase exclamation boundary" -> clauseBoundaryControl '!'
  "retired fixtures root" -> oneLinePathAttack "test/fixtures/example.json"
  "retired fixtures word" -> phraseAttack "committed" "fixtures" "The committed fixtures are retained.\n"
  "retired fixture root" -> oneLinePathAttack "test/fixture/example.json"
  "retired fixture word" -> phraseAttack "committed" "fixture" "The committed fixture is retained.\n"
  "retired goldens root" -> oneLinePathAttack "test/goldens/example.json"
  "retired goldens word" -> phraseAttack "committed" "goldens" "The committed goldens are retained.\n"
  "retired golden root" -> oneLinePathAttack "test/golden/example.json"
  "retired golden word" -> phraseAttack "committed" "golden" "The committed golden is retained.\n"
  "retired mutants root" -> oneLinePathAttack "test/mutants/example.json"
  "retired mutants word" -> phraseAttack "committed" "mutants" "The committed mutants are retained.\n"
  "retired mutant root" -> oneLinePathAttack "test/mutant/example.json"
  "retired mutant word" -> phraseAttack "committed" "mutant" "The committed mutant is retained.\n"
  "retired negative root" -> oneLinePathAttack "test/negative/example.json"
  "retired oracles root" -> oneLinePathAttack "test/oracles/example.json"
  "retired oracles word" -> phraseAttack "committed" "oracles" "The committed oracles are retained.\n"
  "retired oracle root" -> oneLinePathAttack "test/oracle/example.json"
  "retired oracle word" -> phraseAttack "committed" "oracle" "The committed oracle is retained.\n"
  "retired phrase period boundary" -> clauseBoundaryControl '.'
  "comment-elided retired phrase" ->
    phraseAttack "committed" "fixture" "A committed <!-- . --> fixture is retained.\n"
  "raw retired phrase" -> phraseAttack "committed" "fixture" "<!-- A committed fixture is retained. -->\n"
  "retired phrase question boundary" -> clauseBoundaryControl '?'
  "raw single-line retired path" ->
    exactPathAttack
      "raw single-line retired path"
      "test/fixture/example.json"
      "<!-- test/fixture/example.json -->\n"
      "line 1 uses a retired tracked-artifact path: test/fixture/example.json"
  "case-folded retired root" -> oneLinePathAttack "TEST/FIXTURE/example.json"
  "retired phrase semicolon boundary" -> clauseBoundaryControl ';'
  "comment-elided wrapped retired path" ->
    exactPathAttack
      "comment-elided wrapped retired path"
      "test/fixture/example.json"
      "test/fi<!-- concealed\ninside -->xture/example.json\n"
      "physical line wrapping or a multiline HTML comment conceals a retired tracked-artifact path: test/fixture/example.json"
  "raw wrapped retired path" ->
    exactPathAttack
      "raw wrapped retired path"
      "test/fixture/example.json"
      "<!-- test/fi\nxture/example.json -->\n"
      "physical line wrapping or a multiline HTML comment conceals a retired tracked-artifact path: test/fixture/example.json"
  _ -> ["retired selector target is not implemented: " <> target]

retiredSubject :: FilePath
retiredSubject = "AGENTS.md"

oneLinePathAttack :: Text -> [String]
oneLinePathAttack offender =
  exactPathAttack
    ("retired path " <> Text.unpack offender)
    offender
    (offender <> "\n")
    ("line 1 uses a retired tracked-artifact path: " <> offender)

exactPathAdmission :: Text -> [String]
exactPathAdmission path =
  expectExactRetired
    ("exact Haskell path admission " <> Text.unpack path)
    []
    (documentationStructureDiagnostic [(retiredSubject, path <> "\n")])

exactPathAttack :: String -> Text -> Text -> Text -> [String]
exactPathAttack label _offender contents detail =
  expectExactRetired
    label
    [Finding "DOC-RETIRED-TRACKED-ARTIFACT" retiredSubject detail]
    (documentationStructureDiagnostic [(retiredSubject, contents)])

phraseAttack :: Text -> Text -> Text -> [String]
phraseAttack prefix artifact contents =
  expectExactRetired
    ("retired phrase " <> Text.unpack prefix <> " " <> Text.unpack artifact)
    [ Finding
        "DOC-RETIRED-TRACKED-ARTIFACT"
        retiredSubject
        ("document uses retired tracked-artifact wording: " <> prefix <> " … " <> artifact)
    ]
    (documentationStructureDiagnostic [(retiredSubject, contents)])

clauseBoundaryControl :: Char -> [String]
clauseBoundaryControl delimiter =
  expectExactRetired
    ("retired phrase clause boundary " <> [delimiter])
    []
    ( documentationStructureDiagnostic
        [ ( retiredSubject
          , "A committed decision ends"
              <> Text.singleton delimiter
              <> " A fixture is described.\n"
          )
        ]
    )

expectExactRetired :: String -> [Finding] -> CheckResult -> [String]
expectExactRetired label expected result =
  [ label
      <> ": exact retired finding projection differs; expected="
      <> show expected
      <> "; observed="
      <> show observed
  | observed /= expected
  ]
 where
  observed =
    [ item
    | item <- checkFindings result
    , findingCode item == "DOC-RETIRED-TRACKED-ARTIFACT"
    ]

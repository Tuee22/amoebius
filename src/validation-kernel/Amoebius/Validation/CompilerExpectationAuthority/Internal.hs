{-# LANGUAGE OverloadedStrings #-}

-- | Closed, source-bound expectation authority for the Cabal components that
-- exercise the package boundary.  This module states expectations; it does
-- not claim that Cabal elaboration or a compiler observation has occurred.
module Amoebius.Validation.CompilerExpectationAuthority.Internal
  ( CompilerExpectationAuthority
  , CompilerExpectationOutcome
  , CompilerExpectationProblem (..)
  , compilerExpectationAuthority
  , compilerExpectationAuthorityDigest
  , compilerExpectationAuthorityProblems
  , foldCompilerExpectationAuthority
  , foldCompilerExpectationOutcome
  , lookupCompilerExpectation
  ) where

import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Function (on)
import Data.List (groupBy, isPrefixOf, isSuffixOf, sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (isAbsolute, splitDirectories)

-- Constructors remain local so a consumer cannot manufacture a claimed
-- outcome and feed it back as an observation.
data CompilerExpectationOutcome
  = CompileSuccess
  | CompileRefusal
  | FixtureObservation
  deriving (Eq, Ord, Show)

data CompilerExpectationProblem
  = CompilerExpectationRowCardinalityMismatch Int Int
  | CompilerExpectationOutcomeCardinalityMismatch Text Int Int
  | CompilerExpectationDuplicateKey FilePath Text
  | CompilerExpectationDuplicatePath FilePath [Text]
  | CompilerExpectationDuplicateComponent Text [FilePath]
  | CompilerExpectationInvalidPath FilePath
  | CompilerExpectationInvalidComponent Text
  deriving (Eq, Ord, Show)

data CompilerExpectationRow
  = CompilerExpectationRow FilePath Text CompilerExpectationOutcome
  deriving (Eq, Ord, Show)

-- The constructor is deliberately private.  There is one compiled authority,
-- and no function turns caller-supplied rows or digest text into another one.
data CompilerExpectationAuthority
  = CompilerExpectationAuthority [CompilerExpectationRow] [CompilerExpectationProblem] Text

compilerExpectationAuthority :: CompilerExpectationAuthority
compilerExpectationAuthority =
  CompilerExpectationAuthority canonicalRows problems (digestRows canonicalRows)
 where
  canonicalRows = sort expectationRows
  problems = expectationProblems canonicalRows

compilerExpectationAuthorityProblems :: CompilerExpectationAuthority -> [CompilerExpectationProblem]
compilerExpectationAuthorityProblems (CompilerExpectationAuthority _ problems _) = problems

compilerExpectationAuthorityDigest :: CompilerExpectationAuthority -> Text
compilerExpectationAuthorityDigest (CompilerExpectationAuthority _ _ digest) = digest

-- | Exact lookup fails closed if the compiled table is internally invalid or
-- if the exact path/component pair is absent or duplicated.
lookupCompilerExpectation
  :: CompilerExpectationAuthority
  -> FilePath
  -> Text
  -> Maybe CompilerExpectationOutcome
lookupCompilerExpectation (CompilerExpectationAuthority rows problems _) path component
  | not (null problems) = Nothing
  | otherwise = case
      [ outcome
      | CompilerExpectationRow candidatePath candidateComponent outcome <- rows
      , candidatePath == path
      , candidateComponent == component
      ] of
      [outcome] -> Just outcome
      _ -> Nothing

-- | Project every exact row without exposing an authority or row constructor.
foldCompilerExpectationAuthority
  :: (result -> FilePath -> Text -> CompilerExpectationOutcome -> result)
  -> result
  -> CompilerExpectationAuthority
  -> result
foldCompilerExpectationAuthority project initial (CompilerExpectationAuthority rows _ _) =
  foldl' foldRow initial rows
 where
  foldRow result (CompilerExpectationRow path component outcome) =
    project result path component outcome

-- | The arguments are the success, refusal, and fixture projections.
foldCompilerExpectationOutcome
  :: result
  -> result
  -> result
  -> CompilerExpectationOutcome
  -> result
foldCompilerExpectationOutcome success refusal fixture outcome = case outcome of
  CompileSuccess -> success
  CompileRefusal -> refusal
  FixtureObservation -> fixture

expectedRowCount, expectedSuccessCount, expectedRefusalCount, expectedFixtureCount :: Int
expectedRowCount = 369
expectedSuccessCount = 14
expectedRefusalCount = 355
expectedFixtureCount = 0

expectationProblems :: [CompilerExpectationRow] -> [CompilerExpectationProblem]
expectationProblems rows =
  cardinalityProblems
    <> outcomeCardinalityProblems
    <> duplicateKeyProblems rows
    <> duplicatePathProblems rows
    <> duplicateComponentProblems rows
    <> pathProblems
    <> componentProblems
 where
  cardinalityProblems =
    [ CompilerExpectationRowCardinalityMismatch expectedRowCount (length rows)
    | length rows /= expectedRowCount
    ]
  outcomeCardinalityProblems =
    concat
      [ outcomeCountProblems "compile-success" CompileSuccess expectedSuccessCount
      , outcomeCountProblems "compile-refusal" CompileRefusal expectedRefusalCount
      , outcomeCountProblems "fixture-observation" FixtureObservation expectedFixtureCount
      ]
  outcomeCountProblems label outcome expected =
    [ CompilerExpectationOutcomeCardinalityMismatch label expected observed
    | let observed = length [() | CompilerExpectationRow _ _ candidate <- rows, candidate == outcome]
    , observed /= expected
    ]
  pathProblems =
    [ CompilerExpectationInvalidPath path
    | CompilerExpectationRow path _ _ <- rows
    , not (validExpectationPath path)
    ]
  componentProblems =
    [ CompilerExpectationInvalidComponent component
    | CompilerExpectationRow _ component _ <- rows
    , not (validExpectationComponent component)
    ]

duplicateKeyProblems :: [CompilerExpectationRow] -> [CompilerExpectationProblem]
duplicateKeyProblems rows =
  [ CompilerExpectationDuplicateKey path component
  | group@(CompilerExpectationRow path component _ : _) <- groupedBy rowKey rows
  , length group > 1
  ]

duplicatePathProblems :: [CompilerExpectationRow] -> [CompilerExpectationProblem]
duplicatePathProblems rows =
  [ CompilerExpectationDuplicatePath path (sort components)
  | group@(CompilerExpectationRow path _ _ : _) <- groupedBy rowPath rows
  , length group > 1
  , let components = [component | CompilerExpectationRow _ component _ <- group]
  ]

duplicateComponentProblems :: [CompilerExpectationRow] -> [CompilerExpectationProblem]
duplicateComponentProblems rows =
  [ CompilerExpectationDuplicateComponent component (sort paths)
  | group@(CompilerExpectationRow _ component _ : _) <- groupedBy rowComponent rows
  , length group > 1
  , let paths = [path | CompilerExpectationRow path _ _ <- group]
  ]

groupedBy :: Ord key => (CompilerExpectationRow -> key) -> [CompilerExpectationRow] -> [[CompilerExpectationRow]]
groupedBy project = groupBy ((==) `on` project) . sortOn project

rowKey :: CompilerExpectationRow -> (FilePath, Text)
rowKey (CompilerExpectationRow path component _) = (path, component)

rowPath :: CompilerExpectationRow -> FilePath
rowPath (CompilerExpectationRow path _ _) = path

rowComponent :: CompilerExpectationRow -> Text
rowComponent (CompilerExpectationRow _ component _) = component

validExpectationPath :: FilePath -> Bool
validExpectationPath path =
  "test/compile-negative/" `isPrefixOf` path
    && "/Main.hs" `isSuffixOf` path
    && not (isAbsolute path)
    && '\0' `notElem` path
    && '\\' `notElem` path
    && all validSegment (splitDirectories path)
    && case splitDirectories path of
      ["test", "compile-negative", directory, "Main.hs"] -> not (null directory)
      _ -> False
 where
  validSegment segment = not (null segment) && segment /= "." && segment /= ".."

validExpectationComponent :: Text -> Bool
validExpectationComponent component =
  "amoebius.cabal:test:validation-" `Text.isPrefixOf` component
    && not (Text.null component)
    && Text.count ":" component == 2
    && Text.all validCharacter component
 where
  validCharacter character =
    character /= '\0'
      && character /= ' '
      && character /= '\t'
      && character /= '\n'
      && character /= '\r'

digestRows :: [CompilerExpectationRow] -> Text
digestRows rows =
  Text.pack
    ( show
        ( Crypto.hash
            ( ByteString.concat
                ("amoebius.compiler-expectation-authority.v1\NUL" : concatMap encodeRow rows)
            )
            :: Crypto.Digest Crypto.SHA256
        )
    )

encodeRow :: CompilerExpectationRow -> [ByteString]
encodeRow (CompilerExpectationRow path component outcome) =
  [ encodeField (ByteString8.pack path)
  , encodeField (TextEncoding.encodeUtf8 component)
  , encodeField (ByteString8.pack (outcomeToken outcome))
  ]

encodeField :: ByteString -> ByteString
encodeField bytes =
  ByteString8.pack (show (ByteString.length bytes))
    <> ":"
    <> bytes

outcomeToken :: CompilerExpectationOutcome -> String
outcomeToken outcome = case outcome of
  CompileSuccess -> "compile-success"
  CompileRefusal -> "compile-refusal"
  FixtureObservation -> "fixture-observation"

expectationRow :: FilePath -> Text -> CompilerExpectationOutcome -> CompilerExpectationRow
expectationRow = CompilerExpectationRow

expectationRows :: [CompilerExpectationRow]
expectationRows =
  [ expectationRow "test/compile-negative/compiler-component-plan-assignment-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-assignment-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-assignment-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-assignment-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-component-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-component-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-config-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-config-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-config-renderer-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-config-renderer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-derive-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-derive-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-empty-plan-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-empty-plan-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-kind-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-kind-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-limit-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-limit-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-plan-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-plan-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-problem-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-problem-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-problem-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-problem-renderer-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-problem-renderer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-projection-digest-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-projection-digest-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-raw-analyzer-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-raw-analyzer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-raw-entry-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-raw-entry-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-snapshot-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-snapshot-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-component-plan-public-control/Main.hs" "amoebius.cabal:test:validation-compiler-component-plan-public-control" CompileSuccess
  , expectationRow "test/compile-negative/compiler-source-graph-acquired-type-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-acquired-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-acquired-constructor-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-acquired-constructor-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-snapshot-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-snapshot-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-check-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-check-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-acquired-analyzer-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-acquired-analyzer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-raw-analyzer-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-raw-analyzer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-source-graph-public-control/Main.hs" "amoebius.cabal:test:validation-compiler-source-graph-public-control" CompileSuccess
  , expectationRow "test/compile-negative/compiler-elaborated-plan-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-elaborated-plan-refusal-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-refusal-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-elaborated-plan-snapshot-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-snapshot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-elaborated-plan-problem-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-elaborated-plan-fold-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-fold-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-elaborated-plan-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-elaborated-plan-public-positive/Main.hs" "amoebius.cabal:test:validation-compiler-elaborated-plan-public-positive" CompileSuccess
  , expectationRow "test/compile-negative/compiler-buildinfo-public-control/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-public-control" CompileSuccess
  , expectationRow "test/compile-negative/compiler-buildinfo-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-refusal-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-refusal-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-eliminator-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-eliminator-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-expectations-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-expectations-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-snapshot-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-snapshot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-problem-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-expected-compiler-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-expected-compiler-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-expected-identity-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-expected-identity-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-component-identity-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-component-identity-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-argument-observation-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-argument-observation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-path-observation-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-path-observation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-generated-input-observation-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-generated-input-observation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-package-observation-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-package-observation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-component-observation-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-component-observation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-expectation-maker-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-expectation-maker-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-expectation-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-expectation-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-snapshot-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-snapshot-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-component-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-component-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/compiler-buildinfo-problem-projection-opacity/Main.hs" "amoebius.cabal:test:validation-compiler-buildinfo-problem-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/dispatch-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-dispatch-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/dispatch-snapshot-opacity/Main.hs" "amoebius.cabal:test:validation-dispatch-snapshot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/dispatch-discovery-opacity/Main.hs" "amoebius.cabal:test:validation-dispatch-discovery-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/dispatch-readiness-opacity/Main.hs" "amoebius.cabal:test:validation-dispatch-readiness-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/dispatch-validate-phase-opacity/Main.hs" "amoebius.cabal:test:validation-dispatch-validate-phase-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/dispatch-diagnostic-public-control/Main.hs" "amoebius.cabal:test:validation-dispatch-diagnostic-public-control" CompileSuccess
  , expectationRow "test/compile-negative/dispatch-command-public-control/Main.hs" "amoebius.cabal:test:validation-dispatch-command-public-control" CompileSuccess
  , expectationRow "test/compile-negative/evidence-finalized-dispatch-candidate-opacity/Main.hs" "amoebius.cabal:test:validation-evidence-finalized-dispatch-candidate-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/evidence-pass-criterion-evidence-opacity/Main.hs" "amoebius.cabal:test:validation-evidence-pass-criterion-evidence-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-analyze-effects-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-analyze-effects-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-analyze-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-analyze-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-audit-effects-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-audit-effects-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-audit-one-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-audit-one-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-authorized-consumer-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-authorized-consumer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-binding-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-binding-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-bindings-projection-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-bindings-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-check-function-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-check-function-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-classify-entries-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-classify-entries-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-compiler-residue-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-compiler-residue-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-content-consumers-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-content-consumers-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-content-path-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-content-path-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-content-role-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-content-role-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-effect-binding-name-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-effect-binding-name-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-effect-module-name-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-effect-module-name-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-effect-module-path-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-effect-module-path-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-effect-target-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-effect-target-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-effect-target-projection-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-effect-target-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-effect-use-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-effect-use-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-entry-class-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-entry-class-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-graph-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-graph-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-haskell-subject-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-haskell-subject-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-parsed-effect-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-parsed-effect-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-permanent-findings-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-permanent-findings-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-problem-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-problems-projection-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-problems-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-project-role-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-project-role-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-raw-effect-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-raw-effect-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-raw-entry-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-raw-entry-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-required-fact-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-required-fact-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-required-facts-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-required-facts-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-residue-facts-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-residue-facts-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-residue-projection-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-residue-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-residue-snapshot-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-residue-snapshot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-residue-subjects-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-residue-subjects-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-resolved-effect-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-resolved-effect-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-resolved-target-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-resolved-target-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-role-function-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-role-function-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-role-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-role-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-snapshot-projection-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-snapshot-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-subject-mode-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-subject-mode-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-subject-object-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-subject-object-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-subject-path-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-subject-path-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-use-opacity/Main.hs" "amoebius.cabal:test:validation-source-consumer-use-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-consumer-public-control/Main.hs" "amoebius.cabal:test:validation-source-consumer-public-control" CompileSuccess
  , expectationRow "test/compile-negative/pb-bootstrap-analyzer-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-analyzer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-argv-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-argv-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-ast-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-ast-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-binary-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-binary-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-binding-kind-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-binding-kind-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-binding-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-binding-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-canonical-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-canonical-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-cfg-edge-kind-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-cfg-edge-kind-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-cfg-edge-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-cfg-edge-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-cfg-node-kind-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-cfg-node-kind-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-cfg-node-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-cfg-node-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-control-flow-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-control-flow-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-effect-kind-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-effect-kind-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-effect-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-effect-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-effect-origin-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-effect-origin-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-effect-route-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-effect-route-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-ensure-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-ensure-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-environment-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-environment-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-function-cfg-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-function-cfg-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-import-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-import-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-injection-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-injection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-inventory-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-inventory-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-mode-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-mode-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-parser-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-parser-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-phase50-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-phase50-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-platform-adapter-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-platform-adapter-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-platform-limitation-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-platform-limitation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-platform-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-platform-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-problem-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-projection-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-call-count-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-call-count-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-cfg-summary-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-cfg-summary-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-effect-count-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-effect-count-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-expected-sha-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-expected-sha-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-import-closure-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-import-closure-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-platform-labels-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-platform-labels-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-resource-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-resource-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-runtime-residue-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-runtime-residue-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-static-claims-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-static-claims-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-subject-bytes-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-subject-bytes-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-subject-mode-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-subject-mode-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-proof-subject-path-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-proof-subject-path-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-py-argument-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-py-argument-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-py-operator-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-py-operator-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-py-statement-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-py-statement-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resolution-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resolution-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resolved-target-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resolved-target-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-ast-node-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-ast-node-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-ast-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-ast-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-bytes-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-bytes-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-call-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-call-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-control-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-control-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-depth-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-depth-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-effect-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-effect-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-problem-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-resource-token-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-resource-token-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-runtime-boundary-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-runtime-boundary-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-runtime-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-runtime-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-syntax-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-syntax-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-toolchain-opacity/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-toolchain-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/pb-bootstrap-public-control/Main.hs" "amoebius.cabal:test:validation-pb-bootstrap-public-control" CompileSuccess
  , expectationRow "test/compile-negative/source-debt-acquired-check-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-acquired-check-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-baseline-lookup-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-baseline-lookup-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-baseline-registry-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-baseline-registry-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-baseline-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-baseline-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-comparator-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-comparator-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-evidence-constructor-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-evidence-constructor-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-evidence-check-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-evidence-check-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-evidence-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-evidence-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-state-fold-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-state-fold-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-closure-check-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-closure-check-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-raw-check-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-raw-check-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-id-registry-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-id-registry-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-observation-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-observation-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-observer-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-observer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-problem-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-problem-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-problems-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-problems-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-state-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-debt-state-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-debt-public-control/Main.hs" "amoebius.cabal:test:validation-source-debt-public-control" CompileSuccess
  , expectationRow "test/compile-negative/source-snapshot-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-source-snapshot-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-semantic-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-phase-semantic-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-semantic-contract-slot-opacity/Main.hs" "amoebius.cabal:test:validation-phase-semantic-contract-slot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-semantic-registry-opacity/Main.hs" "amoebius.cabal:test:validation-phase-semantic-registry-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-semantic-join-parser-opacity/Main.hs" "amoebius.cabal:test:validation-phase-semantic-join-parser-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-semantic-identity-opacity/Main.hs" "amoebius.cabal:test:validation-phase-semantic-identity-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-resource-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-phase-resource-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-resource-slot-opacity/Main.hs" "amoebius.cabal:test:validation-phase-resource-slot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-resource-registry-opacity/Main.hs" "amoebius.cabal:test:validation-phase-resource-registry-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-acquired-source-snapshot-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-acquired-source-snapshot-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-classified-path-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-classified-path-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-git-executable-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-git-executable-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-git-object-format-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-git-object-format-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-index-entry-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-index-entry-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-index-flag-observation-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-index-flag-observation-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-index-mode-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-index-mode-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-snapshot-problem-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-snapshot-problem-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-class-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-class-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-closure-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-closure-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-debt-id-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-debt-id-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-facet-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-facet-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-snapshot-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-snapshot-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-tracked-entry-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-tracked-entry-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-worktree-entry-kind-type-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-worktree-entry-kind-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-acquired-source-snapshot-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-acquired-source-snapshot-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-classify-entry-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-classify-entry-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-classify-snapshot-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-classify-snapshot-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-check-git-reported-workspace-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-check-git-reported-workspace-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-combine-raw-executable-bits-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-combine-raw-executable-bits-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-compute-source-snapshot-identity-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-compute-source-snapshot-identity-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-closure-paths-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-closure-paths-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-closure-pb-bootstrap-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-closure-pb-bootstrap-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-closure-problems-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-closure-problems-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-closure-registered-debt-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-closure-registered-debt-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-closure-snapshot-identity-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-closure-snapshot-identity-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-final-index-boundary-problems-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-final-index-boundary-problems-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-inventory-authored-paths-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-inventory-authored-paths-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-load-git-snapshot-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-load-git-snapshot-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-load-git-snapshot-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-load-git-snapshot-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-mk-git-executable-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-mk-git-executable-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-object-format-boundary-problems-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-object-format-boundary-problems-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-parse-ls-files-stage-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-parse-ls-files-stage-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-parse-ls-files-tagged-stage-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-parse-ls-files-tagged-stage-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-parse-ls-files-tagged-paths-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-parse-ls-files-tagged-paths-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-registered-source-ids-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-registered-source-ids-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-repository-head-boundary-problems-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-repository-head-boundary-problems-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-render-snapshot-problem-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-render-snapshot-problem-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-render-source-debt-id-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-render-source-debt-id-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-debt-fingerprint-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-debt-fingerprint-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-debt-path-count-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-debt-path-count-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-closure-check-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-closure-check-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-source-closure-check-acquired-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-source-closure-check-acquired-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-verify-blob-object-id-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-verify-blob-object-id-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-raw-source-closure-diagnostic-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-raw-source-closure-diagnostic-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-snapshot-identity-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-snapshot-identity-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-entries-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-entries-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-path-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-path-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-path-depth-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-path-depth-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-path-segment-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-path-segment-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-mode-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-mode-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-object-identity-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-object-identity-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-blob-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-blob-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-aggregate-blob-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-aggregate-blob-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-semantic-line-bytes-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-semantic-line-bytes-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-problems-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-problems-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-maximum-raw-result-findings-value-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-maximum-raw-result-findings-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-source-closure-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/source-closure-public-control/Main.hs" "amoebius.cabal:test:validation-source-closure-public-control" CompileSuccess
  , expectationRow "test/compile-negative/legacy-gate-completion-premises-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-gate-completion-premises-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-gate-prerequisite-construction-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-gate-prerequisite-construction-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-closure-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-closure-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-active-register-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-active-register-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-analyzer-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-analyzer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-closure-rule-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-closure-rule-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-disposition-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-disposition-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-observation-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-observation-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-observation-rule-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-observation-rule-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-observed-state-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-observed-state-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-reintroduction-case-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-reintroduction-case-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-register-problem-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-register-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-active-register-from-snapshot-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-active-register-from-snapshot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-active-register-path-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-active-register-path-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-accepted-legacy-id-encodings-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-accepted-legacy-id-encodings-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-all-legacy-ids-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-all-legacy-ids-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-check-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-check-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-check-acquired-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-check-acquired-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-inventory-diagnostic-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-inventory-diagnostic-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-evaluate-legacy-observation-diagnostic-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-evaluate-legacy-observation-diagnostic-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-analyzer-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-analyzer-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-closure-rule-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-closure-rule-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-disposition-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-disposition-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-observation-rule-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-observation-rule-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-owner-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-owner-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-id-reintroduction-cases-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-id-reintroduction-cases-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-parse-active-register-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-parse-active-register-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-parse-legacy-id-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-parse-legacy-id-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-render-legacy-id-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-render-legacy-id-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-render-register-problem-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-render-register-problem-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-source-debt-legacy-id-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-source-debt-legacy-id-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-diagnostic-public-control/Main.hs" "amoebius.cabal:test:validation-legacy-diagnostic-public-control" CompileSuccess
  , expectationRow "test/compile-negative/legacy-raw-diagnostic-bindings-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-raw-diagnostic-bindings-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-raw-diagnostic-joins-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-raw-diagnostic-joins-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-internal-diagnostic-projection-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-internal-diagnostic-projection-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-binding-slot-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-binding-slot-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-binding-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-binding-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/legacy-legacy-binding-function-opacity/Main.hs" "amoebius.cabal:test:validation-legacy-legacy-binding-function-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-automation-role-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-automation-role-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-archive-register-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-archive-register-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-behavioral-language-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-behavioral-language-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-bootstrap-operation-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-bootstrap-operation-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-dsl-barrier-source-closure-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-dsl-barrier-source-closure-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-generation-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-generation-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-generation-root-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-generation-root-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-generation-timing-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-generation-timing-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-historical-evidence-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-historical-evidence-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-ordering-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-ordering-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-pb-admission-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-pb-admission-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-pb-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-pb-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-pb-source-language-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-pb-source-language-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-pb-transport-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-pb-transport-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-phase50-migration-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-phase50-migration-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-phase-ordinal-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-phase-ordinal-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-phase-role-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-phase-role-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-policy-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-policy-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-policy-id-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-policy-id-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-policy-owner-reference-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-policy-owner-reference-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-predecessor-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-predecessor-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-prehardware-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-prehardware-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-gate-pass-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-gate-pass-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-gate-completion-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-gate-completion-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-public-behavior-authority-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-public-behavior-authority-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-reset-phase-status-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-reset-phase-status-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-register-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-register-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-register-cardinality-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-register-cardinality-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-register-history-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-register-history-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-register-predicate-authority-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-register-predicate-authority-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-registry-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-registry-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-registry-placement-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-registry-placement-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-registry-provider-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-registry-provider-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-source-classification-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-source-classification-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-source-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-source-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-sprint-reset-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-sprint-reset-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-status-reset-contract-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-status-reset-contract-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-status-transition-rule-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-status-transition-rule-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-tracked-generated-artifact-type-opacity/Main.hs" "amoebius.cabal:test:validation-policy-tracked-generated-artifact-type-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-canonical-policy-contract-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-canonical-policy-contract-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-canonical-active-register-path-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-canonical-active-register-path-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-canonical-forbidden-archive-path-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-canonical-forbidden-archive-path-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-behavioral-source-suffix-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-behavioral-source-suffix-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-check-policy-contract-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-check-policy-contract-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-generation-root-path-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-generation-root-path-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-mk-phase-ordinal-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-mk-phase-ordinal-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-phase-ordinal-number-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-phase-ordinal-number-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-phase-role-ordinal-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-phase-role-ordinal-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-policy-contract-digest-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-policy-contract-digest-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-policy-owner-reference-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-policy-owner-reference-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-gate-pass-rule-marker-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-gate-pass-rule-marker-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-registry-image-reference-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-registry-image-reference-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-render-policy-contract-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-render-policy-contract-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-reset-phase-status-text-value-opacity/Main.hs" "amoebius.cabal:test:validation-policy-reset-phase-status-text-value-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-policy-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/policy-public-control/Main.hs" "amoebius.cabal:test:validation-policy-public-control" CompileSuccess
  , expectationRow "test/compile-negative/documentation-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-document-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-check-corpus-opacity/Main.hs" "amoebius.cabal:test:validation-document-check-corpus-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-check-document-structure-opacity/Main.hs" "amoebius.cabal:test:validation-document-check-document-structure-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-check-documents-opacity/Main.hs" "amoebius.cabal:test:validation-document-check-documents-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-check-policy-owner-references-opacity/Main.hs" "amoebius.cabal:test:validation-document-check-policy-owner-references-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-check-policy-owner-references-for-opacity/Main.hs" "amoebius.cabal:test:validation-document-check-policy-owner-references-for-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-github-anchor-opacity/Main.hs" "amoebius.cabal:test:validation-document-github-anchor-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/documentation-public-control/Main.hs" "amoebius.cabal:test:validation-document-public-control" CompileSuccess
  , expectationRow "test/compile-negative/phase-contract-internal-module-opacity/Main.hs" "amoebius.cabal:test:validation-phase-contract-internal-module-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-contract-check-phase-contracts-opacity/Main.hs" "amoebius.cabal:test:validation-phase-contract-check-phase-contracts-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-contract-check-phase-contract-structure-opacity/Main.hs" "amoebius.cabal:test:validation-phase-contract-check-phase-contract-structure-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-contract-check-phase-and-tracker-opacity/Main.hs" "amoebius.cabal:test:validation-phase-contract-check-phase-and-tracker-opacity-attack" CompileRefusal
  , expectationRow "test/compile-negative/phase-contract-public-control/Main.hs" "amoebius.cabal:test:validation-phase-contract-public-control" CompileSuccess
  ]

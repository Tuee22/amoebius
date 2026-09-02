{-# LANGUAGE OverloadedStrings #-}

module CompilerSubjectRegistryOracle
  ( runCompilerSubjectRegistryOracle
  ) where

import Amoebius.Validation.CompilerExpectationAuthority.Internal
  ( CompilerExpectationOutcome (..)
  , CompilerExpectationRow (..)
  , compilerExpectationAuthority
  , expectationProblemsFor
  , compilerExpectationAuthorityProblems
  , foldCompilerExpectationAuthority
  , foldCompilerExpectationOutcome
  )
import Amoebius.Validation.CompilerSubjectRegistry.Internal
  ( ExpectedCompilerOutcome (..)
  , SubjectRole (..)
  , acquireCompilerSubjectContract
  , compilerSubjectAssignments
  , compilerSubjectBindingAssignments
  , compilerSubjectRegistryCheck
  , deriveCompilerSubjectRegistry
  )
import Amoebius.Validation.SourceClosure.Internal
  ( IndexEntry (..)
  , IndexMode (RegularFile)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , sourceClosureInternalTestAcquire
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Monad (unless)
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text

runCompilerSubjectRegistryOracle :: IO ()
runCompilerSubjectRegistryOracle =
  unless (null problems)
    (fail (unlines ("CompilerSubjectRegistryOracle:" : map ("  " <>) problems)))
 where
  problems =
    authorityProblems
      <> cleanProblems
      <> precedenceProblems
      <> harnessProblems
      <> conditionalCompileNegativeProblems
      <> siblingProductProblems
      <> invisibleSiblingIdentityProblems
      <> nestedInvisibleSiblingProblems
      <> configurationCeilingProblems
      <> authorityPropertyProblems
      <> compileNegativePublicControlProblems
      <> unknownCompileNegativeProblems
      <> acquiredCoverageProblems
      <> emptyInventoryProblems

authorityProblems :: [String]
authorityProblems =
  [ "compiled expectation authority reported internal problems"
  | not (null (compilerExpectationAuthorityProblems compilerExpectationAuthority))
  ]
    -- The authority's digest, its row count, and its outcome partition are not
    -- asserted. Each was a measurement of an authored list restated as an
    -- expectation, so adding one compile-negative subject — ordinary Phase-15
    -- work — refused the documentation-suite gate, and the gate chain
    -- re-derives gate 0 inside every later phase. They were also redundant: the
    -- registry already refuses a row whose subject is absent
    -- (RegistryExpectationBindingMissing) and a subject whose row is absent
    -- (RegistryExpectedOutcomeMissing), in both directions.
    --
    -- The positive-control universe below is kept. It is not a magnitude but an
    -- authored inventory of the exact subjects that must COMPILE rather than be
    -- refused, which is the paired-positive half of the compile-fail corpus; a
    -- control silently becoming a refusal is precisely what it exists to catch.
    <> [ "compiled expectation authority positive-control universe changed"
       | sort successBindings /= expectedSuccessBindings
       ]
 where
  rows =
    foldCompilerExpectationAuthority
      (\values path component outcome -> (path, component, outcomeToken outcome) : values)
      []
      compilerExpectationAuthority
  successBindings = [(path, component) | (path, component, "success") <- rows]
  outcomeToken = foldCompilerExpectationOutcome "success" "refusal" "fixture"
  expectedSuccessBindings =
    sort
      [ ("test/compile-negative/compiler-buildinfo-public-control/Main.hs", "amoebius.cabal:test:validation-compiler-buildinfo-public-control")
      , ("test/compile-negative/compiler-component-plan-public-control/Main.hs", "amoebius.cabal:test:validation-compiler-component-plan-public-control")
      , ("test/compile-negative/compiler-elaborated-plan-public-positive/Main.hs", "amoebius.cabal:test:validation-compiler-elaborated-plan-public-positive")
      , ("test/compile-negative/compiler-source-graph-public-control/Main.hs", "amoebius.cabal:test:validation-compiler-source-graph-public-control")
      , ("test/compile-negative/dispatch-command-public-control/Main.hs", "amoebius.cabal:test:validation-dispatch-command-public-control")
      , ("test/compile-negative/dispatch-diagnostic-public-control/Main.hs", "amoebius.cabal:test:validation-dispatch-diagnostic-public-control")
      , ("test/compile-negative/documentation-public-control/Main.hs", "amoebius.cabal:test:validation-document-public-control")
      , ("test/compile-negative/legacy-diagnostic-public-control/Main.hs", "amoebius.cabal:test:validation-legacy-diagnostic-public-control")
      , ("test/compile-negative/pb-bootstrap-public-control/Main.hs", "amoebius.cabal:test:validation-pb-bootstrap-public-control")
      , ("test/compile-negative/phase-contract-public-control/Main.hs", "amoebius.cabal:test:validation-phase-contract-public-control")
      , ("test/compile-negative/policy-public-control/Main.hs", "amoebius.cabal:test:validation-policy-public-control")
      , ("test/compile-negative/source-closure-public-control/Main.hs", "amoebius.cabal:test:validation-source-closure-public-control")
      , ("test/compile-negative/source-consumer-public-control/Main.hs", "amoebius.cabal:test:validation-source-consumer-public-control")
      , ("test/compile-negative/source-debt-public-control/Main.hs", "amoebius.cabal:test:validation-source-debt-public-control")
      ]

cleanProblems :: [String]
cleanProblems =
  [ "single declared library module did not produce the exact independent assignment"
  | compilerSubjectAssignments registry
      /= [("src/A.hs", objectA, ProductSubject, ExpectedCompileSuccess, ["fixture.cabal:lib"])]
  ]
    <> ["single declared library module produced registry findings" | not (null (checkFindings check))]
    <> [ "unconditional library binding did not retain its exact branch identity"
       | compilerSubjectBindingAssignments registry
          /= [ ( "src/A.hs"
               , objectA
               , ProductSubject
               , ExpectedCompileSuccess
               , "fixture.cabal:lib"
               , "unconditional"
               )
             ]
       ]
 where
  registry = deriveCompilerSubjectRegistry (snapshot [cabalEntry ["src"], haskell "src/A.hs" objectA])
  check = compilerSubjectRegistryCheck registry

precedenceProblems :: [String]
precedenceProblems =
  [ "ordered hs-source-dirs did not bind the first exact source"
  | case compilerSubjectAssignments registry of
      ("src/first/A.hs", _, _, _, components) : _ -> components /= ["fixture.cabal:lib"]
      _ -> True
  ]
    <> [ "shadowed later source was not retained as an unassigned exact subject"
       | case compilerSubjectAssignments registry of
          [_first, ("src/second/A.hs", _, _, _, components)] -> not (null components)
          _ -> True
       ]
    <> [ "shadowed later source did not fail the two-way join"
       | length (checkFindings check) /= 1
       ]
 where
  registry =
    deriveCompilerSubjectRegistry
      (snapshot [cabalEntry ["src/first", "src/second"], haskell "src/first/A.hs" objectA, haskell "src/second/A.hs" objectB])
  check = compilerSubjectRegistryCheck registry

harnessProblems :: [String]
harnessProblems =
  [ "literal harness-owned positive did not retain its exact owner and expected outcome"
  | compilerSubjectAssignments registry
      /= [ ( "test/negative/compile_fail/ChildInForceSpec/Positive.hs"
           , objectA
           , CompileNegativeSubject
           , ExpectedCompileSuccess
           , ["harness:compile-fail-harness"]
           )
         ]
  ]
    <> ["literal harness-owned positive produced registry findings" | not (null (checkFindings check))]
 where
  registry =
    deriveCompilerSubjectRegistry
      (snapshot [haskell "test/negative/compile_fail/ChildInForceSpec/Positive.hs" objectA])
  check = compilerSubjectRegistryCheck registry

conditionalCompileNegativeProblems :: [String]
conditionalCompileNegativeProblems =
  [ "a conditionally buildable compile-negative component did not own its exact refusal subject"
  | compilerSubjectAssignments registry
      /= [ ( "test/compile-negative/compiler-component-plan-assignment-opacity/Main.hs"
           , objectA
           , CompileNegativeSubject
           , ExpectedCompileRefusal
           , ["amoebius.cabal:test:validation-compiler-component-plan-assignment-opacity-attack"]
           )
         ]
  ]
    <> [ "a conditionally buildable compile-negative component produced registry findings"
       | not (null (checkFindings check))
       ]
    <> [ "the active compile-negative branch identity was collapsed or selected incorrectly"
       | compilerSubjectBindingAssignments registry
          /= [ ( "test/compile-negative/compiler-component-plan-assignment-opacity/Main.hs"
               , objectA
               , CompileNegativeSubject
               , ExpectedCompileRefusal
               , "amoebius.cabal:test:validation-compiler-component-plan-assignment-opacity-attack"
               , "false:CNot (Var (PackageFlag (FlagName \"validation-compiler-component-plan-assignment-opacity-attack\")))"
               )
             ]
       ]
 where
  registry =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "amoebius.cabal"
              objectC
              ( unlines
                  [ "cabal-version: 3.0"
                  , "name: amoebius"
                  , "version: 0"
                  , "build-type: Simple"
                  , "flag validation-compiler-component-plan-assignment-opacity-attack"
                  , "  default: False"
                  , "  manual: True"
                  , "test-suite validation-compiler-component-plan-assignment-opacity-attack"
                  , "  type: exitcode-stdio-1.0"
                  , "  main-is: Main.hs"
                  , "  hs-source-dirs: test/compile-negative/compiler-component-plan-assignment-opacity"
                  , "  default-language: GHC2024"
                  , "  if !flag(validation-compiler-component-plan-assignment-opacity-attack)"
                  , "    buildable: False"
                  ]
              )
          , haskell "test/compile-negative/compiler-component-plan-assignment-opacity/Main.hs" objectA
          ]
      )
  check = compilerSubjectRegistryCheck registry

-- | Sibling conditions that cannot change a projected declaration field must
-- not multiply the configuration count.
--
-- Twenty @cpp-options@-only siblings describe 2^20 complete leaves under a
-- Cartesian sibling fold, every one of them byte-identical apart from a
-- rendered branch identity no consumer can accept.  The registry must observe
-- exactly one unconditional declaration instead.
siblingProductProblems :: [String]
siblingProductProblems =
  [ "cpp-options-only sibling conditions did not collapse to one unconditional declaration"
  | compilerSubjectBindingAssignments registry
      /= [ ( "src/A.hs"
           , objectA
           , ProductSubject
           , ExpectedCompileSuccess
           , "fixture.cabal:lib"
           , "unconditional"
           )
         ]
  ]
    <> [ "cpp-options-only sibling conditions produced registry findings"
       | not (null (checkFindings check))
       ]
 where
  siblings = [1 .. 20 :: Int]
  flagName ordinal = "sibling-" <> show ordinal <> "-mutant"
  registry =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "fixture.cabal"
              objectC
              ( unlines
                  ( [ "cabal-version: 3.0"
                    , "name: fixture"
                    , "version: 0"
                    , "build-type: Simple"
                    ]
                      <> concat
                        [ [ "flag " <> flagName ordinal
                          , "  default: False"
                          , "  manual: True"
                          ]
                        | ordinal <- siblings
                        ]
                      <> [ "library"
                         , "  exposed-modules: A"
                         , "  hs-source-dirs: src"
                         , "  default-language: GHC2024"
                         ]
                      <> concat
                        [ [ "  if flag(" <> flagName ordinal <> ")"
                          , "    cpp-options: -DSIBLING_" <> show ordinal
                          ]
                        | ordinal <- siblings
                        ]
                  )
              )
          , haskell "src/A.hs" objectA
          ]
      )
  check = compilerSubjectRegistryCheck registry

-- | A projection-invisible sibling must not enter the branch identity of a
-- sibling that is visible.
--
-- This is the conditional compile-negative fixture with one @cpp-options@-only
-- condition added beside its @buildable@ guard.  The expectation authority
-- admits an unconditional identity or a single decision, so a fold that
-- recorded both siblings would make the exact refusal subject unassignable.
invisibleSiblingIdentityProblems :: [String]
invisibleSiblingIdentityProblems =
  [ "an invisible sibling contaminated the exact compile-negative branch identity"
  | compilerSubjectBindingAssignments registry
      /= [ ( "test/compile-negative/compiler-component-plan-assignment-opacity/Main.hs"
           , objectA
           , CompileNegativeSubject
           , ExpectedCompileRefusal
           , "amoebius.cabal:test:validation-compiler-component-plan-assignment-opacity-attack"
           , "false:CNot (Var (PackageFlag (FlagName \"validation-compiler-component-plan-assignment-opacity-attack\")))"
           )
         ]
  ]
    <> [ "an invisible sibling beside a buildable guard produced registry findings"
       | not (null (checkFindings check))
       ]
 where
  registry =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "amoebius.cabal"
              objectC
              ( unlines
                  [ "cabal-version: 3.0"
                  , "name: amoebius"
                  , "version: 0"
                  , "build-type: Simple"
                  , "flag validation-compiler-component-plan-assignment-opacity-attack"
                  , "  default: False"
                  , "  manual: True"
                  , "flag invisible-sibling-mutant"
                  , "  default: False"
                  , "  manual: True"
                  , "test-suite validation-compiler-component-plan-assignment-opacity-attack"
                  , "  type: exitcode-stdio-1.0"
                  , "  main-is: Main.hs"
                  , "  hs-source-dirs: test/compile-negative/compiler-component-plan-assignment-opacity"
                  , "  default-language: GHC2024"
                  , "  if flag(invisible-sibling-mutant)"
                  , "    cpp-options: -DINVISIBLE_SIBLING_MUTANT"
                  , "  if !flag(validation-compiler-component-plan-assignment-opacity-attack)"
                  , "    buildable: False"
                  ]
              )
          , haskell "test/compile-negative/compiler-component-plan-assignment-opacity/Main.hs" objectA
          ]
      )
  check = compilerSubjectRegistryCheck registry

-- | Invisibility is decided through nesting, not only across flat siblings.
nestedInvisibleSiblingProblems :: [String]
nestedInvisibleSiblingProblems =
  [ "nested cpp-options-only conditions did not collapse to one unconditional declaration"
  | compilerSubjectBindingAssignments registry
      /= [ ( "src/A.hs"
           , objectA
           , ProductSubject
           , ExpectedCompileSuccess
           , "fixture.cabal:lib"
           , "unconditional"
           )
         ]
  ]
    <> [ "nested cpp-options-only conditions produced registry findings"
       | not (null (checkFindings check))
       ]
 where
  registry =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "fixture.cabal"
              objectC
              ( unlines
                  [ "cabal-version: 3.0"
                  , "name: fixture"
                  , "version: 0"
                  , "build-type: Simple"
                  , "flag outer-mutant"
                  , "  default: False"
                  , "  manual: True"
                  , "flag inner-mutant"
                  , "  default: False"
                  , "  manual: True"
                  , "library"
                  , "  exposed-modules: A"
                  , "  hs-source-dirs: src"
                  , "  default-language: GHC2024"
                  , "  if flag(outer-mutant)"
                  , "    cpp-options: -DOUTER_MUTANT"
                  , "    if flag(inner-mutant)"
                  , "      cpp-options: -DINNER_MUTANT"
                  ]
              )
          , haskell "src/A.hs" objectA
          ]
      )
  check = compilerSubjectRegistryCheck registry

-- | The configuration ceiling is an admission bound, not a diagnostic.
--
-- A minimally different pair around @maximumComponentConfigurations@: twelve
-- visible binary siblings describe exactly 4,096 configurations and must be
-- admitted, while thirteen describe 8,192 and must be refused by
-- @component-configurations@ before any leaf is built.  The refusal must arrive
-- with no declaration bound, because a partial declaration list presented as a
-- complete registry is the failure the ceiling exists to prevent.
configurationCeilingProblems :: [String]
configurationCeilingProblems =
  [ "twelve visible sibling conditions were refused at the configuration ceiling"
  | not (null (ceilingFindings 12))
  ]
    <> [ "thirteen visible sibling conditions were admitted past the configuration ceiling"
       | null (ceilingFindings 13)
       ]
    <> [ "the configuration ceiling refusal did not name component-configurations"
       | not (any (Text.isInfixOf "component-configurations") (ceilingFindings 13))
       ]
    <> [ "a refused component still bound an exact subject"
       | not (null (compilerSubjectBindingAssignments (ceilingRegistry 13)))
       ]
 where
  ceilingFindings count = map findingDetail (checkFindings (compilerSubjectRegistryCheck (ceilingRegistry count)))
  ceilingRegistry siblingCount =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "fixture.cabal"
              objectC
              ( unlines
                  ( [ "cabal-version: 3.0"
                    , "name: fixture"
                    , "version: 0"
                    , "build-type: Simple"
                    ]
                      <> concat
                        [ [ "flag guard-" <> show ordinal
                          , "  default: False"
                          , "  manual: True"
                          ]
                        | ordinal <- [1 .. siblingCount]
                        ]
                      <> [ "library"
                         , "  exposed-modules: A"
                         , "  hs-source-dirs: src"
                         , "  default-language: GHC2024"
                         ]
                      <> concat
                        [ [ "  if flag(guard-" <> show ordinal <> ")"
                          , "    buildable: False"
                          ]
                        | ordinal <- [1 .. siblingCount :: Int]
                        ]
                  )
              )
          , haskell "src/A.hs" objectA
          ]
      )

-- | Each property of the expectation registry, driven over a supplied row list.
--
-- The authority is one compiled constant, so before the 'expectationProblemsFor'
-- seam existed an oracle could assert only that the live list is clean — never
-- that a malformed one is refused. Every case below differs from
-- 'wellFormedRows' in exactly one dimension and must produce exactly its own
-- refusal.
authorityPropertyProblems :: [String]
authorityPropertyProblems =
  exactlyTagged "a well-formed registry" wellFormedRows []
    <> exactlyTagged
      "a collapsed registry"
      (take 3 wellFormedRows)
      ["CompilerExpectationRegistryCollapsed"]
    <> exactlyTagged
      "a fixture outcome on a compile-negative subject"
      (syntheticRow 1 FixtureObservation : drop 1 wellFormedRows)
      ["CompilerExpectationFixtureOutcomeForbidden"]
    <> exactlyTagged
      "a duplicated row"
      (syntheticRow 2 CompileRefusal : drop 1 wellFormedRows)
      [ "CompilerExpectationDuplicateKey"
      , "CompilerExpectationDuplicatePath"
      , "CompilerExpectationDuplicateComponent"
      ]
    <> exactlyTagged
      "an invalid subject path"
      (CompilerExpectationRow "src/Elsewhere.hs" (syntheticComponent 1) CompileRefusal : drop 1 wellFormedRows)
      ["CompilerExpectationInvalidPath"]
    <> exactlyTagged
      "an invalid component identity"
      (CompilerExpectationRow (syntheticPath 1) "not-a-component" CompileRefusal : drop 1 wellFormedRows)
      ["CompilerExpectationInvalidComponent"]
    <> [ "the live expectation authority admits a fixture-observation row"
       | not (null [() | item <- liveOutcomeTokens, item == "fixture"])
       ]
 where
  exactlyTagged label rows expected =
    [ label
        <> " must be refused with exactly "
        <> show expected
        <> ", observed "
        <> show (tagsFor rows)
    | tagsFor rows /= expected
    ]
  tagsFor rows = map (head . words . show) (expectationProblemsFor rows)
  liveOutcomeTokens =
    foldCompilerExpectationAuthority
      (\tokens _ _ outcome -> foldCompilerExpectationOutcome "success" "refusal" "fixture" outcome : tokens)
      []
      compilerExpectationAuthority

-- | Two hundred and twenty distinct well-formed rows: above the authored floor,
-- so a case that trips the floor is doing so for its own reason.
wellFormedRows :: [CompilerExpectationRow]
wellFormedRows = [syntheticRow ordinal CompileRefusal | ordinal <- [1 .. 220]]

syntheticRow :: Int -> CompilerExpectationOutcome -> CompilerExpectationRow
syntheticRow ordinal outcome =
  CompilerExpectationRow (syntheticPath ordinal) (syntheticComponent ordinal) outcome

syntheticPath :: Int -> FilePath
syntheticPath ordinal = "test/compile-negative/synthetic-" <> show ordinal <> "-opacity/Main.hs"

syntheticComponent :: Int -> Text
syntheticComponent ordinal =
  "amoebius.cabal:test:validation-synthetic-" <> Text.pack (show ordinal) <> "-opacity-attack"

compileNegativePublicControlProblems :: [String]
compileNegativePublicControlProblems =
  [ "a literal compile-positive public control beneath the attack tree was misclassified"
  | compilerSubjectAssignments registry
      /= [ ( "test/compile-negative/compiler-component-plan-public-control/Main.hs"
           , objectA
           , CompileNegativeSubject
           , ExpectedCompileSuccess
           , ["amoebius.cabal:test:validation-compiler-component-plan-public-control"]
           )
         ]
  ]
    <> ["the literal public control produced registry findings" | not (null (checkFindings check))]
 where
  registry =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "amoebius.cabal"
              objectC
              ( unlines
                  [ "cabal-version: 3.0"
                  , "name: amoebius"
                  , "version: 0"
                  , "build-type: Simple"
                  , "test-suite validation-compiler-component-plan-public-control"
                  , "  type: exitcode-stdio-1.0"
                  , "  main-is: Main.hs"
                  , "  hs-source-dirs: test/compile-negative/compiler-component-plan-public-control"
                  , "  default-language: GHC2024"
                  ]
              )
          , haskell "test/compile-negative/compiler-component-plan-public-control/Main.hs" objectA
          ]
      )
  check = compilerSubjectRegistryCheck registry

unknownCompileNegativeProblems :: [String]
unknownCompileNegativeProblems =
  [ "an unregistered compile-negative source inherited a refusal from its directory"
  | case compilerSubjectAssignments registry of
      [(_, _, _, outcome, _)] -> outcome /= ExpectedCompilerOutcomeUnavailable
      _ -> True
  ]
    <> [ "an unregistered compile-negative source did not fail closed"
       | null (checkFindings (compilerSubjectRegistryCheck registry))
       ]
 where
  registry =
    deriveCompilerSubjectRegistry
      ( snapshot
          [ tracked
              "fixture.cabal"
              objectC
              ( unlines
                  [ "cabal-version: 3.0"
                  , "name: fixture"
                  , "version: 0"
                  , "build-type: Simple"
                  , "test-suite unregistered-attack"
                  , "  type: exitcode-stdio-1.0"
                  , "  main-is: Main.hs"
                  , "  hs-source-dirs: test/compile-negative/unregistered"
                  , "  default-language: GHC2024"
                  ]
              )
          , haskell "test/compile-negative/unregistered/Main.hs" objectA
          ]
      )

acquiredCoverageProblems :: [String]
acquiredCoverageProblems =
  [ "a partial snapshot minted a supposedly complete acquired compiler-subject contract"
  | case acquireCompilerSubjectContract (sourceClosureInternalTestAcquire partialSnapshot) of
      Left _ -> False
      Right _ -> True
  ]
 where
  partialSnapshot = snapshot [cabalEntry ["src"], haskell "src/A.hs" objectA]

emptyInventoryProblems :: [String]
emptyInventoryProblems =
  [ "an empty Haskell subject inventory did not refuse"
  | null (checkFindings (compilerSubjectRegistryCheck (deriveCompilerSubjectRegistry (snapshot []))))
  ]

snapshot :: [TrackedEntry] -> SourceSnapshot
snapshot entries = SourceSnapshot "/fixture" snapshotId entries

cabalEntry :: [FilePath] -> TrackedEntry
cabalEntry sourceDirectories =
  tracked
    "fixture.cabal"
    objectC
    ( unlines
        [ "cabal-version: 3.0"
        , "name: fixture"
        , "version: 0"
        , "build-type: Simple"
        , "library"
        , "  exposed-modules: A"
        , "  hs-source-dirs: " <> commaSeparated sourceDirectories
        , "  default-language: GHC2024"
        ]
    )

haskell :: FilePath -> Text -> TrackedEntry
haskell path objectIdentity = tracked path objectIdentity "module A where\n"

tracked :: FilePath -> Text -> String -> TrackedEntry
tracked path objectIdentity bytes =
  TrackedEntry
    { trackedIndex = IndexEntry path RegularFile objectIdentity
    , trackedBytes = ByteString8.pack bytes
    }

commaSeparated :: [String] -> String
commaSeparated [] = ""
commaSeparated (value : values) = value <> concatMap (", " <>) values

snapshotId, objectA, objectB, objectC :: Text
snapshotId = Text.replicate 64 "0"
objectA = Text.replicate 64 "1"
objectB = Text.replicate 64 "2"
objectC = Text.replicate 64 "3"

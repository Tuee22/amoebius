{-# LANGUAGE OverloadedStrings #-}

module CompilerSubjectRegistryOracle
  ( runCompilerSubjectRegistryOracle
  ) where

import Amoebius.Validation.CompilerExpectationAuthority.Internal
  ( compilerExpectationAuthority
  , compilerExpectationAuthorityDigest
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
import Amoebius.Validation.Types (CheckResult (..))
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
      <> compileNegativePublicControlProblems
      <> unknownCompileNegativeProblems
      <> acquiredCoverageProblems
      <> emptyInventoryProblems

authorityProblems :: [String]
authorityProblems =
  [ "compiled expectation authority reported internal problems"
  | not (null (compilerExpectationAuthorityProblems compilerExpectationAuthority))
  ]
    <> [ "compiled expectation authority digest changed"
       | compilerExpectationAuthorityDigest compilerExpectationAuthority
          /= "7efa31beb982692484d1623a8582b5e7d005f9fa285454ac771320705a0f81db"
       ]
    <> [ "compiled expectation authority cardinality changed"
       | length rows /= 369
       ]
    <> [ "compiled expectation authority outcome partition changed"
       | (successCount, refusalCount, fixtureCount) /= (14, 355, 0)
       ]
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
  successCount = length [() | (_, _, "success") <- rows]
  refusalCount = length [() | (_, _, "refusal") <- rows]
  fixtureCount = length [() | (_, _, "fixture") <- rows]
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

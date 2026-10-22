{-# LANGUAGE OverloadedStrings #-}

-- | The runner-area oracle executable. It depends on no @amoebius@ library. It
-- reads the rows the runner suite wrote and prints a ledger derived from the
-- literals below; it exits non-zero when any row is red.
module Main (main) where

import Control.Monad (unless)
import Control.Exception (IOException, try)
import Data.List (isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, findExecutable)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeDirectory, (</>))
import System.FilePath.Posix qualified as Logical
import System.Process (readProcessWithExitCode)
import SolverDemotion (solverDemotionChecks, solverApiChecks, solverReintroductionChecks, solverSourceChecks, solverQualificationChecks)
import SourceCapture (sourceCaptureChecks, sourceApiChecks, predecessorApiChecks, sourceRewriteChecks, sourceTreeChecks, sourceTreeJudge)
import LegacyAudit (legacyAuditChecks, kernelQualificationChecks, kernelJoinChecks, mutationQualificationChecks, mutationJoinChecks, mutationChecks, solverJoinChecks, bootstrapQualificationChecks, bootstrapJoinChecks, correspondenceJoinChecks, custodyJoinChecks, statusJoinChecks, authorityJoinChecks, freshJoinChecks, admissionJoinChecks, probeSourceJoinChecks, vendorSourceJoinChecks, testSourceJoinChecks, toolSourceJoinChecks, pulumiSourceJoinChecks, runtimeIdentityJoinChecks, ignoreContextJoinChecks, sourceGraphJoinChecks, bootstrapSourceJoinChecks)
import Portability (portabilityChecks, observerChecks)
import NativeApi (writeAuthorityCheckers, seedAuthorityRows)

main :: IO ()
main = do
  arguments <- getArgs
  ledger <- case arguments of
    ["--write-authority-checkers", directory] -> writeAuthorityCheckers directory >> pure []
    ["--runner-authority", directory] -> runnerAuthorityJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "authority.tsv")
    ["--fresh-inputs", directory] -> freshInputJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "fresh-inputs.tsv")
    ["--reproducible", directory] -> reproducibleJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "reproducible.tsv")
    ["--oracle-build", directory] -> oracleBuildChecks directory
    ["--oracle-input", directory] -> oracleInputJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "oracle-input.tsv")
    ["--source-tree", directory] -> map (\(name,green,observed) -> LedgerRow name green observed) <$> sourceTreeChecks directory
    ["--oracle-isolation", directory] -> oracleIsolationJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "oracle-isolation.tsv")
    ["--source-read", directory] -> sourceReadJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "source-read.tsv")
    ["--contracts", directory] -> contractStructureJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "contracts.tsv")
    ["--contract-correspondence", directory] -> correspondenceJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "correspondence.tsv")
    ["--receipt-custody", directory] -> receiptCustodyJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "custody.tsv")
    ["--status-authority", directory] -> statusAuthorityJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "status-authority.tsv")
    ["--package-syntax", directory] -> packageSyntaxJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "package-syntax.tsv")
    ["--mutation-source", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> mutationChecks directory
    ["--observer", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> observerChecks directory
    ["--portability", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> portabilityChecks directory
    ["--legacy-kernel", directory, root] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> kernelQualificationChecks directory root
    ["--legacy-mutation", directory, root] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> mutationQualificationChecks directory root
    ["--legacy-solver", directory, root] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> solverQualificationChecks directory root
    ["--legacy-bootstrap", directory, root] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> bootstrapQualificationChecks directory root
    ["--kernel-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> kernelJoinChecks directory
    ["--mutation-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> mutationJoinChecks directory
    ["--solver-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> solverJoinChecks directory
    ["--bootstrap-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> bootstrapJoinChecks directory
    ["--correspondence-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> correspondenceJoinChecks directory
    ["--custody-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> custodyJoinChecks directory
    ["--status-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> statusJoinChecks directory
    ["--authority-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> authorityJoinChecks directory
    ["--fresh-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> freshJoinChecks directory
    ["--admission-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> admissionJoinChecks directory
    ["--bootstrap-source-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> bootstrapSourceJoinChecks directory
    ["--source-graph-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> sourceGraphJoinChecks directory
    ["--ignore-context-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> ignoreContextJoinChecks directory
    ["--runtime-identity-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> runtimeIdentityJoinChecks directory
    ["--pulumi-source-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> pulumiSourceJoinChecks directory
    ["--tool-source-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> toolSourceJoinChecks directory
    ["--test-source-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> testSourceJoinChecks directory
    ["--probe-source-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> probeSourceJoinChecks directory
    ["--vendor-source-join", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> vendorSourceJoinChecks directory
    ["--legacy-audit", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> legacyAuditChecks directory
    ["--source-capture", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> sourceCaptureChecks directory
    ["--source-rewrite", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> sourceRewriteChecks directory
    ["--source-api", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> sourceApiChecks directory
    ["--predecessor-api", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> predecessorApiChecks directory
    ["--solver-demotion", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> solverDemotionChecks directory
    ["--solver-api", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> solverApiChecks directory
    ["--solver-reintroduction", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> solverReintroductionChecks directory
    ["--solver-source", directory] -> map (\(name, green, observed) -> LedgerRow name green observed) <$> solverSourceChecks directory
    _ -> runnerChecks arguments
  mapM_ (TextIO.putStrLn . renderRow) ledger
  unless (all rowGreen ledger) exitFailure

runnerChecks :: [String] -> IO [LedgerRow]
runnerChecks arguments = do
  input <- case arguments of
    [path] -> do
      directory <- doesDirectoryExist path
      pure (if directory then path <> "/runner.tsv" else path)
    _ -> pure ".build/runs/phase-00/runner/runner.tsv"
  contents <- TextIO.readFile input
  native <- inventoryNativeChecks (takeDirectory input </> "legacy-native")
  let rows = map (Text.splitOn "\t") (filter (not . Text.null) (Text.lines contents))
  pure (judge rows <> native)

data LedgerRow = LedgerRow {rowName :: Text, rowGreen :: Bool, rowObserved :: Text}

oracleBuildChecks :: FilePath -> IO [LedgerRow]
oracleBuildChecks directory = oracleBuildJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "oracle-build.tsv")

oracleBuildJudge :: [[Text]] -> [LedgerRow]
oracleBuildJudge rows =
  let cases =
        [("baseline", ""), ("legacy-clean", ""), ("warnings", ""), ("optimization", ""), ("ordinary-extension", ""), ("disabled-th", "")
        ,("default-th", "extension:TemplateHaskell"), ("other-quotes", "extension:TemplateHaskellQuotes")
        ,("old-quasiquotes", "extension:QuasiQuotes"), ("default-cpp", "extension:CPP")
        ,("option-extension", "compiler-option:-XTemplateHaskell"), ("plugin", "compiler-option:-fplugin=Example.Plugin")
        ,("profiling-plugin", "compiler-option:-fplugin=Example.Plugin"), ("shared-plugin", "compiler-option:-fplugin=Example.Plugin")
        ,("profiling-shared-plugin", "compiler-option:-fplugin=Example.Plugin"), ("ghcjs-profiling-shared-plugin", "compiler-option:-fplugin=Example.Plugin")
        ,("ghcjs-plugin", "compiler-option:-fplugin=Example.Plugin")
        ,("preprocessor", "compiler-option:-F,compiler-option:-pgmF,compiler-option:./preprocess")
        ,("package-option", "compiler-option:-package,compiler-option:amoebius")
        ,("cpp-options", "cpp-options"), ("c-source", "c-sources"), ("cxx-source", "cxx-sources")
        ,("javascript-source", "js-sources"), ("assembly-source", "asm-sources"), ("cmm-source", "cmm-sources")
        ,("linker-options", "ld-options"), ("extra-library", "extra-libraries"), ("build-tool", "build-tool-depends")
        ,("legacy-build-tool", "build-tools"), ("pkg-config", "pkgconfig-depends")
        ,("conditional-th", "extension:TemplateHaskell"), ("conditional-else", "compiler-option:-fplugin=Example.Plugin")
        ,("conditional-clean", ""), ("common-clean", "")
        ,("common-plugin", "compiler-option:-fplugin=Example.Plugin")]
      wanted hazards = Text.intercalate "," ["ORACLE-BUILD-BOUNDARY: oracle-dsl " <> hazard | hazard <- Text.splitOn "," hazards, not (Text.null hazard)]
  in LedgerRow "oracle-build.discovery" (sort [name | [name, _] <- rows] == sort (map fst cases)
      && all ((== 2) . length) rows) "closed Cabal controls"
    : [let observed = [value | [key, value] <- rows, key == name]
       in LedgerRow ("oracle-build." <> name) (observed == [wanted hazards]) (Text.pack (show observed)) | (name, hazards) <- cases]

oracleInputJudge :: [[Text]] -> [LedgerRow]
oracleInputJudge rows =
  let cases =
        [("main", []), ("alternate", []), ("missing-entry", ["entry:Missing.hs", "source-unlisted:test/oracle/main/Main.hs"])
        ,("preprocessed-entry", ["entry:Main.hsc", "source:test/oracle/main/Main.hsc", "source-unlisted:test/oracle/main/Main.hs"])
        ,("module", []), ("missing-module", ["module:Fixture.Helper"])
        ,("preprocessed-module", ["module:Fixture.Helper", "source:test/oracle/main/Fixture/Helper.hsc"])
        ,("shadow-preprocessor", ["source:test/oracle/main/Fixture/Helper.hsc"])
        ,("split-directories", []), ("parent-directory", ["source-dir:test/oracle/main/.."])
        ,("custom-build", ["build-type:Custom", "custom-setup"]), ("configure-build", ["build-type:Configure"])
        ,("hooks-build", ["build-type:Hooks", "custom-setup"]), ("custom-setup", ["custom-setup"])
        ,("implicit-custom-setup", ["build-type:Custom", "custom-setup"])
        ,("library-interface", ["interface:detailed-0.9", "source-unlisted:test/oracle/main/Main.hs"])
        ,("external-import", []), ("comment-import", []), ("literal-import", [])
        ,("import-product", ["source-import:test/oracle/main/Main.hs:Product.Subject"])
        ,("import-qualified", ["source-import:test/oracle/main/Main.hs:Product.Subject"])
        ,("import-postqualified", ["source-import:test/oracle/main/Main.hs:Product.Subject"])
        ,("import-package", ["source-import:test/oracle/main/Main.hs:Product.Subject"])
        ,("import-source", ["source-import:test/oracle/main/Main.hs:Product.Subject"])
        ,("import-alias", ["source-import:test/oracle/main/Main.hs:Product.Subject"])
        ,("helper-product", ["source-import:test/oracle/main/Fixture/Helper.hs:Product.Subject"])
        ,("shadow-product", ["source-module:test/oracle/main/Product/Subject.hs:Product.Subject"])
        ,("malformed-module", ["ORACLE-SOURCE-UNSCANNED: test/oracle/main/Main.hs"])
        ,("implicit-main", []), ("wrong-entry-name", ["source-name:test/oracle/main/Main.hs:Alternative"])
        ,("wrong-helper-name", ["source-name:test/oracle/main/Fixture/Helper.hs:Different"])
        ,("unlisted-helper", ["source-unlisted:test/oracle/main/Fixture/Helper.hs"])
        ,("duplicate-helper", ["source-ambiguous:Fixture/Helper.hs"])
        ,("duplicate-entry", ["source-ambiguous:Main.hs"])
        ,("module-path-spoof", ["module:Fixture.Helper", "source-unlisted:test/oracle/main/Helper.hs"])
        ,("helper-external", [])]
      verdict name = case [value | [key, value] <- rows, key == name] of
        [value] -> Just (sort (filter (not . Text.null) (Text.splitOn "," value)))
        _ -> Nothing
  in LedgerRow "oracle-input.discovery" (sort [name | [name, _] <- rows] == sort (map fst cases)
        && all ((== 2) . length) rows) "closed entry/source/setup controls"
    : [let expected = sort [if "ORACLE-" `Text.isPrefixOf` hazard then hazard else "ORACLE-BUILD-BOUNDARY: oracle-fixture " <> hazard | hazard <- hazards]
       in LedgerRow ("oracle-input." <> name) (verdict name == Just expected) (Text.pack (show (verdict name))) | (name, hazards) <- cases]

oracleIsolationJudge :: [[Text]] -> [LedgerRow]
oracleIsolationJudge rows =
  let cases = [("alone",Nothing),("sibling",Nothing),("area-entry",Nothing),("area-helper",Nothing)]
        <> [("repository." <> name,Nothing) | name <- ["oracle-doc","oracle-runner","oracle-dsl","oracle-extensions","oracle-layout","oracle-toolchain"]]
        <> [(key,Just "library:peer") | key <- ["library-shared","library-parent","library-child","library-normalized","library-case","library-default","conditional","common"]]
        <> [(key,Just "executable:peer") | key <- ["executable-shared","executable-default"]]
        <> [(key,Just "test:peer") | key <- ["test-product","test-child","test-default","area-unsafe-peer","area-partial"]]
      expected role = maybe "" ("ORACLE-BUILD-BOUNDARY: oracle-fixture source-shared:test/oracle/main:" <>) role
      observed key = [value | [name,value] <- rows, name == key]
  in LedgerRow "oracle-isolation.discovery" (sort [key | [key,_] <- rows] == sort (map fst cases) && all ((==2) . length) rows) "closed source-area controls"
    : [LedgerRow ("oracle-isolation." <> key) (observed key == [expected role]) (Text.pack (show (observed key))) | (key,role) <- cases]

freshInputJudge :: [[Text]] -> [LedgerRow]
freshInputJudge rows =
  let expected = [("stale-run","positive","copied"),("stale-run","negative","SourceCopyNotFresh")
        ,("ignored-input","positive","verified"),("ignored-input","negative","SourceCopyInputChanged:.build/input.hs")
        ,("authored-output","positive","verified"),("authored-output","negative","SourceCopyInventoryChanged")
        ,("ambient-temp","positive","True"),("ambient-temp","negative","False")
        ,("replayed-input","positive","True"),("replayed-input","negative","False")
        ,("empty-discovery","positive","Program.hs"),("empty-discovery","negative","SourceInventoryEmpty")
        ,("control","stale-sentinel",Text.pack (show ("keep\n" :: Text))),("control","ignored-captured","True"),("control","source-changed","True")
        ,("control","replayed-copy","SourceCopyInputChanged:Program.hs"),("control","authored-restored","verified")
        ,("control","ambient-entry","RUN-ROOT-OUTSIDE-FRAME"),("control","ambient-created","False"),("control","cleanup","True")
        ,("control","collection-unknown","True"),("control","collection-phase","True"),("control","collection-source","True")]
      observed key role = [value | [name,control,value] <- rows,name == key,control == role]
  in LedgerRow "fresh.discovery" (sort [(key,role) | [key,role,_] <- rows] == sort [(key,role) | (key,role,_) <- expected] && all ((==3) . length) rows) "closed captured-source and run-frame cases"
    : [LedgerRow ("fresh." <> key <> "." <> role) (observed key role == [value]) (Text.pack (show (observed key role))) | (key,role,value) <- expected]

runnerAuthorityJudge :: [[Text]] -> [LedgerRow]
runnerAuthorityJudge rows =
  let keys = ["noop-subject","constant-success-checker","forged-exit","omitted-discovery","unavailable-boundary"]
      expected = [(key,role,value) | key <- keys,(role,value) <- [("positive","True"),("negative","False")]]
        <> [("control","subject-exit","ExitFailure 1"),("control","subject-token",Text.pack (show ("PASS ExitSuccess\n" :: Text)))
           ,("control","constant-probe","ExitSuccess"),("control","missing-probe","True"),("control","cleanup","True")]
        <> [("manifest","seed-names",Text.intercalate "," (sort seedAuthorityRows)),("manifest","seed-positive","True")]
        <> [("manifest","omitted." <> key,"False") | key <- seedAuthorityRows]
      observed key role = [value | [name,control,value] <- rows,name == key,control == role]
  in LedgerRow "authority.discovery" (sort [(key,role) | [key,role,_] <- rows] == sort [(key,role) | (key,role,_) <- expected] && all ((==3) . length) rows) "closed native subject/checker boundaries"
    : [LedgerRow ("authority." <> key <> "." <> role) (observed key role == [value]) (Text.pack (show (observed key role))) | (key,role,value) <- expected]

statusAuthorityJudge :: [[Text]] -> [LedgerRow]
statusAuthorityJudge rows =
  let keys = ["status-surface-dirty","status-without-receipt","predecessor-not-reproduced","status-edit-without-receipt"]
      expected = [(key,"positive","") | key <- keys] <> [(key,"negative","True") | key <- keys]
        <> [(part,key,"True") | part <- ["accept","preview","unchanged"], key <- keys] <> [("control","cleanup","True")]
      observed key role = [value | [name,control,value] <- rows,name == key,control == role]
  in LedgerRow "status.discovery" (sort [(key,role) | [key,role,_] <- rows] == sort [(key,role) | (key,role,_) <- expected] && all ((==3) . length) rows) "closed native status and command boundaries"
    : [LedgerRow ("status." <> key <> "." <> role) (observed key role == [value]) (Text.pack (show (observed key role))) | (key,role,value) <- expected]

receiptCustodyJudge :: [[Text]] -> [LedgerRow]
receiptCustodyJudge rows =
  let source value = "module Amoebius.Dsl.Spec where\nvalue = " <> value <> "\n" :: Text
      expected = [("generation-one-receipt","positive","accepted")
        ,("generation-one-receipt","negative","unknown receipt record: amoebius-phase-receipt.v1")
        ,("verifier-diverged","positive","accepted")
        ,("verifier-diverged","negative","archive receipt identity or canonical form is invalid")
        ,("predecessor-closure-edited","positive","accepted"),("predecessor-closure-edited","negative","ReceiptClosureMismatch")
        ,("binding","verifier-positive","accepted"),("binding","verifier-negative","ReceiptVerifierMismatch")
        ,("control","closure-source",Text.pack (show (source "1",source "2")))
        ,("control","closure-restored","True"),("control","outside-closure","True")
        ,("control","unknown-closure","ReceiptClosureUnavailable"),("control","closure-sentinel","ReceiptClosureUnavailable")
        ,("control","capability-binding","ReceiptIdentityMismatch"),("control","governance-binding","ReceiptGovernanceMismatch")
        ,("control","specification-binding","ReceiptSpecificationMismatch"),("control","phase-binding","ReceiptIdentityMismatch")]
        <> [("dependency",key,"True") | key <- ["suite","oracle","custody-suite","entry","build-tool","seed-driver","metadata","bootstrap","documentation","status-projection","cleanup"]]
      observed name role = [value | [key,control,value] <- rows,key == name,control == role]
  in LedgerRow "custody.discovery" (sort [(key,role) | [key,role,_] <- rows] == sort [(key,role) | (key,role,_) <- expected] && all ((==3) . length) rows) "canonical receipt pairs and complete bindings"
    : [LedgerRow ("custody." <> key <> "." <> role) (observed key role == [value]) (Text.pack (show (observed key role))) | (key,role,value) <- expected]

correspondenceJudge :: [[Text]] -> [LedgerRow]
correspondenceJudge rows =
  let expected =
        [("gate-spec-mismatch","positive","")
        ,("gate-spec-mismatch","negative","DOC-GATE-SPEC-MISMATCH:DEVELOPMENT_PLAN/phase_03_typed_spine.md")
        ,("phase-role-swap","positive","accepted"),("phase-role-swap","negative","SPEC-ROLE-MISMATCH: typed_spine")
        ,("byte-copy-equivalence","positive","accepted"),("byte-copy-equivalence","negative","SPEC-CURRENT-MISMATCH: typed_spine")
        ,("subject-not-shipped","positive","accepted"),("subject-not-shipped","negative","SUBJECT-NOT-SHIPPED: Amoebius.Parked.Thing (parked)")
        ,("retired-domain-literal","positive","accepted"),("retired-domain-literal","negative","PHASE-ABSENT: 10")
        ,("control","render-collision","True")
        ,("entry","phase-role-swap","SPEC-ROLE-MISMATCH: typed_spine")
        ,("entry","byte-copy-equivalence","SPEC-CURRENT-MISMATCH: typed_spine")
        ,("entry-root","phase-role-swap","False"),("entry-root","byte-copy-equivalence","False")
        ,("snapshot","contracts",""),("snapshot","selected","accepted")]
      observed name role = [value | [key,control,value] <- rows,key == name,control == role]
  in LedgerRow "correspondence.discovery" (sort [(key,role) | [key,role,_] <- rows] == sort [(key,role) | (key,role,_) <- expected] && all ((==3) . length) rows) "five canonical pairs and native entry controls"
    : [LedgerRow ("correspondence." <> key <> "." <> role) (observed key role == [value]) (Text.pack (show (observed key role))) | (key,role,value) <- expected]

contractStructureJudge :: [[Text]] -> [LedgerRow]
contractStructureJudge rows =
  let path = "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
      expected = [("registered","0,1,2,3,4,5,6,7,8,9"),("empty","SPEC-REGISTRY-DIVERGED"),("duplicate","SPEC-REGISTRY-DIVERGED")
        ,("duplicate-resolve","SPEC-REGISTRY-DIVERGED")
        ,("unknown","SPEC-PHASE-ABSENT: orphan-contract"),("capability-mismatch","SPEC-CAPABILITY-MISMATCH: documentation_suite")
        ,("missing-binary","BINARY-FACT-MISSING"),("missing-seed","SEED-ABSENT")
        ,("unregistered","SPEC-ABSENT: no gate specification is registered for documentation_suite")
        ,("out-of-domain","PHASE-ABSENT: 96"),("reserved-gap","PHASE-ABSENT: 10")
        ,("document-unregistered","DOC-GATE-SPEC-PHASE:" <> path),("document-duplicate-fence","DOC-GATE-SPEC-PHASE:" <> path)
        ,("document-mismatch","DOC-GATE-SPEC-MISMATCH:" <> path),("document-matched","")
        ,("native","")
        ,("children-subjects","Amoebius.Dsl.Children,Amoebius.Dsl.Lower,Amoebius.Kernel.Step,Amoebius.Calculus.Workflow.Obligation")
        ,("ui-subjects","Amoebius.Ui.Effect.Catalog,Amoebius.Ui.Expr,Amoebius.Ui.Check,Amoebius.Ui.Bind,Amoebius.Ui.Plan,Amoebius.Dsl.Lower")
        ,("children-negatives","ReleaseLessChain:compile,ChildNamesUnknownParent:forest,CyclicForest:forest")
        ,("ui-negatives","UnboundPort:binding,RequirementWithoutPort:binding,GuardGap:check,TypeMismatch:check,UnboundedFuel:check,UnknownFunction:check,HandlerCarriesIO:compile,IllTypedComparison:compile")
        ,("barrier-negatives","EndpointDiscardsDecodedValue:endpoint,DemoInsideCorpusTagSet:demo,DemoUnrecorded:demo")
        ,("barrier-inherits-subjects","True")
        ,("barrier-spine","compiled/manifest.json:freeze,decode,lower,recipe,bake,plan,provision,attest,render,extension-chain,child-projection,ui-check,ui-bind,ui-plan,chain,dry-run,fake-apply:applied/fake/applied.sha256")
        ,("slice-substrates","none,none,none")
        ,("slice-oracles","oracle-dsl,oracle-dsl,oracle-dsl")
        ,("barrier-inherits-cases","True")
        ,("role-root","0:SeedGate"),("role-upper","95:HardwareGate"),("role-barrier","9:BarrierGate")
        ,("role-bootstrap","50:OrdinaryGate"),("role-ensure","51:OrdinaryGate"),("role-hardware","52:HardwareGate")]
      observed key = [value | [name,value] <- rows,name == key]
  in LedgerRow "contracts.discovery" (sort [key | [key,_] <- rows] == sort (map fst expected) && all ((==2) . length) rows) "closed contract correspondence controls"
    : [LedgerRow ("contracts." <> key) (observed key == [value]) (Text.pack (show (observed key))) | (key,value) <- expected]

sourceReadJudge :: [[Text]] -> [LedgerRow]
sourceReadJudge rows =
  let expected = [("package-clean","accepted"),("package-limit","accepted")
        ,("package-over","PackageDescriptionUnparsable:SourceByteLimit"),("package-missing","PackageDescriptionUnparsable:unreadable")
        ,("source-not-regular","SourceNotRegular")
        ,("oracle-clean","")
        ,("oracle-over","ORACLE-SOURCE-UNSCANNED: test/oracle/Main.hs")
        ,("oracle-utf8","ORACLE-SOURCE-UNSCANNED: test/oracle/Main.hs")
        ,("hygiene-over","SourceByteLimit"),("capture-limit","captured:16777216")
        ,("gate-hygiene-over","SourceCaptureRefused:SourceByteLimit"),("fresh-hygiene-over","SourceCaptureRefused:SourceByteLimit")
        ,("status-over","SourceByteLimit")
        ,("capture-over","SourceInputUnavailable:large.hs:SourceByteLimit")]
      observed key = [value | [name,value] <- rows,name == key]
  in LedgerRow "source-read.discovery" (sort [key | [key,_] <- rows] == sort (map fst expected) && all ((==2) . length) rows) "closed source-read boundary controls"
    : [LedgerRow ("source-read." <> key) (observed key == [value]) (Text.pack (show (observed key))) | (key,value) <- expected]

packageSyntaxJudge :: [[Text]] -> [LedgerRow]
packageSyntaxJudge rows =
  let cases = [("clean", ""), ("custom-field", ""), ("deprecated", "PWTDeprecatedField@11:5")
        ,("unknown-root", "PWTUnknownField@5:1"), ("unknown-target", "PWTUnknownField@11:5")
        ,("unknown-section", "PWTUnknownSection@5:1"), ("too-new-field", "PWTUnknownField@11:5")
        ,("conditional-unknown", "PWTUnknownField@16:9"), ("common-unknown", "PWTUnknownField@6:5"), ("repository", "")]
      values name = [(native, warnings, result) | [key, native, warnings, result] <- rows, key == name]
  in LedgerRow "package-syntax.discovery" (sort [name | [name, _, _, _] <- rows] == sort (map fst cases)
        && all ((== 4) . length) rows) "closed parser-warning controls"
    : concat [let observed = values name
                  expected = if name `elem` ["clean", "custom-field", "deprecated", "repository"] then "accepted" else "PACKAGE-UNSCANNED: " <> warnings
              in [LedgerRow ("package-syntax." <> name <> ".native") ([(native, warning) | (native, warning, _) <- observed] == [("parsed", warnings)]) (Text.pack (show observed))
                 ,LedgerRow ("package-syntax." <> name <> ".admission") ([result | (_, _, result) <- observed] == [expected]) (Text.pack (show observed))] | (name, warnings) <- cases]

renderRow :: LedgerRow -> Text
renderRow row = Text.intercalate "\t" [rowName row, if rowGreen row then "green" else "red", Text.pack (show (rowObserved row))]

judge :: [[Text]] -> [LedgerRow]
judge rows =
  [ expect "contract.extension-oracle" "oracle-extensions" (value "contract" "extension-oracle")
  , expect "refusal.legal-ordinary" "ok" (value "refusal" "legal-ordinary")
  , expect "refusal.kernel-subject" "SUBJECT-NOT-SHIPPED: Amoebius.Validation.Runner" (value "refusal" "kernel-subject")
  , expect "refusal.missing-binary-fact" "BINARY-FACT-MISSING" (value "refusal" "missing-binary-fact")
  , expect "refusal.barrier-without-spine" "SPINE-FACT-MISSING" (value "refusal" "barrier-without-spine")
  , expect "refusal.seed-with-binary-fact" "SEED-CARRIES-BINARY-FACT" (value "refusal" "seed-with-binary-fact")
  , expect "refusal.hardware-substrate-ordinary" "HARDWARE-BEFORE-BARRIER: linux-cpu" (value "refusal" "hardware-substrate-ordinary")
  , expect "refusal.hardware-role-without-substrate" "SUBSTRATE-ABSENT" (value "refusal" "hardware-role-without-substrate")
  , expect "refusal.stage-not-subject" "STAGE-MODULE-NOT-SUBJECT: Amoebius.Dsl.Other" (value "refusal" "stage-not-subject")
  , expect "refusal.duplicate-case" "CASE-DUPLICATE: a" (value "refusal" "duplicate-case")
  , expect "refusal.legal-seed" "ok" (value "refusal" "legal-seed")
  , expect "refusal.ordinary-with-spine" "ok" (value "refusal" "ordinary-with-spine")
  , expect "render.lines" "11" (value "render" "legal-ordinary")
  , expect "render.staged" "binary-fact: command=compile {input} | input=examples/root.dhall | perturbation=staged(pre=render x --output {input} post=apply y then=sentinel-to-nonce(S),replica-count(1->3)) | outputs={run}/out/m" (value "render" "staged")
  , expect "perturb.staged-direct" "refused" (value "perturb" "staged-direct")
  , expect "verify.closure" "dsl-core,vocabulary" (value "verify" "closure")
  , expect "verify.legal" "ok" (value "verify" "legal")
  , expect "verify.outside-closure" "SUBJECT-NOT-SHIPPED: Amoebius.Parked.Thing (parked)" (value "verify" "outside-closure")
  , expect "verify.not-in-package" "SUBJECT-NOT-IN-PACKAGE: Amoebius.Nowhere" (value "verify" "not-in-package")
  , expect "verify.oracle-depends-on-product" "ORACLE-DEPENDS-ON-PRODUCT: oracle-leaky" (value "verify" "oracle-depends-on-product")
  , expectPrefix "verify.oracle-cpp" "ORACLE-CPP: " (value "verify" "oracle-cpp")
  , expect "verify.oracle-missing" "ORACLE-MISSING: oracle-absent" (value "verify" "oracle-missing")
  , LedgerRow "oracle-syntax.discovery" (sort [name | ["oracle-syntax", name, _] <- rows] == sort (map fst oracleSyntaxExpected)) "closed syntax controls"
  , expect "verify.suite-missing" "SUITE-MISSING: no-suite" (value "verify" "suite-missing")
  , expect "loci.constant-flip" "6,12,17,18,22" (value3 "loci" "constant-flip")
  , expect "loci.boundary-shift" "9" (value3 "loci" "boundary-shift")
  , expect "loci.branch-swap" "12" (value3 "loci" "branch-swap")
  , expect "loci.field-drop" "18" (value3 "loci" "field-drop")
  , expect "loci.list-truncation" "22" (value3 "loci" "list-truncation")
  , expect "sample.deterministic" "equal" (value "sample" "deterministic")
  , expect "sample.seed-sensitive" "differs" (value "sample" "seed-sensitive")
  , expect "sample.size" "4" (value "sample" "size")
  , expect "sample.cap" "9" (value "sample" "cap")
  , expect "sample.fixed-a" "9:boundary-shift,17:constant-flip,18:field-drop,22:constant-flip" (value "sample" "fixed-a")
  , expect "sample.fixed-b" "6:constant-flip,12:constant-flip,12:branch-swap,22:constant-flip" (value "sample" "fixed-b")
  , expect "apply.witness" "changed" (value "apply" "witness")
  , expect "apply.line-6" "limit = 4" (value "apply" "line-6")
  , expect "apply.stale-locus" "refused" (value "apply" "stale-locus")
  , expect "string.plain" "label = \"linux-cpu!\"" (value "string" "plain")
  , expect "string.empty" "label = \"!\"" (value "string" "empty")
  , expect "string.escaped" "label = \"say \\\"hi\\\"!\"" (value "string" "escaped")
  , expect "string.unicode" "label = \"\\955!\"" (value "string" "unicode")
  , expect "string.character-before-string" "quote = '\"'; label = \"cpu!\"" (value "string" "character-before-string")
  , expect "string.character-only" "" (value "string" "character-only")
  , expect "string.comment" "" (value "string" "comment")
  , expect "string.inline-comment" "" (value "string" "inline-comment")
  , expect "string.block-comment" "" (value "string" "block-comment")
  , expect "string.unterminated" "" (value "string" "unterminated")
  , expect "string.integer-priority" "limit = 4; label = \"cpu\"" (value "string" "integer-priority")
  , expect "string.boolean-priority" "flag = False; label = \"cpu\"" (value "string" "boolean-priority")
  , expect "string.import" "" (value "string" "import")
  , expect "string.shipped-lanes-loci" "15,16,17" (value "string" "shipped-lanes-loci")
  , expect "string.shipped-lanes-witness" "changed" (value "string" "shipped-lanes-witness")
  , expect "kill.killed" "3" (value "kill" "killed")
  , expect "kill.viable" "4" (value "kill" "viable")
  , expect "kill.stillborn" "2" (value "kill" "stillborn")
  , expect "kill.ratio" "3 % 4" (value "kill" "ratio")
  , expect "kill.rows" "8" (value "kill" "rows")
  , expect "attribution.owned-red" "True" (value "attribution" "owned-red")
  , expect "attribution.unowned-red" "False" (value "attribution" "unowned-red")
  , expect "attribution.no-policy" "True" (value "attribution" "no-policy")
  , expect "attribution.empty-ledger" "False" (value "attribution" "empty-ledger")
  , expect "hygiene.fixture.kernel-lines" "13" (value "hygiene" "fixture.kernel-lines")
  , expect "hygiene.fixture.cap" "5" (value "hygiene" "fixture.cap")
  , expect "hygiene.fixture.cpp" "2" (value "hygiene" "fixture.cpp")
  , expect "hygiene.fixture.run-modules" "[\"src/validation-kernel/Amoebius/Validation/FooRun/Internal.hs\"]" (value "hygiene" "fixture.run-modules")
  , expect "hygiene.fixture.phase-literals" "1" (value "hygiene" "fixture.phase-literals")
  , expect "hygiene.fixture.phase-tables" "1" (value "hygiene" "fixture.phase-tables")
  , expect "hygiene.fixture.duplicates" "Substrate" (value "hygiene" "fixture.duplicates")
  , expect "hygiene.fixture.product-duplicates" "Substrate" (value "hygiene" "fixture.product-duplicates")
  , expect "hygiene.fixture.problems" "5" (value "hygiene" "fixture.problems")
  , expect "hygiene.clean.green" "True" (value "hygiene" "clean.green")
  , expect "hygiene.clean.cap" "14000" (value "hygiene" "clean.cap")
  , expect "legacy.clean-hygiene" "True" (value "legacy" "clean-hygiene")
  , expect "legacy.required-evidence" legacyUnavailable (value "legacy" "required-evidence")
  , expect "legacy.required-evidence.run-root" "False" (value "legacy" "required-evidence.run-root")
  , expect "legacy.preflight-disabled" legacyUnavailable (value "legacy" "preflight-disabled")
  , expect "legacy.preflight-disabled.run-root" "False" (value "legacy" "preflight-disabled.run-root")
  , expect "legacy.unknown-phase" "LEGACY-INVENTORY-UNAVAILABLE: unknown phase 96" (value "legacy" "unknown-phase")
  , expect "legacy.unknown-phase.run-root" "False" (value "legacy" "unknown-phase.run-root")
  , expect "fresh.directory-refusal" "RUN-ROOT-NOT-FRESH:.build/runs/stale-dir" (value "fresh" "directory-refusal")
  , expect "fresh.directory-sentinel" "\"keep stale work\\n\"" (value "fresh" "directory-sentinel")
  , expect "fresh.file-refusal" "RUN-ROOT-NOT-FRESH:.build/runs/stale-file" (value "fresh" "file-refusal")
  , expect "fresh.file-bytes" "\"keep stale file\\n\"" (value "fresh" "file-bytes")
  , expect "fresh.absent-refusal" legacyUnavailable (value "fresh" "absent-refusal")
  , expect "fresh.absent-created" "False" (value "fresh" "absent-created")
  , expect "fresh.custody-refusal" legacyUnavailable (value "fresh" "custody-refusal")
  , expect "fresh.custody-sentinel" "\"keep stale work\\n\"" (value "fresh" "custody-sentinel")
  , expect "fresh.custody-entries" "[\"sentinel\"]" (value "fresh" "custody-entries")
  , expect "ratchet.empty" "none" (value "ratchet" "empty")
  , expect "ratchet.history" "5" (value "ratchet" "history")
  , expect "ratchet.reset" "5" (value "ratchet" "reset")
  , expect "ratchet.void" "5" (value "ratchet" "void")
  , expect "ratchet.missing" "accepted kernel observation is absent, repeated, or invalid" (value "ratchet" "missing")
  , expect "ratchet.duplicate" "accepted kernel observation is absent, repeated, or invalid" (value "ratchet" "duplicate")
  , expect "ratchet.malformed" "accepted kernel observation is absent, repeated, or invalid" (value "ratchet" "malformed")
  , expect "ratchet.oversized" "accepted kernel observation is absent, repeated, or invalid" (value "ratchet" "oversized")
  , expect "ratchet.overflow" "accepted kernel observation is absent, repeated, or invalid" (value "ratchet" "overflow")
  , expect "ratchet.noncanonical" "accepted kernel observation is absent, repeated, or invalid" (value "ratchet" "noncanonical")
  , expect "ratchet.command-guard" "KernelOverBudget: 6 lines against a cap of 5" (value "ratchet" "command-guard")
  , expect "hygiene.vocabulary" "Architecture,CapabilityArm,ComputeEngine,Detected,EngineRuntime,ExtensionId,InferenceFamily,Lane,Quantity,Register,ResourceVector,Substrate" (value "hygiene" "vocabulary")
  , expect "capture.all-green" "True" (value "capture" "all-green")
  , expect "capture.one-red" "False" (value "capture" "one-red")
  , expect "capture.empty-observation" "False" (value "capture" "empty-observation")
  , expect "capture.reordered" "False" (value "capture" "reordered")
  , expect "capture.rows" "41" (value "capture" "rows")
  , expect "capture.categories" "18" (value "capture" "categories")
  , expect "preflight.clean" "" (value "preflight" "clean")
  , expect "preflight-status-surface-dirty" "StatusSurfaceDirty" (value "preflight" "status-surface-dirty")
  , expect "preflight.predecessor-not-committed" "PredecessorNotCommitted" (value "preflight" "predecessor-not-committed")
  , expect "preflight.status-without-receipt" "STATUS-WITHOUT-RECEIPT" (value "preflight" "status-without-receipt")
  , expect "preflight-predecessor-not-reproduced" "PredecessorNotReproduced" (value "preflight" "predecessor-not-reproduced")
  , expect "preflight.frozen-finding" "GOVERNANCE-UNACCEPTED" (value "preflight" "frozen-finding")
  , expect "preflight.hardware-before-barrier" "HARDWARE-BEFORE-BARRIER" (value "preflight" "hardware-before-barrier")
  , expect "preflight.hardware-after-barrier" "" (value "preflight" "hardware-after-barrier")
  , expect "preflight.substrate-absent" "SUBSTRATE-ABSENT" (value "preflight" "substrate-absent")
  , expect "preflight.kernel-over-budget" "KernelOverBudget" (value "preflight" "kernel-over-budget")
  , expect "preflight.spec-weakened" "SPEC-WEAKENED" (value "preflight" "spec-weakened")
  , expect "preflight.spec-unchanged" "" (value "preflight" "spec-unchanged")
  , expect "preflight.first-run" "" (value "preflight" "first-run")
  , expect "preflight.weakened-detail" "case unbound-need" (value "preflight" "weakened-detail")
  , expect "store.write-seed" "ok" (value "store" "write-seed")
  , expect "store.write-receipt" "ok" (value "store" "write-receipt")
  , expect "store-seed-roundtrip" "equal" (value "store" "seed-roundtrip")
  , expect "store-receipt-roundtrip" "equal" (value "store" "receipt-roundtrip")
  , expect "store.reset-receipt" "kept-beside-pass" (value "store" "reset-receipt")
  , expect "store.latest-generation" "accept phase 0" (value "store" "latest-generation")
  , expect "store.other-generation" "absent" (value "store" "other-generation")
  , expect "store-tampered-receipt" "record digest or UTF-8 is invalid" (value "store" "tampered-receipt")
  , expect "store.corrupted-record" "record digest or UTF-8 is invalid" (value "store" "corrupted-record")
  , expect "store.restored-receipt" "equal" (value "store" "restored-receipt")
  , expect "store.generation-directory" "/s/generation-abcdef0123456789" (value "store" "generation-directory")
  , expect "archive.write" "accepted" (value "archive" "write")
  , expect "archive.roundtrip" "exact" (value "archive" "roundtrip")
  , expect "archive.repeat" "same" (value "archive" "repeat")
  , expect "archive.tampered-evidence" "archive receipt identity or canonical form is invalid" (value "archive" "tampered-evidence")
  , expect "archive.missing-file" "archive bundle has missing or extra records" (value "archive" "missing-file")
  , expect "archive.symlink" "archive bundle contains a symbolic link" (value "archive" "symlink")
  , expect "archive.symlink-root" "archive path contains a symbolic link" (value "archive" "symlink-root")
  , expect "archive.symlink-bundle" "archive bundle is a symbolic link" (value "archive" "symlink-bundle")
  , LedgerRow "archive.symlink-queries" (archiveLinkQueries (value "archive" "symlink-queries")) (value "archive" "symlink-queries")
  , expect "archive.restored" "exact" (value "archive" "restored")
  , expect "archive.distinct-run-bundle" "distinct" (value "archive" "distinct-run-bundle")
  , expect "void.setup" "ready" (value "void" "setup")
  , expect "void.latest-before-red" "newer" (value "void" "latest-before-red")
  , expect "void.tied-publication" "archive receipt issued-at is not newer than the existing phase bundle" (value "void" "tied-publication")
  , expect "void.backdated-publication" "archive receipt issued-at is not newer than the existing phase bundle" (value "void" "backdated-publication")
  , expect "void.wrong-target" "void target or failure identity is invalid" (value "void" "wrong-target")
  , expect "void.invalid-failure" "void target or failure identity is invalid" (value "void" "invalid-failure")
  , expect "void.write" "accepted" (value "void" "write")
  , expect "void.repeat" "same" (value "void" "repeat")
  , expect "void.no-fallback" "blocked" (value "void" "no-fallback")
  , expect "void.history-retained" "two-bundles" (value "void" "history-retained")
  , expect "void.tampered" "void record identity or target is invalid" (value "void" "tampered")
  , expect "void.green-recovery" "later-green" (value "void" "green-recovery")
  , expect "crossvoid.targets" "3" (value "crossvoid" "targets")
  , expect "crossvoid.unrecorded-green" "unrecorded-green" (value "crossvoid" "unrecorded-green")
  , expect "crossvoid.downstream" "0" (value "crossvoid" "downstream")
  , expect "crossvoid.unrelated" "unrelated" (value "crossvoid" "unrelated")
  , expect "crossvoid.history" "5" (value "crossvoid" "history")
  , expect "crossvoid.missing" "recorded receipt is absent from the archive" (value "crossvoid" "missing")
  , expect "status.recorded-frontier" "one-frontier" (value "status" "recorded-frontier")
  , expect "status.surface-digest-stable" "changed" (value "status" "surface-digest-stable")
  , expect "status.patched-files" "3" (value "status" "patched-files")
  , expect "status.bare-receipt-missing" "True" (value "status" "bare-receipt-missing")
  , expect "status.receipted-receipt-missing" "False" (value "status" "receipted-receipt-missing")
  , expect "status.receipted-structural-findings" "" (value "status" "receipted-structural-findings")
  , expect "status.after-active" "✅ Done" (value "status" "after-active")
  , expect "status.after-successor" "🔄 Active — NOT VALIDATED" (value "status" "after-successor")
  , expect "status.after-active-sprints" "done" (value "status" "after-active-sprints")
  , expect "status.receipt-recorded" (Text.replicate 64 "b") (value "status" "receipt-recorded")
  , expect "status.receipt-line" "✅ Done." (value "status" "receipt-line")
  , expect "package.product-closure-validator-free" "True" (value "package" "product-closure-validator-free")
  , expect "package.verifier-links-runner" "True" (value "package" "verifier-links-runner")
  , expectAtMost "package.flags" 20 (value "package" "flags")
  , expect "package.executables" "amoebius,amoebius-validate,extension-source-admission" (value "package" "executables")
  ] <> [expect ("oracle-syntax." <> name) (Text.pack (show expected)) (value "oracle-syntax" name) | (name, expected) <- oracleSyntaxExpected]
    <> oracleBuildJudge [values | "oracle-build" : values <- rows]
    <> oracleInputJudge [values | "oracle-input" : values <- rows]
    <> oracleIsolationJudge [values | "oracle-isolation" : values <- rows]
    <> sourceReadJudge [values | "source-read" : values <- rows]
    <> contractStructureJudge [values | "contracts" : values <- rows]
    <> correspondenceJudge [values | "correspondence" : values <- rows]
    <> receiptCustodyJudge [values | "custody-native" : values <- rows]
    <> statusAuthorityJudge [values | "status-native" : values <- rows]
    <> runnerAuthorityJudge [values | "authority-native" : values <- rows]
    <> freshInputJudge [values | "fresh-native" : values <- rows]
    <> packageSyntaxJudge [values | "package-syntax" : values <- rows]
    <> map (\(name,green,observed) -> LedgerRow name green observed) (sourceTreeJudge [values | "source-tree" : values <- rows])
    <> reproducibleJudge [values | "reproducible" : values <- rows]
    <> inventoryChecks rows <> resetChecks rows
 where
  value kind key = case [rest | (k : name : rest) <- rows, k == kind, name == key] of
    ((observed : _) : _) -> observed
    _ -> "absent"
  value3 kind key = case [rest | (k : name : rest) <- rows, k == kind, name == key] of
    ((_ : lines' : _) : _) -> lines'
    _ -> "absent"

reproducibleJudge :: [[Text]] -> [LedgerRow]
reproducibleJudge input =
  let rows = [if take 1 row == ["reproducible"] then drop 1 row else row | row <- input]
      cases = [("stable-across-runs", "same"), ("diagnostic-path-independent", "same"), ("diagnostic-nonce-independent", "same")
        ,("diagnostic-fields-independent", "same"), ("row-order-independent", "same")]
        <> [(name, "differs") | name <- ["verdict-sensitive", "ledger-sensitive", "spec-sensitive", "ledger-verdict-sensitive"
           ,"ledger-row-omitted", "ledger-row-added", "ledger-exit-sensitive", "ledger-missing-exit-sensitive"
           ,"mutant-outcome-sensitive", "mutant-stage-sensitive", "mutant-location-sensitive", "mutant-operator-sensitive"]]
        <> [(name, "True") | name <- ["raw-transcript-retained", "valid-ledger", "valid-observation-tabs"]]
        <> [(name, "False") | name <- ["red-ledger", "failed-exit", "missing-exit", "empty-ledger", "blank-line", "garbage-line"
           ,"duplicate-row", "empty-name", "unknown-verdict", "truncated-row"]]
      observed name = [value | [key, value] <- rows, key == name]
      label name = if name == "stable-across-runs" then "receipt-reproducible-digest-stable" else "reproducible." <> name
  in LedgerRow "reproducible.discovery" (sort [name | [name, _] <- rows] == sort (map fst cases) && all ((== 2) . length) rows) "closed replay and ledger controls"
    : [LedgerRow (label name) (observed name == [expected]) (Text.pack (show (observed name))) | (name, expected) <- cases]

oracleSyntaxExpected :: [(Text, [(Text, FilePath)])]
oracleSyntaxExpected = [(name, [(reason, "test/oracle/dsl/Portability.hs") | reason <- reasons]) | (name, reasons) <-
  [("baseline", []), ("comment", []), ("quoted-language", []), ("quoted-foreign", []), ("operator", [])
  ,("cpp-pragma", ["ORACLE-CPP"]), ("compact-cpp", ["ORACLE-CPP"]), ("cpp-directive", ["ORACLE-CPP"]), ("tab-cpp", ["ORACLE-CPP"])
  ,("th-pragma", ["ORACLE-TEMPLATE-HASKELL"]), ("th-quotes", ["ORACLE-TEMPLATE-HASKELL"])
  ,("splice", ["ORACLE-TEMPLATE-HASKELL"]), ("typed-splice", ["ORACLE-TEMPLATE-HASKELL"]), ("quote", ["ORACLE-TEMPLATE-HASKELL"])
  ,("name-quote", ["ORACLE-TEMPLATE-HASKELL"]), ("constructor-quote", ["ORACLE-TEMPLATE-HASKELL"])
  ,("operator-quote", ["ORACLE-TEMPLATE-HASKELL"]), ("type-name-quote", ["ORACLE-TEMPLATE-HASKELL"])
  ,("promoted-type", []), ("promoted-list", [])
  ,("typed-quote", ["ORACLE-TEMPLATE-HASKELL"]), ("pattern-quote", ["ORACLE-TEMPLATE-HASKELL"])
  ,("declaration-quote", ["ORACLE-TEMPLATE-HASKELL"]), ("type-quote", ["ORACLE-TEMPLATE-HASKELL"])
  ,("quasiquote", ["ORACLE-TEMPLATE-HASKELL"]), ("foreign-comment", ["ORACLE-FOREIGN-IMPORT"]), ("foreign-export", ["ORACLE-FOREIGN-IMPORT"])
  ,("options", ["ORACLE-SOURCE-UNSCANNED"]), ("malformed", ["ORACLE-SOURCE-UNSCANNED"]), ("multiline-data", [])]]

archiveLinkQueries :: Text -> Bool
archiveLinkQueries input = case reads (Text.unpack input) :: [([[FilePath]], String)] of
  [([outer, [bundle], files], "")] ->
    outer == ["", generation, receipts] && Logical.takeDirectory bundle == receipts
      && prefix `isPrefixOf` Logical.takeFileName bundle
      && let digest = drop (length prefix) (Logical.takeFileName bundle)
          in length digest == 64 && all (`elem` ("0123456789abcdef" :: String)) digest
      && sort files == sort (bundle : [bundle <> "/" <> name | name <- names])
  _ -> False
 where
  generation = "generation-aaaaaaaaaaaaaaaa"
  receipts = generation <> "/receipts"
  prefix = "phase-00-" <> replicate 64 'b' <> "-"
  names = ["receipt.tsv", "receipt.tsv.sha256", "candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]

-- Fixed serial native clients: no concurrency option or compiler fallback.
-- The independent clients observe the actual public source API. Missing GHC
-- or a different error/locus cannot establish an opaque boundary.
inventoryNativeChecks :: FilePath -> IO [LedgerRow]
inventoryNativeChecks directory = do
  compiler <- findExecutable "ghc"
  mapM (observe compiler) boundaries
 where
  boundaries =
    [ ("requirement-constructor", "LegacyRequirement", "legacyRequirement LtdVal001", "LegacyRequirement", 7,
        ["Illegal term-level use of the type constructor", "LegacyRequirement", "[GHC-01928]"])
    , ("analyzer-key-constructor", "LegacyAnalyzerKey", "legacyRequirementAnalyzer (legacyRequirement LtdVal001)", "LegacyAnalyzerKey undefined", 7,
        ["Illegal term-level use of the type constructor", "LegacyAnalyzerKey", "[GHC-01928]"])
    , ("case-key-constructor", "LegacyCaseKey", "NonEmpty.head (legacyRequirementCases (legacyRequirement LtdVal001))", "LegacyCaseKey undefined", 7,
        ["Illegal term-level use of the type constructor", "LegacyCaseKey", "[GHC-01928]"])
    , ("scope-constructor", "LegacyScope", "legacyRequirementScope legacyBootstrapSourceRequirement", "LegacyCapturedBootstrap", 7,
        ["Data constructor not in scope", "LegacyCapturedBootstrap", "[GHC-88464]"])
    , ("lifecycle-constructor", "LegacyLifecycle", "legacyRequirementLifecycle (legacyRequirement LtdVal001)", "LegacyActive", 7,
        ["Data constructor not in scope", "LegacyActive", "[GHC-88464]"])
    , ("case-record-update", "LegacyRequirement", "(legacyRequirement LtdVal001)", "(legacyRequirement LtdVal001) {legacyRequirementCases = undefined}", 38,
        ["Not in scope: record field", "legacyRequirementCases", "[GHC-22385]"])
    , ("requirement-read", "LegacyRequirement", "legacyRequirement LtdVal001", "read \"forged\"", 7,
        ["No instance for", "Read LegacyRequirement"])
    ]
  observe compiler (name, signature, legal, illegal, column, fragments) = do
    admitted <- compile compiler name "Legal" signature legal
    refused <- compile compiler name "Illegal" signature illegal
    let positive = case admitted of Right (ExitSuccess, out, err) -> null out && null err; _ -> False
        negative = case refused of
          Right (ExitFailure 1, _, err) -> let message = Text.pack err in
            all (`Text.isInfixOf` message) fragments
            && ("Illegal.hs:5:" <> Text.pack (show (column :: Int)) <> ": error:") `Text.isInfixOf` message
            && Text.count ": error:" message == 1
          _ -> False
    pure (LedgerRow ("legacy.native." <> name) (positive && negative)
      (Text.pack (show (positive, negative, refused))))
  compile Nothing _ _ _ _ = pure (Left "native GHC unavailable")
  compile (Just compiler) name moduleName signature expression = do
    let root = directory </> Text.unpack name </> moduleName
        source = root </> "Illegal.hs"
        path = if moduleName == "Legal" then root </> "Legal.hs" else source
        program = Text.unlines ["module Client where", "import Amoebius.Plan.Legacy", "import Data.List.NonEmpty qualified as NonEmpty", "bad :: " <> signature, "bad = " <> expression]
    createDirectoryIfMissing True root
    TextIO.writeFile path program
    result <- try (readProcessWithExitCode compiler ["-v0", "-j1", "-XGHC2024", "--make", "-fno-code", "-fforce-recomp",
      "-fdiagnostics-color=never", "-fno-diagnostics-show-caret", "-isrc/plan-decisions", "-outputdir", root, path] "")
      :: IO (Either IOException (ExitCode, String, String))
    case result of
      Left problem -> pure (Left (show problem))
      Right (code, out, err) -> do
        TextIO.writeFile (root </> "stdout") (Text.pack out)
        TextIO.writeFile (root </> "stderr") (Text.pack err)
        TextIO.writeFile (root </> "exit") (Text.pack (show code))
        pure (Right (code, out, err))

-- Independently authored obligation descriptions. These judge declarations,
-- not analyzer execution, zero findings, retirement, or a phase verdict.
resetChecks :: [[Text]] -> [LedgerRow]
resetChecks rows =
  [ expect ("reset." <> key) wanted (value key) | (key, wanted) <-
      [("exit", "ExitSuccess"), ("tracker-changed", "True"), ("archive-count", "1"),
       ("cause", "legacy analyzer join missing|LTD-VAL-001"), ("postimage", "True"),
       ("receipts-remaining", "0"), ("no-gate-pass", "True"),
       ("blocked-archive.exit", "ExitFailure 1"), ("blocked-archive.unchanged", "True"),
       ("blocked-archive.reason", "reset receipt not recorded: archive root is not a directory"),
       ("missing-document.exit", "ExitFailure 1"), ("missing-document.unchanged", "True"),
       ("missing-document.reason", "reset receipt not recorded: status projection is incomplete or inconsistent"),
       ("future-owner.exit", "ExitSuccess"), ("future-owner.unchanged", "True"),
       ("empty-gap.exit", "ExitFailure 1"), ("empty-gap.unchanged", "True"),
       ("empty-gap.reason", "VALIDATOR-GAP-ABSENT"),
       ("unknown-decision.exit", "ExitFailure 1"), ("unknown-decision.unchanged", "True"),
       ("unknown-decision.reason", "DECISION-UNKNOWN: DL-9999"),
       ("unknown-product.exit", "ExitFailure 1"), ("unknown-product.unchanged", "True"),
       ("unknown-product.reason", "PRODUCT-GAP-UNKNOWN: LTD-NONE-999"),
       ("unowned-product.exit", "ExitFailure 1"), ("unowned-product.unchanged", "True"),
       ("unowned-product.reason", "PRODUCT-GAP-UNOWNED: LTD-LIB-002")]]
  <> [expect ("reset.projection." <> number) (document number) (observedDocument number) | number <- ordinals]
  <> [expect "reset.tracker-projection" tracker observedTracker]
  <> [LedgerRow "reset.complete-document-discovery"
        ([number | ["reset-projection", number, _] <- rows] == ordinals) "closed phase inventory"]
 where
  ordinals = map (Text.pack . show) ([0 .. 9] <> [50 .. 95] :: [Int])
  value key = case [v | ["reset", name, v] <- rows, key == name] of [v] -> v; _ -> "missing-or-duplicate"
  shown values = case values of
    [raw] -> case reads (Text.unpack raw) :: [(Text, String)] of [(v, "")] -> v; _ -> "unreadable"
    _ -> "missing-or-duplicate"
  observedDocument number = shown [v | ["reset-projection", actual, v] <- rows, actual == number]
  observedTracker = shown [v | ["reset-tracker", v] <- rows]
  status number = if number == "0" then "🔄 Active — NOT VALIDATED" else "⏸️ Blocked — NOT VALIDATED"
  document number = Text.unlines
    (["# Fixture " <> number, "", "## Phase Status", "", status number <> ".", "sentinel-body-" <> number]
      <> ["## Sprint " <> number <> ".1: Fixture " <> (if number == "0" then "🔄" else "⏸️"),
          "**Status**: " <> (if number == "0" then "Active — NOT VALIDATED" else "Blocked — NOT VALIDATED"), "sentinel-sprint-" <> number <> ".1",
          "## Sprint " <> number <> ".2: Fixture ⏸️", "**Status**: Blocked — NOT VALIDATED", "sentinel-sprint-" <> number <> ".2"])
  tracker = Text.unlines ["| " <> number <> " | fixture | none | none | — | " <> status number <> " | — |" | number <- ordinals]

inventoryChecks :: [[Text]] -> [LedgerRow]
inventoryChecks rows =
  [ expect ("legacy.inventory." <> identifier) (Text.intercalate "|" fields)
      (case [values | (key, values) <- actual, key == identifier] of
        [values] -> Text.intercalate "|" values
        _ -> "missing-or-duplicate")
  | (identifier, fields) <- expected ]
  <> [LedgerRow "legacy.inventory.complete" (actual == expected) (Text.pack (show (length actual)))]
  <> [LedgerRow "legacy.inventory.bootstrap-scope" (bootstrap ==
      [["LTD-SRC-008", "repository_layout_conformance", "active", "captured-bootstrap", "bootstrap-structure",
        "dynamic-import,undeclared-effect,command-dispatch,argv-rewritten,unscanned-syntax"]]) (Text.pack (show bootstrap))]
  <> [LedgerRow "legacy.inventory.supported" (sort supported == sort
      ([[identifier,"snapshot",if identifier `elem` qualified then "True" else "False"] | (identifier,_,_,_) <- obligations]
        <> [["LTD-SRC-008","captured-bootstrap","True"]])) (Text.pack (show supported))]
 where
  actual = [(identifier, fields) | ("legacy-inventory" : identifier : fields) <- rows]
  bootstrap = [fields | ("legacy-bootstrap" : fields) <- rows]
  supported = [fields | ("legacy-supported" : fields) <- rows]
  qualified = ["LTD-VAL-001","LTD-VAL-002","LTD-VAL-003","LTD-VAL-004","LTD-VAL-006","LTD-KRN-001","LTD-KRN-002","LTD-KRN-003","LTD-BOOT-001","LTD-SRC-000","LTD-SRC-008","LTD-SRC-001","LTD-SRC-005","LTD-SRC-006","LTD-NAME-001","LTD-META-001","LTD-SRC-007","LTD-SRC-009"]
  expected = [(identifier, [owner, if identifier `elem` retired then "retired" else "active", "snapshot", analyzer, cases]) | (identifier, owner, analyzer, cases) <- obligations]
  retired = ["LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003", "LTD-BOOT-001", "LTD-SRC-007", "LTD-SRC-009"]
  obligations =
    [ ("LTD-SRC-000", "repository_layout_conformance", "source-graph", "path-omitted,mode-changed,bytes-changed,foreign-behavior-disguised,effect-unattributed")
    , ("LTD-SRC-001", "repository_layout_conformance", "tool-source", "tracked-python-gate,renamed-tool-root")
    , ("LTD-SRC-002", "typed_spine", "dhall-source", "tracked-dhall,tracked-dhall-registry,roundtrip-changed")
    , ("LTD-SRC-003", "typed_spine", "wire-schema", "tracked-proto,field-number-changed,vendor-attribution-duplicated")
    , ("LTD-SRC-004", "ui_program_language_binding", "ui-source", "tracked-purescript,tracked-javascript,root-package-manifest")
    , ("LTD-SRC-005", "repository_layout_conformance", "pulumi-source", "tracked-pulumi-yaml,renamed-pulumi-program")
    , ("LTD-SRC-006", "repository_layout_conformance", "test-source", "tracked-test-script,tracked-test-table,tracked-expected-output,tracked-patch,tracked-mutant-body")
    , ("LTD-SRC-007", "toolchain_spike", "probe-source", "foreign-probe-script,foreign-probe-fixture,probe-case-omitted")
    , ("LTD-SRC-008", "repository_layout_conformance", "bootstrap-source", "bootstrap-byte-changed,bootstrap-extra-role,bootstrap-argv-rewritten")
    , ("LTD-SRC-009", "toolchain_spike", "vendor-source", "top-level-vendor,mutable-reference,tracked-vendor-proto,tracked-foreign-package,tracked-patch-program")
    , ("LTD-META-001", "repository_layout_conformance", "ignore-context", "retired-generated-root,undeclared-state-root")
    , ("LTD-VAL-001", "documentation_suite", "runner-authority", "noop-subject,constant-success-checker,forged-exit,omitted-discovery,unavailable-boundary")
    , ("LTD-VAL-002", "documentation_suite", "contract-correspondence", "gate-spec-mismatch,phase-role-swap,byte-copy-equivalence,subject-not-shipped,retired-domain-literal")
    , ("LTD-VAL-003", "documentation_suite", "receipt-custody", "generation-one-receipt,verifier-diverged,predecessor-closure-edited")
    , ("LTD-VAL-004", "documentation_suite", "status-authority", "status-surface-dirty,status-without-receipt,predecessor-not-reproduced,status-edit-without-receipt")
    , ("LTD-VAL-005", "typed_spine", "spine-handoffs", "hand-built-stage,noop-stage,render-omitted,executed-argv-diverged")
    , ("LTD-VAL-006", "documentation_suite", "fresh-inputs", "stale-run,ignored-input,authored-output,ambient-temp,replayed-input,empty-discovery")
    , ("LTD-VAL-007", "host_assert_cli", "bounded-supervisor", "wrong-length-entropy,endless-entropy,missing-limit,deadline-exceeded,memory-pressure,forced-cleanup")
    , ("LTD-VAL-008", "host_assert_cli", "child-environment", "path-absent,ambient-path,foreign-executable,precedence-reordered,undeclared-variable")
    , ("LTD-DOC-001", "typed_spine", "semantic-inputs", "markdown-behavior-consumer,serialized-registry-consumer")
    , ("LTD-NAME-001", "repository_layout_conformance", "runtime-identity", "stale-ordinal,copied-ordinal,phase-named-runtime")
    , ("LTD-HOST-001", "host_ensure_kernel", "host-ensure", "ensure-caller-bypassed,install-result-ignored,idempotency-broken")
    , ("LTD-HOST-002", "host_ensure_kernel", "owned-executables", "bare-name,foreign-root,ambient-resolution,changed-owner,production-overlap")
    , ("LTD-IMG-001", "base_image_registry", "natural-image", "cross-architecture,emulator-used,index-join")
    , ("LTD-RUN-001", "bootstrap_coordinator_kind", "product-identity", "identity-by-executable,phase-runtime-path,second-product-stanza")
    , ("LTD-SEED-001", "infernix_rederivation", "infernix-independence", "seed-fetch,upstream-namespace,copied-hash,captured-output")
    , ("LTD-SEED-002", "jitml_rederivation", "jitml-independence", "seed-fetch,missing-module,copied-output,silent-cpu-fallback")
    , ("LTD-BOOT-001", "toolchain_spike", "native-tool-versions", "missing-tool,failed-command,malformed-version,unsupported-version")
    , ("LTD-KRN-001", "documentation_suite", "kernel-shape", "per-phase-run-module,phase-number-literal,kernel-over-ratchet")
    , ("LTD-KRN-002", "documentation_suite", "mutation-source", "authored-mutant-symbol,authored-mutant-flag,authored-mutant-selector")
    , ("LTD-KRN-003", "documentation_suite", "solver-demotion", "fake-inductive,fake-proved")
    , ("LTD-DSL-001", "typed_spine", "decoded-lowering", "lowering-bypassed,nonce-discarded")
    , ("LTD-DSL-002", "typed_spine", "typed-root", "two-server-quorum,empty-needs,text-tree-authority")
    , ("LTD-DSL-003", "witness_manifests_capacity_storage", "witness-rendering", "placement-ignored,requests-changed,claim-bytes-changed")
    , ("LTD-DSL-004", "substrates_lanes_image_recipe", "substrate-recipes", "two-server-rke2,duplicate-host,tainted-only-host,unrequired-lane,digest-bearing-channel,architecture-mismatch")
    , ("LTD-DSL-005", "extension_admission_attested_scope", "linked-extensions", "unlinked-extension,consumed-calculus-removed")
    , ("LTD-DSL-006", "ui_program_language_binding", "ui-program", "guard-gap,type-mismatch,unbound-port,requirement-without-port")
    , ("LTD-DSL-007", "extension_admission_attested_scope", "extension-ast", "qualified-forbidden-name,forbidden-reexport,template-haskell-splice,cpp-definition,foreign-import,string-built-name,comment-split-token,raw-io,unsafe-call,orphan-instance,unsanctioned-import")
    , ("LTD-DSL-008", "extension_admission_attested_scope", "attested-scope", "text-minted-scope,claimed-identity,scope-coercion,foreign-tenant-reentry,missing-scope-label")
    , ("LTD-DSL-009", "typed_spine", "endpoint-consumption", "constant-demand,noop-renderer")
    , ("LTD-LIB-001", "dsl_barrier", "parked-calculi", "unconsumed-calculus,undecided-library")
    , ("LTD-LIB-002", "later-phases", "proof-track", "interpreter-error-erased,parameter-state-precedence,raw-line-equation-selection,fake-solver-authority")
    , ("LTD-UI-001", "ui_program_release", "ui-projection", "phantom-route,placeholder-bundle,unchecked-program")
    , ("LTD-HELPER-001", "host_assert_cli", "runtime-handoff", "python-runtime-helper,foreign-deploy-command")
    ]

-- The typed-spine entry owes its own analyzers and every earlier owner. This
-- literal does not import the production inventory or derive expected owners.
legacyUnavailable :: Text
legacyUnavailable = "LEGACY-ANALYZER-UNAVAILABLE: LTD-SRC-002,LTD-SRC-003,LTD-VAL-005,LTD-DOC-001,LTD-DSL-001,LTD-DSL-002,LTD-DSL-009"

expect :: Text -> Text -> Text -> LedgerRow
expect name expected observed = LedgerRow name (expected == observed) observed

expectAtMost :: Text -> Int -> Text -> LedgerRow
expectAtMost name limit observed = LedgerRow name (maybe False (<= limit) (readInt observed)) observed
 where
  readInt text = case reads (Text.unpack text) :: [(Int, String)] of
    [(value, "")] -> Just value
    _ -> Nothing

expectPrefix :: Text -> Text -> Text -> LedgerRow
expectPrefix name prefix observed = LedgerRow name (prefix `Text.isPrefixOf` observed) observed

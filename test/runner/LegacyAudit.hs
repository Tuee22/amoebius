{-# LANGUAGE OverloadedStrings #-}

-- | Raw observations from the source query and untrusted-report audit.
module LegacyAudit (legacyAuditRows, legacyKernelRows, legacyMutationRows, legacySolverRows, legacyBootstrapRows, legacyCorrespondenceRows, legacyCustodyRows, legacyStatusRows, legacyAuthorityRows, legacyFreshRows, legacyAdmissionRows, legacyProbeSourceRows, legacyVendorSourceRows, legacyTestSourceRows, legacyToolSourceRows, legacyPulumiSourceRows, legacyRuntimeIdentityRows, legacyIgnoreContextRows, legacySourceGraphRows, legacyBootstrapSourceRows, mutationRows, solverReintroductionRows, solverSourceRows) where

import Amoebius.Plan.Legacy qualified as L
import Amoebius.Plan.PhaseIdentity qualified as P
import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Runner.Legacy
import Amoebius.Validation.Runner.Observer (observe, runExit)
import Control.Exception (finally)
import Control.Monad (forM, unless)
import Data.ByteString qualified as Bytes
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Text.Encoding qualified as Encoding
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, findExecutable, makeAbsolute, removeFile, removePathForcibly)
import System.Exit (ExitCode (..), die)
import System.FilePath ((</>), takeDirectory)

solverSourceRows :: FilePath -> IO [[Text]]
solverSourceRows output = do
  absolute <- makeAbsolute output
  let tree = absolute </> "source"
      symbolic = "src/symbolic-checker/Amoebius/Checker/Symbolic.hs"
      refinement = "src/refinement-checker/Amoebius/Checker/Refinement.hs"
  original <- captureSource "." >>= either (die . Text.unpack) pure
  mapM_ (createDirectoryIfMissing True . (tree </>) . takeDirectory) [symbolic, refinement]
  initialized <- observe tree "git" ["init", "--quiet"]
  unless (runExit initialized == ExitSuccess) (die "solver source fixture initialization failed")
  let retained path = maybe (die "solver source missing") (pure . Encoding.decodeUtf8) (capturedSourceBytes original path)
  symbolicBody <- retained symbolic
  refinementBody <- retained refinement
  let variants =
        [("baseline", symbolicBody, refinementBody)
        ,("inductive", Text.replace "  | Inconclusive ObligationKind String\n" "  | Inconclusive ObligationKind String\n  | Inductive [(ObligationKind, String)]\n" symbolicBody, refinementBody)
        ,("renamed-positive", Text.replace "  | Inconclusive ObligationKind String\n" "  | Inconclusive ObligationKind String\n  | Certified\n" symbolicBody, refinementBody)
        ,("proved", symbolicBody, Text.replace "  = Inconclusive\n" "  = Inconclusive\n  | Proved\n" refinementBody)
        ,("quoted", symbolicBody <> "\n-- Inductive is not an admitted constructor\nsolverDiagnostic = \"data SymbolicResult = Inductive\"\n", refinementBody)
        ,("missing-declaration", Text.replace "data SymbolicResult\n" "data ParkedResult\n" symbolicBody, refinementBody)
        ,("missing-constructor", Text.replace "  | Unsupported [UnsupportedFeature]\n" "" symbolicBody, refinementBody)
        ,("duplicate-declaration", symbolicBody <> "\ndata SymbolicResult = Duplicate\n", refinementBody)
        ,("malformed", symbolicBody <> "\nunfinished = (\n", refinementBody)
        ,("missing-file", symbolicBody, "")]
  (do
    snapshots <- forM variants $ \(name, left, right) -> do
      TextIO.writeFile (tree </> symbolic) left
      if Text.null right then do
        present <- doesDirectoryExist (tree </> takeDirectory refinement)
        if present then removeFile (tree </> refinement) else pure ()
      else TextIO.writeFile (tree </> refinement) right
      let inputs = absolute </> "inputs" </> Text.unpack name
      createDirectoryIfMissing True inputs
      TextIO.writeFile (inputs </> "Symbolic.hs") left
      TextIO.writeFile (inputs </> "Refinement.hs") right
      current <- captureSource tree >>= either (die . Text.unpack) pure
      pure (name, current)
    forM (zip snapshots (observeLegacyMany P.phaseDomainLowerOrdinal (map snd snapshots) Nothing)) $ \((name, _), reports) ->
      case [report | report <- reports, reportedIdentity report == L.LtdKrn003, reportedScope report == "snapshot"] of
        [report] -> let (state, value) = case reportedObservation report of
                         AnalyzerUnavailable problem -> ("unavailable", problem)
                         AnalyzerFindings items -> ("findings", Text.pack (show [(findingReason item, findingPath item, findingLocus item) | item <- items]))
                    in pure [name, state, value, reportedSource report]
        _ -> die "solver source report missing or duplicate") `finally` removePathForcibly tree

-- Actual changed checker implementations, compiled and exercised serially.
-- These observations do not construct analyzer readiness or phase evidence.
solverReintroductionRows :: FilePath -> IO [[Text]]
solverReintroductionRows output = do
  original <- captureSource "." >>= either (die . Text.unpack) pure
  compiler <- findExecutable "ghc" >>= maybe (die "native compiler absent") pure
  cabal <- findExecutable "cabal" >>= maybe (die "native Cabal absent") pure
  _ <- runSolverReintroductions original output cabal compiler
  map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (output </> "solver-reintroduction.tsv")

-- Reintroductions perturb the actual shipped vocabulary and package description
-- in one fresh captured copy. Reports and retained witnesses are observations.
mutationRows :: FilePath -> IO [[Text]]
mutationRows output = do
  absolute <- makeAbsolute output
  exists <- doesDirectoryExist absolute
  if exists then die "mutation query output must be fresh" else createDirectoryIfMissing True absolute
  snapshot <- captureSource "." >>= either (die . Text.unpack) pure
  let target = "src/vocabulary/Amoebius/Vocabulary.hs"
      retained path = maybe (die "mutation query source absent") pure (capturedSourceBytes snapshot path)
  source <- retained target
  package <- retained "amoebius.cabal"
  tree <- materializeSource snapshot (absolute </> "source") >>= either (die . Text.unpack) pure
  initialized <- observe tree "git" ["init", "--quiet"]
  unless (runExit initialized == ExitSuccess) (die "mutation query fixture Git initialization failed")
  let flag name = "\nflag " <> name <> "\n    default: False\n    manual: True\n"
      variants = [("baseline", "", ""), ("comment", "-- harmless_MUTANT = True\n", "")
        ,("quoted-module", "mutationProbe = \"module Example where\\nprobe_MUTANT = True\\n\"\n", "")
        ,("reserved-data", "mutationProbe = \"_MUTANT\"\n", "")
        ,("conditional", "#if DEBUG\nmutationProbe = True\n#endif\n", "")
        ,("identifier", "mutationProbe_MUTANT = True\n", "")
        ,("qualified-identifier", "mutationProbe = Prelude.value_MUTANT\n", "")
        ,("selector", "mutationProbe = \"AMOEBIUS_MUTANT\"\n", "")
        ,("selector-append", "mutationProbe = \"AMOEBIUS_\" ++ \"MUTANT\"\n", "")
        ,("selector-concat", "mutationProbe = concat [\"AMOEBIUS_\", \"MUTANT\"]\n", "")
        ,("selector-characters", "mutationProbe = ['A','M','O','E','B','I','U','S','_','M','U','T','A','N','T']\n", "")
        ,("selector-alias", "selectorName = \"AMOEBIUS_\" <> \"MUTANT\"\nmutationProbe = selectorName\n", "")
        ,("selector-qualified", "mutationProbe = Data.Text.append \"AMOEBIUS_\" \"MUTANT\"\n", "")
        ,("selector-let", "mutationProbe = let selectorName = \"AMOEBIUS_\" <> \"MUTANT\" in selectorName\n", "")
        ,("selector-bare-read", "mutationProbe = lookupEnv \"_MUTANT\"\n", "")
        ,("selector-aliased-read", "selectorRead = lookupEnv\nmutationProbe = selectorRead \"_MUTANT\"\n", "")
        ,("ordinary-concat", "mutationProbe = \"AMOEBIUS_\" <> \"FEATURE\"\n", "")
        ,("bare-identity", "mutationProbe = id \"_MUTANT\"\n", "")
        ,("shadow-parameter", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe selectorSuffix = selectorPrefix <> selectorSuffix\n", "")
        ,("shadow-let", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe = let selectorSuffix = \"FEATURE\" in selectorPrefix <> selectorSuffix\n", "")
        ,("predicate-alias", "containsMarker = Data.Text.isInfixOf\nmutationProbe = containsMarker \"_MUTANT\"\n", "")
        ,("alias-cycle", "selectorPrefix = selectorSuffix\nselectorSuffix = selectorPrefix\nmutationProbe = selectorPrefix\n", "")
        ,("closure-shadow", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"FEATURE\"\nselectorName = selectorPrefix <> selectorSuffix\nmutationProbe = let selectorSuffix = \"MUTANT\" in selectorName\n", "")
        ,("where-closure", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nselectorName = selectorPrefix <> selectorSuffix where selectorSuffix = \"FEATURE\"\nmutationProbe = selectorName\n", "")
        ,("qualified-alias", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe = Amoebius.Vocabulary.selectorPrefix <> Amoebius.Vocabulary.selectorSuffix\n", "")
        ,("qualified-shadow", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe selectorSuffix = Amoebius.Vocabulary.selectorPrefix <> Amoebius.Vocabulary.selectorSuffix\n", "")
        ,("multiline-decoy", "mutationDecoy = \"\"\"\n#if FEATURE\n\"\"\"\nmutationProbe = \"AMOEBIUS_\" <> \"MUTANT\"\n", "")
        ,("flag", "", flag "mutant-probe"), ("ordinary-flag", "", flag "tracing")
        ,("flag-exact", "", Text.concat [flag ("feature" <> Text.pack (show number)) | number <- [1 :: Int .. 20]])
        ,("flag-budget", "", Text.concat [flag ("feature" <> Text.pack (show number)) | number <- [1 :: Int .. 21]])]
  (do
    snapshots <- forM variants $ \(name, suffix, flags) -> do
      let prefix = if name == "multiline-decoy" then "{-# LANGUAGE MultilineStrings #-}\n" else ""
          body = Encoding.encodeUtf8 prefix <> source <> Encoding.encodeUtf8 suffix
          cabal = package <> Encoding.encodeUtf8 flags
          witness = absolute </> "inputs" </> Text.unpack name
      Bytes.writeFile (tree </> target) body
      Bytes.writeFile (tree </> "amoebius.cabal") cabal
      createDirectoryIfMissing True witness
      Bytes.writeFile (witness </> "Subject.hs") body
      Bytes.writeFile (witness </> "package.cabal") cabal
      current <- captureSource tree >>= either (die . Text.unpack) pure
      pure (name, current)
    forM (zip snapshots (observeLegacyMany P.phaseDomainLowerOrdinal (map snd snapshots) Nothing)) $ \((name, _), reports) -> do
        report <- case [row | row <- reports, reportedIdentity row == L.LtdKrn002, reportedScope row == "snapshot"] of
          [row] -> pure row
          _ -> die "mutation query row missing or duplicate"
        let (state, result) = case reportedObservation report of
              AnalyzerUnavailable problem -> ("unavailable", problem)
              AnalyzerFindings values -> ("findings", Text.pack (show [(maybe "unbound" L.renderLegacyId (findingIdentity f), findingScope f, findingPath f, findingLocus f, findingReason f) | f <- values]))
        pure [name, state, result, reportedSource report]) `finally` removePathForcibly tree

legacyKernelRows, legacyMutationRows, legacySolverRows, legacyBootstrapRows :: FilePath -> IO [[Text]]
legacyKernelRows = qualificationRows L.LtdKrn001
legacyMutationRows = qualificationRows L.LtdKrn002
legacySolverRows = qualificationRows L.LtdKrn003
legacyBootstrapRows = qualificationRows L.LtdSrc008
legacyCorrespondenceRows :: FilePath -> IO [[Text]]
legacyCorrespondenceRows = qualificationRows L.LtdVal002
legacyCustodyRows :: FilePath -> IO [[Text]]
legacyCustodyRows = qualificationRows L.LtdVal003
legacyStatusRows :: FilePath -> IO [[Text]]
legacyStatusRows = qualificationRows L.LtdVal004
legacyAuthorityRows :: FilePath -> IO [[Text]]
legacyAuthorityRows = qualificationRows L.LtdVal001
legacyFreshRows :: FilePath -> IO [[Text]]
legacyFreshRows = qualificationRows L.LtdVal006
legacyAdmissionRows :: FilePath -> IO [[Text]]
legacyAdmissionRows = qualificationRows L.LtdBoot001

legacyProbeSourceRows :: FilePath -> IO [[Text]]
legacyProbeSourceRows = qualificationRows L.LtdSrc007

legacyVendorSourceRows :: FilePath -> IO [[Text]]
legacyVendorSourceRows = qualificationRows L.LtdSrc009

legacyTestSourceRows :: FilePath -> IO [[Text]]
legacyTestSourceRows = qualificationRows L.LtdSrc006

legacyToolSourceRows :: FilePath -> IO [[Text]]
legacyToolSourceRows = qualificationRows L.LtdSrc001

legacyPulumiSourceRows :: FilePath -> IO [[Text]]
legacyPulumiSourceRows = qualificationRows L.LtdSrc005

legacyRuntimeIdentityRows :: FilePath -> IO [[Text]]
legacyRuntimeIdentityRows = qualificationRows L.LtdName001

legacySourceGraphRows :: FilePath -> IO [[Text]]
legacySourceGraphRows = qualificationRows L.LtdSrc000

legacyIgnoreContextRows :: FilePath -> IO [[Text]]
legacyIgnoreContextRows = qualificationRows L.LtdMeta001

legacyBootstrapSourceRows :: FilePath -> IO [[Text]]
legacyBootstrapSourceRows output = maybe (die "whole bootstrap owner absent") (\owner -> qualificationRowsAt owner L.LtdSrc008 output) (L.legacyOwnerOrdinal L.LtdSrc008)

qualificationRows :: L.LegacyId -> FilePath -> IO [[Text]]
qualificationRows identifier output = do
  phase <- if identifier == L.LtdSrc008 then pure P.phaseDomainLowerOrdinal else maybe (die "qualification owner absent") pure (L.legacyOwnerOrdinal identifier)
  qualificationRowsAt phase identifier output

qualificationRowsAt :: Int -> L.LegacyId -> FilePath -> IO [[Text]]
qualificationRowsAt phase identifier output = do
  absolute <- makeAbsolute output
  exists <- doesDirectoryExist absolute
  if exists then die "kernel qualification output must be fresh" else createDirectoryIfMissing True absolute
  source <- acquired "."
  cabal <- findExecutable "cabal" >>= maybe (die "native Cabal unavailable") pure
  compiler <- findExecutable "ghc"
  let qualify = qualifyLegacy identifier
  qualification <- qualify "." (absolute </> "qualified") phase Nothing compiler source >>= either (die . Text.unpack) pure
  let reports = qualifiedLegacyReports phase source [qualification]
      wantedScope = if identifier == L.LtdSrc008 && phase == P.phaseDomainLowerOrdinal then "captured-bootstrap" else "snapshot"
      changed f = map (\row -> if reportedIdentity row == identifier && reportedScope row == wantedScope then f row else row) reports
      currentAudit = auditQualifiedLegacyReports phase source
      audit name tree evidence values = ["scenario", name] : [["audit", name, refusal] | refusal <- (if capturedSourceDigest tree == capturedSourceDigest source then currentAudit else auditQualifiedLegacyReports phase tree) evidence values]
      other = absolute </> "other-source"
  mapM_ (createDirectoryIfMissing True . (other </>)) ["src/validation-kernel", "src/gate-spec"]
  initialized <- observe other "git" ["init", "--quiet"]
  unless (runExit initialized == ExitSuccess) (die "kernel qualification fixture initialization failed")
  TextIO.writeFile (other </> "src/validation-kernel/Kernel.hs") "module Kernel where\n"
  TextIO.writeFile (other </> "src/gate-spec/Spec.hs") "module Spec where\n"
  otherSource <- acquired other
  -- Serial source twins exercise the actual compiled query and its qualifying
  -- oracle. They supply no extra member of the phase's finite seed matrix.
  let queryVariants = if identifier == L.LtdKrn001 then
        [("per-phase-run-module", ", isRunModule file]", ", False]")
        ,("phase-number-literal", ", phaseLiteral text]", ", False]")
        ,("kernel-over-ratchet", "| sum [length (T.lines contents) | (_, contents) <- sources] > maybe kernelBudget (min kernelBudget) bound]", "| False]")]
       else if identifier == L.LtdKrn002 then [("authored-mutant-symbol", "symbol name = [\"MutantSymbol\" | marker (T.pack (unpackFS name))]", "symbol _ = []")
         ,("authored-mutant-flag", "name <- graphFlags graph, \"mutant\" `T.isInfixOf` T.toCaseFold name]", "name <- graphFlags graph, False]")
         ,("authored-mutant-selector", "&& \"_MUTANT\" `T.isInfixOf` value", "&& False")]
       else if identifier == L.LtdKrn003 then [("fake-inductive", "| sort expected /= sort (concatMap constructors", "| typeName == \"RefinementStatus\" && sort expected /= sort (concatMap constructors")
           ,("fake-proved", "| sort expected /= sort (concatMap constructors", "| typeName == \"SymbolicResult\" && sort expected /= sort (concatMap constructors")]
       else [("all-bootstrap-negatives", "Pb.admitBootstrap (E.encodeUtf8 body)", "Right ()")]
      variants = if identifier == L.LtdSrc008 && phase /= P.phaseDomainLowerOrdinal then bootstrapSourceVariants else if identifier == L.LtdSrc000 then sourceGraphVariants else if identifier == L.LtdMeta001 then ignoreContextVariants else if identifier == L.LtdName001 then runtimeIdentityVariants else if identifier == L.LtdSrc005 then pulumiSourceVariants else if identifier == L.LtdSrc001 then toolSourceVariants else if identifier == L.LtdSrc006 then testSourceVariants else if identifier == L.LtdSrc009 then vendorSourceVariants else if identifier == L.LtdSrc007 then probeSourceVariants else if identifier == L.LtdBoot001 then admissionVariants else if identifier == L.LtdVal006 then freshVariants else if identifier == L.LtdVal001 then authorityVariants else if identifier == L.LtdVal002 then correspondenceVariants else if identifier == L.LtdVal003 then custodyVariants else if identifier == L.LtdVal004 then statusVariants else [(key,"src/validation-kernel/Amoebius/Validation/Runner/Legacy.hs",needle,replacement) | (key,needle,replacement) <- queryVariants]
  weakenedRows <- forM variants $ \(key, subjectFile, needle, replacement) -> do
      let work = absolute </> "weakened" </> Text.unpack key
      createDirectoryIfMissing True work
      original <- maybe (die "query weakening source absent") (pure . Encoding.decodeUtf8) (capturedSourceBytes source subjectFile)
      unless (Text.count needle original == 1) (die "kernel weakening locus must occur once")
      let weakened = Text.replace needle replacement original
      TextIO.writeFile (work </> "source-witness.data") (Text.pack (show (subjectFile, original, weakened)))
      weakenedSource <- either (die . Text.unpack) pure (rewriteCapturedSource source subjectFile (Encoding.encodeUtf8 weakened))
      refused <- qualify "." (work </> "qualified") phase Nothing compiler weakenedSource
      pure ["field", "weakened-query." <> key, either id (const "qualified") refused]
  next <- maybe (die "kernel qualification successor absent") pure (P.successorOrdinal phase)
  wrongOwner <- qualify "." (absolute </> "wrong-owner") next (Just cabal) compiler source
  reused <- qualify "." (absolute </> "qualified") phase (Just cabal) compiler source
  otherRows <- if identifier == L.LtdKrn001 then pure [] else do
    otherQualification <- qualifyLegacy L.LtdKrn001 "." (absolute </> "other-analyzer") P.phaseDomainLowerOrdinal Nothing compiler source >>= either (die . Text.unpack) pure
    pure (audit "other-analyzer" source [otherQualification] reports
      <> audit "joint" source [qualification, otherQualification] reports
      <> audit "duplicate-other" source [qualification, otherQualification, otherQualification] reports)
  scopedRows <- if identifier /= L.LtdSrc008 || phase /= P.phaseDomainLowerOrdinal then pure [] else do
    owner <- maybe (die "whole-snapshot owner absent") pure (L.legacyOwnerOrdinal identifier)
    let wholeZero rows = map (\row -> if reportedIdentity row == identifier && reportedScope row == "snapshot" then row {reportedObservation = AnalyzerFindings []} else row) rows
        borrowed = auditQualifiedLegacyReports owner source [qualification] (wholeZero (observeLegacy owner source Nothing))
        scopeSwap = changed (\row -> row {reportedScope = "snapshot"})
    pure ([ ["field", "whole-owner-supported", Text.pack (show (legacyQualificationSupported (L.legacyRequirement identifier)))]
          , ["field", "whole-snapshot-unqualified", Text.pack (show ("LegacyQualificationUnavailable:LTD-SRC-008:snapshot" `elem` borrowed))]
          , ["field", "captured-proof-unexpected", Text.pack (show ("LegacyQualificationUnexpected" `elem` borrowed))] ]
      <> audit "whole-snapshot-zero" source [qualification] (wholeZero reports)
      <> audit "scope-swap" source [qualification] scopeSwap)
  pure ([["field", "wrong-owner", either id (const "qualified") wrongOwner], ["field", "reused", either id (const "qualified") reused]] <> weakenedRows <> concat
    [ audit "qualified" source [qualification] reports
    , audit "missing-evidence" source [] reports
    , audit "duplicate-evidence" source [qualification, qualification] reports
    , audit "other-source" otherSource [qualification] (observeLegacy phase otherSource Nothing)
    , audit "forged-observation" source [qualification] (changed (\row -> row {reportedObservation = AnalyzerUnavailable "forged"}))
    , audit "forged-source" source [qualification] (changed (\row -> row {reportedSource = "forged"}))
    , audit "forged-lifecycle" source [qualification] (changed (\row -> row {reportedLifecycle = "forged"}))
    ] <> otherRows <> scopedRows)
 where acquired root = captureSource root >>= either (die . Text.unpack) pure

bootstrapSourceVariants :: [(Text, FilePath, Text, Text)]
bootstrapSourceVariants =
  [("digest", subject, "digest /= admittedBootstrapDigest", "False")
  ,("footprint", subject, "[(\"pb/__main__.py\", bytes)] -> do", "(\"pb/__main__.py\", bytes) : _ -> do")
  ,("duplicate", subject, "paths /= nub paths", "False")
  ,("source-discovery", subject, "paths = sort (map fst files)", "paths = sort [path | (path,_) <- files,path /= \"test/layout/ClassEffectRoute.hs\"]")
  ,("empty", subject, "null files", "False")]
 where subject = "src/Amoebius/Layout/PbGrammar.hs"

sourceGraphVariants :: [(Text, FilePath, Text, Text)]
sourceGraphVariants =
  [("path-omitted", report, "path `notElem` map pathOf actual]", "False]")
  ,("mode-changed", report, "mode /= foundMode]", "False]")
  ,("bytes-changed", report, "digest /= foundDigest]", "False]")
  ,("kind-changed", report, "kind /= foundKind]", "False]")
  ,("foreign-disguised", graph, "interfaceFindings <> [finding | Left finding <- parsed]", "interfaceFindings <> []")
  ,("effect-unattributed", graph, "| null unresolved && null standaloneUnresolved && null routeGaps && null reportedOpaqueSites", "| True")
  ,("source-omitted", graph, "sort [path | path <- paths, takeExtension path == \".hs\"]", "sort [path | path <- paths, takeExtension path == \".hs\", path /= \"test/layout/ClassEffectRoute.hs\"]")]
 where report = "src/Amoebius/Layout/Report.hs"; graph = "src/Amoebius/Layout/SourceGraph.hs"

ignoreContextVariants :: [(Text, FilePath, Text, Text)]
ignoreContextVariants =
  [("retired-root", subject, "| patternText <- patterns, retired patternText]", "| patternText <- patterns, False]")
  ,("undeclared-root", subject, "patternText <- patterns, patternText `notElem` allowedPatterns, not (retired patternText)", "patternText <- patterns, False, not (retired patternText)")
  ,("required-root", subject, "required <- requiredPatterns, required `notElem` patterns]", "required <- requiredPatterns, False]")
  ,("required-pattern", subject, "patternText <- allowedPatterns, patternText `notElem` patterns]", "patternText <- allowedPatterns, False]")
  ,("archive-visible", subject, "path == \".gitignore\", any (\"validation-records\" `Text.isInfixOf`) patterns]", "path == \".gitignore\", False]")]
 where subject = "src/Amoebius/Layout/Classify.hs"

runtimeIdentityVariants :: [(Text, FilePath, Text, Text)]
runtimeIdentityVariants =
  [("text-ordinal", subject, ", ordinalToken sourceLine]", ", False]")
  ,("path-ordinal", subject, "ordinalName = ordinalToken . Text.pack", "ordinalName _ = False")
  ,("component-ordinal", subject, "| ordinalToken name, not (not (null directories) && all validationSourcePath directories)]", "| False, not (not (null directories) && all validationSourcePath directories)]")
  ,("case-fold", subject, "Text.breakOnAll needle (Text.toCaseFold source)", "Text.breakOnAll needle source")
  ,("validation-component", subject, "not (not (null directories) && all validationSourcePath directories)]", "True]")
  ,("component-discovery", "src/Amoebius/Layout/PackageMap.hs", "(name, tree) <- condForeignLibs description]", "(name, tree) <- take 0 (condForeignLibs description)]")]
 where subject = "src/Amoebius/Layout/Classify.hs"

pulumiSourceVariants :: [(Text, FilePath, Text, Text)]
pulumiSourceVariants =
  [("pulumi-root", subject, "| \"pulumi/\" `prefix` path = reject \"TrackedPulumiProgram\"", "| \"pulumi/\" `prefix` path = Right HaskellSource")
  ,("renamed-program", subject, "| otherwise = reject \"UnclassifiedTrackedPath\"", "| otherwise = Right HaskellSource")
  ,("python-program", subject, "| takeExtension path == \".py\" = reject \"TrackedPythonOutsidePb\"", "| takeExtension path == \".py\" = Right HaskellSource")]
 where subject = "src/Amoebius/Layout/Classify.hs"

toolSourceVariants :: [(Text, FilePath, Text, Text)]
toolSourceVariants =
  [("tool-root", subject, "| \"tools/\" `prefix` path = reject \"TrackedToolRoot\"", "| \"tools/\" `prefix` path = Right HaskellSource")
  ,("python-gate", subject, "| takeExtension path == \".py\" = reject \"TrackedPythonOutsidePb\"", "| takeExtension path == \".py\" = Right HaskellSource")
  ,("renamed-root", subject, "| otherwise = reject \"UnclassifiedTrackedPath\"", "| otherwise = Right HaskellSource")]
 where subject = "src/Amoebius/Layout/Classify.hs"

testSourceVariants :: [(Text, FilePath, Text, Text)]
testSourceVariants =
  [("foreign-input", subject, "if takeExtension path == \".hs\" then Right HaskellSource else reject \"NonHaskellTestInput\"", "Right HaskellSource")
  ,("empty-inventory", subject, "LayoutFinding \"TestSourceInventoryEmpty\" \"test\" | null selected]", "LayoutFinding \"TestSourceInventoryEmpty\" \"test\" | False]")
  ,("duplicate-path", subject, "(path : _ : _) <- group selected]", "(path : _ : _) <- group selected, False]")]
  <> [("source-omitted", subject, "testSourcePaths = filter (\"test/\" `prefix`)",
        "testSourcePaths = filter (\\path -> \"test/\" `prefix` path && path /= \"test/layout/ClassEffectRoute.hs\")")]
 where subject = "src/Amoebius/Layout/Classify.hs"

vendorSourceVariants :: [(Text, FilePath, Text, Text)]
vendorSourceVariants = [("top-level-vendor", subject, "\"vendor/\" `isPrefixOf` path]", "False]")
  ,("mutable-reference", subject, "GitBranch {} -> Left (MutableIdentity (renderReference reference))", "GitBranch {} -> Right reference")
  ,("tracked-vendor-proto", subject, "\"src/vendor/\" `isPrefixOf` path && takeExtension path == \".proto\"]", "False]")
  ,("tracked-foreign-package", subject, "\".cabal\" `isSuffixOf` path && path `notElem` [\"amoebius.cabal\", \"probe/probe.cabal\"]", "False")
  ,("tracked-patch-program", subject, "any (`isSuffixOf` path) [\".patch\", \".diff\"]]", "False]")
  ,("fork-module", subject, "[ForkModuleMissing name | not present]", "[]")]
 where subject = "src/Amoebius/Toolchain/Provenance.hs"

probeSourceVariants :: [(Text, FilePath, Text, Text)]
probeSourceVariants = [("foreign-input", probe, "takeExtension path /= \".hs\" && path /= \"probe/probe.cabal\"]", "False]")
  ,("omitted-case", probe, "name <- required, name `notElem` names]", "name <- required, False]")
  ,("missing-source", probe, "path <- probeSourceRequiredPaths, path `notElem` paths]", "path <- probeSourceRequiredPaths, False]")]
 where probe = "src/Amoebius/Toolchain/Probe.hs"

admissionVariants :: [(Text, FilePath, Text, Text)]
admissionVariants =
  [("missing-tool", acquire, "present <- doesFileExist absolute", "present <- pure True")
  ,("failed-command", acquire, "childExit child /= 0", "False")
  ,("malformed-version", versions, "Nothing -> Left (ToolVersionMalformed tool)", "Nothing -> Right []")
  ,("unsupported-version.exact", versions, "ExactVersion name expected -> (name, (== expected))", "ExactVersion name _ -> (name, const True)")
  ,("unsupported-version.range", versions, "VersionRange name lower upper -> (name, \\version -> version >= lower && version < upper)", "VersionRange name _ _ -> (name, const True)")]
 where
  acquire = "src/Amoebius/Toolchain/Acquire.hs"
  versions = "src/Amoebius/Toolchain/Versions.hs"

freshVariants :: [(Text, FilePath, Text, Text)]
freshVariants =
  [("stale-run",hygiene,"  unless (not exists) (fail \"SourceCopyNotFresh\")\n  createDirectoryIfMissing True parent\n  createDirectory root", "  unless True (fail \"SourceCopyNotFresh\")\n  createDirectoryIfMissing True parent\n  createDirectoryIfMissing True root")
  ,("ignored-input",hygiene,"  forM_ entries $ \\(file, expected) -> do", "  forM_ [entry | entry@(file,_) <- entries, take 1 (splitDirectories file) /= [\".build\"]] $ \\(file, expected) -> do")
  ,("authored-output",hygiene,"unless (sort names == sort [file | (file, Just _) <- entries, take 1 (splitDirectories file) /= [\".build\"]])", "unless True")
  ,("ambient-temp",hygiene,"runRootWithinFrame root path = (\\base absolute physical -> equalFilePath absolute physical && bootstrapInputPathAllowed (intercalate \"/\" (splitDirectories (makeRelative base absolute)))) <$> canonicalizePath root <*> makeAbsolute path <*> canonicalizePath path", "runRootWithinFrame _ _ = pure True")
  ,("ambient-temp.entry","src/validation-kernel/Amoebius/Validation/Runner.hs","not frameAllowed","False")
  ,("replayed-input","src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs","bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing", "bootstrapSnapshotMatches _ _ = True")
  ,("empty-discovery",hygiene,"| Text.null output = Left \"SourceInventoryEmpty\"", "| Text.null output = Right []")]
 where hygiene = "src/validation-kernel/Amoebius/Validation/Runner/Hygiene.hs"

authorityVariants :: [(Text, FilePath, Text, Text)]
authorityVariants = [(key,"src/validation-kernel/Amoebius/Validation/Runner.hs",needle,replacement) | (key,needle,replacement) <-
  [("noop-subject","ledgerValid ledger && ledgerExit ledger == Just ExitSuccess && all (\\(_, verdict, _) -> verdict == \"green\") (ledgerRows ledger)","True")
  ,("constant-success-checker","runExit probe /= ExitSuccess","True")
  ,("forged-exit","runExit subject == ExitSuccess","True")
  ,("omitted-discovery","all (`elem` map (\\(name,_,_) -> name) (ledgerRows parsed)) required","True")
  ,("unavailable-boundary","all (isNothing . runSpawnFailure) [subject,oracle,probe]","all (isNothing . runSpawnFailure) [subject,oracle]")]] <> [("omitted-discovery.seed","src/validation-kernel/Amoebius/Validation/Runner/Spec.hs","requiredSuiteRows spec | Just _ <- gateSeed spec =","requiredSuiteRows spec | False =")]

statusVariants :: [(Text, FilePath, Text, Text)]
statusVariants = [(key,"src/validation-kernel/Amoebius/Validation/Custody/Preflight.hs",needle,"False") | (key,needle) <-
  [("status-surface-dirty","maybe False (/= factsSurfaceDigest facts) (factsAcceptedPostimage facts)")
  ,("status-without-receipt","not (null (factsDoneWithoutReceipt facts))")
  ,("predecessor-not-reproduced","not (null (factsPredecessorsNotReproduced facts))")
  ,("status-edit-without-receipt","not (factsSurfaceConsistent facts)")]]

custodyVariants :: [(Text, FilePath, Text, Text)]
custodyVariants =
  [("generation-one-receipt",store,"if record /= \"amoebius-phase-receipt.v2\" then Left","if False then Left")
  ,("verifier-diverged.reader",store,"receiptVerifierDigest receipt /= generation || ","")
  ,("verifier-diverged.binding",custody,"receiptGeneration receipt == verifier && receiptVerifierDigest receipt == verifier","True")
  ,("predecessor-closure-edited",custody,"fmap fst expected == Just (receiptClosureDigest receipt)","True")
  ,("predecessor-closure-edited.oracle","src/validation-kernel/Amoebius/Validation/Compatibility.hs","target <- targets, Just (info,_)","target <- filter (/= oracleExecutableName (gateOracle spec)) targets, Just (info,_)")]
 where
  store = "src/validation-kernel/Amoebius/Validation/Custody/Store.hs"
  custody = "src/validation-kernel/Amoebius/Validation/Custody.hs"

correspondenceVariants :: [(Text, FilePath, Text, Text)]
correspondenceVariants =
  [("gate-spec-mismatch","src/doc-check/Amoebius/Doc/Governance.hs","| Text.strip block /= Text.strip rendered","| False")
  ,("phase-role-swap",spec,
    "  unless (gateRole supplied == gateRole expected) (Left [\"SPEC-ROLE-MISMATCH: \" <> gateCapability expected])\n  unless (supplied == expected)",
    "  unless True (Left [\"SPEC-ROLE-MISMATCH: \" <> gateCapability expected])\n  unless (supplied == expected || gateRole supplied /= gateRole expected)")
  ,("byte-copy-equivalence",spec,"unless (supplied == expected)","unless (renderGateSpec supplied == renderGateSpec expected)")
  ,("subject-not-shipped",spec,"| maybe False (Set.member stanza) closure -> []","| True -> []")
  ,("retired-domain-literal","src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs",
    "lookupPhaseIdentity ordinal = Map.lookup ordinal phaseIdentityByOrdinal",
    "lookupPhaseIdentity ordinal = case [row | row <- allPhaseIdentities, phaseIdentityOrdinal row == ordinal || (ordinal == fst reservedGap && phaseIdentityCapability row == \"typed_spine\")] of row : _ -> Just row; [] -> Nothing")]
 where spec = "src/validation-kernel/Amoebius/Validation/Runner/Spec.hs"

legacyAuditRows :: FilePath -> IO [[Text]]
legacyAuditRows output = do
  absolute <- makeAbsolute output
  exists <- doesDirectoryExist absolute
  if exists then die "legacy-audit output must be fresh" else createDirectoryIfMissing True absolute
  let root = absolute </> "repo"
      kernelFile = root </> "src/validation-kernel/Kernel.hs"
      specFile = root </> "src/gate-spec/Spec.hs"
      runFile = root </> "src/validation-kernel/LegacyRun.hs"
      phase = P.phaseDomainLowerOrdinal
      plain = "module Spec where\nvalue = True\n"
  mapM_ (createDirectoryIfMissing True . (root </>)) ["src/validation-kernel", "src/gate-spec"]
  initialized <- observe root "git" ["init", "--quiet"]
  unless (runExit initialized == ExitSuccess) (die "legacy-audit fixture Git initialization failed")
  TextIO.writeFile kernelFile "module Kernel where\nvalue = True\n"
  TextIO.writeFile specFile plain
  source <- acquired root
  let reports = observeLegacy phase source Nothing
      kernel = oneKernel reports
      adjust identifier f = map (\r -> if reportedIdentity r == identifier && reportedScope r == "snapshot" then f r else r)
      change = adjust L.LtdKrn001
      finding identifier = LegacyFinding identifier "snapshot" "src/Example.hs" "1" "ExampleFinding"
      reportCase name rows = scenario name phase source rows
  TextIO.writeFile runFile "module LegacyRun where\n"
  withRun <- acquired root
  let runReports = observeLegacy phase withRun Nothing
  removeFile runFile
  TextIO.writeFile specFile ("module Spec where\nvalue = \"phase-" <> Text.pack (show phase) <> "\"\n")
  withLiteral <- acquired root
  TextIO.writeFile specFile plain
  Bytes.writeFile specFile (Bytes.pack [255])
  nonUtf8 <- acquired root
  removeFile specFile
  missingScope <- acquired root
  successor <- maybe (die "legacy-audit successor absent") pure (P.successorOrdinal phase)
  pure
    ( [ ["field", "kernel.zero", observed kernel]
      , ["field", "kernel.source-bound", shown (reportedSource kernel == capturedSourceDigest source)]
      , ["field", "kernel.run-module", findingsText (oneKernel runReports)]
      , ["field", "kernel.phase-literal", findingsText (oneKernel (observeLegacy phase withLiteral Nothing))]
      , ["field", "kernel.over-ratchet", findingsText (oneKernel (observeLegacy phase source (Just 3)))]
      , ["field", "kernel.exact-fit", observed (oneKernel (observeLegacy phase source (Just 4)))]
      , ["field", "kernel.non-utf8", observed (oneKernel (observeLegacy phase nonUtf8 Nothing))]
      , ["field", "kernel.scope-missing", observed (oneKernel (observeLegacy phase missingScope Nothing))]
      , ["field", "bootstrap.scope-distinct", shown (map reportedScope (filter ((== L.LtdSrc008) . reportedIdentity) reports) == ["snapshot", "captured-bootstrap"])]
      ]
      <> concat
        [ reportCase "baseline" reports
        , reportCase "missing-row" (filter ((/= L.LtdKrn001) . reportedIdentity) reports)
        , reportCase "duplicate-row" (kernel : reports)
        , reportCase "source-mismatch" (change (\r -> r {reportedSource = "forged"}) reports)
        , reportCase "analyzer-mismatch" (change (\r -> r {reportedAnalyzer = "forged"}) reports)
        , reportCase "lifecycle-mismatch" (change (\r -> r {reportedLifecycle = "forged"}) reports)
        , reportCase "unbound-finding" (change (\r -> r {reportedObservation = AnalyzerFindings [finding Nothing]}) reports)
        , reportCase "finding-binding" (change (\r -> r {reportedObservation = AnalyzerFindings [finding (Just L.LtdDsl004)]}) reports)
        , reportCase "duplicate-locus" (change (\r -> r {reportedObservation = AnalyzerFindings (replicate 2 (finding (Just L.LtdKrn001)))}) reports)
        , reportCase "later-finding" (adjust L.LtdDsl004 (\r -> r {reportedObservation = AnalyzerFindings [finding (Just L.LtdDsl004)]}) reports)
        , reportCase "later-zero" (adjust L.LtdDsl004 (\r -> r {reportedObservation = AnalyzerFindings []}) reports)
        , reportCase "bootstrap-zero" (map (\r -> if reportedIdentity r == L.LtdSrc008 && reportedScope r == "captured-bootstrap" then r {reportedObservation = AnalyzerFindings []} else r) reports)
        , reportCase "full-bootstrap-zero" (adjust L.LtdSrc008 (\r -> r {reportedObservation = AnalyzerFindings []}) reports)
        , reportCase "bootstrap-scope-swap" (map (\r -> if reportedIdentity r == L.LtdSrc008 && reportedScope r == "captured-bootstrap" then r {reportedScope = "snapshot"} else r) reports)
        , reportCase "unexpected-row" (kernel {reportedScope = "unexpected"} : reports)
        , reportCase "wrong-scope" (change (\r -> r {reportedScope = "unexpected"}) reports)
        , scenario "finding-due" phase withRun runReports
        , scenario "after-owner" successor source (observeLegacy successor source Nothing)
        , scenario "unknown-phase" (-1) source reports
        ])
 where
  acquired root = captureSource root >>= either (die . Text.unpack) pure
  shown :: Show value => value -> Text
  shown = Text.pack . show
  observed = shown . reportedObservation
  oneKernel rows = case filter ((== L.LtdKrn001) . reportedIdentity) rows of [row] -> row; _ -> error "kernel report discovery changed"
  findingsText row = case reportedObservation row of
    AnalyzerUnavailable reason -> reason
    AnalyzerFindings findings -> Text.intercalate "," [findingReason f <> ":" <> Text.pack (findingPath f) <> ":" <> findingLocus f | f <- findings]
  scenario name phase source reports = ["scenario", name] : [["audit", name, refusal] | refusal <- auditLegacyReports phase source reports]

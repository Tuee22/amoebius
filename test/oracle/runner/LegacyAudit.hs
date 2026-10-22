{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored expectations for prequalification diagnostics.
module LegacyAudit (legacyAuditChecks, kernelQualificationChecks, kernelJoinChecks, mutationQualificationChecks, mutationJoinChecks, mutationChecks, solverJoinChecks, bootstrapQualificationChecks, bootstrapJoinChecks, correspondenceJoinChecks, custodyJoinChecks, statusJoinChecks, authorityJoinChecks, freshJoinChecks, admissionJoinChecks, probeSourceJoinChecks, vendorSourceJoinChecks, testSourceJoinChecks, toolSourceJoinChecks, pulumiSourceJoinChecks, runtimeIdentityJoinChecks, ignoreContextJoinChecks, sourceGraphJoinChecks, bootstrapSourceJoinChecks) where

import Data.List (sort)
import NativeApi (seedAuthorityRows)
import Control.Monad (forM)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.ByteString qualified as Bytes
import Data.Text.Encoding qualified as Encoding
import System.Directory (doesDirectoryExist, doesPathExist, listDirectory, pathIsSymbolicLink)
import System.Exit (die)
import System.FilePath ((</>))
import Text.Read (readMaybe)
import Crypto.Hash.SHA256 qualified as Hash
import Numeric (showHex)

bootstrapQualificationChecks :: FilePath -> FilePath -> IO [(Text, Bool, Text)]
bootstrapQualificationChecks directory sourceRoot = do
  input <- TextIO.readFile (directory </> "bootstrap-inputs.data")
  output <- TextIO.readFile (directory </> "bootstrap-output.data")
  scope <- TextIO.readFile (directory </> "scope.data")
  body <- TextIO.readFile (sourceRoot </> "pb/__main__.py")
  let cases = maybe [] snd (readMaybe (Text.unpack input) :: Maybe (Int, [(Text, Text, [(FilePath, Text)])]))
      results = maybe [] id (readMaybe (Text.unpack output) :: Maybe [(Text, Text, Either Text [(Text, FilePath, Text)])])
      argv = "    bootstrap(adapter, sys.argv[1:])"
      definitions = [("dynamic-import", body <> "\n__import__(\"os\")\n", "BootstrapDynamicCall: __import__")
        ,("undeclared-effect", body <> "\nos.system(\"true\")\n", "BootstrapEffectOutsideAdapter: os.system(\"true\")")
        ,("command-dispatch", body <> "\nif sys.argv[1] == \"help\":\n    main()\n", "")
        ,("argv-rewritten", Text.replace argv "    bootstrap(adapter, [])" body, "")
        ,("unscanned-syntax", body <> "\n@unknown\n", "BootstrapSyntaxRefusal: @unknown")]
      keys = [(key, role) | (key, _, _) <- definitions, role <- ["positive", "negative"]]
      observed key role = [value | (name, control, value) <- results, name == key, control == role]
      supplied key role = [value | (name, control, value) <- cases, name == key, control == role]
      reason changed literal = if Text.null literal then "BootstrapDigestMismatch: " <> digest changed else literal
      digest = Text.pack . concatMap (\byte -> let value = showHex byte "" in if length value == 1 then '0' : value else value) . Bytes.unpack . Hash.hash . Encoding.encodeUtf8
  pure (("bootstrap.discovery", scope == "captured-bootstrap" && Text.count argv body == 1
      && sort [(key, role) | (key, role, _) <- cases] == sort keys && sort [(key, role) | (key, role, _) <- results] == sort keys, "canonical captured-source scope and complete pairs")
    : concat [[("bootstrap." <> key <> ".positive", observed key "positive" == [Right []], Text.pack (show (observed key "positive")))
      ,("bootstrap." <> key <> ".negative", observed key "negative" == [Right [("BootstrapStructure", "pb/__main__.py", reason changed literal)]], Text.pack (show (observed key "negative")))
      ,("bootstrap." <> key <> ".delta", changed /= body && supplied key "positive" == [[("pb/__main__.py", body)]]
        && supplied key "negative" == [[("pb/__main__.py", changed)]], "complete independently specified source bytes")]
      | (key, changed, literal) <- definitions])

mutationChecks :: FilePath -> IO [(Text, Bool, Text)]
mutationChecks directory = do
  input <- TextIO.readFile (directory </> "mutation.tsv")
  source <- Bytes.readFile "src/vocabulary/Amoebius/Vocabulary.hs"
  package <- Bytes.readFile "amoebius.cabal"
  removed <- not <$> doesPathExist (directory </> "source")
  let rows = map (Text.splitOn "\t") (Text.lines input)
      nextLine = length (Text.lines (Encoding.decodeUtf8 source)) + 1
      at column = Text.pack (show nextLine <> ":" <> show (column :: Int))
      target = "src/vocabulary/Amoebius/Vocabulary.hs" :: FilePath
      finding reason locus = [("LTD-KRN-002" :: Text, "snapshot" :: Text, target, locus, reason)]
      flag name = "\nflag " <> name <> "\n    default: False\n    manual: True\n"
      cases = [("baseline", "", "", []), ("comment", "-- harmless_MUTANT = True\n", "", [])
        ,("quoted-module", "mutationProbe = \"module Example where\\nprobe_MUTANT = True\\n\"\n", "", [])
        ,("reserved-data", "mutationProbe = \"_MUTANT\"\n", "", [])
        ,("conditional", "#if DEBUG\nmutationProbe = True\n#endif\n", "", finding "ConditionalSource" (at 1)
            <> [("LTD-KRN-002", "snapshot", target, Text.pack (show (nextLine + 2) <> ":1"), "ConditionalSource")])
        ,("identifier", "mutationProbe_MUTANT = True\n", "", finding "MutantSymbol" (at 1))
        ,("qualified-identifier", "mutationProbe = Prelude.value_MUTANT\n", "", finding "MutantSymbol" (at 17))
        ,("selector", "mutationProbe = \"AMOEBIUS_MUTANT\"\n", "", finding "MutantSelector" (at 17))
        ,("selector-append", "mutationProbe = \"AMOEBIUS_\" ++ \"MUTANT\"\n", "", finding "MutantSelector" (at 17))
        ,("selector-concat", "mutationProbe = concat [\"AMOEBIUS_\", \"MUTANT\"]\n", "", finding "MutantSelector" (at 17))
        ,("selector-characters", "mutationProbe = ['A','M','O','E','B','I','U','S','_','M','U','T','A','N','T']\n", "", finding "MutantSelector" (at 17))
        ,("selector-alias", "selectorName = \"AMOEBIUS_\" <> \"MUTANT\"\nmutationProbe = selectorName\n", "", finding "MutantSelector" (at 16)
            <> [("LTD-KRN-002", "snapshot", target, Text.pack (show (nextLine + 1) <> ":17"), "MutantSelector")])
        ,("selector-qualified", "mutationProbe = Data.Text.append \"AMOEBIUS_\" \"MUTANT\"\n", "", finding "MutantSelector" (at 17))
        ,("selector-let", "mutationProbe = let selectorName = \"AMOEBIUS_\" <> \"MUTANT\" in selectorName\n", "", finding "MutantSelector" (at 17))
        ,("selector-bare-read", "mutationProbe = lookupEnv \"_MUTANT\"\n", "", finding "MutantSelector" (at 17))
        ,("selector-aliased-read", "selectorRead = lookupEnv\nmutationProbe = selectorRead \"_MUTANT\"\n", "",
            [("LTD-KRN-002", "snapshot", target, Text.pack (show (nextLine + 1) <> ":17"), "MutantSelector")])
        ,("ordinary-concat", "mutationProbe = \"AMOEBIUS_\" <> \"FEATURE\"\n", "", [])
        ,("bare-identity", "mutationProbe = id \"_MUTANT\"\n", "", [])
        ,("shadow-parameter", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe selectorSuffix = selectorPrefix <> selectorSuffix\n", "", [])
        ,("shadow-let", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe = let selectorSuffix = \"FEATURE\" in selectorPrefix <> selectorSuffix\n", "", [])
        ,("predicate-alias", "containsMarker = Data.Text.isInfixOf\nmutationProbe = containsMarker \"_MUTANT\"\n", "", [])
        ,("alias-cycle", "selectorPrefix = selectorSuffix\nselectorSuffix = selectorPrefix\nmutationProbe = selectorPrefix\n", "", [])
        ,("closure-shadow", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"FEATURE\"\nselectorName = selectorPrefix <> selectorSuffix\nmutationProbe = let selectorSuffix = \"MUTANT\" in selectorName\n", "", [])
        ,("where-closure", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nselectorName = selectorPrefix <> selectorSuffix where selectorSuffix = \"FEATURE\"\nmutationProbe = selectorName\n", "", [])
        ,("qualified-alias", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe = Amoebius.Vocabulary.selectorPrefix <> Amoebius.Vocabulary.selectorSuffix\n", "",
            [("LTD-KRN-002", "snapshot", target, Text.pack (show (nextLine + 2) <> ":17"), "MutantSelector")])
        ,("qualified-shadow", "selectorPrefix = \"AMOEBIUS_\"\nselectorSuffix = \"MUTANT\"\nmutationProbe selectorSuffix = Amoebius.Vocabulary.selectorPrefix <> Amoebius.Vocabulary.selectorSuffix\n", "",
            [("LTD-KRN-002", "snapshot", target, Text.pack (show (nextLine + 2) <> ":32"), "MutantSelector")])
        ,("multiline-decoy", "mutationDecoy = \"\"\"\n#if FEATURE\n\"\"\"\nmutationProbe = \"AMOEBIUS_\" <> \"MUTANT\"\n", "",
            [("LTD-KRN-002", "snapshot", target, Text.pack (show (nextLine + 4) <> ":17"), "MutantSelector")])
        ,("flag", "", flag "mutant-probe", [("LTD-KRN-002", "snapshot", "amoebius.cabal", "mutant-probe", "MutantFlag")])
        ,("ordinary-flag", "", flag "tracing", [])
        ,("flag-exact", "", Text.concat [flag ("feature" <> Text.pack (show n)) | n <- [1 :: Int .. 20]], [])
        ,("flag-budget", "", Text.concat [flag ("feature" <> Text.pack (show n)) | n <- [1 :: Int .. 21]], [("LTD-KRN-002", "snapshot", "amoebius.cabal", "flags", "FlagBudget")])]
      observed name = case [(state, value) | [key, state, value, _] <- rows, key == name] of
        [("findings", value)] -> readMaybe (Text.unpack value) :: Maybe [(Text, Text, FilePath, Text, Text)]
        _ -> Nothing
      digests = [(key, digest) | [key, _, _, digest] <- rows]
  projections <- forM cases $ \(name, suffix, flags, expected) -> do
    body <- Bytes.readFile (directory </> "inputs" </> Text.unpack name </> "Subject.hs")
    cabal <- Bytes.readFile (directory </> "inputs" </> Text.unpack name </> "package.cabal")
    let prefix = if name == "multiline-decoy" then "{-# LANGUAGE MultilineStrings #-}\n" else ""
    pure [("mutation." <> name <> ".projection", body == Encoding.encodeUtf8 prefix <> source <> Encoding.encodeUtf8 suffix && cabal == package <> Encoding.encodeUtf8 flags, "complete independent source/package projection")
         ,("mutation." <> name <> ".verdict", observed name == Just expected, Text.pack (show (observed name)))]
  pure ([ ("mutation.discovery", sort [key | key : _ <- rows] == sort [name | (name, _, _, _) <- cases] && all ((== 4) . length) rows, Text.pack (show rows))
        , ("mutation.source-identities", all (\(_, digest) -> Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest) digests
            && case lookup "baseline" digests of Just baselineDigest -> all (\(name, digest) -> name == "baseline" || digest /= baselineDigest) digests; _ -> False, Text.pack (show digests))
        , ("mutation.teardown", removed, Text.pack (show removed)) ] <> concat projections)

type KernelIdentity = (Text, Text, Int, [Text], [(FilePath, Text, Text)])
correspondenceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
correspondenceJoinChecks = behaviorJoinChecks "correspondence" "LTD-VAL-002"
  ["gate-spec-mismatch","phase-role-swap","byte-copy-equivalence","subject-not-shipped","retired-domain-literal"]
  (["control.render-collision","snapshot.contracts","snapshot.selected"] <> [part <> "." <> key | part <- ["entry","entry-root"],key <- ["phase-role-swap","byte-copy-equivalence"]])
  [(key,path,needle,replacement,["correspondence." <> key <> ".negative"] <> ["correspondence.entry." <> key | key `elem` ["phase-role-swap","byte-copy-equivalence"]]) | (key,path,needle,replacement) <- variants]
 where
  spec = "src/validation-kernel/Amoebius/Validation/Runner/Spec.hs"
  variants =
    [("gate-spec-mismatch","src/doc-check/Amoebius/Doc/Governance.hs","| Text.strip block /= Text.strip rendered","| False")
    ,("phase-role-swap",spec,
      "  unless (gateRole supplied == gateRole expected) (Left [\"SPEC-ROLE-MISMATCH: \" <> gateCapability expected])\n  unless (supplied == expected)",
      "  unless True (Left [\"SPEC-ROLE-MISMATCH: \" <> gateCapability expected])\n  unless (supplied == expected || gateRole supplied /= gateRole expected)")
    ,("byte-copy-equivalence",spec,"unless (supplied == expected)","unless (renderGateSpec supplied == renderGateSpec expected)")
    ,("subject-not-shipped",spec,"| maybe False (Set.member stanza) closure -> []","| True -> []")
    ,("retired-domain-literal","src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs",
      "lookupPhaseIdentity ordinal = Map.lookup ordinal phaseIdentityByOrdinal",
      "lookupPhaseIdentity ordinal = case [row | row <- allPhaseIdentities, phaseIdentityOrdinal row == ordinal || (ordinal == fst reservedGap && phaseIdentityCapability row == \"typed_spine\")] of row : _ -> Just row; [] -> Nothing")]

custodyJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
custodyJoinChecks = behaviorJoinChecks "custody" "LTD-VAL-003"
  ["generation-one-receipt","verifier-diverged","predecessor-closure-edited"]
  (["binding.verifier-positive","binding.verifier-negative"] <> ["control." <> key | key <- ["closure-source","closure-restored","outside-closure","unknown-closure","closure-sentinel","capability-binding","governance-binding","specification-binding","phase-binding"]] <> ["dependency." <> key | key <- ["suite","oracle","custody-suite","entry","build-tool","seed-driver","metadata","bootstrap","documentation","status-projection","cleanup"]])
  [("generation-one-receipt",store,"if record /= \"amoebius-phase-receipt.v2\" then Left","if False then Left",["custody.generation-one-receipt.negative"])
  ,("verifier-diverged.reader",store,"receiptVerifierDigest receipt /= generation || ","",["custody.verifier-diverged.negative"])
  ,("verifier-diverged.binding",custody,"receiptGeneration receipt == verifier && receiptVerifierDigest receipt == verifier","True",["custody.binding.verifier-negative"])
  ,("predecessor-closure-edited",custody,"fmap fst expected == Just (receiptClosureDigest receipt)","True",["custody.predecessor-closure-edited.negative"])
  ,("predecessor-closure-edited.oracle","src/validation-kernel/Amoebius/Validation/Compatibility.hs","target <- targets, Just (info,_)","target <- filter (/= oracleExecutableName (gateOracle spec)) targets, Just (info,_)",["custody.dependency.oracle"])]
 where
  store = "src/validation-kernel/Amoebius/Validation/Custody/Store.hs"
  custody = "src/validation-kernel/Amoebius/Validation/Custody.hs"

freshJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
freshJoinChecks = behaviorJoinChecks "fresh" "LTD-VAL-006"
  ["stale-run","ignored-input","authored-output","ambient-temp","replayed-input","empty-discovery"]
  ["control." <> key | key <- ["stale-sentinel","ignored-captured","source-changed","replayed-copy","authored-restored","ambient-entry","ambient-created","cleanup","collection-unknown","collection-phase","collection-source"]]
  [("stale-run",hygiene,"  unless (not exists) (fail \"SourceCopyNotFresh\")\n  createDirectoryIfMissing True parent\n  createDirectory root", "  unless True (fail \"SourceCopyNotFresh\")\n  createDirectoryIfMissing True parent\n  createDirectoryIfMissing True root",["fresh.stale-run.negative"])
  ,("ignored-input",hygiene,"  forM_ entries $ \\(file, expected) -> do", "  forM_ [entry | entry@(file,_) <- entries, take 1 (splitDirectories file) /= [\".build\"]] $ \\(file, expected) -> do",["fresh.ignored-input.negative"])
  ,("authored-output",hygiene,"unless (sort names == sort [file | (file, Just _) <- entries, take 1 (splitDirectories file) /= [\".build\"]])", "unless True",["fresh.authored-output.negative"])
  ,("ambient-temp",hygiene,"runRootWithinFrame root path = (\\base absolute physical -> equalFilePath absolute physical && bootstrapInputPathAllowed (intercalate \"/\" (splitDirectories (makeRelative base absolute)))) <$> canonicalizePath root <*> makeAbsolute path <*> canonicalizePath path", "runRootWithinFrame _ _ = pure True",["fresh.ambient-temp.negative","fresh.control.ambient-entry"])
  ,("ambient-temp.entry","src/validation-kernel/Amoebius/Validation/Runner.hs","not frameAllowed","False",["fresh.control.ambient-entry"])
  ,("replayed-input","src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs","bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing", "bootstrapSnapshotMatches _ _ = True",["fresh.replayed-input.negative"])
  ,("empty-discovery",hygiene,"| Text.null output = Left \"SourceInventoryEmpty\"", "| Text.null output = Right []",["fresh.empty-discovery.negative"])]
 where hygiene = "src/validation-kernel/Amoebius/Validation/Runner/Hygiene.hs"

authorityJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
authorityJoinChecks = behaviorJoinChecks "authority" "LTD-VAL-001" keys
  (["control." <> key | key <- ["subject-exit","subject-token","constant-probe","missing-probe","cleanup"]] <> ["manifest.seed-names","manifest.seed-positive"] <> ["manifest.omitted." <> key | key <- seedAuthorityRows])
  ([(key,"src/validation-kernel/Amoebius/Validation/Runner.hs",needle,replacement,
    ["authority." <> name <> ".negative" | name <- if key == "noop-subject" then keys else [key]] <> ["authority.manifest.omitted." <> name | key `elem` ["noop-subject","omitted-discovery"], name <- seedAuthorityRows]) | (key,needle,replacement) <-
      [("noop-subject","ledgerValid ledger && ledgerExit ledger == Just ExitSuccess && all (\\(_, verdict, _) -> verdict == \"green\") (ledgerRows ledger)","True")
      ,("constant-success-checker","runExit probe /= ExitSuccess","True")
      ,("forged-exit","runExit subject == ExitSuccess","True")
      ,("omitted-discovery","all (`elem` map (\\(name,_,_) -> name) (ledgerRows parsed)) required","True")
      ,("unavailable-boundary","all (isNothing . runSpawnFailure) [subject,oracle,probe]","all (isNothing . runSpawnFailure) [subject,oracle]")]]
    <> [("omitted-discovery.seed","src/validation-kernel/Amoebius/Validation/Runner/Spec.hs","requiredSuiteRows spec | Just _ <- gateSeed spec =","requiredSuiteRows spec | False =", "authority.manifest.seed-names" : ["authority.manifest.omitted." <> name | name <- seedAuthorityRows])])
 where keys = ["noop-subject","constant-success-checker","forged-exit","omitted-discovery","unavailable-boundary"]

statusJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
statusJoinChecks = behaviorJoinChecks "status" "LTD-VAL-004" keys
  ([part <> "." <> key | part <- ["accept","preview","unchanged"], key <- keys] <> ["control.cleanup"])
  [(key,"src/validation-kernel/Amoebius/Validation/Custody/Preflight.hs",needle,"False",
    ["status." <> key <> ".negative","status.accept." <> key,"status.preview." <> key]) | (key,needle) <-
      [("status-surface-dirty","maybe False (/= factsSurfaceDigest facts) (factsAcceptedPostimage facts)")
      ,("status-without-receipt","not (null (factsDoneWithoutReceipt facts))")
      ,("predecessor-not-reproduced","not (null (factsPredecessorsNotReproduced facts))")
      ,("status-edit-without-receipt","not (factsSurfaceConsistent facts)")]]
 where keys = ["status-surface-dirty","status-without-receipt","predecessor-not-reproduced","status-edit-without-receipt"]

bootstrapSourceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
bootstrapSourceJoinChecks directory = do
  checks <- behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "bootstrap-source" "LTD-SRC-008"
    ["bootstrap-byte-changed","bootstrap-extra-role","bootstrap-argv-rewritten"] ["control.inventory","control.cleanup"]
    [("digest", subject, "digest /= admittedBootstrapDigest", "False", ["bootstrap-source." <> key <> ".negative" | key <- ["bootstrap-byte-changed","bootstrap-extra-role","bootstrap-argv-rewritten"]])
    ,("footprint", subject, "[(\"pb/__main__.py\", bytes)] -> do", "(\"pb/__main__.py\", bytes) : _ -> do", ["bootstrap-source.control.inventory"])
    ,("duplicate", subject, "paths /= nub paths", "False", ["bootstrap-source.control.inventory"])
    ,("source-discovery", subject, "paths = sort (map fst files)", "paths = sort [path | (path,_) <- files,path /= \"test/layout/ClassEffectRoute.hs\"]", ["bootstrap-source.discovery"])
    ,("empty", subject, "null files", "False", ["bootstrap-source.control.inventory"])] directory
  scoped <- TextIO.readFile (directory </> "qualified/scope.data")
  pure (checks <> [("bootstrap-source-join.scope",scoped == "snapshot",scoped)])
 where
  subject = "src/Amoebius/Layout/PbGrammar.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000","LTD-SRC-001","LTD-SRC-005","LTD-SRC-006","LTD-SRC-008","LTD-META-001","LTD-NAME-001",
    "LTD-SRC-007","LTD-SRC-009","LTD-VAL-001","LTD-VAL-002","LTD-VAL-003","LTD-VAL-004","LTD-VAL-006","LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001","LTD-KRN-002","LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002","LTD-KRN-003"]) <> [after "LTD-KRN-001"]

sourceGraphJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
sourceGraphJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "source-graph" "LTD-SRC-000"
  ["path-omitted","mode-changed","bytes-changed","foreign-behavior-disguised","effect-unattributed"] ["control.inventory","control.cleanup"]
  [("path-omitted", report, "path `notElem` map pathOf actual]", "False]", ["source-graph.path-omitted.negative","source-graph.control.inventory"])
  ,("mode-changed", report, "mode /= foundMode]", "False]", ["source-graph.mode-changed.negative"])
  ,("bytes-changed", report, "digest /= foundDigest]", "False]", ["source-graph.bytes-changed.negative"])
  ,("kind-changed", report, "kind /= foundKind]", "False]", ["source-graph.control.inventory"])
  ,("foreign-disguised", graph, "interfaceFindings <> [finding | Left finding <- parsed]", "interfaceFindings <> []", ["source-graph.foreign-behavior-disguised.negative"])
  ,("effect-unattributed", graph, "| null unresolved && null standaloneUnresolved && null routeGaps && null reportedOpaqueSites", "| True", ["source-graph.effect-unattributed.negative"])
  ,("source-omitted", graph, "sort [path | path <- paths, takeExtension path == \".hs\"]", "sort [path | path <- paths, takeExtension path == \".hs\", path /= \"test/layout/ClassEffectRoute.hs\"]", ["source-graph.discovery"])]
 where
  report = "src/Amoebius/Layout/Report.hs"
  graph = "src/Amoebius/Layout/SourceGraph.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000","LTD-SRC-001","LTD-SRC-005","LTD-SRC-006","LTD-SRC-008","LTD-META-001","LTD-NAME-001",
    "LTD-SRC-007","LTD-SRC-009","LTD-VAL-001","LTD-VAL-002","LTD-VAL-003","LTD-VAL-004","LTD-VAL-006","LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001","LTD-KRN-002","LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002","LTD-KRN-003"]) <> [after "LTD-KRN-001"]

ignoreContextJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
ignoreContextJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "ignore-context" "LTD-META-001"
  ["retired-generated-root", "undeclared-state-root"] ["control.inventory", "control.cleanup"]
  [("retired-root", subject, "| patternText <- patterns, retired patternText]", "| patternText <- patterns, False]", ["ignore-context.retired-generated-root.negative"])
  ,("undeclared-root", subject, "patternText <- patterns, patternText `notElem` allowedPatterns, not (retired patternText)", "patternText <- patterns, False, not (retired patternText)", ["ignore-context.undeclared-state-root.negative"])
  ,("required-root", subject, "required <- requiredPatterns, required `notElem` patterns]", "required <- requiredPatterns, False]", ["ignore-context.control.inventory"])
  ,("required-pattern", subject, "patternText <- allowedPatterns, patternText `notElem` patterns]", "patternText <- allowedPatterns, False]", ["ignore-context.control.inventory"])
  ,("archive-visible", subject, "path == \".gitignore\", any (\"validation-records\" `Text.isInfixOf`) patterns]", "path == \".gitignore\", False]", ["ignore-context.control.inventory"])]
 where
  subject = "src/Amoebius/Layout/Classify.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000", "LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006", "LTD-SRC-008", "LTD-META-001", "LTD-NAME-001",
    "LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

runtimeIdentityJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
runtimeIdentityJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "runtime-identity" "LTD-NAME-001"
  ["stale-ordinal", "copied-ordinal", "phase-named-runtime"] ["control.inventory", "control.cleanup"]
  [("text-ordinal", subject, ", ordinalToken sourceLine]", ", False]", ["runtime-identity.stale-ordinal.negative"])
  ,("path-ordinal", subject, "ordinalName = ordinalToken . Text.pack", "ordinalName _ = False", ["runtime-identity.copied-ordinal.negative"])
  ,("component-ordinal", subject, "| ordinalToken name, not (not (null directories) && all validationSourcePath directories)]", "| False, not (not (null directories) && all validationSourcePath directories)]", ["runtime-identity.phase-named-runtime.negative"])
  ,("case-fold", subject, "Text.breakOnAll needle (Text.toCaseFold source)", "Text.breakOnAll needle source", ["runtime-identity.stale-ordinal.negative", "runtime-identity.copied-ordinal.negative"])
  ,("validation-component", subject, "not (not (null directories) && all validationSourcePath directories)]", "True]", ["runtime-identity.control.inventory"])
  ,("component-discovery", packageSource, "(name, tree) <- condForeignLibs description]", "(name, tree) <- take 0 (condForeignLibs description)]", ["runtime-identity.phase-named-runtime.negative"])]
 where
  subject = "src/Amoebius/Layout/Classify.hs"
  packageSource = "src/Amoebius/Layout/PackageMap.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000", "LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006", "LTD-SRC-008", "LTD-META-001", "LTD-NAME-001",
    "LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

pulumiSourceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
pulumiSourceJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "pulumi-source" "LTD-SRC-005"
  ["tracked-pulumi-yaml", "renamed-pulumi-program"] ["control.inventory", "control.cleanup"]
  [("pulumi-root", subject, "| \"pulumi/\" `prefix` path = reject \"TrackedPulumiProgram\"", "| \"pulumi/\" `prefix` path = Right HaskellSource", ["pulumi-source.tracked-pulumi-yaml.negative"])
  ,("renamed-program", subject, "| otherwise = reject \"UnclassifiedTrackedPath\"", "| otherwise = Right HaskellSource", ["pulumi-source.renamed-pulumi-program.negative"])
  ,("python-program", subject, "| takeExtension path == \".py\" = reject \"TrackedPythonOutsidePb\"", "| takeExtension path == \".py\" = Right HaskellSource", ["pulumi-source.renamed-pulumi-program.negative"])]
 where
  subject = "src/Amoebius/Layout/Classify.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000", "LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006", "LTD-SRC-008", "LTD-META-001", "LTD-NAME-001",
    "LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

toolSourceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
toolSourceJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "tool-source" "LTD-SRC-001"
  ["tracked-python-gate", "renamed-tool-root"] ["control.inventory", "control.cleanup"]
  [("tool-root", subject, "| \"tools/\" `prefix` path = reject \"TrackedToolRoot\"", "| \"tools/\" `prefix` path = Right HaskellSource", ["tool-source.tracked-python-gate.negative"])
  ,("python-gate", subject, "| takeExtension path == \".py\" = reject \"TrackedPythonOutsidePb\"", "| takeExtension path == \".py\" = Right HaskellSource", ["tool-source.tracked-python-gate.negative"])
  ,("renamed-root", subject, "| otherwise = reject \"UnclassifiedTrackedPath\"", "| otherwise = Right HaskellSource", ["tool-source.renamed-tool-root.negative"])]
 where
  subject = "src/Amoebius/Layout/Classify.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000", "LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006", "LTD-SRC-008", "LTD-META-001", "LTD-NAME-001",
    "LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

testSourceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
testSourceJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "test-source" "LTD-SRC-006"
  ["tracked-test-script", "tracked-test-table", "tracked-expected-output", "tracked-patch", "tracked-mutant-body"] ["control.inventory", "control.cleanup"]
  [("foreign-input", subject, "if takeExtension path == \".hs\" then Right HaskellSource else reject \"NonHaskellTestInput\"", "Right HaskellSource",
      ["test-source." <> key <> ".negative" | key <- ["tracked-test-script", "tracked-test-table", "tracked-expected-output", "tracked-patch", "tracked-mutant-body"]])
  ,("empty-inventory", subject, "LayoutFinding \"TestSourceInventoryEmpty\" \"test\" | null selected]", "LayoutFinding \"TestSourceInventoryEmpty\" \"test\" | False]", ["test-source.control.inventory"])
  ,("duplicate-path", subject, "(path : _ : _) <- group selected]", "(path : _ : _) <- group selected, False]", ["test-source.control.inventory"])
  ,("source-omitted", subject, "testSourcePaths = filter (\"test/\" `prefix`)",
      "testSourcePaths = filter (\\path -> \"test/\" `prefix` path && path /= \"test/layout/ClassEffectRoute.hs\")", ["test-source.discovery"])]
 where
  subject = "src/Amoebius/Layout/Classify.hs"
  missing identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-000", "LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006", "LTD-SRC-008", "LTD-META-001", "LTD-NAME-001",
    "LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missing due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missing (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

vendorSourceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
vendorSourceJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "vendor-source" "LTD-SRC-009"
  ["top-level-vendor", "mutable-reference", "tracked-vendor-proto", "tracked-foreign-package", "tracked-patch-program"] ["control.fork", "control.cleanup"]
  [("top-level-vendor", subject, "\"vendor/\" `isPrefixOf` path]", "False]", ["vendor-source.top-level-vendor.negative"])
  ,("mutable-reference", subject, "GitBranch {} -> Left (MutableIdentity (renderReference reference))", "GitBranch {} -> Right reference", ["vendor-source.mutable-reference.negative"])
  ,("tracked-vendor-proto", subject, "\"src/vendor/\" `isPrefixOf` path && takeExtension path == \".proto\"]", "False]", ["vendor-source.tracked-vendor-proto.negative"])
  ,("tracked-foreign-package", subject, "\".cabal\" `isSuffixOf` path && path `notElem` [\"amoebius.cabal\", \"probe/probe.cabal\"]", "False", ["vendor-source.tracked-foreign-package.negative"])
  ,("tracked-patch-program", subject, "any (`isSuffixOf` path) [\".patch\", \".diff\"]]", "False]", ["vendor-source.tracked-patch-program.negative"])
  ,("fork-module", subject, "[ForkModuleMissing name | not present]", "[]", ["vendor-source.control.fork"])]
 where
  subject = "src/Amoebius/Toolchain/Provenance.hs"
  missingReport identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missingReport due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missingReport (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

probeSourceJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
probeSourceJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "probe-source" "LTD-SRC-007"
  ["foreign-probe-script", "foreign-probe-fixture", "probe-case-omitted"] ["control.inventory", "control.cleanup"]
  [("foreign-input", probe, "takeExtension path /= \".hs\" && path /= \"probe/probe.cabal\"]", "False]",
     ["probe-source.foreign-probe-script.negative", "probe-source.foreign-probe-fixture.negative"])
  ,("omitted-case", probe, "name <- required, name `notElem` names]", "name <- required, False]", ["probe-source.probe-case-omitted.negative"])
  ,("missing-source", probe, "path <- probeSourceRequiredPaths, path `notElem` paths]", "path <- probeSourceRequiredPaths, False]", ["probe-source.control.inventory"])]
 where
  probe = "src/Amoebius/Toolchain/Probe.hs"
  missingReport identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missingReport due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missingReport (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

admissionJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
admissionJoinChecks = behaviorJoinChecksAgainst otherSource currentSource (filter (/= "LegacyQualificationUnavailable:LTD-KRN-001:snapshot")) "admission" "LTD-BOOT-001"
  ["missing-tool", "failed-command", "malformed-version", "unsupported-version"] ["control.cleanup"]
  [("missing-tool", acquire, "present <- doesFileExist absolute", "present <- pure True", ["admission.missing-tool.negative"])
  ,("failed-command", acquire, "childExit child /= 0", "False", ["admission.failed-command.negative"])
  ,("malformed-version", versions, "Nothing -> Left (ToolVersionMalformed tool)", "Nothing -> Right []", ["admission.malformed-version.negative"])
  ,("unsupported-version.exact", versions, "ExactVersion name expected -> (name, (== expected))", "ExactVersion name _ -> (name, const True)", ["admission.unsupported-version.negative"])
  ,("unsupported-version.range", versions, "VersionRange name lower upper -> (name, \\version -> version >= lower && version < upper)", "VersionRange name _ _ -> (name, const True)", ["admission.unsupported-version.negative"])]
 where
  acquire = "src/Amoebius/Toolchain/Acquire.hs"
  versions = "src/Amoebius/Toolchain/Versions.hs"
  missingReport identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"
  after identifier = "LegacyQualificationUnavailable:" <> identifier <> ":snapshot"
  due = ["LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001"]
  currentSource = map missingReport due <> map after ["LTD-KRN-001", "LTD-KRN-002", "LTD-KRN-003"]
  otherSource = map missingReport (due <> ["LTD-KRN-002", "LTD-KRN-003"]) <> [after "LTD-KRN-001"]

behaviorJoinChecks :: Text -> Text -> [Text] -> [Text] -> [(Text, FilePath, Text, Text, [Text])] -> FilePath -> IO [(Text, Bool, Text)]
behaviorJoinChecks = behaviorJoinChecksAgainst baseline fullSourceBaseline (filter (/= kernel "LegacyQualificationUnavailable"))

behaviorJoinChecksAgainst :: [Text] -> [Text] -> ([Text] -> [Text]) -> Text -> Text -> [Text] -> [Text] -> [(Text, FilePath, Text, Text, [Text])] -> FilePath -> IO [(Text, Bool, Text)]
behaviorJoinChecksAgainst sourceBaseline sourceFull withoutKernel stem identifier keys extra variants directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> Text.unpack (stem <> "-join.tsv"))
  clean <- readIdentity (directory </> "qualified")
  ledger <- readLedger (directory </> "qualified")
  manifest <- (readMaybe . Text.unpack <$> TextIO.readFile (directory </> "qualified" </> Text.unpack (stem <> "-inputs.data"))) :: IO (Maybe (Int, [(Text, Text, [(FilePath, Text)])]))
  removed <- not <$> doesPathExist (directory </> "qualified/source")
  let val reason = reason <> ":" <> identifier <> ":snapshot"
      others = filter (/= val "LegacyAnalyzerUnavailable") sourceFull
      unqualified = "LegacyObservationMismatch" : val "LegacyQualificationUnavailable" : others
      scenariosExpected = [("qualified",others),("missing-evidence",unqualified)
        ,("duplicate-evidence","LegacyQualificationDuplicate" : others)
        ,("other-source","LegacyQualificationSourceMismatch" : sourceBaseline)
        ,("forged-observation","LegacyObservationMismatch" : val "LegacyAnalyzerUnavailable" : others)
        ,("forged-source","LegacyObservationMismatch" : val "LegacySourceMismatch" : others)
        ,("forged-lifecycle","LegacyObservationMismatch" : val "LegacyLifecycleMismatch" : others)
        ,("other-analyzer",withoutKernel unqualified),("joint",withoutKernel others)
        ,("duplicate-other","LegacyQualificationDuplicate" : withoutKernel others)]
      observed name = sort [value | ["audit",key,value] <- rows,key == name]
      field name = [value | ["field",key,value] <- rows,key == name]
      expectedFields = ["wrong-owner","reused"] <> ["weakened-query." <> key | (key,_,_,_,_) <- variants]
      identityGreen = case clean of
        Just (found,source,cap,cases,[(_,a,b),(_,c,d)]) -> found == identifier && Text.length source == 64
          && cap > 0 && cap <= 3357 && sort cases == sort keys && all ((==64) . Text.length) [a,b,c,d] && a == b && c == d && a /= c
        _ -> False
      manifestGreen = case manifest of
        Just (cap,cases) -> cap > 0 && cap <= 3357 && sort cases == sort [(key,role,[]) | key <- keys,role <- ["positive","negative"]]
        _ -> False
  weakened <- fmap concat $ forM variants $ \(key,target,needle,replacement,red) -> do
    let work = directory </> "weakened" </> Text.unpack key
    identity <- readIdentity (work </> "qualified")
    changedLedger <- readLedger (work </> "qualified")
    witness <- TextIO.readFile (work </> "source-witness.data")
    gone <- not <$> doesPathExist (work </> "qualified/source")
    let sourceGreen = case readMaybe (Text.unpack witness) :: Maybe (FilePath,Text,Text) of
          Just (path,before,after) -> path == target && Text.count needle before == 1 && after == Text.replace needle replacement before && before /= after
          _ -> False
        binaryGreen = case (clean,identity) of
          (Just (_,source,_,_,(_,before,_) : _),Just (found,changed,_,cases,[(_,after,same),(_,a,b)])) -> found == identifier
            && source /= changed && sort cases == sort keys && before /= after && after == same && a == b
          _ -> False
        exact = sort [name | name : _ <- changedLedger] == sort names
          && sort [name | name : "red" : _ <- changedLedger] == sort red
          && length [() | _ : "green" : _ <- changedLedger] == length names - length red
        row suffix green details = (stem <> "-join.weakened." <> key <> "." <> suffix,green,details)
    pure [row "source" sourceGreen "independently specified production rewrite"
         ,row "binary" binaryGreen (Text.pack (show identity))
         ,row "locus" exact (Text.pack (show changedLedger))
         ,row "refused" (field ("weakened-query." <> key) == ["user error (LegacyQualificationRefused)"]) (Text.pack (show (field ("weakened-query." <> key))))
         ,row "teardown" gone (Text.pack (show gone))]
  pure ([ (stem <> "-join.discovery",sort [name | ["scenario",name] <- rows] == sort (map fst scenariosExpected)
        && sort [name | ["field",name,_] <- rows] == sort expectedFields
        && all (\row -> case row of ["scenario",name] -> name `elem` map fst scenariosExpected; ["audit",name,_] -> name `elem` map fst scenariosExpected; ["field",name,_] -> name `elem` expectedFields; _ -> False) rows,"closed scenarios and production constraints")
        ,(stem <> "-join.identity",identityGreen,Text.pack (show clean))
        ,(stem <> "-join.manifest",manifestGreen,Text.pack (show manifest))
        ,(stem <> "-join.baseline",sort [name | name : "green" : _ <- ledger] == sort names && length ledger == length names,"complete native baseline")
        ,(stem <> "-join.teardown",removed,Text.pack (show removed))
        ,(stem <> "-join.wrong-owner",field "wrong-owner" == ["user error (LegacyQualificationWrongOwner)"],Text.pack (show (field "wrong-owner")))
        ,(stem <> "-join.reused",field "reused" == ["user error (LegacyQualificationRunNotFresh)"],Text.pack (show (field "reused")))]
      <> [(stem <> "-join." <> name,observed name == sort expected,Text.pack (show (observed name))) | (name,expected) <- scenariosExpected] <> weakened)
 where
  names = (stem <> ".discovery") : [stem <> "." <> key <> "." <> role | key <- keys,role <- ["positive","negative"]] <> map ((stem <> ".") <>) extra
  readIdentity root = readMaybe . Text.unpack <$> TextIO.readFile (root </> "identities.data") :: IO (Maybe KernelIdentity)
  readLedger root = map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (root </> "oracle-ledger.tsv")

kernelJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
kernelJoinChecks directory = do
  input <- TextIO.readFile (directory </> "kernel-join.tsv")
  identities <- TextIO.readFile (directory </> "qualified/identities.data")
  removed <- not <$> doesPathExist (directory </> "qualified/source")
  let identity = readMaybe (Text.unpack identities) :: Maybe KernelIdentity
      identityGreen = case identity of
        Just (identifier, source, cap, keys, [(_, a, b), (_, c, d)]) -> identifier == "LTD-KRN-001" && Text.length source == 64 && cap > 0 && cap <= 14000
          && sort keys == ["kernel-over-ratchet", "per-phase-run-module", "phase-number-literal"]
          && all ((== 64) . Text.length) [a, b, c, d] && a == b && c == d && a /= c
        _ -> False
  let rows = map (Text.splitOn "\t") (Text.lines input)
      scenariosExpected =
        [("qualified", others), ("missing-evidence", currentBaseline)
        ,("duplicate-evidence", "LegacyQualificationDuplicate" : others)
        ,("other-source", "LegacyQualificationSourceMismatch" : baseline)
        ,("forged-observation", "LegacyObservationMismatch" : kernel "LegacyAnalyzerUnavailable" : others)
        ,("forged-source", "LegacyObservationMismatch" : kernel "LegacySourceMismatch" : others)
        ,("forged-lifecycle", "LegacyObservationMismatch" : kernel "LegacyLifecycleMismatch" : others)]
      observed name = sort [value | ["audit", key, value] <- rows, key == name]
      field name = [value | ["field", key, value] <- rows, key == name]
  weakened <- kernelWeakeningChecks directory identity rows
  pure ([ ("kernel-join.discovery", sort [name | ["scenario", name] <- rows] == sort (map fst scenariosExpected)
          && sort [name | ["field", name, _] <- rows] == sort ["wrong-owner", "reused", "weakened-query.per-phase-run-module", "weakened-query.phase-number-literal", "weakened-query.kernel-over-ratchet"]
          && all (\row -> case row of ["scenario", name] -> name `elem` map fst scenariosExpected; ["audit", name, _] -> name `elem` map fst scenariosExpected; ["field", _, _] -> True; _ -> False) rows, Text.pack (show rows))
        , ("kernel-join.artifact-identities", identityGreen, Text.pack (show identity))
        , ("kernel-join.teardown", removed, Text.pack (show removed))
        , ("kernel-join.wrong-owner", field "wrong-owner" == ["user error (LegacyQualificationWrongOwner)"], Text.pack (show (field "wrong-owner")))
        , ("kernel-join.reused", field "reused" == ["user error (LegacyQualificationRunNotFresh)"], Text.pack (show (field "reused"))) ]
    <> [("kernel-join." <> name, observed name == sort expected, Text.pack (show (observed name))) | (name, expected) <- scenariosExpected] <> weakened)
 where
  currentBaseline = fullSourceBaseline
  others = filter (/= kernel "LegacyQualificationUnavailable") currentBaseline

kernelWeakeningChecks :: FilePath -> Maybe KernelIdentity -> [[Text]] -> IO [(Text, Bool, Text)]
kernelWeakeningChecks = queryWeakeningChecks "kernel"
  [("per-phase-run-module", ", isRunModule file]", ", False]")
  ,("phase-number-literal", ", phaseLiteral text]", ", False]")
  ,("kernel-over-ratchet", "| sum [length (T.lines contents) | (_, contents) <- sources] > maybe kernelBudget (min kernelBudget) bound]", "| False]")]

mutationJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
mutationJoinChecks directory = do
  input <- TextIO.readFile (directory </> "mutation-join.tsv")
  identity <- (readMaybe . Text.unpack <$> TextIO.readFile (directory </> "qualified/identities.data")) :: IO (Maybe KernelIdentity)
  other <- (readMaybe . Text.unpack <$> TextIO.readFile (directory </> "other-analyzer/identities.data")) :: IO (Maybe KernelIdentity)
  removed <- not <$> doesPathExist (directory </> "qualified/source")
  otherRemoved <- not <$> doesPathExist (directory </> "other-analyzer/source")
  let rows = map (Text.splitOn "\t") (Text.lines input)
      mutation reason = reason <> ":LTD-KRN-002:snapshot"
      current = fullSourceBaseline
      others = filter (/= mutation "LegacyQualificationUnavailable") current
      jointly = filter (/= kernel "LegacyQualificationUnavailable") others
      scenariosExpected = [("qualified", others), ("missing-evidence", current)
        ,("duplicate-evidence", "LegacyQualificationDuplicate" : others)
        ,("other-source", "LegacyQualificationSourceMismatch" : baseline)
        ,("forged-observation", "LegacyObservationMismatch" : mutation "LegacyAnalyzerUnavailable" : others)
        ,("forged-source", "LegacyObservationMismatch" : mutation "LegacySourceMismatch" : others)
        ,("forged-lifecycle", "LegacyObservationMismatch" : mutation "LegacyLifecycleMismatch" : others)
        ,("other-analyzer", filter (/= kernel "LegacyQualificationUnavailable") current)
        ,("joint", jointly), ("duplicate-other", "LegacyQualificationDuplicate" : jointly)]
      observed name = sort [value | ["audit", key, value] <- rows, key == name]
      field name = [value | ["field", key, value] <- rows, key == name]
      identityOkay identifier expected value = case value of
        Just (key, source, cap, keys, [(_, a, b), (_, c, d)]) -> key == identifier && Text.length source == 64
          && cap > 0 && cap <= 14000 && sort keys == sort expected
          && all ((== 64) . Text.length) [a, b, c, d] && a == b && c == d && a /= c
        _ -> False
      sameSource = case (identity, other) of (Just (_, a, ac, _, _), Just (_, b, bc, _, _)) -> a == b && ac == bc; _ -> False
      variants = [("authored-mutant-symbol", "symbol name = [\"MutantSymbol\" | marker (T.pack (unpackFS name))]", "symbol _ = []")
        ,("authored-mutant-flag", "name <- graphFlags graph, \"mutant\" `T.isInfixOf` T.toCaseFold name]", "name <- graphFlags graph, False]")
        ,("authored-mutant-selector", "&& \"_MUTANT\" `T.isInfixOf` value", "&& False")]
  weakened <- queryWeakeningChecks "mutation" variants directory identity rows
  pure ([ ("mutation-join.discovery", sort [name | ["scenario", name] <- rows] == sort (map fst scenariosExpected)
          && sort [name | ["field", name, _] <- rows] == sort (["wrong-owner", "reused"] <> ["weakened-query." <> key | (key, _, _) <- variants])
          && all (\row -> case row of ["scenario", name] -> name `elem` map fst scenariosExpected; ["audit", name, _] -> name `elem` map fst scenariosExpected; ["field", _, _] -> True; _ -> False) rows, Text.pack (show rows))
        ,("mutation-join.artifact-identities", identityOkay "LTD-KRN-002" [key | (key, _, _) <- variants] identity, Text.pack (show identity))
        ,("mutation-join.teardown", removed, Text.pack (show removed))
        ,("mutation-join.wrong-owner", field "wrong-owner" == ["user error (LegacyQualificationWrongOwner)"], Text.pack (show (field "wrong-owner")))
        ,("mutation-join.reused", field "reused" == ["user error (LegacyQualificationRunNotFresh)"], Text.pack (show (field "reused")))
        ,("mutation-join.other-analyzer-identities", sameSource && otherRemoved && identityOkay "LTD-KRN-001" ["per-phase-run-module", "phase-number-literal", "kernel-over-ratchet"] other, Text.pack (show other))]
    <> [("mutation-join." <> name, observed name == sort expected, Text.pack (show (observed name))) | (name, expected) <- scenariosExpected] <> weakened)

solverJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
solverJoinChecks directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "solver-join.tsv")
  identity <- (readMaybe . Text.unpack <$> TextIO.readFile (directory </> "qualified/identities.data")) :: IO (Maybe KernelIdentity)
  other <- (readMaybe . Text.unpack <$> TextIO.readFile (directory </> "other-analyzer/identities.data")) :: IO (Maybe KernelIdentity)
  removed <- not <$> doesPathExist (directory </> "qualified/source")
  otherRemoved <- not <$> doesPathExist (directory </> "other-analyzer/source")
  ledger <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "qualified/oracle-ledger.tsv")
  let current = fullSourceBaseline
      solver reason = reason <> ":LTD-KRN-003:snapshot"
      others = filter (/= solver "LegacyQualificationUnavailable") current
      jointly = filter (/= kernel "LegacyQualificationUnavailable") others
      scenariosExpected = [("qualified", others), ("missing-evidence", current)
        ,("duplicate-evidence", "LegacyQualificationDuplicate" : others), ("other-source", "LegacyQualificationSourceMismatch" : baseline)
        ,("forged-observation", "LegacyObservationMismatch" : solver "LegacyAnalyzerUnavailable" : others)
        ,("forged-source", "LegacyObservationMismatch" : solver "LegacySourceMismatch" : others)
        ,("forged-lifecycle", "LegacyObservationMismatch" : solver "LegacyLifecycleMismatch" : others)
        ,("other-analyzer", filter (/= kernel "LegacyQualificationUnavailable") current)
        ,("joint", jointly), ("duplicate-other", "LegacyQualificationDuplicate" : jointly)]
      variants = [("fake-inductive", "| sort expected /= sort (concatMap constructors", "| typeName == \"RefinementStatus\" && sort expected /= sort (concatMap constructors")
        ,("fake-proved", "| sort expected /= sort (concatMap constructors", "| typeName == \"SymbolicResult\" && sort expected /= sort (concatMap constructors")]
      identityOkay identifier keys value = case value of
        Just (key, source, cap, cases, [(_, a, b), (_, c, d)]) -> key == identifier && sort cases == sort keys
          && cap > 0 && cap <= 14000 && all ((== 64) . Text.length) [source, a, b, c, d] && a == b && c == d && a /= c
        _ -> False
      sameSource = case (identity, other) of (Just (_, a, ac, _, _), Just (_, b, bc, _, _)) -> a == b && ac == bc; _ -> False
      field name = [value | ["field", key, value] <- rows, key == name]
      observed name = sort [value | ["audit", key, value] <- rows, key == name]
      names = "solver.discovery" : ["solver." <> key <> "." <> role | key <- ["fake-inductive", "fake-proved"], role <- ["positive", "negative", "delta"]]
        <> ["solver-reintroduction.discovery", "solver-reintroduction.baseline"]
        <> ["solver-reintroduction." <> key <> "." <> role | key <- ["clean", "fake-inductive", "fake-proved"], role <- ["runtime", "api", "execution", "source", "images", "teardown"]]
  weakened <- queryWeakeningChecks "solver" variants directory identity rows
  pure ([("solver-join.discovery", sort [name | ["scenario", name] <- rows] == sort (map fst scenariosExpected)
      && sort [name | ["field", name, _] <- rows] == sort (["wrong-owner", "reused"] <> ["weakened-query." <> key | (key, _, _) <- variants])
      && all (\row -> case row of ["scenario", key] -> key `elem` map fst scenariosExpected; ["audit", key, _] -> key `elem` map fst scenariosExpected; ["field", _, _] -> True; _ -> False) rows, Text.pack (show rows))
    ,("solver-join.identities", identityOkay "LTD-KRN-003" ["fake-inductive", "fake-proved"] identity, Text.pack (show identity))
    ,("solver-join.qualified-ledger", sort [key | [key, "green", _] <- ledger] == sort names && length ledger == 27, Text.pack (show ledger))
    ,("solver-join.teardown", removed, Text.pack (show removed))
    ,("solver-join.other-analyzer", sameSource && otherRemoved && identityOkay "LTD-KRN-001" ["per-phase-run-module", "phase-number-literal", "kernel-over-ratchet"] other, Text.pack (show other))
    ,("solver-join.wrong-owner", field "wrong-owner" == ["user error (LegacyQualificationWrongOwner)"], Text.pack (show (field "wrong-owner")))
    ,("solver-join.reused", field "reused" == ["user error (LegacyQualificationRunNotFresh)"], Text.pack (show (field "reused")))]
    <> [("solver-join." <> name, observed name == sort expected, Text.pack (show (observed name))) | (name, expected) <- scenariosExpected] <> weakened)

bootstrapJoinChecks :: FilePath -> IO [(Text, Bool, Text)]
bootstrapJoinChecks directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "bootstrap-join.tsv")
  identity <- loadIdentity "qualified"
  other <- loadIdentity "other-analyzer"
  weak <- loadIdentity "weakened/all-bootstrap-negatives/qualified"
  scope <- TextIO.readFile (directory </> "qualified/scope.data")
  ledger <- readLedger "qualified"
  weakLedger <- readLedger "weakened/all-bootstrap-negatives/qualified"
  removed <- not <$> doesPathExist (directory </> "qualified/source")
  otherRemoved <- not <$> doesPathExist (directory </> "other-analyzer/source")
  weakRemoved <- not <$> doesPathExist (directory </> "weakened/all-bootstrap-negatives/qualified/source")
  witness <- readMaybe . Text.unpack <$> TextIO.readFile (directory </> "weakened/all-bootstrap-negatives/source-witness.data")
  let keys = ["dynamic-import", "undeclared-effect", "command-dispatch", "argv-rewritten", "unscanned-syntax"]
      names = "bootstrap.discovery" : ["bootstrap." <> key <> "." <> role | key <- keys, role <- ["positive", "negative", "delta"]]
      scoped reason = reason <> ":LTD-SRC-008:captured-bootstrap"
      others = filter (/= scoped "LegacyQualificationUnavailable") fullSourceBaseline
      joint = filter (/= kernel "LegacyQualificationUnavailable") others
      expectedScenarios = [("qualified", others), ("missing-evidence", fullSourceBaseline)
        ,("duplicate-evidence", "LegacyQualificationDuplicate" : others)
        ,("other-source", "LegacyQualificationSourceMismatch" : baseline)
        ,("forged-observation", "LegacyObservationMismatch" : scoped "LegacyAnalyzerUnavailable" : others)
        ,("forged-source", "LegacyObservationMismatch" : scoped "LegacySourceMismatch" : others)
        ,("forged-lifecycle", "LegacyObservationMismatch" : scoped "LegacyLifecycleMismatch" : others)
        ,("other-analyzer", filter (/= kernel "LegacyQualificationUnavailable") fullSourceBaseline)
        ,("joint", joint), ("duplicate-other", "LegacyQualificationDuplicate" : joint)
        ,("whole-snapshot-zero", "LegacyObservationMismatch" : "LegacyActiveZeroBeforeOwner:LTD-SRC-008:snapshot" : others)
        ,("scope-swap", ["LegacyObservationMismatch", "LegacyRowMissing:LTD-SRC-008:captured-bootstrap", "LegacyRowDuplicate:LTD-SRC-008:snapshot"] <> others)]
      expectedFields = ["wrong-owner", "reused", "whole-owner-supported", "whole-snapshot-unqualified", "captured-proof-unexpected", "weakened-query.all-bootstrap-negatives"]
      field name = [value | ["field", key, value] <- rows, key == name]
      observed name = sort [value | ["audit", key, value] <- rows, key == name]
      identityOkay expected expectedKeys value = case value of
        Just (key, source, cap, cases, [(_, a, b), (_, c, d)]) -> key == expected && sort cases == sort expectedKeys
          && cap > 0 && cap <= 14000 && all ((== 64) . Text.length) [source, a, b, c, d] && a == b && c == d && a /= c
        _ -> False
      sameSource = case (identity, other) of (Just (_, a, ac, _, _), Just (_, b, bc, _, _)) -> a == b && ac == bc; _ -> False
      changedSource = case witness :: Maybe (FilePath, Text, Text) of
        Just (path, before, after) -> path == "src/validation-kernel/Amoebius/Validation/Runner/Legacy.hs"
          && Text.count "Pb.admitBootstrap (E.encodeUtf8 body)" before == 1 && before /= after
          && after == Text.replace "Pb.admitBootstrap (E.encodeUtf8 body)" "Right ()" before
        _ -> False
      changedImage = case (identity, weak) of
        (Just (_, a, _, _, (_, b, _) : _), Just (_, c, _, _, (_, d, _) : _)) -> a /= c && b /= d
        _ -> False
      redNames = ["bootstrap." <> key <> ".negative" | key <- keys]
  pure ([("bootstrap-join.discovery", sort [name | ["scenario", name] <- rows] == sort (map fst expectedScenarios)
      && sort [name | ["field", name, _] <- rows] == sort expectedFields
      && all (\row -> case row of ["scenario", key] -> key `elem` map fst expectedScenarios; ["audit", key, _] -> key `elem` map fst expectedScenarios; ["field", key, _] -> key `elem` expectedFields; _ -> False) rows, Text.pack (show rows))
    ,("bootstrap-join.identities", identityOkay "LTD-SRC-008" keys identity, Text.pack (show identity))
    ,("bootstrap-join.scope", scope == "captured-bootstrap", scope)
    ,("bootstrap-join.qualified-ledger", sort [key | [key, "green", _] <- ledger] == sort names && length ledger == 16, Text.pack (show ledger))
    ,("bootstrap-join.teardown", removed, Text.pack (show removed))
    ,("bootstrap-join.other-analyzer", sameSource && otherRemoved && identityOkay "LTD-KRN-001" ["per-phase-run-module", "phase-number-literal", "kernel-over-ratchet"] other, Text.pack (show other))
    ,("bootstrap-join.wrong-owner", field "wrong-owner" == ["user error (LegacyQualificationWrongOwner)"], Text.pack (show (field "wrong-owner")))
    ,("bootstrap-join.reused", field "reused" == ["user error (LegacyQualificationRunNotFresh)"], Text.pack (show (field "reused")))
    ,("bootstrap-join.whole-owner-supported", field "whole-owner-supported" == ["True"], Text.pack (show (field "whole-owner-supported")))
    ,("bootstrap-join.whole-snapshot-unqualified", field "whole-snapshot-unqualified" == ["True"], Text.pack (show (field "whole-snapshot-unqualified")))
    ,("bootstrap-join.captured-proof-unexpected", field "captured-proof-unexpected" == ["True"], Text.pack (show (field "captured-proof-unexpected")))]
    <> [("bootstrap-join." <> name, observed name == sort expected, Text.pack (show (observed name))) | (name, expected) <- expectedScenarios]
    <> [("bootstrap-join.weakened.source", changedSource, "complete exact analyzer rewrite")
       ,("bootstrap-join.weakened.image", changedImage && identityOkay "LTD-SRC-008" keys weak, Text.pack (show weak))
       ,("bootstrap-join.weakened.rows", sort [key | [key, _, _] <- weakLedger] == sort names
          && sort [key | [key, "red", _] <- weakLedger] == sort redNames
          && length [() | [_, "green", _] <- weakLedger] == 11, Text.pack (show weakLedger))
       ,("bootstrap-join.weakened.refused", field "weakened-query.all-bootstrap-negatives" == ["user error (LegacyQualificationRefused)"], Text.pack (show (field "weakened-query.all-bootstrap-negatives")))
       ,("bootstrap-join.weakened.teardown", weakRemoved, Text.pack (show weakRemoved))])
 where
  loadIdentity path = readMaybe . Text.unpack <$> TextIO.readFile (directory </> path </> "identities.data") :: IO (Maybe KernelIdentity)
  readLedger path = map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> path </> "oracle-ledger.tsv")

queryWeakeningChecks :: Text -> [(Text, Text, Text)] -> FilePath -> Maybe KernelIdentity -> [[Text]] -> IO [(Text, Bool, Text)]
queryWeakeningChecks stem variants directory clean rows = fmap concat $ forM variants
  $ \(key, needle, replacement) -> do
    let work = directory </> "weakened" </> Text.unpack key
        field = [value | ["field", name, value] <- rows, name == "weakened-query." <> key]
        row suffix green details = (stem <> "-join.weakened." <> key <> "." <> suffix, green, details)
    identities <- TextIO.readFile (work </> "qualified/identities.data")
    ledger <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (work </> "qualified/oracle-ledger.tsv")
    witness <- TextIO.readFile (work </> "source-witness.data")
    removed <- not <$> doesPathExist (work </> "qualified/source")
    let identity = readMaybe (Text.unpack identities) :: Maybe KernelIdentity
        changedSource = case readMaybe (Text.unpack witness) :: Maybe (FilePath, Text, Text) of
          Just (path, before, after) -> path == "src/validation-kernel/Amoebius/Validation/Runner/Legacy.hs"
            && Text.count needle before == 1 && after == Text.replace needle replacement before && before /= after
          _ -> False
        changedBinary = case (clean, identity) of
          (Just (_, _, _, _, (_, before, _) : _), Just (_, _, _, _, (_, after, _) : _)) -> before /= after
          _ -> False
        expected = stem <> ".discovery" : [stem <> "." <> name <> "." <> control
          | (name, _, _) <- variants, control <- ["positive", "negative", "delta"]]
          <> (["solver-reintroduction.discovery", "solver-reintroduction.baseline"]
            <> ["solver-reintroduction." <> name <> "." <> role | name <- ["clean", "fake-inductive", "fake-proved"], role <- ["runtime", "api", "execution", "source", "images", "teardown"]] >>= \name -> [name | stem == "solver"])
        exact = sort [name | name : _ <- ledger] == sort expected
          && [name | name : "red" : _ <- ledger] == [stem <> "." <> key <> ".negative"]
          && length [() | _ : "green" : _ <- ledger] == length expected - 1
    pure [row "source" changedSource "exact production constraint rewrite"
         ,row "binary" changedBinary (Text.pack (show (clean, identity)))
         ,row "locus" exact (Text.pack (show ledger))
         ,row "refused" (field == ["user error (LegacyQualificationRefused)"]) (Text.pack (show field))
         ,row "teardown" removed (Text.pack (show removed))]

-- This registry and its projections are independently authored. No product,
-- inventory, analyzer, serializer, mutation helper or expectation is imported.
kernelQualificationChecks :: FilePath -> FilePath -> IO [(Text, Bool, Text)]
kernelQualificationChecks directory sourceRoot = do
  scope <- TextIO.readFile (directory </> "scope.data")
  input <- TextIO.readFile (directory </> "kernel-inputs.data")
  output <- TextIO.readFile (directory </> "kernel-output.data")
  (cap, cases) <- maybe (die "kernel inputs malformed") pure
    (readMaybe (Text.unpack input) :: Maybe (Int, [(Text, Text, [(FilePath, Text)])]))
  results <- maybe (die "kernel observations malformed") pure
    (readMaybe (Text.unpack output) :: Maybe [(Text, Text, Either Text [(Text, FilePath, Text)])])
  controlSources <- sort . concat <$> mapM (walkControl sourceRoot) ["src/validation-kernel", "src/gate-spec"]
  original <- maybe (die "kernel control locus absent") pure (lookup target controlSources)
  let keys = ["per-phase-run-module", "phase-number-literal", "kernel-over-ratchet"]
      names = [(key, control) | key <- keys, control <- ["positive", "negative"]]
      observed key control = case [value | (k, c, value) <- results, k == key, c == control] of
        [value] -> Just value
        _ -> Nothing
      inputs key control = case [value | (k, c, value) <- cases, k == key, c == control] of
        [value] -> Just (sort value)
        _ -> Nothing
      replaced body = [(file, if file == target then body else value) | (file, value) <- controlSources]
      padding = cap - sum [length (Text.lines body) | (_, body) <- controlSources]
      expectedPositive key
        | key == "kernel-over-ratchet" = replaced (original <> Text.replicate padding "\n")
        | otherwise = controlSources
      expectedNegative key = case key of
        "per-phase-run-module" -> [(if file == target then "src/validation-kernel/Amoebius/Validation/Runner/CapturedRun.hs" else file, value) | (file, value) <- controlSources]
        "phase-number-literal" -> replaced (Text.unlines [if number == (21 :: Int) then "  Red -> \"phase-0\"" else line | (number, line) <- zip [1 ..] (Text.lines original)])
        _ -> replaced (original <> Text.replicate (padding + 1) "\n")
      expectedFinding key = case key of
        "per-phase-run-module" -> [("RunModule", "src/validation-kernel/Amoebius/Validation/Runner/CapturedRun.hs", "module")]
        "phase-number-literal" -> [("PhaseLiteral", target, "21")]
        _ -> [("KernelOverBudget", "validator", "kernel-lines")]
      row key control green details = ("kernel." <> key <> "." <> control, green, details)
  pure (("kernel.discovery", scope == "snapshot" && padding >= 0 && cap <= 14000 && cap > 0
    && sort [(key, control) | (key, control, _) <- cases] == sort names
    && sort [(key, control) | (key, control, _) <- results] == sort names
    && length (Text.lines original) >= 21 && Text.lines original !! 20 == "  Red -> \"red\"", Text.pack (show (cap, names)))
    : concat
      [ [row key "positive" (observed key "positive" == Just (Right [])) (Text.pack (show (observed key "positive")))
        ,row key "negative" (observed key "negative" == Just (Right (expectedFinding key))) (Text.pack (show (observed key "negative")))
        ,row key "delta" (inputs key "positive" == Just (sort (expectedPositive key))
          && inputs key "negative" == Just (sort (expectedNegative key))
          && expectedPositive key /= expectedNegative key) "complete paired source projections"]
      | key <- keys])
 where
  target = "src/validation-kernel/Amoebius/Validation/Runner/Capture.hs"

mutationQualificationChecks :: FilePath -> FilePath -> IO [(Text, Bool, Text)]
mutationQualificationChecks directory sourceRoot = do
  scope <- TextIO.readFile (directory </> "scope.data")
  input <- TextIO.readFile (directory </> "mutation-inputs.data")
  output <- TextIO.readFile (directory </> "mutation-output.data")
  cases <- maybe (die "mutation qualification inputs malformed") (pure . snd)
    (readMaybe (Text.unpack input) :: Maybe (Int, [(Text, Text, [(FilePath, Text)])]))
  results <- maybe (die "mutation qualification output malformed") pure
    (readMaybe (Text.unpack output) :: Maybe [(Text, Text, Either Text [(Text, FilePath, Text)])])
  haskell <- concat <$> mapM (walkControl sourceRoot) ["src", "app", "test"]
  package <- controlText (sourceRoot </> "amoebius.cabal")
  let source = sort (("amoebius.cabal", package) : haskell)
      target = "src/vocabulary/Amoebius/Vocabulary.hs"
  body <- maybe (die "mutation qualification subject absent") pure (lookup target source)
  let entries = [("authored-mutant-symbol", target, body <> "\nqualificationProbe = True\n", body <> "\nqualificationProbe_MUTANT = True\n",
                    [("MutantSymbol", target, Text.pack (show (length (Text.lines body) + 2) <> ":1"))])
        ,("authored-mutant-flag", "amoebius.cabal", flag "qualification-feature", flag "mutant-qualification",
                    [("MutantFlag", "amoebius.cabal", "mutant-qualification")])
        ,("authored-mutant-selector", target, selectorPositive, selectorNegative,
                    [("MutantSelector", target, Text.pack (show (length (Text.lines body) + line) <> ":" <> show column))
                    | (line, column) <- [(4, 22 :: Int), (5, 27), (7, 23), (7, 42), (7, 62), (7, 113), (7, 152), (7, 177), (7, 240), (7, 280)]])]
      selectorPositive = body <> Text.unlines
        ["", "qualificationPrefix = \"AMOEBIUS_\"", "qualificationSuffix = \"FEATURE\""
        ,"qualificationAlias = qualificationPrefix ++ qualificationSuffix"
        ,"qualificationCharacters = ['A','M','O','E','B','I','U','S','_','F','E','A','T','U','R','E']"
        ,"qualificationReader = lookupEnv"
        ,"qualificationProbe = (\"AMOEBIUS_FEATURE\", qualificationAlias, concat [qualificationPrefix, qualificationSuffix], Data.Text.append \"AMOEBIUS_\" \"FEATURE\", qualificationCharacters, let part = qualificationSuffix in qualificationPrefix <> part, lookupEnv (\"_\" <> qualificationSuffix), qualificationReader (\"_\" <> qualificationSuffix))"]
      selectorNegative = body <> Text.unlines
        ["", "qualificationPrefix = \"AMOEBIUS_\"", "qualificationSuffix = \"MUTANT\""
        ,"qualificationAlias = qualificationPrefix ++ qualificationSuffix"
        ,"qualificationCharacters = ['A','M','O','E','B','I','U','S','_','M','U','T','A','N','T']"
        ,"qualificationReader = lookupEnv"
        ,"qualificationProbe = (\"AMOEBIUS_MUTANT\", qualificationAlias, concat [qualificationPrefix, qualificationSuffix], Data.Text.append \"AMOEBIUS_\" \"MUTANT\", qualificationCharacters, let part = qualificationSuffix in qualificationPrefix <> part, lookupEnv (\"_\" <> qualificationSuffix), qualificationReader (\"_\" <> qualificationSuffix))"]
      flag name = package <> "\nflag " <> name <> "\n    default: False\n    manual: True\n"
      names = [(key, role) | (key, _, _, _, _) <- entries, role <- ["positive", "negative"]]
      observed key role = [value | (k, r, value) <- results, k == key, r == role]
      supplied key role = [sort files | (k, r, files) <- cases, k == key, r == role]
      projection path text = [(file, if file == path then text else value) | (file, value) <- source]
      row key role green detail = ("mutation." <> key <> "." <> role, green, detail)
  pure (("mutation.discovery", scope == "snapshot" && sort [(k, r) | (k, r, _) <- cases] == sort names
      && sort [(k, r) | (k, r, _) <- results] == sort names, Text.pack (show names)) : concat
    [ [row key "positive" (observed key "positive" == [Right []]) (Text.pack (show (observed key "positive")))
      ,row key "negative" (map (fmap sort) (observed key "negative") == [Right (sort findings)]) (Text.pack (show (observed key "negative")))
      ,row key "delta" (supplied key "positive" == [projection path positive]
          && supplied key "negative" == [projection path negative] && positive /= negative) "complete independent source/package projections"]
    | (key, path, positive, negative, findings) <- entries])

walkControl :: FilePath -> FilePath -> IO [(FilePath, Text)]
walkControl root relative = do
  names <- sort <$> listDirectory (root </> relative)
  concat <$> mapM (\name -> do
    let file = relative <> "/" <> name; path = root </> file
    linked <- pathIsSymbolicLink path
    if linked then die "query oracle source symlink" else pure ()
    isDirectory <- doesDirectoryExist path
    if isDirectory then walkControl root file else if ".hs" `Text.isSuffixOf` Text.pack file
      then (\body -> [(file, body)]) <$> controlText path else pure []) names

controlText :: FilePath -> IO Text
controlText path = Bytes.readFile path >>= either (die . show) pure . Encoding.decodeUtf8'

legacyAuditChecks :: FilePath -> IO [(Text, Bool, Text)]
legacyAuditChecks directory = do
  contents <- TextIO.readFile (directory </> "legacy.tsv")
  let rows = map (Text.splitOn "\t") (Text.lines contents)
      field name = case [value | ["field", key, value] <- rows, key == name] of
        [value] -> value
        _ -> "missing-or-duplicate-field"
      observed name = sort [value | ["audit", key, value] <- rows, key == name]
      discovered = sort [name | ["scenario", name] <- rows]
  pure (("legacy-audit.scenarios", discovered == sort (map fst scenarios), Text.intercalate "," discovered)
    : [("legacy-audit.field." <> name, field name == expected, field name) | (name, expected) <- fields]
    <> [("legacy-audit." <> name, observed name == sort expected, Text.intercalate "," (observed name)) | (name, expected) <- scenarios])

fields :: [(Text, Text)]
fields =
  [ ("kernel.zero", "AnalyzerFindings []")
  , ("kernel.source-bound", "True")
  , ("kernel.run-module", "RunModule:src/validation-kernel/LegacyRun.hs:module")
  , ("kernel.phase-literal", "PhaseLiteral:src/gate-spec/Spec.hs:2")
  , ("kernel.over-ratchet", "KernelOverBudget:validator:kernel-lines")
  , ("kernel.exact-fit", "AnalyzerFindings []")
  , ("kernel.non-utf8", "AnalyzerUnavailable \"KernelSourceNonUtf8\"")
  , ("kernel.scope-missing", "AnalyzerUnavailable \"KernelSourceScopeMissing\"")
  , ("bootstrap.scope-distinct", "True")
  ]

scenarios :: [(Text, [Text])]
scenarios =
  [ ("baseline", baseline)
  , ("missing-row", replaceKernel "LegacyRowMissing")
  , ("duplicate-row", replaceKernel "LegacyRowDuplicate")
  , ("source-mismatch", replaceKernel "LegacySourceMismatch")
  , ("analyzer-mismatch", replaceKernel "LegacyAnalyzerMismatch")
  , ("lifecycle-mismatch", replaceKernel "LegacyLifecycleMismatch")
  , ("unbound-finding", replaceKernel "LegacyFindingUnbound")
  , ("finding-binding", replaceKernel "LegacyFindingBindingMismatch")
  , ("duplicate-locus", "LegacyDuplicateLocus" : replaceKernel "LegacyFindingDue")
  , ("later-finding", baseline)
  , ("later-zero", "LegacyActiveZeroBeforeOwner:LTD-DSL-004:snapshot" : baseline)
  , ("bootstrap-zero", "LegacyQualificationUnavailable:LTD-SRC-008:captured-bootstrap" : filter (/= "LegacyAnalyzerUnavailable:LTD-SRC-008:captured-bootstrap") baseline)
  , ("full-bootstrap-zero", "LegacyActiveZeroBeforeOwner:LTD-SRC-008:snapshot" : baseline)
  , ("bootstrap-scope-swap", ["LegacyRowMissing:LTD-SRC-008:captured-bootstrap", "LegacyRowDuplicate:LTD-SRC-008:snapshot"] <> filter (/= "LegacyAnalyzerUnavailable:LTD-SRC-008:captured-bootstrap") baseline)
  , ("unexpected-row", "LegacyUnexpectedRow" : baseline)
  , ("wrong-scope", "LegacyUnexpectedRow" : replaceKernel "LegacyRowMissing")
  , ("finding-due", replaceKernel "LegacyFindingDue")
  , ("after-owner", map unavailable ["LTD-SRC-007", "LTD-SRC-009", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-BOOT-001", "LTD-KRN-002", "LTD-KRN-003"] <> [kernel "LegacyQualificationUnavailable"])
  , ("unknown-phase", ["LegacyPhaseUnknown"])
  ]

baseline :: [Text]
baseline = map unavailable ["LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-006", "LTD-KRN-002", "LTD-KRN-003"]
  <> ["LegacyAnalyzerUnavailable:LTD-SRC-008:captured-bootstrap", kernel "LegacyQualificationUnavailable"]

fullSourceBaseline :: [Text]
fullSourceBaseline = map (\value -> maybe value id (lookup value replacements)) baseline
 where
  replacements = [(unavailable key, "LegacyQualificationUnavailable:" <> key <> ":snapshot") | key <- ["LTD-KRN-002", "LTD-KRN-003"]]
    <> [("LegacyAnalyzerUnavailable:LTD-SRC-008:captured-bootstrap", "LegacyQualificationUnavailable:LTD-SRC-008:captured-bootstrap")]

unavailable :: Text -> Text
unavailable identifier = "LegacyAnalyzerUnavailable:" <> identifier <> ":snapshot"

kernel :: Text -> Text
kernel reason = reason <> ":LTD-KRN-001:snapshot"

replaceKernel :: Text -> [Text]
replaceKernel reason = kernel reason : filter (/= kernel "LegacyQualificationUnavailable") baseline

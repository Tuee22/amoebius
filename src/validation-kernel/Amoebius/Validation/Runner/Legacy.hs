{-# LANGUAGE OverloadedStrings #-}
-- | Untrusted analyzer reports and their prequalification audit. No pass authority.
module Amoebius.Validation.Runner.Legacy
  ( LegacyFinding (..), LegacyObservation (..), LegacyReport (..)
  , legacyRequirementsAt, observeLegacy, observeLegacyMany, auditLegacyReports, renderLegacyReports
  , LegacyCollection, collectLegacy, inheritLegacyCollection, auditLegacyCollection, legacyCollectionRuns, legacyCollectionEvidence, legacyQualificationSupported
  , LegacyQualification, qualifyLegacy, qualifiedLegacyReports, auditQualifiedLegacyReports, runLegacyProbe, runSolverReintroductions ) where
import Amoebius.Layout.PbGrammar qualified as Pb
import Amoebius.Plan.Legacy qualified as L
import Amoebius.Plan.PhaseIdentity qualified as P
import Amoebius.Toolchain.Acquire qualified as Tools
import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Custody.Store (archivedKernelCap)
import Amoebius.Validation.GateSpec (OracleExecutable (..), GateRole (SeedGate), mkGateSpec)
import Amoebius.Validation.GateSpec.Seed (phaseZeroSpecInput)
import Amoebius.Validation.Runner.Observer
import Amoebius.Validation.Runner.Spec (loadPackageGraph, verifyOracle, parsePackageGraph, graphFlags, sourceTokens, sourceTree, sourceDirectives, requiredSuiteRows)
import Control.Exception (IOException, finally, try)
import Control.Monad (unless, forM, foldM)
import Data.ByteString qualified as B
import Data.Data (Data, cast, gmapQ)
import Data.List (nub, sort)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.List.NonEmpty qualified as NE
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as E
import Data.Text.IO qualified as TIO
import GHC.Data.FastString (FastString, unpackFS)
import GHC.Hs
import GHC.Hs.Instances ()
import GHC.Parser.Lexer (Token (..))
import GHC.Types.Name.Reader (RdrName (..), rdrNameOcc)
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.SrcLoc (GenLocated (..), SrcSpan (..), srcSpanStartLine, srcSpanStartCol, unLoc)
import System.Directory (canonicalizePath, createDirectory, createDirectoryIfMissing, doesPathExist, makeAbsolute, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath (equalFilePath, isAbsolute, makeRelative, splitDirectories, takeDirectory, takeExtension, (</>))
import Text.Read (readMaybe)
data LegacyFinding = LegacyFinding
  { findingIdentity :: Maybe L.LegacyId, findingScope :: Text, findingPath :: FilePath
  , findingLocus :: Text, findingReason :: Text } deriving (Eq, Show)
data LegacyObservation = AnalyzerUnavailable Text | AnalyzerFindings [LegacyFinding] deriving (Eq, Show)
data LegacyReport = LegacyReport
  { reportedIdentity :: L.LegacyId, reportedScope :: Text, reportedLifecycle :: Text
  , reportedAnalyzer :: Text, reportedSource :: Text, reportedObservation :: LegacyObservation } deriving (Eq, Show)
legacyRequirementsAt :: Int -> [L.LegacyRequirement]
legacyRequirementsAt phase = L.legacyRequirements <> [L.legacyBootstrapSourceRequirement | phase == P.phaseDomainLowerOrdinal]
observeLegacy :: Int -> CapturedSource -> Maybe Int -> [LegacyReport]
observeLegacy phase source cap = concat (observeLegacyMany phase [source] cap)
observeLegacyMany :: Int -> [CapturedSource] -> Maybe Int -> [[LegacyReport]]
observeLegacyMany phase sources cap = [map (observeRequirement source) (legacyRequirementsAt phase) | source <- sources]
 where
  scanner = sourceScans [files | source <- sources, Right files <- [sourceTexts ".hs" ["src", "app", "test"] source]]
  observeRequirement source requirement = LegacyReport (L.legacyRequirementId requirement) (scope requirement)
    (L.renderLegacyLifecycle (L.legacyRequirementLifecycle requirement))
    (L.renderLegacyAnalyzerKey (L.legacyRequirementAnalyzer requirement)) (capturedSourceDigest source)
    (either AnalyzerUnavailable (AnalyzerFindings . map (\(reason, path, locus) -> LegacyFinding (Just (L.legacyRequirementId requirement)) (scope requirement) path locus reason))
      (queryInputs requirement source >>= query scanner requirement cap))
scope :: L.LegacyRequirement -> Text
scope = L.renderLegacyScope . L.legacyRequirementScope
-- Reports, source hashes and empty findings cannot supply canonical qualification.
auditLegacyReports :: Int -> CapturedSource -> [LegacyReport] -> [Text]
auditLegacyReports = auditReports []
auditReports :: [(L.LegacyId, Text)] -> Int -> CapturedSource -> [LegacyReport] -> [Text]
auditReports qualified phase source reports
  | not (P.isPhaseOrdinal phase) = ["LegacyPhaseUnknown"]
  | otherwise = ["LegacyUnexpectedRow" | any (\r -> reportKey r `notElem` keys) reports]
      <> ["LegacyDuplicateLocus" | length loci /= length (nub loci)] <> concatMap audit requirements
 where
  requirements = legacyRequirementsAt phase
  key requirement = (L.legacyRequirementId requirement, scope requirement)
  keys = map key requirements
  reportKey report = (reportedIdentity report, reportedScope report)
  findings = concat [items | report <- reports, AnalyzerFindings items <- [reportedObservation report]]
  loci = [(findingScope f, findingPath f, findingLocus f) | f <- findings]
  ref reason requirement = reason <> ":" <> L.renderLegacyId (L.legacyRequirementId requirement) <> ":" <> scope requirement
  audit requirement = case filter ((== key requirement) . reportKey) reports of
    [] -> [ref "LegacyRowMissing" requirement]
    [report] -> let
      bad = [ref reason requirement | (reason, valid) <-
        [("LegacySourceMismatch", reportedSource report == capturedSourceDigest source)
        ,("LegacyAnalyzerMismatch", reportedAnalyzer report == L.renderLegacyAnalyzerKey (L.legacyRequirementAnalyzer requirement))
        ,("LegacyLifecycleMismatch", reportedLifecycle report == L.renderLegacyLifecycle (L.legacyRequirementLifecycle requirement))], not valid]
      owner = if scope requirement == "captured-bootstrap" then Just P.phaseDomainLowerOrdinal else L.legacyOwnerOrdinal (L.legacyRequirementId requirement)
      later = maybe True (> phase) owner
      observation = case reportedObservation report of
        AnalyzerUnavailable _ -> [ref "LegacyAnalyzerUnavailable" requirement | not later]
        AnalyzerFindings items
          | any ((== Nothing) . findingIdentity) items -> [ref "LegacyFindingUnbound" requirement]
          | any (\f -> findingIdentity f /= Just (reportedIdentity report) || findingScope f /= reportedScope report) items -> [ref "LegacyFindingBindingMismatch" requirement]
          | not (null items) -> [ref "LegacyFindingDue" requirement | not later]
          | later -> [ref "LegacyActiveZeroBeforeOwner" requirement]
          | maybe False (< phase) owner && not (L.legacyRequirementRetired requirement) -> [ref "LegacyActiveZeroAfterOwner" requirement]
          | otherwise -> [ref "LegacyQualificationUnavailable" requirement | key requirement `notElem` qualified]
      in if null bad then observation else bad
    _ -> [ref "LegacyRowDuplicate" requirement]
renderLegacyReports :: [LegacyReport] -> Text
renderLegacyReports = T.unlines . map (T.pack . show)
sourceTexts :: Text -> [FilePath] -> CapturedSource -> Either Text [(FilePath, Text)]
sourceTexts suffix roots source = traverse (\(file, bytes) -> either (const (Left "KernelSourceNonUtf8")) (Right . (,) file) (E.decodeUtf8' bytes))
    [(file, bytes) | file <- capturedSourceFiles source, any (\root -> (T.pack root <> "/") `T.isPrefixOf` T.pack file) roots, suffix `T.isSuffixOf` T.pack file, Just bytes <- [capturedSourceBytes source file]]
kernelShapeFiles :: Maybe Int -> [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
kernelShapeFiles bound sources =
  if any (\root -> not (any (\(file, _) -> (T.pack root <> "/") `T.isPrefixOf` T.pack file) sources)) kernelRoots then Left "KernelSourceScopeMissing" else
    Right ([("RunModule", file, "module") | (file, _) <- sources, isRunModule file]
      <> [("PhaseLiteral", file, T.pack (show line)) | (file, contents) <- sources, (line, text) <- zip [1 :: Int ..] (T.lines contents), phaseLiteral text]
      <> [("KernelOverBudget", "validator", "kernel-lines") | sum [length (T.lines contents) | (_, contents) <- sources] > maybe kernelBudget (min kernelBudget) bound])
queryInputs :: L.LegacyRequirement -> CapturedSource -> Either Text [(FilePath, Text)]
queryInputs requirement source | requirement == L.legacyBootstrapSourceRequirement = sourceTexts "" ["pb"] source
queryInputs requirement source = case L.legacyRequirementId requirement of
  L.LtdKrn001 -> sourceTexts ".hs" kernelRoots source
  L.LtdKrn003 -> sourceTexts ".hs" ["src/symbolic-checker", "src/refinement-checker"] source
  L.LtdKrn002 -> do
    files <- sourceTexts ".hs" ["src", "app", "test"] source
    bytes <- maybe (Left "MutationPackageMissing") Right (capturedSourceBytes source "amoebius.cabal")
    package <- either (const (Left "MutationPackageNonUtf8")) Right (E.decodeUtf8' bytes)
    Right (("amoebius.cabal", package) : files)
  _ -> Left "AnalyzerNotImplemented"
type SourceScan = (FilePath, Text) -> Either Text [(Text, FilePath, Text)]
sourceScans :: [[(FilePath, Text)]] -> SourceScan
sourceScans inputs = retained `seq` \key -> maybe (Left "SourceScanMissing") id (Map.lookup key retained)
 where retained = Map.fromList [(entry, mutationFile entry) | entry <- Map.keys (Map.fromList [(entry, ()) | files <- inputs, entry@(path, _) <- files, ".hs" `T.isSuffixOf` T.pack path])]
query :: SourceScan -> L.LegacyRequirement -> Maybe Int -> [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
query _ requirement _ | requirement == L.legacyBootstrapSourceRequirement = bootstrapShape
query scanner requirement cap = case L.legacyRequirementId requirement of L.LtdKrn001 -> kernelShapeFiles cap; L.LtdKrn002 -> mutationShape scanner; L.LtdKrn003 -> solverShape; _ -> const (Left "AnalyzerNotImplemented")
bootstrapShape :: [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
bootstrapShape files = case files of [(path, body)] | path == "pb/__main__.py" -> Right [("BootstrapStructure", path, Pb.renderBootstrapRefusal refusal) | Left refusal <- [Pb.admitBootstrap (E.encodeUtf8 body)]]; _ -> Left "BootstrapSourceInventory"
solverShape :: [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
solverShape files = concat <$> traverse check
  [("src/symbolic-checker/Amoebius/Checker/Symbolic.hs", "SymbolicResult", ["NotInductive", "Unsupported", "Inconclusive"])
  ,("src/refinement-checker/Amoebius/Checker/Refinement.hs", "RefinementStatus", ["Inconclusive", "PostconditionCounterexample", "CorrespondenceMismatch", "UnknownInvariant"])]
 where
  check (file, typeName, expected) = do
    body <- maybe (Left ("SolverSourceMissing:" <> T.pack file)) Right (lookup file files)
    tree <- sourceTree file body
    case [(declaration, definition) | declaration@(L _ (TyClD _ DataDecl {tcdLName = key, tcdDataDefn = definition})) <- hsmodDecls tree, occNameString (rdrNameOcc (unLoc key)) == typeName] of
      [(declaration, definition)] -> case getLocA declaration of
        RealSrcSpan span_ _ -> Right [("SolverResultShape", file, T.pack (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_))) | sort expected /= sort (concatMap constructors (foldr (:) [] (dd_cons definition)))]
        _ -> Left ("SolverPositionUnscanned:" <> T.pack file)
      _ -> Left ("SolverResultDeclarationUnscanned:" <> T.pack file)
  constructors :: LConDecl GhcPs -> [String]
  constructors (L _ declaration) = map (occNameString . rdrNameOcc . unLoc) (case declaration of ConDeclH98 {con_name = key} -> [key]; ConDeclGADT {con_names = keys} -> NE.toList keys)
mutationShape :: SourceScan -> [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
mutationShape scanner inputs = do
  let files = [(path, body) | (path, body) <- inputs, ".hs" `T.isSuffixOf` T.pack path]
  unless (all (\root -> any (T.isPrefixOf root . T.pack . fst) files) ["src/", "app/", "test/"]) (Left "MutationSourceScopeMissing")
  package <- maybe (Left "MutationPackageMissing") Right (lookup "amoebius.cabal" inputs)
  graph <- either (Left . T.pack . show) Right (parsePackageGraph (E.encodeUtf8 package))
  observations <- concat <$> traverse scanner files
  Right ([("MutantFlag", "amoebius.cabal", name) | name <- graphFlags graph, "mutant" `T.isInfixOf` T.toCaseFold name]
    <> [("FlagBudget", "amoebius.cabal", "flags") | length (graphFlags graph) > 20] <> nub observations)
mutationFile :: SourceScan
mutationFile (file, contents) = case sourceTokens file contents of
    Left problem -> Left problem
    Right tokens -> do
      let directives = sourceDirectives contents
          lexical = [(reason, file, T.pack (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_)))
            | L (RealSrcSpan span_ _) token <- tokens
            , reason <- ["ConditionalSource" | (srcSpanStartLine span_, srcSpanStartCol span_) `elem` directives] <> reserved token]
      semantic <- if any (\(reason, _, _) -> reason == "ConditionalSource") lexical then Right [] else sourceTree file contents >>= selectorExpressions file
      Right (lexical <> semantic)
 where
  reserved token = case token of
    ITvarid name -> symbol name
    ITconid name -> symbol name
    ITqvarid (_, name) -> symbol name
    ITqconid (_, name) -> symbol name
    ITstring _ name | reservedSelector (T.pack (unpackFS name)) -> ["MutantSelector"]
    _ -> []
  marker = T.isInfixOf "_MUTANT"
  symbol name = ["MutantSymbol" | marker (T.pack (unpackFS name))]
reservedSelector :: Text -> Bool
reservedSelector value = not (T.null value) && T.head value `elem` ['A' .. 'Z'] && T.all (\c -> c == '_' || c `elem` ['A' .. 'Z'] || c `elem` ['0' .. '9']) value && "_MUTANT" `T.isInfixOf` value
type Bindings = Map.Map Text (Maybe BoundValue)
data BoundValue = BoundValue Bindings (LHsExpr GhcPs)
selectorExpressions :: FilePath -> HsModule GhcPs -> Either Text [(Text, FilePath, Text)]
selectorExpressions file tree = traverse position (walk globals tree)
 where
  current = maybe "Main" (T.pack . moduleNameString . unLoc) (hsmodName tree)
  globals = bindings Map.empty [(qualified, body) | Just (key, body) <- map binding [bind | L _ (ValD _ bind) <- hsmodDecls tree], qualified <- [key, current <> "." <> key]]
  modules = Map.fromList [(maybe module_ (T.pack . moduleNameString . unLoc) (ideclAs declaration), module_)
    | L _ declaration <- hsmodImports tree, let module_ = T.pack (moduleNameString (unLoc (ideclName declaration)))]
  name rdr = case rdr of Qual qualifier occurrence -> let qualifier_ = T.pack (moduleNameString qualifier) in Map.findWithDefault qualifier_ qualifier_ modules <> "." <> T.pack (occNameString occurrence); _ -> T.pack (occNameString (rdrNameOcc rdr))
  binding bind = case bind of
    FunBind {fun_id = key, fun_matches = matches} -> Just (name (unLoc key), case unLoc (mg_alts matches) of
      [L _ Match {m_pats = pats, m_grhss = GRHSs {grhssGRHSs = [L _ (GRHS _ [] body)], grhssLocalBinds = locals}}] | null (unLoc pats) -> Just (locals, body); _ -> Nothing)
    _ -> Nothing
  bindings outer entries = let bound = Map.map (fmap (\(locals, body) -> BoundValue (local bound locals) body)) (Map.fromListWith (\_ _ -> Nothing) entries) <> outer in bound
  local outer value = case value of HsValBinds _ (ValBinds _ values _) -> bindings outer (mapMaybe binding (map unLoc values)); _ -> outer
  variables :: Data a => a -> [Text]
  variables value = case cast value :: Maybe (LPat GhcPs) of Just (L _ (VarPat _ key)) -> [name (unLoc key)]; _ -> concat (gmapQ variables value)
  matchScope env value = local (Map.fromList [(key, Nothing) | key <- variables (m_pats value)] <> env) (grhssLocalBinds (m_grhss value))
  walk :: Data a => Bindings -> a -> [SrcSpan]
  walk env value = case cast value :: Maybe (LHsExpr GhcPs) of
    Just expression -> let nested = case unLoc expression of HsLet _ locals _ -> local env locals; _ -> env
      in if maybe False reservedSelector (text nested [] expression) || bareUse nested expression then [getLocA expression]
         else case unLoc expression of HsLit {} -> []; HsOverLit {} -> []; _ -> concat (gmapQ (walk nested) (unLoc expression))
    Nothing | Just _ <- (cast value :: Maybe FastString) -> []
            | Just _ <- (cast value :: Maybe RdrName) -> []
            | otherwise -> case cast value :: Maybe (Match GhcPs (LHsExpr GhcPs)) of
      Just match -> concat (gmapQ (walk (matchScope env match)) match)
      Nothing -> concat (gmapQ (walk env) value)
  appendNames = ["++", "<>", "mappend", "Prelude.++", "Prelude.<>", "Prelude.mappend", "Data.Text.append"]
  identityNames = ["id", "Prelude.id", "Data.Text.pack", "Data.Text.unpack"]
  function env seen expression = case unLoc expression of
    HsVar _ key -> let key_ = name (unLoc key) in case Map.lookup key_ env of
      Just body -> body >>= \(BoundValue nested inner) -> if getLocA inner `elem` seen then Nothing else function nested (getLocA inner : seen) inner
      Nothing -> Just key_
    HsPar _ inner -> function env seen inner
    _ -> Nothing
  text env seen expression = case unLoc expression of
    HsLit _ (HsString _ value) -> Just (T.pack (unpackFS value))
    HsLit _ (HsMultilineString _ value) -> Just (T.pack (unpackFS value))
    HsOverLit _ OverLit {ol_val = HsIsString _ value} -> Just (T.pack (unpackFS value))
    HsVar _ key -> Map.lookup (name (unLoc key)) env >>= id >>= \(BoundValue nested inner) -> if getLocA inner `elem` seen then Nothing else text nested (getLocA inner : seen) inner
    HsPar _ inner -> text env seen inner
    ExprWithTySig _ inner _ -> text env seen inner
    HsLet _ locals inner -> text (local env locals) seen inner
    OpApp _ left operator right | function env [] operator `elem` map Just appendNames -> (<>) <$> text env seen left <*> text env seen right
    HsApp _ (L _ (HsApp _ operator left)) right | function env [] operator `elem` map Just appendNames -> (<>) <$> text env seen left <*> text env seen right
    HsApp _ operator inner | function env [] operator `elem` map Just identityNames -> text env seen inner
    HsApp _ operator (L _ (ExplicitList _ items)) | function env [] operator `elem` map Just ["concat", "mconcat", "Prelude.concat", "Prelude.mconcat", "Data.Text.concat"] -> T.concat <$> traverse (text env seen) items
    ExplicitList _ items -> T.pack <$> traverse (\item -> case unLoc item of HsLit _ (HsChar _ char) -> Just char; _ -> Nothing) items
    _ -> Nothing
  bareUse env expression = case unLoc expression of
    HsApp _ operator inner -> text env [] inner == Just "_MUTANT" && function env [] operator `notElem`
      map Just (appendNames <> identityNames <> ["Just", "Prelude.Just", "Data.Maybe.Just", "Data.Text.isInfixOf", "Data.Text.isPrefixOf", "Data.Text.isSuffixOf", "Data.List.isInfixOf", "Data.List.isPrefixOf", "Data.List.isSuffixOf"])
    _ -> False
  position (RealSrcSpan span_ _) = Right ("MutantSelector", file, T.pack (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_)))
  position _ = Left "SelectorPositionUnscanned"
-- Opaque source-bound readiness for one query; no detached pass or serialization.
data LegacyQualification = LegacyQualified L.LegacyId L.LegacyScope Text Int [Text] Text [ObservedRun] Tools.Acquisition [(FilePath,Text,Text)] deriving (Eq, Show)
canonicalRequirement :: Int -> L.LegacyId -> L.LegacyRequirement
canonicalRequirement phase identifier = if identifier == L.LtdSrc008 && phase == P.phaseDomainLowerOrdinal then L.legacyBootstrapSourceRequirement else L.legacyRequirement identifier
type KernelCases = (Int, [(Text, Text, [(FilePath, Text)])])
runLegacyProbe :: L.LegacyId -> FilePath -> IO Text
runLegacyProbe identifier file = do
  (cap, cases) <- TIO.readFile file >>= maybe (fail "KernelProbeInputMalformed") pure . (readMaybe . T.unpack :: Text -> Maybe KernelCases)
  let scanner = sourceScans [files | (_, _, files) <- cases]
  pure (T.pack (show [(key, control, query scanner (canonicalRequirement P.phaseDomainLowerOrdinal identifier) (Just cap) files) | (key, control, files) <- cases]))
kernelCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
kernelCases cap files = do
  original <- maybe (Left "KernelQualificationLocusMissing") Right (lookup target files)
  unless (length (filter (== "  Red -> \"red\"") (T.lines original)) == 1) (Left "KernelQualificationLocusMissing")
  let replace text = [(file, if file == target then text else body) | (file, body) <- files]
      padding = cap - sum (map (length . T.lines . snd) files)
      pair key positive negative = [(key, "positive", positive), (key, "negative", negative)]
  if padding < 0 then Left "KernelQualificationOverBudget" else Right (cap,
    pair "per-phase-run-module" files [(if file == target then "src/validation-kernel/Amoebius/Validation/Runner/CapturedRun.hs" else file, body) | (file, body) <- files]
    <> pair "phase-number-literal" files (replace (T.replace "  Red -> \"red\"" ("  Red -> \"phase-" <> T.pack (show P.phaseDomainLowerOrdinal) <> "\"") original))
    <> pair "kernel-over-ratchet" (replace (original <> T.replicate padding "\n")) (replace (original <> T.replicate (padding + 1) "\n")))
 where target = "src/validation-kernel/Amoebius/Validation/Runner/Capture.hs"
mutationCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
mutationCases cap files = do
  body <- maybe (Left "MutationQualificationLocusMissing") Right (lookup target files)
  package <- maybe (Left "MutationPackageMissing") Right (lookup "amoebius.cabal" files)
  let replace path text = [(file, if file == path then text else value) | (file, value) <- files]
      pair key path positive negative = [(key, control, replace path text) | (control, text) <- [("positive", positive), ("negative", negative)]]
      flag name = package <> "\nflag " <> name <> "\n    default: False\n    manual: True\n"
      selectors word = body <> T.unlines
        ["", "qualificationPrefix = \"AMOEBIUS_\"", "qualificationSuffix = \"" <> word <> "\""
        , "qualificationAlias = qualificationPrefix ++ qualificationSuffix"
        , "qualificationCharacters = [" <> T.intercalate "," [T.pack (show char) | char <- T.unpack ("AMOEBIUS_" <> word)] <> "]"
        , "qualificationReader = lookupEnv"
        , "qualificationProbe = (\"AMOEBIUS_" <> word <> "\", qualificationAlias, concat [qualificationPrefix, qualificationSuffix], Data.Text.append \"AMOEBIUS_\" \"" <> word <> "\", qualificationCharacters, let part = qualificationSuffix in qualificationPrefix <> part, lookupEnv (\"_\" <> qualificationSuffix), qualificationReader (\"_\" <> qualificationSuffix))"]
  Right (cap, pair "authored-mutant-symbol" target (body <> "\nqualificationProbe = True\n") (body <> "\nqualificationProbe_MUTANT = True\n")
    <> pair "authored-mutant-flag" "amoebius.cabal" (flag "qualification-feature") (flag "mutant-qualification")
    <> pair "authored-mutant-selector" target (selectors "FEATURE") (selectors "MUTANT"))
 where target = "src/vocabulary/Amoebius/Vocabulary.hs"
solverVariants :: [(Text, FilePath, [(Text, Text)])]
solverVariants = [("clean", "", [])
  ,("fake-inductive", "src/symbolic-checker/Amoebius/Checker/Symbolic.hs",
    [("  | Inconclusive ObligationKind String\n", "  | Inconclusive ObligationKind String\n  | Inductive [(ObligationKind, String)]\n")
    ,("runObligations _ passed [] = pure (Right (case reverse passed of\n  (kind, _) : _ -> Inconclusive kind \"UNADMITTED-SOLVER: unsat responses do not establish induction\"\n  [] -> Unsupported [NoSafetyInvariants]))", "runObligations _ passed [] = pure (Right (Inductive (reverse passed)))")])
  ,("fake-proved", "src/refinement-checker/Amoebius/Checker/Refinement.hs",
    [("  = Inconclusive\n", "  = Inconclusive\n  | Proved\n")
    ,("Right (makeResult Inconclusive \"UNADMITTED-SOLVER: unsat responses do not establish preservation or correspondence\" \"\")", "Right (makeResult Proved \"qualification reintroduction\" \"\")")])]
solverCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
solverCases cap files = (,) cap . concat <$> forM [(key, file, needle, replacement) | (key, file, (needle, replacement) : _) <- solverVariants] (\(key, target, needle, replacement) -> do
  body <- maybe (Left "SolverQualificationLocusMissing") Right (lookup target files)
  unless (T.count needle body == 1) (Left "SolverQualificationLocusMissing")
  Right [(key, "positive", files), (key, "negative", [(file, if file == target then T.replace needle replacement body else value) | (file, value) <- files])])
nativeImages :: ([String] -> IO ObservedRun) -> [String] -> IO ([ObservedRun], [FilePath])
nativeImages native targets = do
  build <- native (["build", "-v0", "--jobs=1", "--builddir=.build/dist-native"] <> targets)
  unless (runExit build == ExitSuccess) (fail ("LegacyQualificationBuild:" <> T.unpack (runStderr build)))
  located <- mapM (\target -> native ["list-bin", "--builddir=.build/dist-native", target]) targets
  unless (all ((== ExitSuccess) . runExit) located && length located == length targets) (fail "LegacyQualificationBinaryAbsent")
  pure (build : located, map (T.unpack . T.strip . runStdout) located)
readImages :: FilePath -> [FilePath] -> IO [B.ByteString]
readImages tree images = do
  resolved <- mapM canonicalizePath images
  unless (and (zipWith equalFilePath resolved images) && all (\image -> isAbsolute image && let relative = makeRelative tree image in not (isAbsolute relative || ".." `elem` splitDirectories relative)) images) (fail "LegacyQualificationForeignBinary")
  bytes <- mapM B.readFile images
  unless (all (not . B.null) bytes) (fail "LegacyQualificationBinaryEmpty")
  pure bytes
runSolverReintroductions :: CapturedSource -> FilePath -> FilePath -> FilePath -> IO [ObservedRun]
runSolverReintroductions original destination cabal compiler = do
  absolute <- makeAbsolute destination
  present <- doesPathExist absolute
  unless (not present) (fail "LegacyQualificationRunNotFresh")
  createDirectoryIfMissing True absolute
  results <- forM solverVariants $ \(name, target, replacements) -> do
    let work = absolute </> T.unpack name
    createDirectoryIfMissing True work
    source <- if null replacements then pure original else do
      before <- maybe (fail "SolverQualificationLocusMissing") (either (fail . show) pure . E.decodeUtf8') (capturedSourceBytes original target)
      after <- foldM (\body (needle, replacement) -> unless (T.count needle body == 1) (fail "SolverQualificationLocusMissing") >> pure (T.replace needle replacement body)) before replacements
      TIO.writeFile (work </> "source-witness.data") (T.pack (show (target, before, after)))
      either (fail . T.unpack) pure (rewriteCapturedSource original target (E.encodeUtf8 after))
    tree <- materializeSource source (work </> "source") >>= either (fail . T.unpack) pure
    (do
      (builds, paths) <- nativeImages (observeNativeCabal tree cabal (Just compiler)) ["test:symbolic-checker-spec", "test:refinement-checker-spec", "test:oracle-runner"]
      let observations = work </> "observations"; fake = tree </> ".build" </> ("fake-smt-solver" <> takeExtension (last paths))
      fakeBuild <- observe tree compiler ["-v0", "-j1", "-XGHC2024", "--make", "-package", "filepath", "-outputdir", tree </> ".build/fake-smt-objects", "-o", fake, "test/spec/formal/symbolic/FakeSmtSolver.hs"]
      unless (runExit fakeBuild == ExitSuccess) (fail "SolverQualificationFakeBuild")
      before <- readImages tree (paths <> [fake])
      subjects <- mapM (\path -> observe tree path [fake, observations]) (take 2 paths)
      runtime <- observe tree (last paths) ["--solver-demotion", observations]
      api <- observe tree (last paths) ["--solver-api", observations </> "api"]
      after <- readImages tree (paths <> [fake])
      unchanged <- verifySourceCopy source tree
      let events = builds <> [fakeBuild] <> subjects <> [runtime, api]
      mapM_ (\(file, body) -> TIO.writeFile (work </> file) body) [("runtime-ledger.tsv", runStdout runtime), ("api-ledger.tsv", runStdout api), ("processes.data", T.pack (show events)), ("identities.data", T.pack (show (capturedSourceDigest source, zip3 (paths <> [fake]) (map sha256Bytes before) (map sha256Bytes after))))]
      pure ([name, T.pack (show (map runExit subjects, runExit runtime, runExit api)), T.pack (show (before == after && unchanged == Right ()))], events)) `finally` removePathForcibly tree
  TIO.writeFile (absolute </> "solver-reintroduction.tsv") (renderTsv (map fst results))
  pure (concatMap snd results)
bootstrapCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
bootstrapCases cap files = do
  body <- maybe (Left "BootstrapQualificationLocusMissing") Right (lookup "pb/__main__.py" files)
  let argv = "    bootstrap(adapter, sys.argv[1:])"
      changes = [("dynamic-import", body <> "\n__import__(\"os\")\n"), ("undeclared-effect", body <> "\nos.system(\"true\")\n")
        ,("command-dispatch", body <> "\nif sys.argv[1] == \"help\":\n    main()\n"), ("argv-rewritten", T.replace argv "    bootstrap(adapter, [])" body), ("unscanned-syntax", body <> "\n@unknown\n")]
  unless (T.count argv body == 1) (Left "BootstrapQualificationLocusMissing")
  Right (cap, [(key, control, if control == "positive" then files else [("pb/__main__.py", changed)]) | (key, changed) <- changes, control <- ["positive", "negative"]])
qualifyLegacy :: L.LegacyId -> FilePath -> FilePath -> Int -> Maybe FilePath -> Maybe FilePath -> CapturedSource -> IO (Either Text LegacyQualification)
qualifyLegacy identifier repository destination phase cabal compiler source = do
  attempted <- try acquire :: IO (Either IOException LegacyQualification)
  pure (either (Left . T.pack . show) Right attempted)
 where
  required = canonicalRequirement phase identifier; wholeBootstrap = identifier == L.LtdSrc008 && required /= L.legacyBootstrapSourceRequirement; oracleName = if wholeBootstrap || identifier `elem` [L.LtdSrc000,L.LtdSrc001,L.LtdSrc005,L.LtdSrc006,L.LtdName001,L.LtdMeta001] then "oracle-layout" else if identifier `elem` [L.LtdBoot001,L.LtdSrc007,L.LtdSrc009] then "oracle-toolchain" else "oracle-runner"
  behavioral = wholeBootstrap || identifier `elem` [L.LtdVal001,L.LtdVal002,L.LtdVal003,L.LtdVal004,L.LtdVal006,L.LtdBoot001,L.LtdSrc000,L.LtdSrc001,L.LtdSrc005,L.LtdSrc006,L.LtdName001,L.LtdMeta001,L.LtdSrc007,L.LtdSrc009]
  manifest = either (const []) requiredSuiteRows (mkGateSpec SeedGate phaseZeroSpecInput)
  (stem, makeCases) = case identifier of L.LtdSrc000 -> ("source-graph", behavioralCases); L.LtdMeta001 -> ("ignore-context", behavioralCases); L.LtdName001 -> ("runtime-identity", behavioralCases); L.LtdSrc001 -> ("tool-source", behavioralCases); L.LtdSrc005 -> ("pulumi-source", behavioralCases); L.LtdSrc006 -> ("test-source", behavioralCases); L.LtdSrc009 -> ("vendor-source", behavioralCases); L.LtdSrc007 -> ("probe-source", behavioralCases); L.LtdBoot001 -> ("admission", behavioralCases); L.LtdVal006 -> ("fresh", behavioralCases); L.LtdVal001 -> ("authority", behavioralCases); L.LtdKrn001 -> ("kernel", kernelCases); L.LtdKrn003 -> ("solver", solverCases); L.LtdSrc008 -> if wholeBootstrap then ("bootstrap-source", behavioralCases) else ("bootstrap", bootstrapCases); L.LtdVal002 -> ("correspondence", behavioralCases); L.LtdVal003 -> ("custody", behavioralCases); L.LtdVal004 -> ("status", behavioralCases); _ -> ("mutation", mutationCases)
  keys = map L.renderLegacyCaseKey (NE.toList (L.legacyRequirementCases required))
  behavioralCases cap _ = Right (cap, [(key,control,[]) | key <- keys, control <- ["positive","negative"]])
  acquire = do
    unless ((if required == L.legacyBootstrapSourceRequirement then Just P.phaseDomainLowerOrdinal else L.legacyOwnerOrdinal identifier) == Just phase) (fail "LegacyQualificationWrongOwner")
    unless (not (any (\file -> any (`T.isPrefixOf` T.pack file) [".build/", ".data/", ".test_data/"]) (capturedSourceFiles source))) (fail "LegacyQualificationCandidateStatePresent")
    cap <- archivedKernelCap repository >>= either (fail . T.unpack) (pure . maybe kernelBudget (min kernelBudget))
    files <- if behavioral then pure [] else either (fail . T.unpack) pure (queryInputs required source)
    unless (behavioral || query mutationFile required (Just cap) files == Right []) (fail "LegacyQueryNotZero")
    cases@(_, inputs) <- either (fail . T.unpack) pure (makeCases cap files)
    unless (sort (nub [key | (key, _, _) <- inputs]) == sort keys && length inputs == 2 * length keys) (fail "LegacyQualificationCasesMismatch")
    tools <- Tools.selectToolchain repository (Tools.ToolchainPaths Nothing compiler cabal) >>= either (fail . show) pure
    work <- makeAbsolute destination
    present <- doesPathExist work
    unless (not present) (fail "LegacyQualificationRunNotFresh")
    createDirectoryIfMissing True (takeDirectory work)
    createDirectory work
    let tree = work </> "source"; input = work </> (stem <> "-inputs.data")
        native = observeNativeCabal tree (Tools.acquisitionPackageTool tools) (Just (Tools.acquisitionCompiler tools))
    (do
      _ <- materializeSource source tree >>= either (fail . T.unpack) pure
      graph <- loadPackageGraph tree >>= either (fail . show) pure
      problems <- verifyOracle tree graph (OracleExecutable oracleName)
      unless (null problems) (fail (show problems))
      mapM_ (\(file, body) -> TIO.writeFile file body) [(input, T.pack (show cases)), (work </> "scope.data", scope required), (work </> "tools.data", T.pack (show tools))]
      (builds, images) <- nativeImages (\args -> native (args <> ["exe:amoebius" | identifier == L.LtdSrc000, take 1 args == ["build"]])) [if oracleName == "oracle-layout" then "test:layout-suite" else if identifier `elem` [L.LtdBoot001,L.LtdSrc007,L.LtdSrc009] then "test:toolchain-suite" else if behavioral then "test:runner-suite" else "exe:amoebius-validate", "test:" <> T.unpack oracleName]
      (subjectImage, oracleImage) <- case images of [a, b] -> pure (a, b); _ -> fail "LegacyQualificationBinaryAbsent"
      before <- readImages tree images
      subject <- observe tree subjectImage (if behavioral then ["--" <> T.unpack (L.renderLegacyAnalyzerKey (L.legacyRequirementAnalyzer required)),work] else [stem <> "-observe", "--input", input])
      TIO.writeFile (work </> (stem <> "-output.data")) (runStdout subject)
      runtimeRuns <- if identifier == L.LtdKrn003 then runSolverReintroductions source (work </> "solver-runtime") (Tools.acquisitionPackageTool tools) (Tools.acquisitionCompiler tools) else pure []
      oracle <- observe tree oracleImage (if behavioral then ["--" <> T.unpack (L.renderLegacyAnalyzerKey (L.legacyRequirementAnalyzer required)),work] else ["--legacy-" <> stem, work, tree])
      after <- readImages tree images
      unchanged <- verifySourceCopy source tree
      let rows = map (T.splitOn "\t") (T.lines (runStdout oracle))
          names = [T.pack stem <> ".discovery"] <> [T.pack stem <> "." <> key <> "." <> control | key <- keys, control <- if behavioral then ["positive","negative"] else ["positive", "negative", "delta"]] <> [T.pack stem <> "." <> field | behavioral, field <- if identifier == L.LtdSrc009 then ["control.fork","control.cleanup"] else if identifier `elem` [L.LtdSrc000,L.LtdSrc001,L.LtdSrc005,L.LtdSrc006,L.LtdName001,L.LtdMeta001,L.LtdSrc007,L.LtdSrc008] then ["control.inventory","control.cleanup"] else if identifier == L.LtdBoot001 then ["control.cleanup"] else if identifier == L.LtdVal006 then ["control." <> key | key <- ["stale-sentinel","ignored-captured","source-changed","replayed-copy","authored-restored","ambient-entry","ambient-created","cleanup","collection-unknown","collection-phase","collection-source"]] else if identifier == L.LtdVal001 then ["control." <> key | key <- ["subject-exit","subject-token","constant-probe","missing-probe","cleanup"]] <> ["manifest.seed-names","manifest.seed-positive"] <> ["manifest.omitted." <> key | key <- manifest] else if identifier == L.LtdVal004 then [part <> "." <> key | part <- ["accept","preview","unchanged"], key <- keys] <> ["control.cleanup"] else if identifier == L.LtdVal002 then ["control.render-collision","snapshot.contracts","snapshot.selected"] <> [part <> "." <> key | part <- ["entry","entry-root"], key <- ["phase-role-swap","byte-copy-equivalence"]] else ["binding.verifier-positive","binding.verifier-negative"] <> ["control." <> key | key <- ["closure-source","closure-restored","outside-closure","unknown-closure","closure-sentinel","capability-binding","governance-binding","specification-binding","phase-binding"]] <> ["dependency." <> key | key <- ["suite","oracle","custody-suite","entry","build-tool","seed-driver","metadata","bootstrap","documentation","status-projection","cleanup"]]]
            <> (["solver-reintroduction.discovery", "solver-reintroduction.baseline"] <> ["solver-reintroduction." <> key <> "." <> field | key <- "clean" : keys, field <- ["runtime", "api", "execution", "source", "images", "teardown"]] >>= \key -> [key | identifier == L.LtdKrn003])
          events = builds <> [subject] <> runtimeRuns <> [oracle]
      mapM_ (\(file, body) -> TIO.writeFile (work </> file) body) [("processes.data", T.pack (show events)), ("identities.data", T.pack (show (L.renderLegacyId identifier, capturedSourceDigest source, cap, keys, zip3 images (map sha256Bytes before) (map sha256Bytes after)))), ("oracle-ledger.tsv", runStdout oracle), ("checks.data", T.pack (show (unchanged, runExit subject, T.null (runStderr subject), runExit oracle, before == after, sort names, sort [name | name : "green" : _ <- rows], length rows)))]
      unless (runExit subject == ExitSuccess && T.null (runStderr subject) && runExit oracle == ExitSuccess && before == after && unchanged == Right ()
        && sort [name | name : "green" : _ <- rows] == sort names && length rows == length names) (fail "LegacyQualificationRefused")
      pure (LegacyQualified identifier (L.legacyRequirementScope required) (capturedSourceDigest source) cap keys (sha256Hex (T.pack (show (scope required, map sha256Bytes before, cases, runStdout subject, runStdout oracle, map observedDigest runtimeRuns, Tools.renderAcquisition tools)))) events tools (zip3 images (map sha256Bytes before) (map sha256Bytes after))))
      `finally` removePathForcibly tree
qualifiedLegacyReports :: Int -> CapturedSource -> [LegacyQualification] -> [LegacyReport]
qualifiedLegacyReports phase source = let observed = observeLegacy phase source Nothing in \evidence -> [if reportedIdentity report `elem` [L.LtdVal001,L.LtdVal002,L.LtdVal003,L.LtdVal004,L.LtdVal006,L.LtdBoot001,L.LtdSrc000,L.LtdSrc008,L.LtdSrc001,L.LtdSrc005,L.LtdSrc006,L.LtdName001,L.LtdMeta001,L.LtdSrc007,L.LtdSrc009] && any (\(LegacyQualified identifier scoped digest _ _ _ _ _ _) -> identifier == reportedIdentity report && scope (canonicalRequirement phase identifier) == reportedScope report && scoped == L.legacyRequirementScope (canonicalRequirement phase identifier) && digest == capturedSourceDigest source) evidence then report {reportedObservation = AnalyzerFindings []} else report | report <- observed]
auditQualifiedLegacyReports :: Int -> CapturedSource -> [LegacyQualification] -> [LegacyReport] -> [Text]
auditQualifiedLegacyReports phase source = audit
 where
  expected = qualifiedLegacyReports phase source
  audit evidence reports = let expectedReports = expected evidence in
    ["LegacyQualificationSourceMismatch" | any (\(LegacyQualified _ _ digest _ _ _ _ _ _) -> digest /= capturedSourceDigest source) evidence]
    <> ["LegacyQualificationDuplicate" | let keys = [(identifier, scoped) | LegacyQualified identifier scoped _ _ _ _ _ _ _ <- evidence], length keys /= length (nub keys)]
    <> ["LegacyQualificationUnexpected" | any (\(LegacyQualified identifier scoped _ _ _ _ _ _ _) -> (identifier, L.renderLegacyScope scoped) `notElem` [(L.legacyRequirementId r, scope r) | r <- legacyRequirementsAt phase]) evidence]
    <> ["LegacyObservationMismatch" | any (`notElem` expectedReports) reports]
    <> auditReports [(identifier, L.renderLegacyScope scoped) | LegacyQualified identifier scoped digest _ _ _ _ _ _ <- evidence, digest == capturedSourceDigest source] phase source reports
data LegacyCollection = LegacyCollected Int Text [LegacyQualification] [LegacyReport] [Text] deriving (Eq, Show)
legacyQualificationSupported :: L.LegacyRequirement -> Bool
legacyQualificationSupported requirement = requirement == L.legacyBootstrapSourceRequirement || L.legacyRequirementId requirement `elem` [L.LtdVal001,L.LtdVal002,L.LtdVal003,L.LtdVal004,L.LtdVal006,L.LtdBoot001,L.LtdSrc000,L.LtdSrc008,L.LtdSrc001,L.LtdSrc005,L.LtdSrc006,L.LtdName001,L.LtdMeta001,L.LtdSrc007,L.LtdSrc009,L.LtdKrn001,L.LtdKrn002,L.LtdKrn003]
collectLegacy :: FilePath -> FilePath -> Int -> Maybe FilePath -> Maybe FilePath -> CapturedSource -> IO LegacyCollection
collectLegacy repository destination phase cabal compiler source = do
  results <- forM [requirement | requirement <- legacyRequirementsAt phase, (if requirement == L.legacyBootstrapSourceRequirement then Just P.phaseDomainLowerOrdinal else L.legacyOwnerOrdinal (L.legacyRequirementId requirement)) == Just phase] $ \requirement -> do
    result <- qualifyLegacy (L.legacyRequirementId requirement) repository (destination </> T.unpack (L.renderLegacyId (L.legacyRequirementId requirement) <> "-" <> scope requirement)) phase cabal compiler source
    pure (requirement,result)
  let qualifications = [value | (_,Right value) <- results]
      reports = qualifiedLegacyReports phase source qualifications
  pure (LegacyCollected phase (capturedSourceDigest source) qualifications reports [L.renderLegacyId (L.legacyRequirementId requirement) <> ":" <> scope requirement <> ":" <> problem | (requirement,Left problem) <- results])
auditLegacyCollection :: Int -> CapturedSource -> LegacyCollection -> [Text]
auditLegacyCollection phase source (LegacyCollected ordinal digest qualifications reports errors) = ["LegacyCollectionContextMismatch" | ordinal /= phase || digest /= capturedSourceDigest source] <> errors <> auditQualifiedLegacyReports phase source qualifications reports
inheritLegacyCollection :: CapturedSource -> LegacyCollection -> LegacyCollection -> LegacyCollection
inheritLegacyCollection source prior@(LegacyCollected predecessor bound older _ _) (LegacyCollected phase digest current _ errors) =
  let admitted = [(L.legacyRequirementId r, L.legacyRequirementScope r) | r <- legacyRequirementsAt phase, L.legacyRequirementRetired r, maybe False (< phase) (L.legacyOwnerOrdinal (L.legacyRequirementId r))]
      combined = current <> [q | q@(LegacyQualified identifier scoped _ _ _ _ _ _ _) <- older, (identifier, scoped) `elem` admitted]
  in LegacyCollected phase digest combined (qualifiedLegacyReports phase source combined) (errors <> auditLegacyCollection predecessor source prior <> ["LegacyInheritanceContextMismatch" | P.predecessorOrdinal phase /= Just predecessor || bound /= digest || digest /= capturedSourceDigest source])
legacyCollectionRuns :: LegacyCollection -> [ObservedRun]
legacyCollectionRuns (LegacyCollected _ _ qualifications _ _) = concat [runs | LegacyQualified _ _ _ _ _ _ runs _ _ <- qualifications]
legacyCollectionEvidence :: LegacyCollection -> [(Text,Text)]
legacyCollectionEvidence (LegacyCollected phase digest qualifications reports errors) = [("legacy.phase",T.pack (show phase)),("legacy.source",digest),("legacy.report-count",T.pack (show (length reports))),("legacy.qualification-count",T.pack (show (length qualifications))),("legacy.reports",renderLegacyReports reports)] <> [("legacy.qualification." <> L.renderLegacyId identifier <> "." <> L.renderLegacyScope scoped,T.pack (show (source,cap,keys,proof,runs,Tools.renderAcquisition tools,images))) | LegacyQualified identifier scoped source cap keys proof runs tools images <- qualifications] <> [("legacy.refusal",problem) | problem <- errors]

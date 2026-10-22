{-# LANGUAGE OverloadedStrings #-}
-- | Derive source-bound subject, closure and oracle contracts (gate_runner_doctrine.md section 3).
module Amoebius.Validation.Runner.Spec
  ( PackageGraph (..), SpecProblem (..), VerifiedSpec (..), executableClosure, libraryClosure, internalDependencies, loadPackageGraph
  , moduleSourcePath, parsePackageGraph, renderSpecProblem, verifySpec, verifySpecAgainst, verifyOracle, sourceTokens
  , sourceTree, sourceDirectives, compiledBlocks, resolveSpec, bindPhaseSpec, roleFor, requiredSuiteRows ) where
import Amoebius.Validation.GateSpec
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Runner.Hygiene (haskellFilesUnder, parseSourceInventory, readSourceBytes, readSourceText, sourceAttempt)
import Control.Monad (forM, foldM, filterM, unless)
import Data.ByteString qualified as ByteString
import Data.Data (Data, cast, gmapQ)
import Data.List (isPrefixOf, nub, sort)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Compat.NonEmptySet qualified as NonEmptySet
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.Compiler (CompilerFlavor (GHC, GHCJS))
import Distribution.PackageDescription (BuildInfo (..), Executable (..), GenericPackageDescription (..), Library (..), LibraryName (..), PackageFlag (..), TestSuite (..), TestSuiteInterface (..), BuildType (Simple), buildType, setupBuildInfo)
import Distribution.Types.BuildInfo (allExtensions, allLanguages, hcOptions, hcProfOptions, hcSharedOptions, hcProfSharedOptions, hcStaticOptions)
import Language.Haskell.Extension qualified as Cabal
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Parsec.Warning (PWarning (..), PWarnType (PWTDeprecatedField))
import Distribution.Parsec.Position (showPos)
import Distribution.Pretty (prettyShow)
import Distribution.Types.CondTree (CondBranch (..), CondTree (..))
import Distribution.Types.Dependency (Dependency (..))
import Distribution.Types.PackageName (unPackageName)
import Distribution.Types.UnqualComponentName (unUnqualComponentName)
import Distribution.Utils.Path (getSymbolicPath)
import GHC.Data.EnumSet qualified as EnumSet
import GHC.Data.FastString (mkFastString)
import GHC.Data.StringBuffer (stringToStringBuffer)
import GHC.Driver.Session (xFlags, flagSpecFlag, flagSpecName, Language (..), languageExtensions, impliedXFlags)
import GHC.Hs (GhcPs, HsExpr (..), HsModule, hsmodName, hsmodImports, ideclName)
import GHC.Hs.Instances ()
import GHC.Parser (parseModule)
import GHC.Parser.Lexer (ParseResult (..), Token (..), lexTokenStream, mkParserOpts, ParserOpts, initParserState, unP)
import GHC.Types.SrcLoc (GenLocated (..), SrcSpan (..), Located, mkRealSrcLoc, srcSpanStartLine, srcSpanStartCol, unLoc)
import GHC.Unit.Module (moduleNameString)
import GHC.Utils.Error (emptyDiagOpts)
import System.Directory (doesDirectoryExist, doesFileExist, findFile)
import System.FilePath ((</>), (<.>), dropExtension, takeExtension, makeRelative, normalise, splitDirectories)
requiredSuiteRows :: GateSpec -> [Text]
requiredSuiteRows spec | Just _ <- gateSeed spec = ["phase.cardinality","phase.table","phase.resource-required","phase.paths","gap","integrity.problems","legacy.cardinality","legacy.owners","decision.ids","frozen.paths","frozen.digests","frozen.decisions","frozen.amendments","frozen.amendment-digests","evidence-path.cardinality","evidence-path.results","evidence-parser.bundle-only","evidence-parser.void-only","evidence-parser.void-fields","doc.findings","doc.governed-count-observed","negative.discovery"] <> ["negative." <> name | name <- ["broken-link","stale-backlink","missing-status-line","non-frontier-status-vector","unauthorised-frozen-edit","uncited-module-claim","gate-spec-block-mismatch","decision-log-out-of-order","receipt-line-unexpected"]] <> ["role." <> PhaseIdentity.renderPhaseRole role | role <- PhaseIdentity.allPhaseRoles] <> [kind <> "." <> Text.pack (show ordinal) | (kind,Just ordinal) <- [("predecessor",Just PhaseIdentity.phaseDomainLowerOrdinal),("predecessor",PhaseIdentity.successorOrdinal PhaseIdentity.phaseDomainLowerOrdinal),("predecessor",PhaseIdentity.roleOrdinal PhaseIdentity.BootstrapHandoff),("successor",PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier),("successor",Just PhaseIdentity.phaseDomainUpperOrdinal)]]
requiredSuiteRows spec = [caseName item | item <- gateCases spec, "case:" `Text.isPrefixOf` caseName item]
data PackageGraph = PackageGraph
  { graphLibraries :: Map Text (Set Text, Set Text, [FilePath]) -- stanza -> (modules, internal library deps, source dirs)
  , graphExecutables :: Map Text BuildInfo -- retain source directories as well as dependencies
  , graphTestSuites :: Map Text (BuildInfo, [TestSuiteInterface]) -- retain every declared interface
  , graphOraclePolicy :: [Text]
  , graphFlags :: [Text] } deriving (Eq, Show)
data SpecProblem
  = PackageDescriptionUnparsable Text | PackageDescriptionUnscanned [Text]
  | SubjectNotInPackage ProductionModule
  | SubjectInMultipleStanzas ProductionModule [Text]
  | SubjectOutsideClosure ProductionModule Text
  | ProductExecutableMissing | SuiteStanzaMissing CabalTarget | OracleStanzaMissing OracleExecutable
  | OracleDependsOnPackage OracleExecutable | OracleSourceDirectoryMissing OracleExecutable FilePath
  | OracleConditionalCompilation FilePath | OracleTemplateHaskell FilePath | OracleForeignImport FilePath
  | OracleSourceUnscanned FilePath | OracleBuildBoundary OracleExecutable Text deriving (Eq, Ord, Show)
renderSpecProblem :: SpecProblem -> Text
renderSpecProblem problem = case problem of
  PackageDescriptionUnparsable detail -> "PACKAGE-UNPARSABLE: " <> detail
  PackageDescriptionUnscanned warnings -> "PACKAGE-UNSCANNED: " <> Text.intercalate "," warnings
  SubjectNotInPackage (ProductionModule name) -> "SUBJECT-NOT-IN-PACKAGE: " <> name
  SubjectInMultipleStanzas (ProductionModule name) stanzas -> "SUBJECT-AMBIGUOUS: " <> name <> " in " <> Text.intercalate "," stanzas
  SubjectOutsideClosure (ProductionModule name) stanza -> "SUBJECT-NOT-SHIPPED: " <> name <> " (" <> stanza <> ")"
  ProductExecutableMissing -> "PRODUCT-EXECUTABLE-MISSING"
  SuiteStanzaMissing (CabalTarget name) -> "SUITE-MISSING: " <> name
  OracleStanzaMissing (OracleExecutable name) -> "ORACLE-MISSING: " <> name
  OracleDependsOnPackage (OracleExecutable name) -> "ORACLE-DEPENDS-ON-PRODUCT: " <> name
  OracleSourceDirectoryMissing (OracleExecutable name) directory -> "ORACLE-SOURCE-MISSING: " <> name <> " " <> Text.pack directory
  OracleConditionalCompilation path -> "ORACLE-CPP: " <> Text.pack path
  OracleTemplateHaskell path -> "ORACLE-TEMPLATE-HASKELL: " <> Text.pack path
  OracleForeignImport path -> "ORACLE-FOREIGN-IMPORT: " <> Text.pack path
  OracleSourceUnscanned file -> "ORACLE-SOURCE-UNSCANNED: " <> Text.pack file
  OracleBuildBoundary (OracleExecutable name) detail -> "ORACLE-BUILD-BOUNDARY: " <> name <> " " <> detail
data VerifiedSpec = VerifiedSpec
  { verifiedSpec :: GateSpec, verifiedStanzaOf :: Map ProductionModule Text
  , verifiedClosure :: Set Text, verifiedOracleDirectories :: [FilePath] } deriving (Eq, Show)
loadPackageGraph :: FilePath -> IO (Either SpecProblem PackageGraph)
loadPackageGraph root = either (Left . PackageDescriptionUnparsable) parsePackageGraph <$> sourceAttempt (readSourceBytes (root </> "amoebius.cabal"))
compiledBlocks :: [(Text, GateSpecInput)] -> Either [Text] [(Int, Text)]
compiledBlocks proposals
  | null proposals = Left ["SPEC-REGISTRY-DIVERGED"]
  | otherwise = forM (map fst proposals) $ \capability -> maybe (Left ["SPEC-PHASE-ABSENT: " <> capability]) (\ordinal -> (\(_, spec) -> (ordinal, renderGateSpec spec)) <$> resolveSpec proposals ordinal) (PhaseIdentity.lookupCapabilityOrdinal capability)
resolveSpec :: [(Text, GateSpecInput)] -> Int -> Either [Text] (PhaseIdentity.PhaseIdentity, GateSpec)
resolveSpec proposals ordinal = do
  unless (length proposals == length (nub (map fst proposals)) && null PhaseIdentity.phaseIdentityIntegrityProblems) (Left ["SPEC-REGISTRY-DIVERGED"])
  row <- maybe (Left ["PHASE-ABSENT: " <> Text.pack (show ordinal)]) Right (PhaseIdentity.lookupPhaseIdentity ordinal)
  let capability = PhaseIdentity.phaseIdentityCapability row
  input <- maybe (Left ["SPEC-ABSENT: no gate specification is registered for " <> capability]) Right (lookup capability proposals)
  unless (inputCapability input == capability) (Left ["SPEC-CAPABILITY-MISMATCH: " <> capability])
  spec <- either (Left . map renderSpecRefusal) Right (mkGateSpec (roleFor ordinal) input)
  pure (row, spec)
bindPhaseSpec :: [(Text, GateSpecInput)] -> Int -> GateSpec -> Either [Text] ()
bindPhaseSpec proposals ordinal supplied = do
  (_, expected) <- resolveSpec proposals ordinal
  unless (gateRole supplied == gateRole expected) (Left ["SPEC-ROLE-MISMATCH: " <> gateCapability expected])
  unless (supplied == expected) (Left ["SPEC-CURRENT-MISMATCH: " <> gateCapability expected])
roleFor :: Int -> GateRole
roleFor ordinal
  | ordinal == PhaseIdentity.phaseDomainLowerOrdinal = SeedGate
  | Just ordinal == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier = BarrierGate
  | maybe False (ordinal >=) (PhaseIdentity.roleOrdinal PhaseIdentity.FirstHardware) = HardwareGate
  | otherwise = OrdinaryGate
parsePackageGraph :: ByteString.ByteString -> Either SpecProblem PackageGraph
parsePackageGraph bytes = case runParseResult (parseGenericPackageDescription bytes) of
  (_, Left (_, problems)) -> Left (PackageDescriptionUnparsable (Text.pack (show (NonEmpty.toList problems))))
  (warnings, Right description) -> case sort [Text.pack (show kind <> "@" <> showPos position) | PWarning kind position _ <- warnings, kind /= PWTDeprecatedField] of
    [] -> Right (reduce description)
    refused -> Left (PackageDescriptionUnscanned refused)
reduce :: GenericPackageDescription -> PackageGraph
reduce description = PackageGraph
    { graphFlags = map (Text.pack . prettyShow . flagName) (genPackageFlags description)
    , graphLibraries = named libraryEntry (condSubLibraries description)
        <> Map.fromList [("amoebius", libraryEntry (flatten tree)) | Just tree <- [condLibrary description]]
    , graphExecutables = named buildInfo (condExecutables description)
    , graphTestSuites = Map.fromList [(Text.pack (unUnqualComponentName name), (testBuildInfo (flatten tree), nub [testInterface suite | suite <- nodes tree, testInterface suite /= mempty])) | (name, tree) <- condTestSuites description]
    , graphOraclePolicy = let package_ = packageDescription description in ["build-type:" <> Text.pack (prettyShow (buildType package_)) | buildType package_ /= Simple] <> ["custom-setup" | Just _ <- [setupBuildInfo package_]]
    }
 where
  named project entries = Map.fromList [(Text.pack (unUnqualComponentName name), project (flatten tree)) | (name, tree) <- entries]
  libraryEntry library = (Set.fromList (map (Text.pack . prettyShow) (exposedModules library <> otherModules (libBuildInfo library))),
    internalDependencies (libBuildInfo library), map getSymbolicPath (hsSourceDirs (libBuildInfo library)))
internalDependencies :: BuildInfo -> Set Text
internalDependencies info = Set.fromList
  [libraryStanza name | Dependency package _ libraries <- targetBuildDepends info,
    unPackageName package == "amoebius", name <- NonEmptySet.toList libraries]
 where
  libraryStanza LMainLibName = "amoebius"
  libraryStanza (LSubLibName sub) = Text.pack (unUnqualComponentName sub)
flatten :: Monoid a => CondTree v c a -> a
flatten = mconcat . nodes
nodes :: CondTree v c a -> [a]
nodes tree = condTreeData tree : concat [nodes (condBranchIfTrue branch) <> maybe [] nodes (condBranchIfFalse branch) | branch <- condTreeComponents tree]
executableClosure :: PackageGraph -> Text -> Maybe (Set Text)
executableClosure graph executable = libraryClosure graph . Set.toList . internalDependencies <$> Map.lookup executable (graphExecutables graph)
libraryClosure :: PackageGraph -> [Text] -> Set Text
libraryClosure graph = close Set.empty
 where
  close seen [] = seen
  close seen (stanza : rest)
    | Set.member stanza seen = close seen rest
    | otherwise = let deps = maybe Set.empty (\(_, internal, _) -> internal) (Map.lookup stanza (graphLibraries graph))
        in close (Set.insert stanza seen) (Set.toList deps <> rest)
verifySpec :: FilePath -> GateSpec -> IO (Either [SpecProblem] VerifiedSpec)
verifySpec root spec = do
  loaded <- loadPackageGraph root
  either (pure . Left . pure) (\graph -> verifySpecAgainst root graph spec) loaded
-- | Verify against an already parsed graph; the oracle source scan reads the
-- oracle directories beneath the root.
verifySpecAgainst :: FilePath -> PackageGraph -> GateSpec -> IO (Either [SpecProblem] VerifiedSpec)
verifySpecAgainst root graph spec = do
  oracleProblems <- verifyOracle root graph oracle
  let problems = subjectProblems <> suiteProblems <> oracleProblems
  pure $ case (problems, closure) of
    ([], Just shipped) -> Right VerifiedSpec
      { verifiedSpec = spec, verifiedStanzaOf = Map.fromList [(subject, stanza) | subject <- gateSubjects spec, [stanza] <- [stanzasOf subject]]
      , verifiedClosure = shipped, verifiedOracleDirectories = oracleDirectories }
    _ -> Left (nub problems)
 where
  closure = executableClosure graph (if gateRole spec == SeedGate then "amoebius-validate" else "amoebius")
  stanzasOf (ProductionModule name) = sort [stanza | (stanza, (modules, _, _)) <- Map.toList (graphLibraries graph), Set.member name modules]
  subjectProblems = [ProductExecutableMissing | closure == Nothing] <> concatMap subjectProblem (gateSubjects spec)
  subjectProblem subject = case stanzasOf subject of
    [] -> [SubjectNotInPackage subject]
    [stanza]
      | maybe False (Set.member stanza) closure -> []
      | otherwise -> [SubjectOutsideClosure subject stanza]
    many -> [SubjectInMultipleStanzas subject many]
  suiteProblems = [SuiteStanzaMissing (gateSuite spec) | Map.notMember (cabalTargetName (gateSuite spec)) (graphTestSuites graph)]
  oracle = gateOracle spec
  oracleEntry = Map.lookup (oracleExecutableName oracle) (graphTestSuites graph)
  oracleDirectories = maybe [] (map getSymbolicPath . hsSourceDirs . fst) oracleEntry
verifyOracle :: FilePath -> PackageGraph -> OracleExecutable -> IO [SpecProblem]
verifyOracle root graph oracle = case Map.lookup (oracleExecutableName oracle) (graphTestSuites graph) of
  Nothing -> pure [OracleStanzaMissing oracle]
  Just (info, interfaces) -> do
    let dirs = map getSymbolicPath (hsSourceDirs info); boundary = OracleBuildBoundary oracle
        dirsOf peer = case map getSymbolicPath (hsSourceDirs peer) of [] -> ["."]; paths -> paths
        area = [(name, peer, peerInterfaces) | (name, (peer, peerInterfaces)) <- Map.toList (graphTestSuites graph), name == oracleExecutableName oracle
          || Set.fromList (dirsOf peer) == Set.fromList dirs && Set.null (internalDependencies peer) && null (oracleBuildHazards peer)]
        others = [("library:" <> name, paths) | (name, (_, _, paths)) <- Map.toList (graphLibraries graph)]
          <> [(tag <> name, dirsOf peer) | (tag, peers) <- [("executable:", Map.toList (graphExecutables graph)), ("test:", [(name, peer) | (name, (peer, _)) <- Map.toList (graphTestSuites graph), name `notElem` [key | (key, _, _) <- area]])], (name, peer) <- peers]
        overlaps a b = let parts = map (Text.toCaseFold . Text.pack) . filter (/= ".") . splitDirectories . normalise in parts a `isPrefixOf` parts b || parts b `isPrefixOf` parts a
        valid path = parseSourceInventory (Text.pack path <> "\0") == Right [path]
        invalid = ["source-dir:" <> Text.pack dir | dir <- dirs, not (valid dir)]
        owned = Set.unions [names | (names, _, _) <- Map.elems (graphLibraries graph)]
        entries = nub [getSymbolicPath path | (_, _, declared) <- area, TestSuiteExeV10 _ path <- declared]
        modules = nub [(Text.pack (prettyShow name), Text.unpack (Text.replace "." "/" (Text.pack (prettyShow name))) <> ".hs") | (_, peer, _) <- area, name <- otherModules peer]
        sources = nub [(dir </> path, name) | dir <- dirs, (name, path) <- [("Main", path) | path <- entries] <> modules]
        inspect file contents = [boundary ("source-unlisted:" <> Text.pack file) | file `notElem` map fst sources]
          <> if not (null hygiene) then hygiene else case sourceTree (root </> file) contents of
              Left _ -> [OracleSourceUnscanned (root </> file)]
              Right tree -> [boundary ("source-import:" <> Text.pack file <> ":" <> name) | declaration <- hsmodImports tree,
                let name = Text.pack (moduleNameString (unLoc (ideclName (unLoc declaration)))), Set.member name owned]
                <> [boundary ("source-module:" <> Text.pack file <> ":" <> name) | declared <- maybe [] pure (hsmodName tree),
                  let name = Text.pack (moduleNameString (unLoc declared)), Set.member name owned]
                <> [boundary ("source-name:" <> Text.pack file <> ":" <> name) | (path, expected) <- sources, path == file,
                  let name = maybe "Main" (Text.pack . moduleNameString . unLoc) (hsmodName tree), name /= expected]
          where hygiene = sourceHygiene (root </> file) contents
    if not (null invalid) then pure (map boundary invalid) else do
      scanned <- forM dirs $ \dir -> do
        present <- doesDirectoryExist (root </> dir)
        if present then either (const (Left (OracleSourceUnscanned (root </> dir)))) Right <$> sourceAttempt (haskellFilesUnder root dir) else pure (Left (OracleSourceDirectoryMissing oracle dir))
      let files = nub (concat [values | Right values <- scanned])
          found path = valid path && takeExtension path == ".hs" && any (\dir -> dir </> path `elem` files) dirs
          alternatives = nub [(dir </> dropExtension path) <.> suffix | dir <- dirs, path <- entries <> map snd modules, valid path, suffix <- ["lhs", "hsc", "chs", "x", "y", "ly", "cpphs", "hspp", "hs-boot", "lhs-boot"]]
          unsupported = ["interface:missing" | null interfaces] <> ["interface:" <> (case interface of TestSuiteLibV09 _ _ -> "detailed-0.9"; TestSuiteUnsupported kind -> Text.pack (prettyShow kind); TestSuiteExeV10 {} -> "exitcode-stdio-1.0") | interface <- interfaces, case interface of TestSuiteExeV10 {} -> False; _ -> True]
      preprocessed <- filterM (doesFileExist . (root </>)) alternatives
      syntax <- concat <$> mapM (\file -> either (const [OracleSourceUnscanned (root </> file)]) (inspect file) <$> sourceAttempt (readSourceText (root </> file))) files
      pure ([OracleDependsOnPackage oracle | not (Set.null (internalDependencies info))] <> [problem | Left problem <- scanned] <> syntax
        <> map boundary (graphOraclePolicy graph <> oracleBuildHazards info <> unsupported <> ["entry:" <> Text.pack path | path <- entries, not (found path)]
          <> ["source-shared:" <> Text.pack dir <> ":" <> name | dir <- dirs, (name, paths) <- others, any (overlaps dir) (if null paths then ["."] else paths)]
          <> ["module:" <> name | (name, path) <- modules, not (found path)] <> ["source:" <> Text.pack path | path <- preprocessed]
          <> ["source-ambiguous:" <> Text.pack path | path <- nub (entries <> map snd modules), length [() | dir <- nub dirs, dir </> path `elem` files] > 1]))
oracleBuildHazards :: BuildInfo -> [Text]
oracleBuildHazards info =
  ["extension:" <> Text.pack (prettyShow extension) | extension <- allExtensions info, case extension of Cabal.UnknownExtension _ -> True; Cabal.EnableExtension flag -> flag `elem` [Cabal.CPP, Cabal.TemplateHaskell, Cabal.TemplateHaskellQuotes, Cabal.QuasiQuotes]; _ -> False]
  <> ["language:" <> Text.pack (prettyShow language) | language <- allLanguages info, prettyShow language `notElem` ["Haskell98", "Haskell2010", "GHC2021", "GHC2024"]]
  <> ["compiler-option:" <> Text.pack option | select <- [hcOptions, hcProfOptions, hcSharedOptions, hcProfSharedOptions, hcStaticOptions], flavor <- [GHC, GHCJS], option <- select flavor info, not (safe option)]
  <> [label | (label, present) <-
    [("buildable:false", not (buildable info)), ("build-tools", not (null (buildTools info))), ("build-tool-depends", not (null (buildToolDepends info)))
    ,("pkgconfig-depends", not (null (pkgconfigDepends info)))
    ,("cpp-options", not (null (cppOptions info))), ("asm-options", not (null (asmOptions info))), ("cmm-options", not (null (cmmOptions info)))
    ,("cc-options", not (null (ccOptions info))), ("cxx-options", not (null (cxxOptions info))), ("jspp-options", not (null (jsppOptions info))), ("ld-options", not (null (ldOptions info))), ("hsc2hs-options", not (null (hsc2hsOptions info)))
    ,("asm-sources", not (null (asmSources info))), ("cmm-sources", not (null (cmmSources info))), ("c-sources", not (null (cSources info))), ("cxx-sources", not (null (cxxSources info))), ("js-sources", not (null (jsSources info)))
    ,("frameworks", not (null (frameworks info))), ("extra-framework-dirs", not (null (extraFrameworkDirs info))), ("extra-libraries", not (null (extraLibs info))), ("extra-libraries-static", not (null (extraLibsStatic info)))
    ,("extra-ghci-libraries", not (null (extraGHCiLibs info))), ("extra-bundled-libraries", not (null (extraBundledLibs info))), ("extra-library-flavours", not (null (extraLibFlavours info))), ("extra-dynamic-library-flavours", not (null (extraDynLibFlavours info)))
    ,("extra-lib-dirs", not (null (extraLibDirs info))), ("extra-lib-dirs-static", not (null (extraLibDirsStatic info))), ("include-dirs", not (null (includeDirs info))), ("includes", not (null (includes info)))
    ,("autogen-includes", not (null (autogenIncludes info))), ("install-includes", not (null (installIncludes info))), ("autogen-modules", not (null (autogenModules info))), ("virtual-modules", not (null (virtualModules info))), ("mixins", not (null (mixins info)))], present]
 where safe option = option `elem` ["-w", "-O", "-O0", "-O1", "-O2", "-g", "-threaded", "-rtsopts", "-eventlog"] || "-W" `isPrefixOf` option && all (\c -> c == '-' || c == '=' || c `elem` ['a' .. 'z'] || c `elem` ['0' .. '9']) (drop 2 option)
sourceHygiene :: FilePath -> Text -> [SpecProblem]
sourceHygiene file contents = case sourceTokens file contents of
  Left _ -> [OracleSourceUnscanned file]
  Right located -> let tokens = map unLoc located
                       syntax = filter codeToken tokens
                       directives = sourceDirectives contents
                       pragmas = sourcePragmas tokens
                       extensions = concat [names | "LANGUAGE" : names <- pragmas]
                       quoted = if any (\token -> case token of ITsimpleQuote -> True; _ -> False) tokens
                         then templateTree <$> sourceTree file contents else Right False
    in [OracleConditionalCompilation file | "CPP" `elem` extensions || any (\(L span_ _) -> case span_ of
          RealSrcSpan position _ -> (srcSpanStartLine position, srcSpanStartCol position) `elem` directives; _ -> False) located]
      <> [OracleTemplateHaskell file | any (`elem` extensions) ["TemplateHaskell", "TemplateHaskellQuotes", "QuasiQuotes"] || any template tokens || quoted == Right True]
      <> [OracleForeignImport file | any (\pair -> case pair of (ITforeign, ITimport) -> True; (ITforeign, ITexport) -> True; _ -> False) (zip syntax (drop 1 syntax))]
      <> [OracleSourceUnscanned file | either (const True) (const False) quoted || any (\pragma -> take 1 pragma == ["OPTIONS_GHC"]) pragmas || any (\token -> case token of IToptions_prag {} -> True; ITinclude_prag {} -> True; _ -> False) tokens]
 where
  codeToken token = case token of ITblockComment {} -> False; ITlineComment {} -> False; ITdocComment {} -> False; _ -> True
  template token = case token of ITdollar -> True; ITdollardollar -> True; ITopenExpQuote {} -> True; ITopenPatQuote -> True; ITopenDecQuote -> True; ITopenTypQuote -> True; ITopenTExpQuote {} -> True; ITtyQuote -> True; ITquasiQuote {} -> True; ITqQuasiQuote {} -> True; _ -> False
sourceTokens :: FilePath -> Text -> Either Text [Located Token]
sourceTokens file contents = case lexTokenStream sourceOptions (stringToStringBuffer (Text.unpack contents)) (mkRealSrcLoc (mkFastString file) 1 1) of
  PFailed _ -> Left ("SourceUnscanned:" <> Text.pack file)
  POk _ tokens -> Right tokens
sourceOptions :: ParserOpts
sourceOptions = mkParserOpts (EnumSet.fromList (map flagSpecFlag xFlags)) emptyDiagOpts [] False False False False
sourcePragmas :: [Token] -> [[Text]]
sourcePragmas tokens = [Text.words (Text.replace "," " " body) | ITblockComment comment _ <- tokens,
  Just start <- [Text.stripPrefix "{-#" (Text.pack comment)], Just body <- [Text.stripSuffix "#-}" start]]
sourceTree :: FilePath -> Text -> Either Text (HsModule GhcPs)
sourceTree file contents = do
  tokens <- sourceTokens file contents
  let header = takeWhile (\token -> case unLoc token of ITblockComment {} -> True; ITlineComment {} -> True; ITdocComment {} -> True; _ -> False) tokens
  flags <- foldM select (EnumSet.fromList (languageExtensions (Just GHC2024))) [name | "LANGUAGE" : names <- sourcePragmas (map unLoc header), name <- names]
  let observed = foldr enable flags [flagSpecFlag flag | flag <- xFlags, flagSpecName flag `elem` ["TemplateHaskell", "TemplateHaskellQuotes", "QuasiQuotes"]]
      options = mkParserOpts observed emptyDiagOpts [] False False False False
  case unP parseModule (initParserState options (stringToStringBuffer (Text.unpack contents)) (mkRealSrcLoc (mkFastString file) 1 1)) of
    PFailed _ -> Left ("SourceUnscanned:" <> Text.pack file)
    POk _ tree -> Right (unLoc tree)
 where
  extensions = [(Text.pack (flagSpecName flag), flagSpecFlag flag) | flag <- xFlags]
  select flags name
    | Just edition <- lookup name [("GHC2024", GHC2024), ("GHC2021", GHC2021), ("Haskell2010", Haskell2010), ("Haskell98", Haskell98)] = Right (EnumSet.fromList (languageExtensions (Just edition)))
    | Just flag <- lookup name extensions = Right (enable flag flags)
    | Just rest <- Text.stripPrefix "No" name, Just flag <- lookup rest extensions = Right (EnumSet.delete flag flags)
    | otherwise = Left ("SourceExtensionUnscanned:" <> name)
  enable flag flags = foldl (\enabled (yes, dependency) -> if yes then enable dependency enabled else EnumSet.delete dependency enabled) (EnumSet.insert flag flags)
    [(yes, dependency) | (parent, yes, dependency) <- impliedXFlags, parent == flag]
templateTree :: Data a => a -> Bool
templateTree value = maybe False bracket (cast value :: Maybe (HsExpr GhcPs)) || or (gmapQ templateTree value)
 where bracket expression = case expression of HsTypedBracket {} -> True; HsUntypedBracket {} -> True; _ -> False
sourceDirectives :: Text -> [(Int, Int)]
sourceDirectives contents = [(number, Text.foldl' (\column char -> if char == '\t' then column + 8 - (column - 1) `mod` 8 else column + 1) 1 (Text.takeWhile (`elem` (" \t" :: String)) line)) | (number, line) <- zip [1 ..] (Text.lines contents), "#" `Text.isPrefixOf` Text.stripStart line]
-- | The source file of a module inside a stanza: the first source directory of
-- that stanza beneath which the module path exists.
moduleSourcePath :: FilePath -> PackageGraph -> Text -> ProductionModule -> IO (Maybe FilePath)
moduleSourcePath root graph stanza (ProductionModule name) =
  fmap (fmap (makeRelative root)) (findFile [root </> dir | (_, _, dirs) <- maybe [] pure (Map.lookup stanza (graphLibraries graph)), dir <- dirs] (Text.unpack (Text.replace "." "/" name) <> ".hs"))

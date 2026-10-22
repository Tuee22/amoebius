{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Parse, never execute, a complete contributed source closure. This library
-- is shared by the early build guard and the trusted link boundary.
module Amoebius.Extension.AstCheck
  ( AstViolationReason (..), SourceSpan (..), AstViolation (..)
  , CheckedExtensionSource, ExtensionSourceVerdict (..)
  , checkExtensionSource, checkExtensionSources, checkedSourceFiles, checkedSourceModules
  , linkCheckedExtension, renderAstViolation
  ) where

import Amoebius.Extension.SanctionedApi
import Data.Data (Data, cast, gmapQ)
import Data.List (nub, nubBy, sortOn, stripPrefix)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Data.EnumSet qualified as EnumSet
import GHC.Data.FastString (mkFastString, unpackFS)
import GHC.Data.StringBuffer (stringToStringBuffer)
import GHC.Driver.Session
  (Language (..), FlagSpec (flagSpecName, flagSpecFlag), impliedXFlags, languageExtensions, xFlags)
import GHC.Hs
  ( GhcPs, HsModule, hsmodName, hsmodDecls, hsmodImports, hsmodExports
  , ImportDecl (..), ImportDeclQualifiedStyle (NotQualified), ImportListInterpretation (..), IsBootInterface (..)
  , IE (..), IEWildcard (..), IEWrappedName (..), lieWrappedName
  , HsDecl (..), TyClDecl (..), InstDecl (..), ClsInstDecl (..), HsSigType (..), DerivDecl (..), hswc_body
  , HsType (..), LHsType, HsExpr (..), LHsExpr, Pat (..), LPat )
import GHC.Hs.Instances ()
import GHC.Internal.LanguageExtensions qualified as Extension
import GHC.Parser (parseModule)
import GHC.Parser.Annotation (HasLoc, LocatedN, getLocA)
import GHC.Parser.Header (toArgs)
import GHC.Parser.Lexer
  ( ParseResult (..), Token (..), initParserState, initPragState
  , lexer, lexTokenStream, mkParserOpts, unP )
import GHC.Types.Name.Occurrence (isTcOcc, occNameString)
import GHC.Types.Name (isWiredInName)
import GHC.Types.Name.Reader (RdrName (..), rdrNameOcc)
import GHC.Types.PkgQual (RawPkgQual (..))
import GHC.Types.SrcLoc
  ( GenLocated (..), SrcSpan (..), getLoc, mkRealSrcLoc
  , realSrcSpanStart, srcSpanStartCol, srcSpanStartLine, unLoc )
import GHC.Unit.Module qualified as Module
import GHC.Utils.Error (emptyDiagOpts)

data AstViolationReason
  = UnsanctionedImport | RawIO | ForeignCall | UnsafeOperation
  | TemplateHaskell | OrphanInstance
  deriving (Bounded, Enum, Eq, Ord, Show)

data SourceSpan = SourceSpan {sourceLine :: Int, sourceColumn :: Int}
  deriving (Eq, Ord, Show)

data AstViolation = AstViolation
  { violationModulePath :: FilePath
  , violationSpan :: SourceSpan
  , violationReason :: AstViolationReason
  , violationNode :: Text
  }
  deriving (Eq, Show)

-- No Generic, Read, serialization, record selectors or exported constructor
-- can manufacture this evidence. A linked factory is sealed separately against
-- these exact actual files, before its contributed module is compiled.
newtype CheckedExtensionSource = CheckedExtensionSource (NonEmpty (FilePath, Text, Text))
  deriving (Eq, Show)

data ExtensionSourceVerdict
  = Rejected (NonEmpty AstViolation)
  | Accepted CheckedExtensionSource
  deriving (Eq, Show)

checkExtensionSource :: FilePath -> Text -> ExtensionSourceVerdict
checkExtensionSource path source = checkExtensionSources ((path, source) :| [])

checkExtensionSources :: NonEmpty (FilePath, Text) -> ExtensionSourceVerdict
checkExtensionSources sources =
  let inputs = NonEmpty.toList sources
      parsed = [(path, parseOne path source) | (path, source) <- inputs]
      modules = [name | (_, Right (name, _)) <- parsed]
      local = Set.fromList modules
      firstPath = fst (NonEmpty.head sources)
      closureProblems =
        [plain firstPath UnsafeOperation "duplicate-module" | length modules /= length (nub modules)]
        <> [plain firstPath UnsafeOperation "duplicate-source-path"
           | length inputs /= length (nub (map fst inputs))]
      problems = closureProblems <> concat
        [either id (\(_, tree) -> judge path local tree) result | (path, result) <- parsed]
      ordered = nubBy sameObservation (sortOn observationOrder problems)
   in case ordered of
        [] -> case [(path, name, source) | ((path, source), name) <- zip inputs modules] of
          first : rest -> Accepted (CheckedExtensionSource (first :| rest))
          [] -> Rejected (plain firstPath UnsafeOperation "empty-source-closure" :| [])
        problem : rest -> Rejected (problem :| rest)
 where
  sameObservation a b = violationModulePath a == violationModulePath b
    && violationSpan a == violationSpan b && violationReason a == violationReason b
  observationOrder v = (violationModulePath v, violationSpan v,
    if violationNode v == "name-reference" then (1 :: Int) else 0)

-- GHC's getOptions throws SourceError for malformed input. The pure admission
-- boundary instead consumes native pragma tokens and the total toArgs result.
-- Position pragmas are disabled in both lexers, retaining physical locations.
parseOne :: FilePath -> Text -> Either [AstViolation] (Text, HsModule GhcPs)
parseOne path source = do
  enabled <- header initial (initPragState (options initial) buffer origin)
  inspectTokens enabled
  case unP parseModule (initParserState (options enabled) buffer origin) of
    PFailed _ -> Left [plain path UnsafeOperation "parse-error"]
    POk _ located -> let tree = unLoc located
      in Right (maybe "Main" (moduleText . unLoc) (hsmodName tree), tree)
 where
  buffer = stringToStringBuffer (Text.unpack source)
  origin = mkRealSrcLoc (mkFastString path) 1 1
  initial = Set.fromList (languageExtensions (Just GHC2024))
  observationFeatures = [Extension.PackageImports, Extension.PatternSynonyms,
    Extension.TemplateHaskell, Extension.TemplateHaskellQuotes,
    Extension.ForeignFunctionInterface]
  options enabled = mkParserOpts
    (EnumSet.fromList (Set.toList enabled <> observationFeatures))
    emptyDiagOpts pragmaNames False False False False
  pragmaNames = map fst languages <> concat [[name, "No" <> name] | (name, _) <- extensionNames]
  languages = [("GHC2024", GHC2024), ("GHC2021", GHC2021),
    ("Haskell2010", Haskell2010), ("Haskell98", Haskell98)]
  header enabled state = case unP (lexer False pure) state of
    PFailed _ -> Left [plain path UnsafeOperation "header-parse-error"]
    POk next token -> case unLoc token of
      ITlanguage_prag -> language enabled next
      ITlineComment {} -> header enabled next
      ITblockComment {} -> header enabled next
      ITdocComment {} -> header enabled next
      _ -> case pragmaProblem token of
        Just refusal -> Left [refusal]
        Nothing -> Right enabled
  language enabled state = case unP (lexer False pure) state of
    PFailed _ -> Left [plain path UnsafeOperation "language-pragma"]
    POk next token -> case unLoc token of
      ITconid name -> do
        updated <- select token enabled (unpackFS name)
        case unP (lexer False pure) next of
          POk after separator -> case unLoc separator of
            ITcomma -> language updated after
            ITclose_prag -> header updated after
            _ -> Left [atSpan path (getLoc separator) UnsafeOperation "language-pragma"]
          PFailed _ -> Left [plain path UnsafeOperation "language-pragma"]
      _ -> Left [atSpan path (getLoc token) UnsafeOperation "language-pragma"]
  select token enabled name
    | Just edition <- lookup name languages = Right (Set.fromList (languageExtensions (Just edition)))
    | Just extension <- lookup name extensionNames =
        if extension == Extension.Cpp then Left [atSpan path (getLoc token) UnsafeOperation "language-pragma"]
          else Right (enable extension enabled)
    | Just rest <- stripPrefix "No" name, Just extension <- lookup rest extensionNames =
        Right (Set.delete extension enabled)
    | otherwise = Left [atSpan path (getLoc token) UnsafeOperation "language-pragma"]
  extensionNames = [(flagSpecName flag, flagSpecFlag flag) | flag <- xFlags]
  enable extension enabled = foldl' imply (Set.insert extension enabled)
    [(turnOn, dependency) | (parent, turnOn, dependency) <- impliedXFlags, parent == extension]
  imply enabled (True, extension) = enable extension enabled
  imply enabled (False, extension) = Set.delete extension enabled
  inspectTokens enabled = case lexTokenStream (options enabled) buffer origin of
    PFailed _ -> Left [plain path UnsafeOperation "token-parse-error"]
    POk _ tokens -> case [problem | token <- tokens, Just problem <- [pragmaProblem token]] of
      [] -> Right ()
      problems -> Left problems
  pragmaProblem token = case unLoc token of
    IToptions_prag text -> Just (optionsRefusal token text)
    ITinclude_prag _ -> Just (atSpan path (getLoc token) UnsafeOperation "include-pragma")
    ITdocOptions {} -> Just (atSpan path (getLoc token) UnsafeOperation "doc-options-pragma")
    ITline_prag {} -> Just (atSpan path (getLoc token) UnsafeOperation "position-pragma")
    ITcolumn_prag {} -> Just (atSpan path (getLoc token) UnsafeOperation "position-pragma")
    _ -> Nothing
  optionsRefusal token text = case getLoc token of
    RealSrcSpan span_ _ -> case toArgs (realSrcSpanStart span_) text of
      Right (first : _) -> atSpan path (getLoc first) UnsafeOperation "options-pragma"
      _ -> atSpan path (getLoc token) UnsafeOperation "options-pragma"
    _ -> plain path UnsafeOperation "options-pragma"

judge :: FilePath -> Set Text -> HsModule GhcPs -> [AstViolation]
judge path local tree = moduleProblems <> importProblems <> exportProblems
  <> declarationProblems <> everything expressions tree <> everything types tree
  <> everything patterns tree <> everything names tree
 where
  current = maybe "Main" (moduleText . unLoc) (hsmodName tree)
  moduleProblems = [plain path UnsafeOperation "module-shadow"
    | ModuleName current `Set.member` sanctionedModules sanctionedApi]
  imports = map unLoc (hsmodImports tree)
  aliases = Map.fromListWith (<>)
    [(maybe name (moduleText . unLoc) (ideclAs declaration), [name])
    | declaration <- imports, let name = moduleText (unLoc (ideclName declaration))]
  importProblems = concatMap checkImport (hsmodImports tree)
  checkImport located =
    let declaration = unLoc located
        name = moduleText (unLoc (ideclName declaration))
        sanctioned = ModuleName name `Set.member` sanctionedModules sanctionedApi
        localModule = name `Set.member` local
        packageFree = case ideclPkgQual declaration of NoRawPkgQual -> True; RawPkgQual _ -> False
        ordinarySource = case ideclSource declaration of NotBoot -> True; IsBoot -> False
        explicit = case ideclImportList declaration of Just (Exactly, _) -> True; _ -> False
        bounded = localModule || name == "Prelude" || ideclQualified declaration /= NotQualified || explicit
        hiding = case ideclImportList declaration of Just (EverythingBut, _) -> True; _ -> False
        selfAlias = maybe name (moduleText . unLoc) (ideclAs declaration) == current && name /= current
        membership = case ideclImportList declaration of
          Just (Exactly, entries) | sanctioned -> concatMap (checkImportEntry name) (unLoc entries)
          _ -> []
     in [at path located UnsanctionedImport "import-declaration"
        | not (sanctioned || localModule) || not packageFree || not ordinarySource || not bounded || hiding
          || selfAlias || not (null membership)]
        <> membership
  checkImportEntry name located = case unLoc located of
    IEVar _ wrapped _ -> imported ValueNamespace wrapped
    IEThingAbs _ wrapped _ -> imported TypeNamespace wrapped
    IEThingWith _ wrapped NoIEWildcard children _ ->
      imported TypeNamespace wrapped <> concatMap (imported ValueNamespace) children
    _ -> [at path located UnsanctionedImport "import-list"]
   where
    imported fallback wrapped =
      let occurrence = occurrenceText (lieWrappedName wrapped)
          namespace = case unLoc wrapped of
            IEPattern {} -> ValueNamespace
            IEType {} -> TypeNamespace
            _ -> fallback
       in [at path wrapped UnsanctionedImport "import-symbol"
          | not (admittedSymbol (ModuleName name) namespace occurrence)]
  exportProblems = concatMap checkExport (maybe [] unLoc (hsmodExports tree))
  checkExport located = case unLoc located of
    IEModuleContents {} -> [at path located UnsafeOperation "module-reexport"]
    IEThingAll {} -> [at path located UnsafeOperation "wildcard-export"]
    IEThingWith _ _ (IEWildcard _) _ _ -> [at path located UnsafeOperation "wildcard-export"]
    _ -> []
  localTypes = Set.fromList
    [occurrenceText (unLoc (tcdLName declaration))
    | located <- hsmodDecls tree, TyClD _ declaration <- [unLoc located]
    , case declaration of DataDecl {} -> True; ClassDecl {} -> True; _ -> False]
  declarationProblems = concatMap checkDeclaration (hsmodDecls tree)
  checkDeclaration located = case unLoc located of
    ForD {} -> [at path located ForeignCall "foreign-declaration"]
    SpliceD {} -> [at path located TemplateHaskell "splice-declaration"]
    AnnD {} -> [at path located UnsafeOperation "annotation-declaration"]
    RuleD {} -> [at path located UnsafeOperation "rewrite-rule"]
    DerivD _ declaration -> [at path located OrphanInstance "deriving-declaration"
      | orphanHead (sig_body (unLoc (hswc_body (deriv_type declaration))))]
    InstD _ ClsInstD {cid_inst = instanceBody} ->
      [at path located OrphanInstance "instance-declaration"
      | orphanHead (sig_body (unLoc (cid_poly_ty instanceBody)))]
    InstD {} -> [at path located UnsafeOperation "family-instance-declaration"]
    _ -> []
  orphanHead body = Set.null (Set.intersection localTypes
    (Set.fromList (everything (localTypeNames current) (headType body))))
  headType located = case unLoc located of
    HsForAllTy {hst_body = body} -> headType body
    HsQualTy {hst_body = body} -> headType body
    _ -> located
  expressions :: forall a. Data a => a -> [AstViolation]
  expressions value = case cast value :: Maybe (LHsExpr GhcPs) of
    Just located -> case unLoc located of
      HsVar _ name -> judgeName (at path located) "identifier" (unLoc name)
      HsTypedSplice {} -> refused TemplateHaskell "splice-expression"
      HsUntypedSplice {} -> refused TemplateHaskell "splice-expression"
      HsTypedBracket {} -> refused TemplateHaskell "quotation-expression"
      HsUntypedBracket {} -> refused TemplateHaskell "quotation-expression"
      RecordUpd {} -> refused UnsafeOperation "record-update"
      HsGetField {} -> refused UnsafeOperation "record-projection"
      HsProjection {} -> refused UnsafeOperation "record-projection"
      HsOverLabel {} -> refused UnsafeOperation "overloaded-label"
      ArithSeq {} -> refused UnsafeOperation "enumeration-expression"
      HsStatic {} -> refused UnsafeOperation "static-expression"
      _ -> []
     where refused reason node = [at path located reason node]
    Nothing -> []
  types :: forall a. Data a => a -> [AstViolation]
  types value = case cast value :: Maybe (LHsType GhcPs) of
    Just located -> case unLoc located of
      HsTyVar _ _ name -> judgeName (at path located) "type-variable" (unLoc name)
      HsSpliceTy {} -> [at path located TemplateHaskell "splice-type"]
      _ -> []
    Nothing -> []
  patterns :: forall a. Data a => a -> [AstViolation]
  patterns value = case cast value :: Maybe (LPat GhcPs) of
    Just located -> case unLoc located of
      SplicePat {} -> [at path located TemplateHaskell "splice-pattern"]
      ConPat {pat_con = name} -> judgeName (at path located) "constructor-pattern" (unLoc name)
      _ -> []
    Nothing -> []
  names :: forall a. Data a => a -> [AstViolation]
  names value = case cast value :: Maybe (LocatedN RdrName) of
    Just located -> judgeName (at path located) "name-reference" (unLoc located)
    Nothing -> []
  judgeName make node name = case reservedName occurrence of
    Just "RawIO" -> [make RawIO node]
    Just _ -> [make UnsafeOperation node]
    Nothing -> case name of
      Qual qualifier _
        | moduleText qualifier == current -> []
        | otherwise -> case Map.lookup (moduleText qualifier) aliases of
            Just [imported]
              | imported `Set.member` local -> []
              | admittedSymbol (ModuleName imported) namespace occurrence -> []
            _ -> [make UnsanctionedImport node]
      Unqual _ -> []
      Exact builtin | isWiredInName builtin -> []
      _ -> [make UnsafeOperation node]
   where
    occurrence = occurrenceText name
    namespace = if isTcOcc (rdrNameOcc name) then TypeNamespace else ValueNamespace

localTypeNames :: forall a. Data a => Text -> a -> [Text]
localTypeNames current value = case cast value :: Maybe (LHsType GhcPs) of
  Just located -> case unLoc located of
    HsTyVar _ _ name -> case unLoc name of
      Unqual _ -> [occurrenceText (unLoc name)]
      Qual qualifier _ | moduleText qualifier == current -> [occurrenceText (unLoc name)]
      _ -> []
    _ -> []
  Nothing -> []

everything :: Data a => (forall b. Data b => b -> [result]) -> a -> [result]
everything query value = query value <> concat (gmapQ (everything query) value)

moduleText :: Module.ModuleName -> Text
moduleText = Text.pack . Module.moduleNameString

occurrenceText :: RdrName -> Text
occurrenceText = Text.pack . occNameString . rdrNameOcc

plain :: FilePath -> AstViolationReason -> Text -> AstViolation
plain path = AstViolation path (SourceSpan 1 1)

at :: HasLoc l => FilePath -> GenLocated l a -> AstViolationReason -> Text -> AstViolation
at path located = atSpan path (getLocA located)

atSpan :: FilePath -> SrcSpan -> AstViolationReason -> Text -> AstViolation
atSpan path location = AstViolation path position
 where
  position = case location of
    RealSrcSpan span_ _ -> SourceSpan (srcSpanStartLine span_) (srcSpanStartCol span_)
    UnhelpfulSpan _ -> SourceSpan 1 1

checkedSourceFiles :: CheckedExtensionSource -> NonEmpty (FilePath, Text)
checkedSourceFiles (CheckedExtensionSource sources) = fmap (\(path, _, source) -> (path, source)) sources

checkedSourceModules :: CheckedExtensionSource -> NonEmpty (FilePath, Text)
checkedSourceModules (CheckedExtensionSource sources) = fmap (\(path, name, _) -> (path, name)) sources

-- Compatibility projection; the real link seam consumes the opaque seal.
linkCheckedExtension :: CheckedExtensionSource -> Text
linkCheckedExtension = Text.concat . map snd . NonEmpty.toList . checkedSourceFiles

renderAstViolation :: AstViolation -> Text
renderAstViolation violation = Text.intercalate ":"
  [Text.pack (violationModulePath violation), Text.pack (show (sourceLine (violationSpan violation))),
   Text.pack (show (sourceColumn (violationSpan violation))),
   Text.pack (show (violationReason violation)), violationNode violation]

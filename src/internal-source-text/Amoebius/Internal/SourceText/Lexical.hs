{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | Pure compatibility facts from one supplied compiler AST. This private unit
-- neither acquires source nor supplies a provider, byte, native or pass seal.
module Amoebius.Internal.SourceText.Lexical
  ( LexicalModule, LexicalOccurrence, AstStep (..), AstPath (..)
  , OccurrenceId (..), ScopeId (..), DeclarationId (..), ImportId (..)
  , ParameterHitId (..), PatternSearchPath (..), OccurrenceView (..)
  , ScopeKind (..), ScopeFact (..), DeclarationFact (..), LocalGroupFact (..)
  , ImportFact (..), ParameterHit (..), ParameterSearchFact (..), ModuleFacts (..)
  , QueryKind (..), Dependency (..), LookupSource (..), QueryIssue (..)
  , QueryProjection (..), prepareLexicalModule, inspectLexicalModule
  , inspectOccurrence, queryWholeText, queryFunctionSpelling
  , SuppliedSpanCase (..), lexicalCompatibilityExamples ) where

import Data.Data (Data, Typeable, cast, gmapQ, showConstr, toConstr, typeOf)
import Data.List (foldl')
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Data.FastString (FastString, unpackFS)
import GHC.Hs
import GHC.Hs.Instances ()
import GHC.Parser.Annotation (getLocA)
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.Name.Reader (RdrName (..), rdrNameOcc)
import GHC.Types.SrcLoc (GenLocated (..), SrcSpan, unLoc)
import GHC.Unit.Module (moduleNameString)
import Numeric.Natural (Natural)

data AstStep = DataChild Natural | ExpressionPayload deriving (Eq, Ord, Show)
newtype AstPath = AstPath [AstStep] deriving (Eq, Ord, Show)
newtype OccurrenceId = OccurrenceId [Natural] deriving (Eq, Ord, Show)
newtype ScopeId = ScopeId Natural deriving (Eq, Ord, Show)
data DeclarationId = DeclarationId ScopeId Natural deriving (Eq, Ord, Show)
newtype ImportId = ImportId Natural deriving (Eq, Ord, Show)
data ParameterHitId = ParameterHitId AstPath Natural deriving (Eq, Ord, Show)
newtype PatternSearchPath = PatternSearchPath [Natural] deriving (Eq, Ord, Show)

data LexicalModule = LexicalModule ModuleFacts
-- Context is private and tied to this very forest, never supplied by a caller.
data LexicalOccurrence = LexicalOccurrence OccurrenceView Context

data OccurrenceView = OccurrenceView
  { occurrenceId :: OccurrenceId, occurrencePath :: AstPath
  , occurrenceAst :: LHsExpr GhcPs, occurrenceRawSpan :: SrcSpan
  , occurrenceChildren :: [LexicalOccurrence]
  , occurrenceCompatibilityScope :: ScopeId
  }
data ScopeKind = ModuleValues | MatchCompatibilityShadows | RecursiveValues
  deriving (Eq, Ord, Show)
data ScopeFact = ScopeFact
  { scopeId :: ScopeId, scopePath :: AstPath, scopeKind :: ScopeKind
  , scopeOuter :: Maybe ScopeId, scopeDeclarations :: [DeclarationId]
  }
data DeclarationFact = DeclarationFact
  { declarationId :: DeclarationId, declarationPath :: AstPath
  , declarationAst :: HsBindLR GhcPs GhcPs, declarationLookupKeys :: [Text]
  , declarationValueBody :: Maybe OccurrenceId
  , declarationWhereGroup :: Maybe AstPath
  }
data LocalGroupFact = LocalGroupFact
  { localGroupPath :: AstPath, localGroupAst :: HsLocalBindsLR GhcPs GhcPs
  , localGroupRecognizedScope :: Maybe ScopeId
  }
data ImportFact = ImportFact
  { importId :: ImportId, importPath :: AstPath, importAst :: LImportDecl GhcPs
  , importQualifierKey :: Text, importModuleSpelling :: Text
  }
data ParameterHit = ParameterHit
  { parameterHitId :: ParameterHitId, parameterHitSearchPath :: PatternSearchPath
  , parameterHitAst :: LPat GhcPs, parameterHitName :: RdrName
  , parameterHitLookupKey :: Text
  }
data ParameterSearchFact = ParameterSearchFact
  { parameterMatchPath :: AstPath, parameterSearchRootPath :: AstPath
  , parameterSearchRoots :: [LPat GhcPs], parameterSearchHits :: [ParameterHit]
  , parameterCompatibilityScope :: ScopeId
  }
data ModuleFacts = ModuleFacts
  { moduleAst :: HsModule GhcPs, moduleRoots :: [LexicalOccurrence]
  , moduleOccurrences :: [OccurrenceView], moduleScopes :: [ScopeFact]
  , moduleDeclarations :: [DeclarationFact], moduleLocalGroups :: [LocalGroupFact]
  , moduleImports :: [ImportFact], moduleParameterSearches :: [ParameterSearchFact]
  }
data QueryKind = WholeText | FunctionSpelling deriving (Eq, Ord, Show)
data Dependency
  = Requested QueryKind OccurrenceId | Followed DeclarationId OccurrenceId
  | ProbedCharacter OccurrenceId | InspectedExplicitList OccurrenceId
  deriving (Eq, Ord, Show)
data LookupSource = DeclarationLookup (NonEmpty DeclarationId)
  | ParameterShadowLookup (NonEmpty ParameterHitId) deriving (Eq, Ord, Show)
data QueryIssue
  = UnknownTextName Text | NonValueLookup LookupSource
  | DuplicateDeclarations (NonEmpty DeclarationId)
  | SpanCycleCutoff (NonEmpty DeclarationId) (NonEmpty OccurrenceId)
  | UnsupportedTextConstructor Text | UnsupportedHeadConstructor Text
  | UnrecognizedTextOperation Text | NonCharacterElement OccurrenceId
  | AmbiguousQualifierAlternatives (NonEmpty ImportId)
  deriving (Eq, Ord, Show)
data QueryProjection = QueryProjection
  { queryScalar :: Maybe Text, queryDependencies :: [Dependency]
  , queryLiteralOrigins :: [OccurrenceId], queryIssues :: [QueryIssue]
  } deriving (Eq, Show)

-- Supplied compiler values exercise the pure compatibility API. These inputs
-- carry no filesystem observation and cannot close a native capture boundary.
data SuppliedSpanCase = PreserveSuppliedSpans | ShareHelpfulSpans | RemoveHelpfulSpans
  deriving (Eq, Show)

lexicalCompatibilityExamples :: [(Text, Text, SuppliedSpanCase)]
lexicalCompatibilityExamples =
  [(name <> suffix, header <> source, spans)
  | (name,source) <- sources
  , (suffix,spans) <- [(".native",PreserveSuppliedSpans),(".shared",ShareHelpfulSpans),(".unhelpful",RemoveHelpfulSpans)]]
 where
  header = "{-# LANGUAGE OverloadedStrings #-}\nmodule Supplied where\n"
  sources =
    [("alias","value = first\nfirst = second\nsecond = \"end\"\n")
    ,("cycle","value = first\nfirst = second\nsecond = first\n")
    ,("repeated","value = (\"same\", \"same\")\n")
    ,("where","value = local where local = inner where inner = \"end\"\n")
    ,("let","value = let name = \"inner\" in name\nname = \"outer\"\n")
    ,("parameters","value (left, right) = left <> right\nleft = \"outer\"\n")
    ,("duplicate","name = \"first\"\nname = \"second\"\nvalue = name\n")
    ,("qualifiers","import qualified Data.Text as T\nimport qualified Data.Text.Lazy as T\nvalue = T.pack \"value\"\n")
    ,("guarded","value | True = \"guarded\"\nother = value\n")
    ,("concat","value = choose [\"first\", unknown, \"ignored\"]\nchoose = concat\n")
    ,("empty-let","value = let {} in \"empty\"\n")]

data RawOccurrence = RawOccurrence OccurrenceId AstPath (LHsExpr GhcPs)
  [RawOccurrence] ScopeId
data PendingDeclaration = PendingDeclaration DeclarationId AstPath
  (HsBindLR GhcPs GhcPs) [Text] (Maybe (AstPath, AstPath))
data Build = Build
  { nextScope :: Natural, scopes :: [ScopeFact]
  , declarations :: [PendingDeclaration], groups :: [LocalGroupFact]
  , parameters :: [ParameterSearchFact], groupScopes :: Map.Map AstPath ScopeId
  }
data Binding = DeclarationBinding (NonEmpty DeclarationId) (Maybe OccurrenceId)
  | ParameterBinding (NonEmpty ParameterHitId)
data Context = Context
  { contextOccurrences :: Map.Map OccurrenceId LexicalOccurrence
  , contextPaths :: Map.Map AstPath LexicalOccurrence
  , contextScopes :: Map.Map ScopeId (Map.Map Text Binding)
  , contextImports :: [ImportFact]
  }

inspectLexicalModule :: LexicalModule -> ModuleFacts
inspectLexicalModule (LexicalModule facts) = facts
inspectOccurrence :: LexicalOccurrence -> OccurrenceView
inspectOccurrence (LexicalOccurrence view _) = view

appendPath :: AstPath -> [AstStep] -> AstPath
appendPath (AstPath path) suffix = AstPath (path <> suffix)

-- Locate an actual typed field among its parent's actual direct Data children.
-- Shape drift refuses rather than inventing an ordinal or using a source span.
fieldPath :: (Data parent, Typeable child) => AstPath -> parent -> child -> AstPath
fieldPath path parent witness = case
    [index | (index, True) <- zip [0 ..] (gmapQ (\child -> typeOf child == typeOf witness) parent)] of
  [index] -> appendPath path [DataChild index]
  _ -> error "SourceTextDirectFieldShapeUnavailable"

listEntries :: Data item => AstPath -> [item] -> [(AstPath, item)]
listEntries _ [] = []
listEntries path list@(item : remaining) =
  (fieldPath path list item, item) : listEntries (fieldPath path list remaining) remaining

locatedValuePath :: (Data annotation, Data value) => AstPath -> GenLocated annotation value -> AstPath
locatedValuePath path located = fieldPath path located (unLoc located)

prepareLexicalModule :: HsModule GhcPs -> LexicalModule
prepareLexicalModule tree = LexicalModule facts
 where
  importFacts =
    [ImportFact (ImportId index) path located qualifier module_
    | (index, (path, located)) <- zip [0 ..]
        (listEntries (fieldPath (AstPath []) tree (hsmodImports tree)) (hsmodImports tree))
    , let declaration = unLoc located
          module_ = Text.pack (moduleNameString (unLoc (ideclName declaration)))
          qualifier = maybe module_ (Text.pack . moduleNameString . unLoc) (ideclAs declaration)]
  current = maybe "Main" (Text.pack . moduleNameString . unLoc) (hsmodName tree)
  topDeclarations =
    [(fieldPath (locatedValuePath path located) declaration bind, bind)
    | (path, located) <- listEntries (fieldPath (AstPath []) tree (hsmodDecls tree)) (hsmodDecls tree)
    , let declaration = unLoc located, ValD _ bind <- [declaration]]
  initialDeclarations = registerDeclarations importFacts (Just current) (ScopeId 0) topDeclarations
  initial = Build 1 [ScopeFact (ScopeId 0) (AstPath []) ModuleValues Nothing
      [identifier | PendingDeclaration identifier _ _ _ _ <- initialDeclarations]]
      initialDeclarations [] [] Map.empty
  (rawRoots, built) = walk importFacts (AstPath []) (ScopeId 0) [] 0 tree initial
  roots = map makeOccurrence rawRoots
  views = concatMap flatten roots
  byPath = Map.fromList [(occurrencePath view, occurrenceId view) | view <- views]
  finalDeclarations =
    [DeclarationFact identifier path bind keys (fmap (\(bodyPath, _) -> requiredLookup "SourceTextDeclarationBodyUnavailable" bodyPath byPath) body)
       (snd <$> body)
    | PendingDeclaration identifier path bind keys body <- declarations built]
  facts = ModuleFacts tree roots views (scopes built) finalDeclarations
    (groups built) importFacts (parameters built)
  context = Context
    (Map.fromList [(occurrenceId (inspectOccurrence occurrence), occurrence) | occurrence <- allOccurrences roots])
    (Map.fromList [(occurrencePath (inspectOccurrence occurrence), occurrence) | occurrence <- allOccurrences roots])
    environments importFacts
  environments = foldl' addScope Map.empty (scopes built)
  addScope previous scope = Map.insert (scopeId scope) (environment previous scope) previous
  environment previous scope = own <> maybe Map.empty
    (\outer -> requiredLookup "SourceTextOuterScopeUnavailable" outer previous) (scopeOuter scope)
   where
    own = case scopeKind scope of
      MatchCompatibilityShadows -> Map.map ParameterBinding . Map.fromListWith (flip (<>)) $
        [(parameterHitLookupKey hit, parameterHitId hit :| [])
        | search <- parameters built, parameterCompatibilityScope search == scopeId scope
        , hit <- parameterSearchHits search]
      _ -> Map.map declarationBinding . Map.fromListWith (flip (<>)) $
        [(key, declaration :| []) | declaration <- finalDeclarations
        , declarationId declaration `elem` scopeDeclarations scope
        , key <- declarationLookupKeys declaration]
    declarationBinding entries = DeclarationBinding (fmap declarationId entries)
      (case NonEmpty.toList entries of [entry] -> declarationValueBody entry; _ -> Nothing)
  makeOccurrence (RawOccurrence identifier path expression children scope) =
    LexicalOccurrence (OccurrenceView identifier path expression (getLocA expression)
      (map makeOccurrence children) scope) context
  flatten occurrence = inspectOccurrence occurrence : concatMap flatten (occurrenceChildren (inspectOccurrence occurrence))
  allOccurrences occurrences = concatMap (\occurrence -> occurrence : allOccurrences (occurrenceChildren (inspectOccurrence occurrence))) occurrences

registerDeclarations :: [ImportFact] -> Maybe Text -> ScopeId
  -> [(AstPath, HsBindLR GhcPs GhcPs)] -> [PendingDeclaration]
registerDeclarations imports current scope entries =
  [PendingDeclaration (DeclarationId scope index) path bind keys (valueBody path bind)
  | (index, (path, bind)) <- zip [0 ..] entries
  , let keys = case bind of
          FunBind {fun_id = name} -> let key = fst (projectName imports (unLoc name))
            in key : [module_ <> "." <> key | Just module_ <- [current]]
          _ -> []]

valueBody :: AstPath -> HsBindLR GhcPs GhcPs -> Maybe (AstPath, AstPath)
valueBody path bind = case bind of
  FunBind {fun_matches = matches}
    | [locatedMatch] <- unLoc (mg_alts matches)
    , match@Match {m_pats = patterns, m_grhss = rhsGroup@GRHSs
        {grhssGRHSs = [locatedRhs], grhssLocalBinds = locals}} <- unLoc locatedMatch
    , null (unLoc patterns)
    , rhs@(GRHS _ [] body) <- unLoc locatedRhs ->
        let matchesPath = fieldPath path bind matches
            alternativesPath = fieldPath matchesPath matches (mg_alts matches)
            listPath = locatedValuePath alternativesPath (mg_alts matches)
            matchPath = locatedValuePath (fst (head (listEntries listPath (unLoc (mg_alts matches))))) locatedMatch
            rhsGroupPath = fieldPath matchPath match rhsGroup
            rhssPath = fieldPath rhsGroupPath rhsGroup (grhssGRHSs rhsGroup)
            rhsPath = locatedValuePath (fst (head (listEntries rhssPath (grhssGRHSs rhsGroup)))) locatedRhs
        in Just (fieldPath rhsPath rhs body, fieldPath rhsGroupPath rhsGroup locals)
  _ -> Nothing

localDeclarations :: AstPath -> HsLocalBindsLR GhcPs GhcPs
  -> [(AstPath, HsBindLR GhcPs GhcPs)]
localDeclarations path locals = case locals of
  HsValBinds _ values@(ValBinds _ binds _) ->
    [(locatedValuePath bindPath located, unLoc located)
    | (bindPath, located) <- listEntries (fieldPath (fieldPath path locals values) values binds) binds]
  _ -> []

introduceGroup :: [ImportFact] -> AstPath -> ScopeId -> HsLocalBindsLR GhcPs GhcPs
  -> Build -> (ScopeId, Build)
introduceGroup imports path outer locals built
  | null entries = (outer, built {groups = groups built <> [LocalGroupFact path locals Nothing]})
  | otherwise =
      let identifier = ScopeId (nextScope built)
          pending = registerDeclarations imports Nothing identifier entries
          fact = ScopeFact identifier path RecursiveValues (Just outer)
            [key | PendingDeclaration key _ _ _ _ <- pending]
      in (identifier, built {nextScope = nextScope built + 1,
          scopes = scopes built <> [fact], declarations = declarations built <> pending,
          groups = groups built <> [LocalGroupFact path locals (Just identifier)],
          groupScopes = Map.insert path identifier (groupScopes built)})
 where entries = localDeclarations path locals

parameterHits :: [ImportFact] -> AstPath -> [LPat GhcPs] -> [ParameterHit]
parameterHits imports matchPath patterns =
  [ParameterHit (ParameterHitId matchPath index) (PatternSearchPath path) pattern_ name
     (fst (projectName imports name))
  | (index, (path, pattern_, name)) <- zip [0 ..] (search [] patterns)]
 where
  search :: Data value => [Natural] -> value -> [([Natural], LPat GhcPs, RdrName)]
  search path value = case cast value :: Maybe (LPat GhcPs) of
    Just pattern_@(L _ (VarPat _ name)) -> [(path, pattern_, unLoc name)]
    _ -> concat [child (path <> [index]) | (index, child) <- zip [0 ..] (gmapQ (\part suffix -> search suffix part) value)]

walk :: Data value => [ImportFact] -> AstPath -> ScopeId -> [Natural] -> Natural
  -> value -> Build -> ([RawOccurrence], Build)
walk imports path scope parent ordinal value built = case cast value :: Maybe (LHsExpr GhcPs) of
  Just expression ->
    let (nested, prepared) = case unLoc expression of
          payload@(HsLet _ locals _) -> introduceGroup imports
            (fieldPath (appendPath path [ExpressionPayload]) payload locals) scope locals built
          _ -> (scope, built)
        identifier = parent <> [ordinal]
        (children, finished) = case unLoc expression of
          HsLit {} -> ([], prepared)
          HsOverLit {} -> ([], prepared)
          payload -> walkChildren imports (appendPath path [ExpressionPayload]) nested identifier payload prepared
    in ([RawOccurrence (OccurrenceId identifier) path expression children nested], finished)
  Nothing
    | Just _ <- (cast value :: Maybe FastString) -> ([], built)
    | Just _ <- (cast value :: Maybe RdrName) -> ([], built)
    | Just match <- (cast value :: Maybe (Match GhcPs (LHsExpr GhcPs))) ->
        let shadow = ScopeId (nextScope built)
            patterns = unLoc (m_pats match)
            rootsPath = locatedValuePath (fieldPath path match (m_pats match)) (m_pats match)
            search = ParameterSearchFact path rootsPath patterns
              (parameterHits imports path patterns) shadow
            scoped = built {nextScope = nextScope built + 1,
              scopes = scopes built <> [ScopeFact shadow path MatchCompatibilityShadows (Just scope) []],
              parameters = parameters built <> [search]}
            rhsGroup = m_grhss match
            locals = grhssLocalBinds rhsGroup
            localPath = fieldPath (fieldPath path match rhsGroup) rhsGroup locals
            (nested, prepared) = introduceGroup imports localPath shadow locals scoped
        in walkChildrenAt ordinal imports path nested parent match prepared
    | Just locals <- (cast value :: Maybe (HsLocalBindsLR GhcPs GhcPs)) ->
        let retained = if any ((== path) . localGroupPath) (groups built) then built
              else built {groups = groups built <> [LocalGroupFact path locals (Map.lookup path (groupScopes built))]}
        in walkChildrenAt ordinal imports path scope parent value retained
    | otherwise -> walkChildrenAt ordinal imports path scope parent value built

walkChildren :: Data value => [ImportFact] -> AstPath -> ScopeId -> [Natural]
  -> value -> Build -> ([RawOccurrence], Build)
walkChildren = walkChildrenAt 0

walkChildrenAt :: Data value => Natural -> [ImportFact] -> AstPath -> ScopeId
  -> [Natural] -> value -> Build -> ([RawOccurrence], Build)
walkChildrenAt initial imports path scope parent value built = go [] built children
 where
  children = zip [0 ..] (gmapQ (\child childPath rank state -> walk imports childPath scope parent rank child state) value)
  go found state [] = (found, state)
  go found state ((index, child) : remaining) =
    let (roots, next) = child (appendPath path [DataChild index])
          (initial + fromIntegral (length found)) state
    in go (found <> roots) next remaining

projectName :: [ImportFact] -> RdrName -> (Text, [QueryIssue])
projectName imports name = case name of
  Qual qualifier occurrence ->
    let spelling = Text.pack (moduleNameString qualifier)
        alternatives = filter ((== spelling) . importQualifierKey) imports
        module_ = case reverse alternatives of entry : _ -> importModuleSpelling entry; [] -> spelling
        issues = case map importId alternatives of
          first : second : rest -> [AmbiguousQualifierAlternatives (first :| (second : rest))]
          _ -> []
    in (module_ <> "." <> Text.pack (occNameString occurrence), issues)
  _ -> (Text.pack (occNameString (rdrNameOcc name)), [])

queryWholeText :: LexicalOccurrence -> QueryProjection
queryWholeText = query WholeText []
queryFunctionSpelling :: LexicalOccurrence -> QueryProjection
queryFunctionSpelling = query FunctionSpelling []

type AliasRoute = [(DeclarationId, OccurrenceId, SrcSpan)]
emptyProjection :: Maybe Text -> QueryProjection
emptyProjection scalar = QueryProjection scalar [] [] []
withIssue :: QueryIssue -> QueryProjection
withIssue issue = QueryProjection Nothing [] [] [issue]

-- The right projection supplies the result; both complete demanded prefixes stay.
followedBy :: QueryProjection -> QueryProjection -> QueryProjection
followedBy first second = second
  {queryDependencies = queryDependencies first <> queryDependencies second,
   queryLiteralOrigins = queryLiteralOrigins first <> queryLiteralOrigins second,
   queryIssues = queryIssues first <> queryIssues second}

query :: QueryKind -> AliasRoute -> LexicalOccurrence -> QueryProjection
query kind seen occurrence@(LexicalOccurrence view _) =
  (emptyProjection Nothing) {queryDependencies = [Requested kind (occurrenceId view)]}
    `followedBy` case kind of
      WholeText -> textQuery seen occurrence
      FunctionSpelling -> case unLoc (occurrenceAst view) of
        HsVar _ name -> lookupQuery kind seen occurrence (unLoc name)
        HsPar {} -> query kind seen (onlyExpressionField occurrence)
        payload -> withIssue (UnsupportedHeadConstructor (constructorName payload))

lookupQuery :: QueryKind -> AliasRoute -> LexicalOccurrence -> RdrName -> QueryProjection
lookupQuery kind seen (LexicalOccurrence view context) reader = ambiguity `followedBy` result
 where
  (key, issues) = projectName (contextImports context) reader
  ambiguity = (emptyProjection Nothing) {queryIssues = issues}
  bindings = requiredLookup "SourceTextOccurrenceScopeUnavailable" (occurrenceCompatibilityScope view) (contextScopes context)
  result = case Map.lookup key bindings of
    Nothing -> if kind == FunctionSpelling then emptyProjection (Just key) else withIssue (UnknownTextName key)
    Just (ParameterBinding hits) -> withIssue (NonValueLookup (ParameterShadowLookup hits))
    Just (DeclarationBinding identifiers body) -> case NonEmpty.toList identifiers of
      [identifier] -> case body of
        Nothing -> withIssue (NonValueLookup (DeclarationLookup identifiers))
        Just target ->
          let inner = requiredLookup "SourceTextBodyOccurrenceUnavailable" target (contextOccurrences context)
              span_ = occurrenceRawSpan (inspectOccurrence inner)
              route = seen <> [(identifier, target, span_)]
              prefix = (emptyProjection Nothing) {queryDependencies = [Followed identifier target]}
          in prefix `followedBy` if span_ `elem` [old | (_, _, old) <- seen]
             then withIssue (SpanCycleCutoff
               (NonEmpty.fromList [declaration | (declaration, _, _) <- route])
               (NonEmpty.fromList [expression | (_, expression, _) <- route]))
             else query kind route inner
      _ -> withIssue (DuplicateDeclarations identifiers)

constructorName :: Data value => value -> Text
constructorName = Text.pack . showConstr . toConstr
requiredLookup :: Ord key => String -> key -> Map.Map key value -> value
requiredLookup reason key values = maybe (error reason) id (Map.lookup key values)

-- Direct expression fields are joined by actual Data-child ordinal, not Eq AST
-- or raw span equality; equal and unhelpful spans therefore remain distinct.
expressionFields :: LexicalOccurrence -> [LexicalOccurrence]
expressionFields (LexicalOccurrence view context) =
  [requiredLookup "SourceTextExpressionFieldUnavailable"
     (appendPath (occurrencePath view) [ExpressionPayload, DataChild index]) (contextPaths context)
  | (index, Just _) <- zip [0 ..]
      (gmapQ (\child -> cast child :: Maybe (LHsExpr GhcPs)) (unLoc (occurrenceAst view)))]

onlyExpressionField :: LexicalOccurrence -> LexicalOccurrence
onlyExpressionField occurrence = case expressionFields occurrence of
  [inner] -> inner
  _ -> error "SourceTextSingleExpressionFieldUnavailable"

listItems :: LexicalOccurrence -> [LHsExpr GhcPs] -> [LexicalOccurrence]
listItems (LexicalOccurrence view context) items =
  [requiredLookup "SourceTextListItemUnavailable" path (contextPaths context)
  | (path, _) <- listEntries
      (fieldPath (appendPath (occurrencePath view) [ExpressionPayload]) (unLoc (occurrenceAst view)) items) items]

appendNames, identityNames, concatNames :: [Text]
appendNames = ["++", "<>", "mappend", "Prelude.++", "Prelude.<>", "Prelude.mappend", "Data.Text.append"]
identityNames = ["id", "Prelude.id", "Data.Text.pack", "Data.Text.unpack"]
concatNames = ["concat", "mconcat", "Prelude.concat", "Prelude.mconcat", "Data.Text.concat"]

textQuery :: AliasRoute -> LexicalOccurrence -> QueryProjection
textQuery seen occurrence@(LexicalOccurrence view _) = case unLoc (occurrenceAst view) of
  HsLit _ (HsString _ literal) -> literalResult (Text.pack (unpackFS literal))
  HsLit _ (HsMultilineString _ literal) -> literalResult (Text.pack (unpackFS literal))
  HsOverLit _ OverLit {ol_val = HsIsString _ literal} -> literalResult (Text.pack (unpackFS literal))
  HsVar _ name -> lookupQuery WholeText seen occurrence (unLoc name)
  HsPar {} -> query WholeText seen (onlyExpressionField occurrence)
  ExprWithTySig {} -> query WholeText seen (onlyExpressionField occurrence)
  HsLet {} -> query WholeText seen (onlyExpressionField occurrence)
  OpApp {} -> case expressionFields occurrence of
    [left, operator, right] ->
      let headResult = queryFunctionSpelling operator
      in headResult `followedBy` if queryScalar headResult `elem` map Just appendNames
         then appendText seen left right else terminal headResult
    _ -> error "SourceTextOperatorFieldsUnavailable"
  HsApp {} -> applicationQuery seen occurrence
  ExplicitList _ items -> characterList (listItems occurrence items)
  payload -> withIssue (UnsupportedTextConstructor (constructorName payload))
 where
  literalResult literal = (emptyProjection (Just literal)) {queryLiteralOrigins = [occurrenceId view]}
  terminal headResult = case queryScalar headResult of
    Just name -> withIssue (UnrecognizedTextOperation name)
    Nothing -> withIssue (UnsupportedTextConstructor (constructorName (unLoc (occurrenceAst view))))

appendText :: AliasRoute -> LexicalOccurrence -> LexicalOccurrence -> QueryProjection
appendText seen left right =
  let first = query WholeText seen left
  in case queryScalar first of
    Nothing -> first
    Just prefix -> let second = query WholeText seen right
      in (first `followedBy` second) {queryScalar = (prefix <>) <$> queryScalar second}

applicationQuery :: AliasRoute -> LexicalOccurrence -> QueryProjection
applicationQuery seen occurrence = case expressionFields occurrence of
  [operator, argument] -> case unLoc (occurrenceAst (inspectOccurrence operator)) of
    HsApp {} -> case expressionFields operator of
      [innerOperator, left] ->
        let firstGuard = queryFunctionSpelling innerOperator
        in if queryScalar firstGuard `elem` map Just appendNames
           then firstGuard `followedBy` appendText seen left argument
           else ordinary firstGuard operator argument
      _ -> error "SourceTextInnerApplicationFieldsUnavailable"
    _ -> ordinary (emptyProjection Nothing) operator argument
  _ -> error "SourceTextApplicationFieldsUnavailable"
 where
  ordinary prefix operator argument =
    let identityGuard = queryFunctionSpelling operator
        checkedIdentity = prefix `followedBy` identityGuard
    in if queryScalar identityGuard `elem` map Just identityNames
       then checkedIdentity `followedBy` query WholeText seen argument
       else case unLoc (occurrenceAst (inspectOccurrence argument)) of
         ExplicitList _ items ->
           let concatGuard = queryFunctionSpelling operator
               checkedConcat = checkedIdentity `followedBy` concatGuard
           in checkedConcat `followedBy` if queryScalar concatGuard `elem` map Just concatNames
              then concatenateItems seen argument (listItems argument items)
              else terminal concatGuard
         _ -> checkedIdentity `followedBy` terminal identityGuard
  terminal result = case queryScalar result of
    Just name -> withIssue (UnrecognizedTextOperation name)
    Nothing -> withIssue (UnsupportedTextConstructor "HsApp")

concatenateItems :: AliasRoute -> LexicalOccurrence -> [LexicalOccurrence] -> QueryProjection
concatenateItems seen list items =
  (emptyProjection Nothing) {queryDependencies = [InspectedExplicitList (occurrenceId (inspectOccurrence list))]}
    `followedBy` go items
 where
  go [] = emptyProjection (Just "")
  go (item : remaining) =
    let first = query WholeText seen item
    in case queryScalar first of
      Nothing -> first
      Just prefix -> let rest = go remaining
        in (first `followedBy` rest) {queryScalar = (prefix <>) <$> queryScalar rest}

characterList :: [LexicalOccurrence] -> QueryProjection
characterList [] = emptyProjection (Just "")
characterList (item : remaining) =
  let view = inspectOccurrence item
      prefix = (emptyProjection Nothing) {queryDependencies = [ProbedCharacter (occurrenceId view)]}
  in prefix `followedBy` case unLoc (occurrenceAst view) of
    HsLit _ (HsChar _ character) ->
      let rest = characterList remaining
      in rest {queryScalar = Text.cons character <$> queryScalar rest,
          queryLiteralOrigins = occurrenceId view : queryLiteralOrigins rest}
    _ -> withIssue (NonCharacterElement (occurrenceId view))

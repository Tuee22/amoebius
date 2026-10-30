{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | Independent relational interpretation of complete native parser inputs.
-- This module imports neither product nor validator code. Its occurrence and
-- scope tables are derived afresh from the separately parsed complete module.
module StaticTextExpected
  ( parseReference, referenceModuleName, referenceRows, referenceScalarContract, referenceCompatibilityRows, referenceCompatibilitySummary, referenceCompatibilityFacts, referenceEmptyLetGroups ) where

import Data.Data (Data, Typeable, cast, gmapQ, gmapT, showConstr, toConstr, typeOf)
import Data.Foldable (toList)
import Data.ByteString qualified as Bytes
import Data.Char (isUpper)
import Data.List (foldl', isPrefixOf, nub, sort, stripPrefix)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe,mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import GHC.Data.EnumSet qualified as EnumSet
import GHC.Data.FastString (FastString, mkFastString, unpackFS)
import GHC.Data.StringBuffer (stringToStringBuffer)
import GHC.Hs
import GHC.Hs.Instances ()
import GHC.Hs.Utils (CollectFlag (..), collectPatBinders)
import GHC.LanguageExtensions.Type qualified as Extension
import GHC.Parser (parseModule)
import GHC.Parser.Header (getOptions)
import GHC.Parser.Lexer (ParseResult (..), initParserState, mkParserOpts, unP)
import GHC.Utils.Error (emptyDiagOpts)
import GHC.Types.PkgQual (RawPkgQual (..))
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.Name.Reader (RdrName (..), rdrNameOcc)
import GHC.Types.SrcLoc (GenLocated (..), SrcSpan, mkRealSrcLoc, mkSrcLoc, mkSrcSpan, noSrcSpan, unLoc)
import GHC.Parser.Annotation (LocatedN, getLocA)
import GHC.Unit.Module (moduleNameString)
import Numeric.Natural (Natural)

-- These are oracle-local wire spellings, not imported product constructors.
data AstStep = DataChild Natural | ExpressionPayload deriving (Eq, Ord, Show)
newtype AstPath = AstPath [AstStep] deriving (Eq, Ord, Show)
newtype OccurrenceId = OccurrenceId [Natural] deriving (Eq, Ord, Show)
newtype ScopeId = ScopeId Natural deriving (Eq, Ord, Show)
data DeclarationId = DeclarationId ScopeId Natural deriving (Eq, Ord, Show)
newtype ImportId = ImportId Natural deriving (Eq, Ord, Show)
data ParameterHitId = ParameterHitId AstPath Natural deriving (Eq, Ord, Show)
data QueryKind = WholeText | FunctionSpelling deriving (Eq, Ord, Show)
data Dependency = Requested QueryKind OccurrenceId | Followed DeclarationId OccurrenceId
  | ProbedCharacter OccurrenceId | InspectedExplicitList OccurrenceId deriving (Eq, Show)
data LookupSource = DeclarationLookup (NonEmpty DeclarationId)
  | ParameterShadowLookup (NonEmpty ParameterHitId) deriving (Eq, Show)
data QueryIssue = UnknownTextName Text | NonValueLookup LookupSource
  | DuplicateDeclarations (NonEmpty DeclarationId)
  | SpanCycleCutoff (NonEmpty DeclarationId) (NonEmpty OccurrenceId)
  | UnsupportedTextConstructor Text | UnsupportedHeadConstructor Text
  | UnrecognizedTextOperation Text | NonCharacterElement OccurrenceId
  | AmbiguousQualifierAlternatives (NonEmpty ImportId) deriving (Eq, Show)
data QueryProjection = QueryProjection
  { queryScalar :: Maybe Text, queryDependencies :: [Dependency]
  , queryLiteralOrigins :: [OccurrenceId], queryIssues :: [QueryIssue]
  } deriving (Eq, Show)

type Path = [AstStep]
type Sink = (Text, Text, Text, Text, [(Int, Text)])
data Event = Expression Path (Maybe Path) (LHsExpr GhcPs)
  | MatchRegion Path (Match GhcPs (LHsExpr GhcPs))
  | LetRegion Path (HsLocalBindsLR GhcPs GhcPs)
data RefOccurrence = RefOccurrence Path OccurrenceId ScopeId (LHsExpr GhcPs)
data Scope = Scope ScopeId Path (Maybe ScopeId) [(Text, Binding)]
data Binding = Declarations (NonEmpty DeclarationId) (Maybe Path)
  | Parameters (NonEmpty ParameterHitId)
data Import = Import ImportId Text Text (ImportDecl GhcPs)
data ReferenceModule = ReferenceModule (HsModule GhcPs) [String]

data Model = Model
  { occurrences :: Map.Map Path RefOccurrence
  , environments :: Map.Map ScopeId (Map.Map Text Binding)
  , imports :: [Import]
  }

-- Strict UTF-8 decoding precedes the parser. Both pragma discovery and native
-- parsing consume this exact immutable byte string, with its original filename.
parseReference :: FilePath -> Bytes.ByteString -> Either Text ReferenceModule
parseReference path bytes = do
  source <- either (const (Left "HaskellSourceEncodingInvalid")) Right (Encoding.decodeUtf8' bytes)
  let buffer = stringToStringBuffer (Text.unpack source)
      options = map unLoc (snd (getOptions baseOptions buffer path))
      enabled = foldl' pragma (Set.fromList baseExtensions) options
      state = initParserState (parserOptions (Set.toList enabled)) buffer
        (mkRealSrcLoc (mkFastString path) 1 1)
  case unP parseModule state of
    PFailed _ -> Left "HaskellSourceUnparsable"
    POk _ located -> Right (ReferenceModule (unLoc located) options)
 where
  baseExtensions = [Extension.PackageImports, Extension.PatternSynonyms, Extension.TemplateHaskell,
    Extension.TemplateHaskellQuotes, Extension.ForeignFunctionInterface]
  baseOptions = parserOptions baseExtensions
  parserOptions extensions = mkParserOpts (EnumSet.fromList extensions) emptyDiagOpts
    (["GHC2024", "GHC2021", "Haskell2010", "Haskell98"]
      <> concat [[show extension, "No" <> show extension] | extension <- allExtensions])
    False False False False
  allExtensions = [minBound .. maxBound] :: [Extension.Extension]
  pragma enabled option = case stripPrefix "-XNo" option of
    Just name | Just extension <- lookup name [(show item,item) | item <- allExtensions] -> Set.delete extension enabled
    _ -> case stripPrefix "-X" option of
      Just name | Just extension <- lookup name [(show item,item) | item <- allExtensions] -> Set.insert extension enabled
      _ -> enabled

referenceModuleName :: ReferenceModule -> Text
referenceModuleName (ReferenceModule tree _) = moduleNameOf tree

moduleNameOf :: HsModule GhcPs -> Text
moduleNameOf tree = maybe "Main" (Text.pack . moduleNameString . unLoc) (hsmodName tree)

-- First enumerate immutable structural events, without allocating a scope or
-- following a declaration. Relations between those events supply the model.
events :: Data value => Path -> Maybe Path -> value -> [Event]
events path parent value
  | Just expression <- cast value :: Maybe (LHsExpr GhcPs) =
      Expression path parent expression :
        [LetRegion path locals | HsLet _ locals _ <- [unLoc expression]] <> case unLoc expression of
          HsLit {} -> []
          HsOverLit {} -> []
          payload -> children (path <> [ExpressionPayload]) (Just path) payload
  | Just _ <- cast value :: Maybe FastString = []
  | Just _ <- cast value :: Maybe RdrName = []
  | Just match <- cast value :: Maybe (Match GhcPs (LHsExpr GhcPs)) =
      MatchRegion path match : children path parent value
  | otherwise = children path parent value
 where
  children :: Data child => Path -> Maybe Path -> child -> [Event]
  children base nearest node = concat
    [descend (base <> [DataChild index]) nearest
    | (index,descend) <- zip [0 ..] (gmapQ (\child p outer -> events p outer child) node)]

field :: (Data parent, Typeable child) => Path -> parent -> child -> Path
field path parent witness = case
  [index | (index,True) <- zip [0 ..] (gmapQ (\child -> typeOf child == typeOf witness) parent)] of
  [index] -> path <> [DataChild index]
  _ -> error "IndependentStaticTextFieldAmbiguous"

locatedPath :: (Data annotation, Data value) => Path -> GenLocated annotation value -> Path
locatedPath path value = field path value (unLoc value)

listPaths :: Data item => Path -> [item] -> [(Path,item)]
listPaths _ [] = []
listPaths path values@(item:rest) = (field path values item,item) : listPaths (field path values rest) rest

topBindings :: HsModule GhcPs -> [(Path, HsBindLR GhcPs GhcPs)]
topBindings tree =
  [(field (locatedPath path located) declaration bind,bind)
  | (path,located) <- listPaths (field [] tree (hsmodDecls tree)) (hsmodDecls tree)
  , let declaration=unLoc located, ValD _ bind <- [declaration]]

localBindings :: Path -> HsLocalBindsLR GhcPs GhcPs -> [(Path,HsBindLR GhcPs GhcPs)]
localBindings path locals = case locals of
  HsValBinds _ values@(ValBinds _ binds _) ->
    [(locatedPath bindingPath located,unLoc located)
    | (bindingPath,located) <- listPaths (field (field path locals values) values binds) binds]
  _ -> []

valuePath :: Path -> HsBindLR GhcPs GhcPs -> Maybe Path
valuePath path bind = case bind of
  FunBind {fun_matches=matches}
    | [locatedMatch] <- unLoc (mg_alts matches)
    , match@Match {m_pats=patterns,m_grhss=rhsGroup@GRHSs {grhssGRHSs=[locatedRhs]}} <- unLoc locatedMatch
    , null (unLoc patterns), rhs@(GRHS _ [] body) <- unLoc locatedRhs ->
        let alternatives=field (field path bind matches) matches (mg_alts matches)
            matchPath=locatedPath (fst (head (listPaths (locatedPath alternatives (mg_alts matches)) (unLoc (mg_alts matches))))) locatedMatch
            groupPath=field matchPath match rhsGroup
            rhsPath=locatedPath (fst (head (listPaths (field groupPath rhsGroup (grhssGRHSs rhsGroup)) (grhssGRHSs rhsGroup)))) locatedRhs
        in Just (field rhsPath rhs body)
  _ -> Nothing

parameterNames :: [LPat GhcPs] -> [RdrName]
parameterNames = collect
 where
  collect :: Data value => value -> [RdrName]
  collect value = case cast value :: Maybe (LPat GhcPs) of
    Just (L _ (VarPat _ name)) -> [unLoc name]
    _ -> concat (gmapQ collect value)

makeModel :: HsModule GhcPs -> (Model,[RefOccurrence])
makeModel tree = (model,ordered)
 where
  sourceEvents=events [] Nothing tree
  importList=
    [Import (ImportId index) qualifier module_ declaration
    | (index,located) <- zip [0 ..] (hsmodImports tree)
    , let declaration=unLoc located
          module_=Text.pack (moduleNameString (unLoc (ideclName declaration)))
          qualifier=maybe module_ (Text.pack . moduleNameString . unLoc) (ideclAs declaration)]
  root=Scope (ScopeId 0) [] Nothing (declarationEntries (ScopeId 0) (Just (moduleNameOf tree)) (topBindings tree))
  regions=concatMap region sourceEvents
  region event=case event of
    Expression {} -> []
    LetRegion path locals ->
      let entries=localBindings (field (path<>[ExpressionPayload]) (expressionAt path) locals) locals
      in [(path,False,entries,[]) | not (null entries)]
    MatchRegion path match ->
      let rhs= m_grhss match; locals=grhssLocalBinds rhs
          entries=localBindings (field (field path match rhs) rhs locals) locals
      in (path,True,[],parameterNames (unLoc (m_pats match))) : [(path,False,entries,[]) | not (null entries)]
  expressionAt path=case [unLoc expression | Expression found _ expression<-sourceEvents,found==path] of
    [expression]->expression
    _->error "IndependentStaticTextExpressionUnavailable"
  scopes=foldl' appendScope [root] (zip [1 ..] regions)
  appendScope previous (index,(path,isParameters,entries,names)) =
    let identifier=ScopeId index
        outer=case reverse [key | Scope key regionPath _ _<-previous,regionPath `isPrefixOf` path] of
          key:_->key
          []->error "IndependentStaticTextOuterScopeUnavailable"
        own=if isParameters
          then [(fst (nameProjection importList name),Parameters (ParameterHitId (AstPath path) ordinal :| [])) | (ordinal,name)<-zip [0 ..] names]
          else declarationEntries identifier Nothing entries
    in previous<>[Scope identifier path (Just outer) own]
  declarationEntries identifier current entries =
    [(key,Declarations (DeclarationId identifier index :| []) (valuePath path bind))
    | (index,(path,bind))<-zip [0 ..] entries, FunBind {fun_id=name} <- [bind]
    , let key_=fst (nameProjection importList (unLoc name))
    , key<-key_:[module_<>"."<>key_ | Just module_<-[current]]]
  environment=foldl' addEnvironment Map.empty scopes
  addEnvironment previous (Scope key _ outer entries)=Map.insert key
    (Map.union (Map.fromListWith joinBinding entries) (maybe Map.empty (\parent->required parent previous) outer)) previous
  joinBinding (Declarations newer _) (Declarations older _)=Declarations (older<>newer) Nothing
  joinBinding (Parameters newer) (Parameters older)=Parameters (older<>newer)
  joinBinding _ _=error "IndependentStaticTextMixedBindingScope"
  expressionEvents=[(path,parent,expression) | Expression path parent expression<-sourceEvents]
  identifiers=fst (foldl' addIdentifier (Map.empty,Map.empty) expressionEvents)
  addIdentifier (known,counters) (path,parent,_) =
    let rank=Map.findWithDefault 0 parent counters
        ancestor=maybe [] (\key->case required key known of OccurrenceId values->values) parent
    in (Map.insert path (OccurrenceId (ancestor<>[rank])) known,Map.insert parent (rank+1) counters)
  ordered=[RefOccurrence path (required path identifiers) (scopeFor path) expression | (path,_,expression)<-expressionEvents]
  scopeFor path=case reverse [identifier | Scope identifier regionPath _ _<-scopes,regionPath `isPrefixOf` path] of
    identifier:_->identifier
    []->error "IndependentStaticTextOccurrenceScopeUnavailable"
  model=Model (Map.fromList [(path,occurrence) | occurrence@(RefOccurrence path _ _ _)<-ordered]) environment importList

required :: Ord key => key -> Map.Map key value -> value
required key values=case Map.lookup key values of
  Just value->value
  Nothing->error "IndependentStaticTextRelationUnavailable"

nameProjection :: [Import] -> RdrName -> (Text,[QueryIssue])
nameProjection imports_ reader=case reader of
  Qual qualifier occurrence->
    let key=Text.pack (moduleNameString qualifier)
        alternatives=[(identifier,module_) | Import identifier spelling module_ _<-imports_,spelling==key]
        chosen=case reverse alternatives of (_,module_):_->module_;[]->key
    in (chosen<>"."<>Text.pack (occNameString occurrence),
        case map fst alternatives of first:second:rest->[AmbiguousQualifierAlternatives (first :| (second : rest))];_->[])
  _->(Text.pack (occNameString (rdrNameOcc reader)),[])

empty :: Maybe Text -> QueryProjection
empty scalar=QueryProjection scalar [] [] []
issue :: QueryIssue -> QueryProjection
issue item=(empty Nothing) {queryIssues=[item]}
sequenceProjection :: QueryProjection -> QueryProjection -> QueryProjection
sequenceProjection left right=right
  {queryDependencies=queryDependencies left<>queryDependencies right
  ,queryLiteralOrigins=queryLiteralOrigins left<>queryLiteralOrigins right
  ,queryIssues=queryIssues left<>queryIssues right}

type Route = [(DeclarationId,OccurrenceId,SrcSpan)]
query :: Model -> QueryKind -> Route -> RefOccurrence -> QueryProjection
query model kind route occurrence@(RefOccurrence _ identifier _ expression)=
  sequenceProjection ((empty Nothing) {queryDependencies=[Requested kind identifier]}) $ case kind of
    FunctionSpelling->case unLoc expression of
      HsVar _ name->lookupName model kind route occurrence (unLoc name)
      HsPar {}->query model kind route (singleField model occurrence)
      payload->issue (UnsupportedHeadConstructor (constructor payload))
    WholeText->wholeText model route occurrence

lookupName :: Model -> QueryKind -> Route -> RefOccurrence -> RdrName -> QueryProjection
lookupName model kind route (RefOccurrence _ _ scope _) reader =
  sequenceProjection ((empty Nothing) {queryIssues=ambiguities}) resolution
 where
  (key,ambiguities)=nameProjection (imports model) reader
  resolution=case Map.lookup key (required scope (environments model)) of
    Nothing->if kind==FunctionSpelling then empty (Just key) else issue (UnknownTextName key)
    Just (Parameters hits)->issue (NonValueLookup (ParameterShadowLookup hits))
    Just (Declarations identifiers body)->case NonEmpty.toList identifiers of
      [declaration]->case body of
        Nothing->issue (NonValueLookup (DeclarationLookup identifiers))
        Just targetPath->
          let target@(RefOccurrence _ identifier _ located)=required targetPath (occurrences model)
              span_=getLocA located
              next=route<>[(declaration,identifier,span_)]
              prefix=(empty Nothing) {queryDependencies=[Followed declaration identifier]}
          in sequenceProjection prefix (if span_ `elem` [previous | (_,_,previous)<-route]
            then issue (SpanCycleCutoff (NonEmpty.fromList [item | (item,_,_)<-next]) (NonEmpty.fromList [item | (_,item,_)<-next]))
            else query model kind next target)
      _->issue (DuplicateDeclarations identifiers)

constructor :: Data value => value -> Text
constructor=Text.pack . showConstr . toConstr
expressionFields :: Model -> RefOccurrence -> [RefOccurrence]
expressionFields model (RefOccurrence path _ _ located)=
  [required (path<>[ExpressionPayload,DataChild index]) (occurrences model)
  | (index,Just _) <- zip [0 ..] (gmapQ (\value->cast value :: Maybe (LHsExpr GhcPs)) (unLoc located))]
singleField :: Model -> RefOccurrence -> RefOccurrence
singleField model occurrence=case expressionFields model occurrence of
  [field_]->field_
  _->error "IndependentStaticTextSingleExpressionUnavailable"
listFields :: Model -> RefOccurrence -> [LHsExpr GhcPs] -> [RefOccurrence]
listFields model (RefOccurrence path _ _ located) items=
  [required at (occurrences model) | (at,_)<-listPaths (field (path<>[ExpressionPayload]) (unLoc located) items) items]

appendNames, identityNames, concatNames :: [Text]
appendNames=["++","<>","mappend","Prelude.++","Prelude.<>","Prelude.mappend","Data.Text.append"]
identityNames=["id","Prelude.id","Data.Text.pack","Data.Text.unpack"]
concatNames=["concat","mconcat","Prelude.concat","Prelude.mconcat","Data.Text.concat"]

wholeText :: Model -> Route -> RefOccurrence -> QueryProjection
wholeText model route occurrence@(RefOccurrence _ identifier _ located)=case unLoc located of
  HsLit _ (HsString _ literal)->literalValue (Text.pack (unpackFS literal))
  HsLit _ (HsMultilineString _ literal)->literalValue (Text.pack (unpackFS literal))
  HsOverLit _ OverLit {ol_val=HsIsString _ literal}->literalValue (Text.pack (unpackFS literal))
  HsVar _ name->lookupName model WholeText route occurrence (unLoc name)
  HsPar {}->query model WholeText route (singleField model occurrence)
  ExprWithTySig {}->query model WholeText route (singleField model occurrence)
  HsLet {}->query model WholeText route (singleField model occurrence)
  OpApp {}->case expressionFields model occurrence of
    [left,operator,right]->let guard_=query model FunctionSpelling [] operator in
      sequenceProjection guard_ (if queryScalar guard_ `elem` map Just appendNames then appendValues left right else terminal guard_)
    _->error "IndependentStaticTextOperatorFieldsUnavailable"
  HsApp {}->application
  ExplicitList _ items->characters (listFields model occurrence items)
  payload->issue (UnsupportedTextConstructor (constructor payload))
 where
  literalValue value=(empty (Just value)) {queryLiteralOrigins=[identifier]}
  terminal guard_=case queryScalar guard_ of
    Just name->issue (UnrecognizedTextOperation name)
    Nothing->issue (UnsupportedTextConstructor (constructor (unLoc located)))
  appendValues left right=let first=query model WholeText route left in case queryScalar first of
    Nothing->first
    Just value->let second=query model WholeText route right in
      (sequenceProjection first second) {queryScalar=(value<>) <$> queryScalar second}
  application=case expressionFields model occurrence of
    [operator,argument]->case unLoc (ast operator) of
      HsApp {}->case expressionFields model operator of
        [inner,left]->let guard_=query model FunctionSpelling [] inner in
          if queryScalar guard_ `elem` map Just appendNames
            then sequenceProjection guard_ (appendValues left argument)
            else ordinary guard_ operator argument
        _->error "IndependentStaticTextInnerApplicationUnavailable"
      _->ordinary (empty Nothing) operator argument
    _->error "IndependentStaticTextApplicationFieldsUnavailable"
  ordinary prefix operator argument=
    let guard_=query model FunctionSpelling [] operator; checked=sequenceProjection prefix guard_ in
    if queryScalar guard_ `elem` map Just identityNames
      then sequenceProjection checked (query model WholeText route argument)
      else case unLoc (ast argument) of
        ExplicitList _ items->
          let second=query model FunctionSpelling [] operator; both=sequenceProjection checked second in
          sequenceProjection both (if queryScalar second `elem` map Just concatNames
            then sequenceProjection ((empty Nothing) {queryDependencies=[InspectedExplicitList (identifierOf argument)]}) (concatenateValues (listFields model argument items))
            else applicationTerminal second)
        _->sequenceProjection checked (applicationTerminal guard_)
  applicationTerminal guard_=case queryScalar guard_ of
    Just name->issue (UnrecognizedTextOperation name)
    Nothing->issue (UnsupportedTextConstructor "HsApp")
  concatenateValues []=empty (Just "")
  concatenateValues (item:rest)=let first=query model WholeText route item in case queryScalar first of
    Nothing->first
    Just prefix->let next=concatenateValues rest in (sequenceProjection first next) {queryScalar=(prefix<>) <$> queryScalar next}
  characters []=empty (Just "")
  characters (item:rest)=
    let prefix=(empty Nothing) {queryDependencies=[ProbedCharacter (identifierOf item)]} in
    sequenceProjection prefix (case unLoc (ast item) of
      HsLit _ (HsChar _ character)->let next=characters rest in next
        {queryScalar=Text.cons character <$> queryScalar next,queryLiteralOrigins=identifierOf item:queryLiteralOrigins next}
      _->issue (NonCharacterElement (identifierOf item)))

ast :: RefOccurrence -> LHsExpr GhcPs
ast (RefOccurrence _ _ _ located)=located
identifierOf :: RefOccurrence -> OccurrenceId
identifierOf (RefOccurrence _ identifier _ _)=identifier
pathOf :: RefOccurrence -> AstPath
pathOf (RefOccurrence path _ _ _)=AstPath path

applicationSpine :: Model -> RefOccurrence -> Maybe (RefOccurrence,[RefOccurrence])
applicationSpine model occurrence=case unLoc (ast occurrence) of
  HsApp {}->case expressionFields model occurrence of
    [function,argument]->Just (flatten function [argument])
    _->error "IndependentStaticTextSpineUnavailable"
  _->Nothing
 where
  flatten function arguments=case unLoc (ast function) of
    HsApp {}->case expressionFields model function of
      [inner,argument]->flatten inner (argument:arguments)
      _->error "IndependentStaticTextSpineChildUnavailable"
    HsPar {}->flatten (singleField model function) arguments
    _->(function,arguments)

-- The oracle resolves catalogue membership from its own import facts and its
-- independently authored sink catalogue. No product graph/provider row is read.
referenceRows :: [Sink] -> [Text] -> FilePath -> ReferenceModule -> [Text]
referenceRows catalogue sourceModules path native =
  [Text.pack (show (path,identifierOf use,pathOf use,getLocA (ast use),
      (target,spelling),module_,name,kind,position,role,identifierOf argument,pathOf argument,
      headProjection,argumentProjection))
  | (use,target,spelling,module_,name,kind,position,role,argument,headProjection,argumentProjection)
      <- referenceUses catalogue sourceModules native]

referenceScalarContract :: [Sink] -> [Text] -> ReferenceModule -> [(Maybe Text,[Text],Int,[Text])]
referenceScalarContract catalogue sourceModules native =
  [projectionContract projection | (_,_,_,_,_,_,_,_,_,_,projection) <- referenceUses catalogue sourceModules native]

projectionContract :: QueryProjection -> (Maybe Text,[Text],Int,[Text])
projectionContract projection=(queryScalar projection,map dependencyTag (queryDependencies projection),
    length (queryLiteralOrigins projection),map issueTag (queryIssues projection))
 where
  dependencyTag dependency=case dependency of
    Requested kind _->case kind of WholeText->"text";FunctionSpelling->"head"
    Followed {}->"follow"
    ProbedCharacter {}->"character"
    InspectedExplicitList {}->"list"
  issueTag problem=case problem of
    UnknownTextName {}->"unknown"
    NonValueLookup {}->"nonvalue"
    DuplicateDeclarations {}->"duplicate"
    SpanCycleCutoff {}->"cycle"
    UnsupportedTextConstructor {}->"unsupported-text"
    UnsupportedHeadConstructor {}->"unsupported-head"
    UnrecognizedTextOperation {}->"operation"
    NonCharacterElement {}->"non-character"
    AmbiguousQualifierAlternatives {}->"ambiguous-qualifier"

-- Explicit supplied-value scope. These observations provide no native byte or
-- filesystem claim, and the native capture reference never calls this adapter.
referenceCompatibilityRows :: Text -> ReferenceModule -> Either Text [Text]
referenceCompatibilityRows flavor native = do
  ReferenceModule tree _ <- suppliedLocations flavor native
  let (model,ordered)=makeModel tree
  pure [Text.pack (show (identifier,pathOf occurrence,getLocA located,scope,
        query model FunctionSpelling [] occurrence,query model WholeText [] occurrence))
    | occurrence@(RefOccurrence _ identifier scope located)<-ordered]

referenceCompatibilityFacts :: Text -> ReferenceModule -> Either Text ([Text],[Text],[Text])
referenceCompatibilityFacts flavor native = do
  ReferenceModule tree _ <- suppliedLocations flavor native
  let (_,ordered)=makeModel tree
  pure (map (Text.pack.show.identifierOf) ordered,map (Text.pack.show.pathOf) ordered,
    map (Text.pack.show.getLocA.ast) ordered)

referenceCompatibilitySummary :: Text -> ReferenceModule -> Either Text (Maybe Text,[Text],Int,[Text])
referenceCompatibilitySummary flavor native = do
  ReferenceModule tree _ <- suppliedLocations flavor native
  let (model,ordered)=makeModel tree
  case ordered of
    first:_->pure (projectionContract (query model WholeText [] first))
    []->Left "IndependentCompatibilityExpressionsMissing"

-- The empty match group precedes its RHS's empty let group. Both paths come
-- from this independently parsed typed value, without reading product facts.
referenceEmptyLetGroups :: Text -> ReferenceModule -> Either Text [(Text,Text,Maybe Text,Int)]
referenceEmptyLetGroups flavor native=do
  ReferenceModule tree _<-suppliedLocations flavor native
  let sourceEvents=events [] Nothing tree
      matches=[(path,match) | MatchRegion path match<-sourceEvents]
      expressions=[(path,expression) | Expression path _ expression<-sourceEvents]
  case (matches,expressions) of
    ([(matchPath,match)],[(expressionPath,located),_])
      | payload@(HsLet _ locals _)<-unLoc located->
          let rhs=m_grhss match
              outerLocals=grhssLocalBinds rhs
              outerPath=field (field matchPath match rhs) rhs outerLocals
              innerPath=field (expressionPath<>[ExpressionPayload]) payload locals
              emptyGroups=null (localBindings outerPath outerLocals) && null (localBindings innerPath locals)
          in if emptyGroups then Right
               [(Text.pack (show (AstPath outerPath)),constructor outerLocals,Nothing,0)
               ,(Text.pack (show (AstPath innerPath)),constructor locals,Nothing,0)]
             else Left "IndependentEmptyLetDeclarationsPresent"
    _->Left "IndependentEmptyLetShapeMismatch"

suppliedLocations :: Text -> ReferenceModule -> Either Text ReferenceModule
suppliedLocations flavor (ReferenceModule tree options)=case flavor of
  "PreserveSuppliedSpans"->Right (ReferenceModule tree options)
  "ShareHelpfulSpans"->Right (ReferenceModule (replaceLocations shared tree) options)
  "RemoveHelpfulSpans"->Right (ReferenceModule (replaceLocations noSrcSpan tree) options)
  _->Left "IndependentCompatibilitySpanModeUnknown"
 where shared=mkSrcSpan (mkSrcLoc (mkFastString "Shared.hs") 1 1) (mkSrcLoc (mkFastString "Shared.hs") 1 2)

replaceLocations :: Data value => SrcSpan -> value -> value
replaceLocations location value=case cast value :: Maybe SrcSpan of
  Just _->fromMaybe (error "IndependentCompatibilitySpanTypeUnavailable") (cast location)
  Nothing->case (cast value :: Maybe FastString,cast value :: Maybe RdrName) of
    (Just _,_)->value
    (_,Just _)->value
    _->gmapT (replaceLocations location) value

type ReferenceUse = (RefOccurrence,Text,Text,Text,Text,Text,Int,Text,RefOccurrence,QueryProjection,QueryProjection)
referenceUses :: [Sink] -> [Text] -> ReferenceModule -> [ReferenceUse]
referenceUses catalogue sourceModules (ReferenceModule tree options)=
  [(use,target,spelling,module_,name,kind,position,role,argument,
      headProjection,query model WholeText [] argument)
  | use<-ordered, Just (head_,arguments)<-[applicationSpine model use]
  , let headProjection=query model FunctionSpelling [] head_
  , Just target<-[queryScalar headProjection]
  , spelling<-nub (target:[qualifier<>"."<>suffix | Import _ qualifier module_ _<-imports model,Just suffix<-[Text.stripPrefix (module_<>".") target]])
  , (module_,name,kind,_,positions)<-resolved spelling
  , (position,role)<-positions
  , (index,argument)<-zip [0 ..] arguments,index==position]
 where
  (model,ordered)=makeModel tree
  implicitPrelude=not (any ((=="Prelude").importModule) (imports model))
    && not (any (`elem` options) ["-XNoImplicitPrelude","-XRebindableSyntax"])
  importModule (Import _ _ module_ _)=module_
  resolved target=Map.elems (Map.fromListWith prefer
    [(entity,row) | row@(_,_,_,entity,_)<-matching target])
  prefer a@(left,_,_,_,_) b@(right,_,_,_,_)=if left<=right then a else b
  matching target=
    [row | Import _ qualifier module_ declaration<-imports model
    , NoRawPkgQual<-[ideclPkgQual declaration],module_ `notElem` sourceModules
    , row@(candidate,name,_,_,_)<-catalogue,candidate==module_
    , importedValue qualifier declaration target==Just name]
    <> [row | implicitPrelude,not (qualified target),target `notElem` topNames
       ,row@(module_,name,_,_,_)<-catalogue,module_=="Prelude",name==target]
  topNames=concatMap (declarationValues . unLoc) (hsmodDecls tree)
  declarationValues declaration=case declaration of
    ValD _ binding->bindingValues binding
    TyClD _ DataDecl {tcdDataDefn=definition}->concatMap constructorValues (toList (dd_cons definition))
    TyClD _ ClassDecl {tcdSigs=signatures,tcdMeths=defaults}->
      [reader name | signature<-signatures,ClassOpSig _ _ names _<-[unLoc signature],name<-names]
        <> concatMap (bindingValues.unLoc) (toList defaults)
    ForD _ ForeignImport {fd_name=name}->[reader name]
    ForD _ ForeignExport {fd_name=name}->[reader name]
    _->[]
  bindingValues binding=case binding of
    FunBind {fun_id=name}->[reader name]
    PatBind {pat_lhs=pattern_}->map (Text.pack.occNameString.rdrNameOcc) (collectPatBinders CollNoDictBinders pattern_)
    _->[]
  constructorValues :: LConDecl GhcPs -> [Text]
  constructorValues constructor_=case unLoc constructor_ of
    ConDeclH98 {con_name=name,con_args=arguments}->reader name:case arguments of
      RecCon fields->fieldValues (unLoc fields)
      _->[]
    ConDeclGADT {con_names=names,con_g_args=arguments}->map reader (NonEmpty.toList names)<>case arguments of
      RecConGADT _ fields->fieldValues (unLoc fields)
      _->[]
  fieldValues fields=[reader (foLabel (unLoc name)) | field_<-fields,name<-cd_fld_names (unLoc field_)]
  reader name=Text.pack (occNameString (rdrNameOcc (unLoc name)))
  importedValue qualifier declaration target=do
    name<-case Text.stripPrefix (qualifier<>".") target of
      Just value | not (Text.null value)->Just value
      _ | ideclQualified declaration==NotQualified && not (qualified target)->Just target
      _->Nothing
    case ideclImportList declaration of
      Nothing->Just name
      Just (Exactly,located)->if name `elem` mapMaybe valueImport (unLoc located) then Just name else Nothing
      Just (EverythingBut,located)->case traverse valueImport (unLoc located) of
        Just hidden | name `notElem` hidden->Just name
        _->Nothing
  valueImport located=case unLoc located of
    IEVar _ wrapped _->Just (Text.pack (occNameString (rdrNameOcc (unLoc (wrappedName (unLoc wrapped))))))
    _->Nothing
  wrappedName :: IEWrappedName GhcPs -> LocatedN RdrName
  wrappedName wrapped=case wrapped of
    IEName _ name->name
    IEDefault _ name->name
    IEPattern _ name->name
    IEType _ name->name
  qualified text=case Text.uncons text of Just (first,_)->isUpper first && "." `Text.isInfixOf` text;Nothing->False

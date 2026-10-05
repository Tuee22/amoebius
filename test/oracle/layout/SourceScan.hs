{-# LANGUAGE OverloadedStrings #-}

-- | A deliberately small, separately authored reading of Haskell source text for the
-- layout oracle. It shares no code with the product's parser: it blanks comments and
-- literals, then reads identifiers, imports, and declaration heads from what remains.
-- Every function here is total over arbitrary text and makes no claim outside the
-- forms this repository's sources use.
module SourceScan
  ( ImportStatement (..)
  , blankSource
  , derivedClassCount
  , identifierTokens
  , importStatements
  , instanceDeclarationCount
  , languagePragmaEnabled
  , newtypeRepresentation
  , sinkHits
  , sliceSpan
  , useArguments
  , standaloneDerivingCount
  , declaredAsNewtype
  ) where

import Data.Char (isAlphaNum, isDigit, isSpace, isUpper)
import Data.Maybe (fromMaybe, isJust, listToMaybe, mapMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- | Comments, string literals, and character literals become spaces; newlines stay,
-- so every remaining character keeps its original line and column.
blankSource :: Text -> Text
blankSource = Text.pack . scan ' ' (0 :: Int) . Text.unpack
 where
  scan _ _ [] = []
  scan previous depth chars@(c : rest)
    | depth > 0 = case chars of
        '{' : '-' : more -> "  " <> scan ' ' (depth + 1) more
        '-' : '}' : more -> "  " <> scan ' ' (depth - 1) more
        _ -> blank c : scan ' ' depth rest
    | otherwise = case chars of
        '{' : '-' : more -> "  " <> scan ' ' 1 more
        '-' : '-' : more | lineComment more ->
          let (comment, remaining) = break (== '\n') more
          in replicate (2 + length comment) ' ' <> scan ' ' 0 remaining
        '"' : more ->
          let (consumed, remaining) = stringBody more
          in ' ' : map blank consumed <> scan ' ' 0 remaining
        '\'' : more | not (identifierChar previous), Just width <- characterLiteral more ->
          replicate (1 + width) ' ' <> scan ' ' 0 (drop width more)
        _ -> c : scan c 0 rest
  blank character = if character == '\n' then '\n' else ' '
  lineComment more = case dropWhile (== '-') more of
    next : _ -> next `notElem` ("!#$%&*+./<=>?@\\^|~:" :: String)
    [] -> True
  stringBody = loop []
   where
    loop accumulated ('\\' : escaped : remaining) = loop (escaped : '\\' : accumulated) remaining
    loop accumulated ('"' : remaining) = (reverse ('"' : accumulated), remaining)
    loop accumulated (character : remaining) = loop (character : accumulated) remaining
    loop accumulated [] = (reverse accumulated, [])
  characterLiteral more = case more of
    '\\' : escaped -> case break (== '\'') (drop 1 escaped) of
      (body, '\'' : _) | length body <= 8 -> Just (1 + 1 + length body + 1)
      _ -> Nothing
    character : '\'' : _ | character /= '\\', character /= '\'' -> Just 2
    _ -> Nothing

identifierChar :: Char -> Bool
identifierChar character = isAlphaNum character || character == '_' || character == '\''

identifierStart :: Char -> Bool
identifierStart character = (isAlphaNum character && not (isDigit character)) || character == '_'

-- | Identifiers, with a module qualifier when one precedes them, in source order with
-- their one-based line number.
identifierTokens :: Text -> [(Int, Text)]
identifierTokens source =
  [(number, token) | (number, line) <- zip [1 ..] (Text.lines source), token <- lineTokens (Text.unpack line)]
 where
  lineTokens [] = []
  lineTokens chars@(c : rest)
    | identifierStart c = let (token, remaining) = qualifiedName chars in Text.pack token : lineTokens remaining
    | isDigit c = lineTokens (dropWhile identifierChar chars)
    | otherwise = lineTokens rest

qualifiedName :: String -> (String, String)
qualifiedName chars =
  let (word, remaining) = span identifierChar chars
  in case (word, remaining) of
    (first : _, '.' : next : _) | isUpper first, identifierStart next ->
      let (more, remaining') = qualifiedName (drop 1 remaining) in (word <> "." <> more, remaining')
    _ -> (word, remaining)

data ImportStatement = ImportStatement
  { importModule :: Text
  , importQualified :: Bool
  , importAlias :: Maybe Text
  , importHiding :: Bool
  , importNames :: Maybe [Text]
  }
  deriving (Eq, Show)

-- | The import statements of blanked source: a statement starts at column one and
-- continues over the indented lines that follow.
importStatements :: Text -> [ImportStatement]
importStatements source = [statement | group' <- groups (Text.lines source), Just statement <- [parse group']]
 where
  groups [] = []
  groups (line : rest)
    | "import " `Text.isPrefixOf` line =
        let (continuation, remaining) = span continues rest in Text.unwords (line : continuation) : groups remaining
    | otherwise = groups rest
  continues line = case Text.uncons line of
    Just (first, _) -> isSpace first
    Nothing -> True
  parse statement =
    let tokens = importTokens (Text.unpack statement)
        afterImport = drop 1 (dropWhile (/= "import") tokens)
        (prefixWords, remaining) = span (`elem` ["safe", "qualified"]) afterImport
        prequalified = "qualified" `elem` prefixWords
    in case remaining of
      moduleName : rest ->
        let (postqualified, afterQualified) = case rest of
              "qualified" : more -> (True, more)
              _ -> (False, rest)
            (alias, afterAlias) = case afterQualified of
              "as" : name : more -> (Just (Text.pack name), more)
              _ -> (Nothing, afterQualified)
            (hiding, afterHiding) = case afterAlias of
              "hiding" : more -> (True, more)
              _ -> (False, afterAlias)
            names = case afterHiding of
              "(" : more -> Just (topLevelNames (0 :: Int) more)
              _ -> Nothing
        in Just (ImportStatement (Text.pack moduleName) (prequalified || postqualified) alias hiding names)
      [] -> Nothing
  topLevelNames _ [] = []
  topLevelNames depth (token : rest) = case token of
    "(" -> topLevelNames (depth + 1) rest
    ")" | depth == 0 -> []
        | otherwise -> topLevelNames (depth - 1) rest
    _ | depth == 0, all identifierChar token, not (null token) -> Text.pack token : topLevelNames depth rest
      | otherwise -> topLevelNames depth rest

importTokens :: String -> [String]
importTokens [] = []
importTokens chars@(c : rest)
  | isSpace c = importTokens rest
  | identifierStart c = let (token, remaining) = qualifiedName chars in token : importTokens remaining
  | c `elem` ("(),"  :: String) = [c] : importTokens rest
  | otherwise = let (symbols, remaining) = break (\x -> isSpace x || identifierStart x || x `elem` ("()," :: String)) chars
                in symbols : importTokens remaining

-- | The source with every import statement's lines blanked, so an import list does
-- not count as a use of the names it lists.
withoutImports :: Text -> Text
withoutImports source = Text.unlines (go (Text.lines source))
 where
  go [] = []
  go (line : rest)
    | "import " `Text.isPrefixOf` line =
        let (continuation, remaining) = span continues rest
        in Text.empty : map (const Text.empty) continuation <> go remaining
    | otherwise = line : go rest
  continues line = case Text.uncons line of
    Just (first, _) -> isSpace first
    Nothing -> True

-- | Whether a language pragma in the raw source enables the named extension.
languagePragmaEnabled :: Text -> Text -> Bool
languagePragmaEnabled extension source = any mentions (Text.lines source)
 where
  mentions line = "{-#" `Text.isPrefixOf` Text.stripStart line
    && "LANGUAGE" `Text.isInfixOf` line
    && extension `elem` map (Text.filter (\c -> identifierChar c)) (Text.split (\c -> c == ',' || isSpace c) line)

-- | The classes named by every deriving clause: the count of non-standalone clauses'
-- class lists.
derivedClassCount :: Text -> Int
derivedClassCount = sum . map (either (const 0) id) . derivingForms

-- | The number of standalone deriving declarations.
standaloneDerivingCount :: Text -> Int
standaloneDerivingCount = length . filter (either id (const False)) . derivingForms

-- | One entry per @deriving@ keyword: Left for a standalone declaration, Right with
-- the number of classes in a clause.
derivingForms :: Text -> [Either Bool Int]
derivingForms source = go (importTokens (Text.unpack source))
 where
  go [] = []
  go ("deriving" : rest) =
    let afterStrategy = skipStrategy rest
    in case afterStrategy of
      "instance" : more -> Left True : go more
      "(" : more ->
        let (inside, remaining) = matching (0 :: Int) [] more
        in Right (classesIn inside) : go (skipVia remaining)
      token : more | all identifierChar token, not (null token) -> Right 1 : go (skipVia more)
      _ -> go afterStrategy
  go (_ : rest) = go rest
  skipStrategy tokens = case tokens of
    "stock" : more -> more
    "newtype" : more -> more
    "anyclass" : more -> more
    "via" : _ : more -> more
    _ -> tokens
  skipVia tokens = case tokens of
    "via" : _ : more -> more
    _ -> tokens
  matching _ accumulated [] = (reverse accumulated, [])
  matching depth accumulated (token : rest) = case token of
    ")" | depth == 0 -> (reverse accumulated, rest)
        | otherwise -> matching (depth - 1) (token : accumulated) rest
    "(" -> matching (depth + 1) (token : accumulated) rest
    _ -> matching depth (token : accumulated) rest
  classesIn inside
    | null inside = 0
    | otherwise = 1 + length (commasAtTopLevel (0 :: Int) inside)
  commasAtTopLevel _ [] = []
  commasAtTopLevel depth (token : rest) = case token of
    "(" -> commasAtTopLevel (depth + 1) rest
    ")" -> commasAtTopLevel (depth - 1) rest
    "," | depth == 0 -> token : commasAtTopLevel depth rest
    _ -> commasAtTopLevel depth rest

-- | The number of top-level instance declarations: lines that start, in column one,
-- with the keyword.
instanceDeclarationCount :: Text -> Int
instanceDeclarationCount = length . filter ("instance " `Text.isPrefixOf`) . Text.lines

-- | Whether a top-level @newtype@ declaration names the type.
declaredAsNewtype :: Text -> Text -> Maybe Bool
declaredAsNewtype typeName source =
  listToMaybe
    ([True | any (startsWith "newtype") lines']
      <> [False | any (startsWith "data") lines'])
 where
  lines' = Text.lines source
  startsWith keyword line = case Text.words line of
    first : second : _ -> first == keyword && second == typeName
    _ -> False

-- | The catalogued sink uses a file's imports and tokens justify: pairs of module,
-- name, and kind, from a flat catalogue of module, name, and kind.
sinkHits :: [(Text, Text, Text)] -> Text -> Text -> Set (Text, Text, Text)
sinkHits catalogue raw blanked = Set.fromList
  ([ (moduleName, name, kind)
   | (moduleName, name, kind) <- catalogue
   , moduleName /= "Prelude"
   , any (\statement -> importModule statement == moduleName && reaches statement name) imports]
  <> [ ("Prelude", name, kind)
     | implicitPrelude
     , ("Prelude", name, kind) <- catalogue
     , name `Set.member` unqualified
     , name `Set.notMember` defined])
 where
  imports = importStatements blanked
  tokens = map snd (identifierTokens (withoutImports blanked))
  unqualified = Set.fromList (filter (not . Text.isInfixOf ".") tokens)
  qualifiedTokens = Set.fromList (filter (Text.isInfixOf ".") tokens)
  defined = Set.fromList [Text.takeWhile identifierChar line | line <- Text.lines blanked, Just (first, _) <- [Text.uncons line], identifierStart first]
  implicitPrelude = not (languagePragmaEnabled "NoImplicitPrelude" raw)
    && all (\statement -> importModule statement /= "Prelude") imports
  reaches statement name =
    let alias = fromMaybe (importModule statement) (importAlias statement)
        qualifiedHit = (alias <> "." <> name) `Set.member` qualifiedTokens
        listed = fromMaybe [] (importNames statement)
        permitted
          | importHiding statement = name `notElem` listed
          | otherwise = case importNames statement of
              Nothing -> True
              Just _ -> name `elem` listed
        unqualifiedHit = not (importQualified statement) && permitted && name `Set.member` unqualified && name `Set.notMember` defined
    in (qualifiedHit && permitted) || unqualifiedHit

-- | The text of a one-based, end-exclusive @(line, column)@ span in a file's lines.
sliceSpan :: [Text] -> ((Int, Int), (Int, Int)) -> Text
sliceSpan fileLines ((startLine, startColumn), (endLine, endColumn))
  | startLine == endLine = Text.take (endColumn - startColumn) (Text.drop (startColumn - 1) (line startLine))
  | otherwise = Text.intercalate "\n"
      ( [Text.drop (startColumn - 1) (line startLine)]
        <> [line number | number <- [startLine + 1 .. endLine - 1]]
        <> [Text.take (endColumn - 1) (line endLine)] )
 where
  line number = fromMaybe "" (listToMaybe (drop (number - 1) fileLines))

-- | A token of a sink use's own text, read from the raw source of its span.
data UseToken
  = UString Text
  | UWord Text
  | UOperator Text
  | UBackquoted Text
  | UGroup Char [UseToken]
  | UComma
  deriving (Eq, Show)

-- | A piece of a path expression: a literal, the separator an operator inserts, or an
-- operand that is not a literal.
data PathPiece = PLit Text | PSep Text | PDyn

-- | For each argument position of the application the span's text spells, the runs of
-- literal path text the argument supplies, each with whether it starts the argument.
-- Nothing when the text is outside the forms handled here: a prefix application, a
-- prefix application ending in a dollar, or a named function used infix on two atoms.
useArguments :: Text -> Maybe [(Int, [(Bool, Text)])]
useArguments site = do
  tokens <- useTokens site
  arguments <- applicationArguments tokens
  pure [(position, pathRuns (pathPieces expression)) | (position, expression) <- zip [0 ..] arguments]

applicationArguments :: [UseToken] -> Maybe [[UseToken]]
applicationArguments tokens = case break isOperatorToken tokens of
  (UWord _ : atoms, []) | all isAtom atoms -> Just (map pure atoms)
  (UWord _ : atoms, UOperator operator : rest)
    | operator `elem` ["$", "$!"], all isAtom atoms, not (null rest) -> Just (map pure atoms <> [rest])
  ([left], UBackquoted _ : [right]) | isAtom left, isAtom right -> Just [[left], [right]]
  _ -> Nothing

isOperatorToken :: UseToken -> Bool
isOperatorToken token = case token of
  UOperator _ -> True
  UBackquoted _ -> True
  _ -> False

isAtom :: UseToken -> Bool
isAtom token = not (isOperatorToken token) && token /= UComma

pathPieces :: [UseToken] -> [PathPiece]
pathPieces tokens
  | all (isJust . pathJoiner) operators =
      concat (zipWith (<>) (map operandPieces operands) ([[PSep joiner] | joiner <- mapMaybe pathJoiner operators] <> [[]]))
  | otherwise = [PDyn]
 where
  (operands, operators) = splitChain tokens

splitChain :: [UseToken] -> ([[UseToken]], [Text])
splitChain tokens = case break isOperatorToken tokens of
  (operand, []) -> ([operand], [])
  (operand, token : rest) ->
    let (operands, operators) = splitChain rest
    in (operand : operands, operatorText token : operators)
 where
  operatorText token = case token of
    UOperator text -> text
    UBackquoted name -> "`" <> name <> "`"
    _ -> ""

pathJoiner :: Text -> Maybe Text
pathJoiner operator = lookup operator [("</>", "/"), ("<.>", "."), ("<>", ""), ("++", "")]

operandPieces :: [UseToken] -> [PathPiece]
operandPieces operand = case operand of
  [UString text] -> [PLit text]
  [UGroup '(' inner] -> pathPieces inner
  [UWord function, argument]
    | Text.takeWhileEnd (/= '.') function `elem` ["pack", "unpack", "fromString", "toString", "normalise"]
    , isAtom argument -> pathPieces [argument]
  _ -> [PDyn]

pathRuns :: [PathPiece] -> [(Bool, Text)]
pathRuns pieces = go startsRooted pieces
 where
  startsRooted = case pieces of
    PLit _ : _ -> True
    _ -> False
  go _ [] = []
  go rooted remaining =
    let (run, rest) = break isDynamic remaining
        text = joined run
    in [(rooted, text) | not (Text.null text)] <> go False (dropWhile isDynamic rest)
  isDynamic piece = case piece of
    PDyn -> True
    _ -> False
  joined = fst . foldl step ("", "")
  step (accumulated, pending) piece = case piece of
    PLit text -> (if Text.null accumulated then text else accumulated <> pending <> text, "")
    PSep separator -> (accumulated, separator)
    PDyn -> (accumulated, pending)

-- | The tokens of a span's text; Nothing if it has unbalanced brackets, an unterminated
-- string, or a character this reading does not handle.
useTokens :: Text -> Maybe [UseToken]
useTokens input = case sequenceTokens (Text.unpack input) of
  Just (tokens, []) -> Just tokens
  _ -> Nothing

sequenceTokens :: String -> Maybe ([UseToken], String)
sequenceTokens = go []
 where
  go accumulated [] = Just (reverse accumulated, [])
  go accumulated chars@(c : rest)
    | isSpace c = go accumulated rest
    | '{' : '-' : more <- chars = blockComment (1 :: Int) more >>= go accumulated
    | '-' : '-' : more <- chars, lineComment more = go accumulated (dropWhile (/= '\n') more)
    | c `elem` (")]}" :: String) = Just (reverse accumulated, chars)
    | c `elem` ("([{" :: String) = do
        (inner, remaining) <- go [] rest
        case remaining of
          closer : after | closer == closing c -> go (UGroup c inner : accumulated) after
          _ -> Nothing
    | c == ',' = go (UComma : accumulated) rest
    | c == '"' = do
        (value, after) <- decodedString rest
        go (UString value : accumulated) after
    | c == '`' = let (name, after) = break (== '`') rest in go (UBackquoted (Text.pack name) : accumulated) (drop 1 after)
    | c == '\'' = characterLiteral rest >>= go (UWord "'" : accumulated)
    | identifierStart c =
        let (word, after) = qualifiedName chars
        in case (word, after) of
          (first : _, '.' : next : _) | isUpper first, operatorChar next ->
            let (operator, remaining) = span operatorChar (drop 1 after)
            in go (UOperator (Text.pack operator) : accumulated) remaining
          _ -> go (UWord (Text.pack word) : accumulated) after
    | isDigit c = let (word, after) = span identifierChar chars in go (UWord (Text.pack word) : accumulated) after
    | operatorChar c = let (operator, after) = span operatorChar chars in go (UOperator (Text.pack operator) : accumulated) after
    | otherwise = Nothing
  closing bracket = case bracket of
    '(' -> ')'
    '[' -> ']'
    _ -> '}'
  lineComment more = case dropWhile (== '-') more of
    next : _ -> not (operatorChar next)
    [] -> True
  blockComment depth chars = case chars of
    '{' : '-' : more -> blockComment (depth + 1) more
    '-' : '}' : more | depth == 1 -> Just more
                     | otherwise -> blockComment (depth - 1) more
    _ : more -> blockComment depth more
    [] -> Nothing
  characterLiteral chars = case chars of
    '\\' : escaped -> case break (== '\'') (drop 1 escaped) of
      (_, '\'' : after) -> Just after
      _ -> Nothing
    _ : '\'' : after -> Just after
    _ -> Nothing

operatorChar :: Char -> Bool
operatorChar character = character `elem` ("!#$%&*+./<=>?@\\^|-~:" :: String)

decodedString :: String -> Maybe (Text, String)
decodedString = loop []
 where
  loop accumulated chars = case chars of
    '"' : rest -> Just (Text.pack (reverse accumulated), rest)
    '\\' : escaped : rest
      | Just character <- lookup escaped [('n', '\n'), ('t', '\t'), ('r', '\r'), ('"', '"'), ('\\', '\\'), ('\'', '\'')] ->
          loop (character : accumulated) rest
      | escaped == '&' -> loop accumulated rest
      | isSpace escaped -> case break (== '\\') rest of
          (_, '\\' : after) -> loop accumulated after
          _ -> Nothing
      | otherwise -> Nothing
    character : rest -> loop (character : accumulated) rest
    [] -> Nothing

-- | The head type constructor a top-level newtype wraps, read from the newtype's own
-- text for the prefix and single-field record forms; Nothing for any other form.
-- A list is @[]@, a tuple @(,)@, and a function @->@.
newtypeRepresentation :: Text -> Text -> Maybe Text
newtypeRepresentation typeName source = do
  block <- listToMaybe [candidate | candidate <- topLevelBlocks (Text.lines source), namesType candidate]
  let afterEquals = Text.drop 1 (Text.dropWhile (/= '=') block)
      body = Text.strip (fst (Text.breakOn "deriving" afterEquals))
  let (constructor, rest) = Text.break isSpace body
  case Text.uncons (Text.strip rest) of
    _ | Text.null constructor -> Nothing
    Just ('{', inside) ->
      let fieldType = Text.drop 2 (snd (Text.breakOn "::" inside))
      in typeHeadText (fst (Text.breakOn "}" fieldType))
    Just _ -> typeHeadText rest
    Nothing -> Nothing
 where
  namesType block = case Text.words (Text.replace "\n" " " block) of
    "newtype" : name : _ -> name == typeName
    _ -> False
  topLevelBlocks [] = []
  topLevelBlocks (line : rest) =
    let (continuation, remaining) = span (\next -> Text.null next || maybe False (isSpace . fst) (Text.uncons next)) rest
    in Text.unlines (line : continuation) : topLevelBlocks remaining

typeHeadText :: Text -> Maybe Text
typeHeadText text = case Text.uncons (Text.strip text) of
  Nothing -> Nothing
  Just ('[', _) -> Just "[]"
  Just ('(', more) ->
    let inner = Text.take (matchingClose (0 :: Int) (Text.unpack more)) more
    in if topLevelContains "," inner then Just "(,)"
       else if topLevelContains "->" inner then Just "->"
       else typeHeadText inner
  Just (c, _) | identifierStart c -> Just (Text.pack (fst (qualifiedName (Text.unpack (Text.strip text)))))
  _ -> Nothing
 where
  matchingClose _ [] = 0
  matchingClose depth (character : rest)
    | character == ')' && depth == 0 = 0
    | character == ')' = 1 + matchingClose (depth - 1) rest
    | character == '(' = 1 + matchingClose (depth + 1) rest
    | otherwise = 1 + matchingClose depth rest
  topLevelContains needle haystack = go (0 :: Int) haystack
   where
    go _ remaining | Text.null remaining = False
    go depth remaining = case Text.uncons remaining of
      Just (c, rest)
        | c `elem` ("([" :: String) -> go (depth + 1) rest
        | c `elem` (")]" :: String) -> go (depth - 1) rest
        | depth == 0 && needle `Text.isPrefixOf` remaining -> True
        | otherwise -> go depth rest
      Nothing -> False

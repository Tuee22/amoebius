{-# LANGUAGE CPP #-}

-- | A deliberately bounded refinement checker for compiled Haskell fixtures.
--
-- The caller supplies source bytes and an absolute solver path.  This module
-- owns the annotation grammar, expression grammar, sort checking, SMT query,
-- refinement classification, and implementation-to-model correspondence.
module Amoebius.Checker.Refinement
  ( RefinementSolver
  , mkRefinementSolver
  , RefinementExpr (..)
  , RefinementSource (..)
  , RefinementStatus (..)
  , RefinementResult (..)
  , RefinementError (..)
  , parseRefinementExpr
  , parseRefinementSource
  , checkRefinement
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString.Char8 qualified as Char8
import Data.Char (isAlpha, isAlphaNum, isDigit, isSpace)
import Data.List (find, intercalate, nub)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Numeric (showHex)
import System.Directory (doesFileExist, executable, getPermissions)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute)
import System.Process (readProcessWithExitCode)

newtype RefinementSolver = RefinementSolver FilePath
  deriving stock (Eq, Ord, Show)

data RefinementExpr
  = IntegerLiteral Integer
  | BooleanLiteral Bool
  | Variable String
  | Add RefinementExpr RefinementExpr
  | Subtract RefinementExpr RefinementExpr
  | Negate RefinementExpr
  | LessThan RefinementExpr RefinementExpr
  | LessThanOrEqual RefinementExpr RefinementExpr
  | GreaterThan RefinementExpr RefinementExpr
  | GreaterThanOrEqual RefinementExpr RefinementExpr
  | Equal RefinementExpr RefinementExpr
  | NotEqual RefinementExpr RefinementExpr
  | And RefinementExpr RefinementExpr
  | Or RefinementExpr RefinementExpr
  | Not RefinementExpr
  | IfThenElse RefinementExpr RefinementExpr RefinementExpr
  deriving stock (Eq, Ord, Show)

data RefinementSource = RefinementSource
  { refinementPath :: FilePath
  , refinementModel :: String
  , refinementInvariant :: String
  , refinementFunction :: String
  , refinementArguments :: [String]
  , refinementPrecondition :: RefinementExpr
  , refinementPostcondition :: RefinementExpr
  , refinementBody :: RefinementExpr
  , refinementFunctionLine :: Int
  , refinementSourceDigest :: String
  }
  deriving stock (Eq, Ord, Show)

data RefinementStatus
  = Proved
  | PostconditionCounterexample
  | CorrespondenceMismatch
  | UnknownInvariant
  deriving stock (Eq, Ord, Show)

data RefinementResult = RefinementResult
  { refinementResultPath :: FilePath
  , refinementResultFunction :: String
  , refinementResultStatus :: RefinementStatus
  , refinementResultReason :: String
  , refinementResultLine :: Int
  , refinementResultSourceDigest :: String
  , refinementResultSolverModel :: String
  }
  deriving stock (Eq, Ord, Show)

data RefinementError
  = SolverPathNotAbsolute FilePath
  | SolverPathNotExecutable FilePath
  | MalformedRefinementSource FilePath String
  | MalformedRefinementExpression String
  | UnboundRefinementVariable String
  | RefinementSortMismatch String String String
  | RefinementSolverFailure String
  deriving stock (Eq, Ord, Show)

data Token
  = TokenInteger Integer
  | TokenName String
  | TokenOperator String
  deriving stock (Eq, Ord, Show)

data Sort = BooleanSort | IntegerSort
  deriving stock (Eq, Ord, Show)

data Term = Term Sort String

data SolverStatus = SolverSat | SolverUnsat

mkRefinementSolver :: FilePath -> IO (Either RefinementError RefinementSolver)
mkRefinementSolver path
  | not (isAbsolute path) = pure (Left (SolverPathNotAbsolute path))
  | otherwise = do
      present <- doesFileExist path
      permissions <- if present then Just <$> getPermissions path else pure Nothing
      pure $ case permissions of
        Just mode | executable mode -> Right (RefinementSolver path)
        _ -> Left (SolverPathNotExecutable path)

parseRefinementExpr :: String -> Either RefinementError RefinementExpr
parseRefinementExpr input = do
  tokens <- tokenize input
  (expression, remaining) <- parseIf tokens
  case remaining of
    [] -> Right expression
    token : _ -> Left (MalformedRefinementExpression ("unexpected token " <> show token))

tokenize :: String -> Either RefinementError [Token]
tokenize [] = Right []
tokenize input@(character : rest)
  | isSpace character = tokenize rest
  | isDigit character =
      let (digits, remaining) = span isDigit input
       in (TokenInteger (read digits) :) <$> tokenize remaining
  | isAlpha character || character == '_' =
      let (name, remaining) = span (\value -> isAlphaNum value || value == '_') input
       in (TokenName name :) <$> tokenize remaining
  | otherwise = case find (`prefixOf` input) ["<=", ">=", "==", "/=", "&&", "||", "(", ")", "+", "-", "<", ">"] of
      Just operator -> (TokenOperator operator :) <$> tokenize (drop (length operator) input)
      Nothing -> Left (MalformedRefinementExpression ("unsupported syntax at " <> show input))

parseIf :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parseIf (TokenName "if" : rest) = do
  (condition, afterCondition) <- parseOr rest
  afterThen <- consumeName "then" afterCondition
  (whenTrue, afterTrue) <- parseIf afterThen
  afterElse <- consumeName "else" afterTrue
  (whenFalse, remaining) <- parseIf afterElse
  Right (IfThenElse condition whenTrue whenFalse, remaining)
parseIf tokens = parseOr tokens

parseOr :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parseOr tokens = parseLeftAssociative parseAnd [("||", Or)] tokens

parseAnd :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parseAnd tokens = parseLeftAssociative parseComparison [("&&", And)] tokens

parseComparison :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parseComparison tokens = do
  (left, remaining) <- parseAddition tokens
  case remaining of
    TokenOperator operator : rest
      | Just constructor <- lookup operator comparisonOperators -> do
          (right, afterRight) <- parseAddition rest
          Right (constructor left right, afterRight)
    _ -> Right (left, remaining)
 where
  comparisonOperators =
    [ ("<", LessThan), ("<=", LessThanOrEqual), (">", GreaterThan)
    , (">=", GreaterThanOrEqual), ("==", Equal), ("/=", NotEqual)
    ]

parseAddition :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parseAddition tokens = parseLeftAssociative parseUnary [("+", Add), ("-", Subtract)] tokens

parseUnary :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parseUnary (TokenName "not" : rest) = do
  (expression, remaining) <- parseUnary rest
  Right (Not expression, remaining)
parseUnary (TokenOperator "-" : rest) = do
  (expression, remaining) <- parseUnary rest
  Right (Negate expression, remaining)
parseUnary tokens = parsePrimary tokens

parsePrimary :: [Token] -> Either RefinementError (RefinementExpr, [Token])
parsePrimary tokens = case tokens of
  TokenOperator "(" : rest -> do
    (expression, remaining) <- parseIf rest
    afterClose <- consumeOperator ")" remaining
    Right (expression, afterClose)
  TokenInteger value : rest -> Right (IntegerLiteral value, rest)
  TokenName "true" : rest -> Right (BooleanLiteral True, rest)
  TokenName "false" : rest -> Right (BooleanLiteral False, rest)
  TokenName name : rest -> Right (Variable name, rest)
  [] -> Left (MalformedRefinementExpression "unexpected end of expression")
  token : _ -> Left (MalformedRefinementExpression ("unsupported primary token " <> show token))

parseLeftAssociative
  :: ([Token] -> Either RefinementError (RefinementExpr, [Token]))
  -> [(String, RefinementExpr -> RefinementExpr -> RefinementExpr)]
  -> [Token]
  -> Either RefinementError (RefinementExpr, [Token])
parseLeftAssociative subordinate operators tokens = do
  (first, remaining) <- subordinate tokens
  continue first remaining
 where
  continue left (TokenOperator operator : rest)
    | Just constructor <- lookup operator operators = do
        (right, afterRight) <- subordinate rest
        continue (constructor left right) afterRight
  continue left remaining = Right (left, remaining)

consumeName :: String -> [Token] -> Either RefinementError [Token]
consumeName expected (TokenName actual : rest)
  | expected == actual = Right rest
consumeName expected tokens = Left (MalformedRefinementExpression ("expected " <> show expected <> ", got " <> show (take 1 tokens)))

consumeOperator :: String -> [Token] -> Either RefinementError [Token]
consumeOperator expected (TokenOperator actual : rest)
  | expected == actual = Right rest
consumeOperator expected tokens = Left (MalformedRefinementExpression ("expected " <> show expected <> ", got " <> show (take 1 tokens)))

parseRefinementSource :: FilePath -> String -> Either RefinementError RefinementSource
parseRefinementSource path source = do
  annotation <- annotationLines path (lines source)
  fields <- annotationFields path annotation
  let required = ["arguments", "function", "invariant", "model", "post", "pre"]
      observed = Map.keys fields
  if observed /= required
    then malformed path ("annotation fields " <> show observed <> " /= " <> show required)
    else pure ()
  model <- field path "model" fields
  invariant <- field path "invariant" fields
  function <- field path "function" fields
  argumentsText <- field path "arguments" fields
  preconditionText <- field path "pre" fields
  postconditionText <- field path "post" fields
  let arguments = filter (not . null) (map trim (splitOn ',' argumentsText))
  if null arguments || length arguments /= length (nub arguments) || any (not . validName) arguments
    then malformed path "arguments must be a non-empty unique identifier list"
    else pure ()
  (functionLine, equationArguments, bodyText) <- findEquation path function (lines source)
  if equationArguments /= arguments
    then malformed path ("annotation arguments " <> show arguments <> " /= equation " <> show equationArguments)
    else pure ()
  checkSignature path function arguments (lines source)
  precondition <- parseRefinementExpr preconditionText
  postcondition <- parseRefinementExpr postconditionText
  body <- parseRefinementExpr bodyText
  Right RefinementSource
    { refinementPath = path
    , refinementModel = model
    , refinementInvariant = invariant
    , refinementFunction = function
    , refinementArguments = arguments
    , refinementPrecondition = precondition
    , refinementPostcondition = postcondition
    , refinementBody = body
    , refinementFunctionLine = functionLine
    , refinementSourceDigest = digest source
    }

annotationLines :: FilePath -> [String] -> Either RefinementError [String]
annotationLines path sourceLines = case dropWhile ((/= "{-@ amoebius-refinement") . trim) sourceLines of
  [] -> malformed path "missing amoebius-refinement annotation"
  _ : rest -> case break ((== "@-}") . trim) rest of
    (_, []) -> malformed path "unterminated amoebius-refinement annotation"
    (body, _ : _) -> Right body

annotationFields :: FilePath -> [String] -> Either RefinementError (Map String String)
annotationFields path = foldl step (Right Map.empty)
 where
  step accumulated raw = do
    fields <- accumulated
    let line = trim raw
    if null line then Right fields else case break (== ':') line of
      (key, ':' : value)
        | not (null (trim key)) && not (null (trim value)) && Map.notMember (trim key) fields ->
            Right (Map.insert (trim key) (trim value) fields)
      _ -> malformed path ("malformed or duplicate annotation line " <> show line)

field :: FilePath -> String -> Map String String -> Either RefinementError String
field path key fields = maybe (malformed path ("missing field " <> key)) Right (Map.lookup key fields)

findEquation :: FilePath -> String -> [String] -> Either RefinementError (Int, [String], String)
findEquation path function sourceLines = case candidates of
  [(lineNumber, arguments, body)] -> Right (lineNumber, arguments, body)
  _ -> malformed path "annotated function equation is absent, duplicate, or outside the one-line fragment"
 where
  candidates =
    [ (lineNumber, words (trim argumentsText), trim body)
    | (lineNumber, raw) <- zip [1 ..] sourceLines
    , let (left, separatorAndBody) = break (== '=') raw
    , '=' : body <- [separatorAndBody]
    , let (name, argumentsText) = break isSpace (trim left)
    , name == function
    , not (null (trim argumentsText))
    , not (null (trim body))
    ]

checkSignature :: FilePath -> String -> [String] -> [String] -> Either RefinementError ()
checkSignature path function arguments sourceLines = case candidates of
  [actual] | normalizeSpaces actual == expected -> Right ()
  _ -> malformed path ("signature must be " <> expected)
 where
  expected = intercalate " -> " (replicate (length arguments + 1) "Integer")
  candidates =
    [ trim (drop 2 suffix)
    | raw <- sourceLines
    , let (name, suffix) = breakOn "::" raw
    , trim name == function
    , "::" `prefixOf` suffix
    ]

checkRefinement
  :: RefinementSolver
  -> Map (String, String) RefinementExpr
  -> RefinementSource
  -> IO (Either RefinementError RefinementResult)
checkRefinement solver invariants source = case Map.lookup key invariants of
  Nothing -> pure (Right (makeResult UnknownInvariant "annotation names no registered model invariant" ""))
  Just invariant -> case prepare invariant of
    Left problem -> pure (Left problem)
    Right (post, modelPost, precondition, body) -> do
#ifdef REFINEMENT_SKIPS_CORRESPONDENCE_MUTANT
      let correspondence = pure (Right (SolverUnsat, ""))
#else
      let correspondence = solve solver (renderQuery arguments [post, "(not " <> modelPost <> ")"])
#endif
      correspondenceResult <- correspondence
      case correspondenceResult of
        Left problem -> pure (Left problem)
        Right (SolverSat, solverModel) ->
          pure (Right (makeResult CorrespondenceMismatch "postcondition does not imply the registered model invariant" solverModel))
        Right (SolverUnsat, _) -> do
#ifdef REFINEMENT_WEAKENS_POSTCONDITION_MUTANT
          let proofPost = "true"
#else
          let proofPost = post
#endif
          preservation <- solve solver (renderQuery arguments [precondition, "(= result " <> body <> ")", "(not " <> proofPost <> ")"])
          pure $ case preservation of
            Left problem -> Left problem
            Right (SolverSat, solverModel) -> Right (makeResult PostconditionCounterexample "function body does not establish its postcondition" solverModel)
            Right (SolverUnsat, _) -> Right (makeResult Proved "postcondition preserved and correspondence established" "")
 where
  key = (refinementModel source, refinementInvariant source)
  arguments = refinementArguments source
  prepare invariant = do
    Term postSort post <- translate (arguments <> ["result"]) (refinementPostcondition source)
    Term invariantSort modelPost <- translate (arguments <> ["result"]) invariant
#ifdef REFINEMENT_DROPS_PRECONDITION_CONJUNCT_MUTANT
    let selectedPrecondition = case refinementPrecondition source of
          And left _ -> left
          other -> other
#else
    let selectedPrecondition = refinementPrecondition source
#endif
    Term preSort precondition <- translate (arguments <> ["result"]) selectedPrecondition
    Term bodySort body <- translate arguments (refinementBody source)
    requireSort "postcondition" BooleanSort postSort
    requireSort "model invariant" BooleanSort invariantSort
    requireSort "precondition" BooleanSort preSort
    requireSort "function body" IntegerSort bodySort
    Right (post, modelPost, precondition, body)
  makeResult status reason solverModel = RefinementResult
    { refinementResultPath = refinementPath source
    , refinementResultFunction = refinementFunction source
    , refinementResultStatus = status
    , refinementResultReason = reason
    , refinementResultLine = refinementFunctionLine source
    , refinementResultSourceDigest = refinementSourceDigest source
    , refinementResultSolverModel = solverModel
    }

translate :: [String] -> RefinementExpr -> Either RefinementError Term
translate admitted expression = case expression of
  IntegerLiteral value -> Right (Term IntegerSort (show value))
  BooleanLiteral value -> Right (Term BooleanSort (if value then "true" else "false"))
  Variable name
    | name `elem` admitted -> Right (Term IntegerSort name)
    | otherwise -> Left (UnboundRefinementVariable name)
  Add left right -> integerBinary "+" left right
  Subtract left right -> integerBinary "-" left right
  Negate value -> do
    Term actual rendered <- translate admitted value
    requireSort "negate" IntegerSort actual
    Right (Term IntegerSort ("(- " <> rendered <> ")"))
  LessThan left right -> comparison "<" left right
  LessThanOrEqual left right -> comparison "<=" left right
  GreaterThan left right -> comparison ">" left right
  GreaterThanOrEqual left right -> comparison ">=" left right
  Equal left right -> equality "=" left right
  NotEqual left right -> equality "distinct" left right
  And left right -> booleanBinary "and" left right
  Or left right -> booleanBinary "or" left right
  Not value -> do
    Term actual rendered <- translate admitted value
    requireSort "not" BooleanSort actual
    Right (Term BooleanSort ("(not " <> rendered <> ")"))
  IfThenElse condition whenTrue whenFalse -> do
    Term conditionSort renderedCondition <- translate admitted condition
    Term trueSort renderedTrue <- translate admitted whenTrue
    Term falseSort renderedFalse <- translate admitted whenFalse
    requireSort "if condition" BooleanSort conditionSort
    requireSort "if branches" trueSort falseSort
    Right (Term trueSort ("(ite " <> renderedCondition <> " " <> renderedTrue <> " " <> renderedFalse <> ")"))
 where
  integerBinary operator left right = do
    Term leftSort renderedLeft <- translate admitted left
    Term rightSort renderedRight <- translate admitted right
    requireSort operator IntegerSort leftSort
    requireSort operator IntegerSort rightSort
    Right (Term IntegerSort ("(" <> operator <> " " <> renderedLeft <> " " <> renderedRight <> ")"))
  comparison operator left right = do
    Term leftSort renderedLeft <- translate admitted left
    Term rightSort renderedRight <- translate admitted right
    requireSort operator IntegerSort leftSort
    requireSort operator IntegerSort rightSort
    Right (Term BooleanSort ("(" <> operator <> " " <> renderedLeft <> " " <> renderedRight <> ")"))
  equality operator left right = do
    Term leftSort renderedLeft <- translate admitted left
    Term rightSort renderedRight <- translate admitted right
    requireSort operator leftSort rightSort
    Right (Term BooleanSort ("(" <> operator <> " " <> renderedLeft <> " " <> renderedRight <> ")"))
  booleanBinary operator left right = do
    Term leftSort renderedLeft <- translate admitted left
    Term rightSort renderedRight <- translate admitted right
    requireSort operator BooleanSort leftSort
    requireSort operator BooleanSort rightSort
    Right (Term BooleanSort ("(" <> operator <> " " <> renderedLeft <> " " <> renderedRight <> ")"))

requireSort :: String -> Sort -> Sort -> Either RefinementError ()
requireSort context expected actual
  | expected == actual = Right ()
  | otherwise = Left (RefinementSortMismatch context (show expected) (show actual))

renderQuery :: [String] -> [String] -> String
renderQuery arguments assertions = unlines
  ( ["(set-option :produce-models true)", "(set-option :timeout 10000)", "(set-logic QF_LIA)"]
      <> ["(declare-const " <> name <> " Int)" | name <- arguments <> ["result"]]
      <> ["(assert " <> assertion <> ")" | assertion <- assertions]
      <> ["(check-sat)"]
  )

solve :: RefinementSolver -> String -> IO (Either RefinementError (SolverStatus, String))
solve (RefinementSolver path) query = do
  (exitCode, output, errors) <- readProcessWithExitCode path ["-in", "-smt2"] query
  case find (`elem` ["sat", "unsat", "unknown"]) (map trim (lines output)) of
    Just "unsat" -> pure (Right (SolverUnsat, ""))
    Just "sat" -> do
      (_, modelOutput, modelErrors) <- readProcessWithExitCode path ["-in", "-smt2"] (query <> "(get-model)\n")
      pure (Right (SolverSat, modelOutput <> modelErrors))
    status -> pure (Left (RefinementSolverFailure (renderExit exitCode <> "; status=" <> show status <> "; " <> output <> errors)))
 where
  renderExit ExitSuccess = "solver emitted no decision"
  renderExit (ExitFailure code) = "solver exited " <> show code

malformed :: FilePath -> String -> Either RefinementError value
malformed path = Left . MalformedRefinementSource path

validName :: String -> Bool
validName [] = False
validName (first : rest) = (isAlpha first || first == '_') && all (\value -> isAlphaNum value || value == '_') rest

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

normalizeSpaces :: String -> String
normalizeSpaces = unwords . words

splitOn :: Char -> String -> [String]
splitOn delimiter input = case break (== delimiter) input of
  (before, []) -> [before]
  (before, _ : after) -> before : splitOn delimiter after

breakOn :: String -> String -> (String, String)
breakOn needle haystack = search [] haystack
 where
  search prefix remaining
    | needle `prefixOf` remaining = (reverse prefix, remaining)
  search prefix (character : rest) = search (character : prefix) rest
  search prefix [] = (reverse prefix, [])

prefixOf :: Eq value => [value] -> [value] -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (left : lefts) (right : rights) = left == right && prefixOf lefts rights

digest :: String -> String
digest = concatMap byteHex . Char8.unpack . SHA256.hash . Char8.pack
 where
  byteHex character = let rendered = showHex (fromEnum character) "" in replicate (2 - length rendered) '0' <> rendered

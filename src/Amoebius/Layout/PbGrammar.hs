{-# LANGUAGE OverloadedStrings #-}

-- | Static admission of the one bootstrap program. The admitted language is
-- deliberately a singleton: its reviewed bytes have one SHA-256 identity.
-- Any changed token, import, call, decorator, or effect changes that identity
-- and is refused. This does not make a runtime claim about the interpreter;
-- the bootstrap handoff gate owns that observation.
module Amoebius.Layout.PbGrammar
  ( BootstrapRefusal (..)
  , admittedBootstrapDigest
  , admitBootstrap
  , bootstrapGraphRows
  , renderBootstrapRefusal
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.Char (isAlpha, isAlphaNum, isDigit)
import Data.List (nub, sort)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Numeric (showHex)
import Text.ParserCombinators.ReadP
  ( ReadP, char, chainl1, eof, get, look, munch, munch1, pfail
  , readP_to_S, satisfy, sepBy, skipSpaces, string, (<++) )

data BootstrapRefusal
  = BootstrapDigestMismatch Text
  | BootstrapNonUtf8
  | BootstrapMissing
  | BootstrapImportRefusal Text
  | BootstrapSyntaxRefusal Text
  | BootstrapUnresolvedCall Text
  | BootstrapDynamicCall Text
  | BootstrapControlFlowRefusal Text
  | BootstrapEffectOutsideAdapter Text
  deriving (Eq, Ord, Show)

admittedBootstrapDigest :: Text
admittedBootstrapDigest = "c978ad12876e570bc12704543b5c59c98fe03362acb19d4e527cbeb6090888bc"

admitBootstrap :: ByteString -> Either BootstrapRefusal ()
admitBootstrap bytes
  | ByteString.null bytes = Left BootstrapMissing
  | Left _ <- TextEncoding.decodeUtf8' bytes = Left BootstrapNonUtf8
  | Right source <- TextEncoding.decodeUtf8' bytes, Just refusal <- firstRefusal source = Left refusal
  | digest /= admittedBootstrapDigest = Left (BootstrapDigestMismatch digest)
  | otherwise = Right ()
 where
  digest = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))
  hexByte byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

-- | Direct calls and effect sites in the one admitted source. The exact byte
-- check precedes projection, and every row comes from a parsed expression tree.
bootstrapGraphRows :: ByteString -> Either BootstrapRefusal [Text]
bootstrapGraphRows bytes = do
  admitBootstrap bytes
  source <- either (const (Left BootstrapNonUtf8)) Right (TextEncoding.decodeUtf8' bytes)
  tree <- parseStatementTree source
  let calls = concatMap (ownedCalls "module") tree
  pure (nub (sort
    ([Text.intercalate "\t" ["bootstrap-call", owner, call]
      | (owner, call) <- calls]
      <> [Text.intercalate "\t" ["bootstrap-effect", owner, call]
         | (owner, call) <- calls, effectCall call])))

ownedCalls :: Text -> Statement -> [(Text, Text)]
ownedCalls owner statement = case statement of
  Leaf line -> fromLine owner line
  Block header children ->
    fromLine owner header <> concatMap (ownedCalls (childOwner owner header)) children
 where
  fromLine scope line = case parseStatementExpression line of
    Right (Just parsed) -> [(scope, call) | call <- expressionCalls parsed]
    _ -> []
  childOwner scope header
    | "class " `Text.isPrefixOf` header = Text.dropEnd 1 (Text.drop 6 header)
    | "def " `Text.isPrefixOf` header =
        let name = Text.takeWhile (/= '(') (Text.drop 4 header)
        in if scope == "module" then name else scope <> "." <> name
    | otherwise = scope

-- | The admitted language contains one reviewed program. These checks expose
-- the import, syntax, direct-call, control, and effect boundary before the
-- final exact-byte admission check. Unknown rewrites fail the digest check.
firstRefusal :: Text -> Maybe BootstrapRefusal
firstRefusal source = case refusals of
  refusal : _ -> Just refusal
  [] -> Nothing
 where
  lines' = Text.lines source
  stripped = map Text.strip lines'
  imports = filter (\line -> "import " `Text.isPrefixOf` line || "from " `Text.isPrefixOf` line) stripped
  expectedImports =
    [ "import hashlib", "import os", "import platform", "import subprocess"
    , "import sys", "import urllib.request", "from pathlib import Path"
    ]
  forbiddenControl =
    ["for ", "while ", "with ", "try:", "except ", "finally:", "async ",
     "await ", "match ", "case ", "yield", "global ", "nonlocal ",
     "del ", "assert ", "break", "continue", "pass"]
  unsupported =
    ["@", "lambda ", "metaclass=", "exec ", "class "]
  parsedExpressions = map parseStatementExpression
    [line | line <- stripped, not (Text.null line || "#" `Text.isPrefixOf` line)]
  calls = concat [expressionCalls parsed | Right (Just parsed) <- parsedExpressions]
  dynamic = ["eval", "exec", "compile", "getattr", "setattr", "delattr", "__import__", "globals", "locals"]
  allowedCalls =
    [ "Path", ".resolve", "RuntimeError", "BootstrapAdapter", "str", "select_artifact", "bootstrap", "main"
    , "platform.system", "platform.machine", "hashlib.sha256", "urllib.request.urlopen"
    , "subprocess.run", "os.execv", "target.is_file", "target.read_bytes"
    , "target.parent.mkdir", "target.write_bytes", "target.chmod", "response.read"
    , "existing_hash_value.hexdigest", "hash_value.hexdigest", "home.mkdir"
    , "cache.mkdir", "temporary.mkdir", "binary_bytes.decode", "binary_text.strip"
    , "adapter.repository_root", "adapter.platform", "adapter.ensure_ghcup"
    , "adapter.environment", "adapter.run", "adapter.capture", "adapter.handoff"
    ]
  effectOutside = case parseStatementTree source of
    Left _ -> []
    Right tree ->
      [line | (insideAdapter, line, call) <- concatMap (callSites False) tree,
        not insideAdapter, effectCall call]
  refusals =
    [BootstrapImportRefusal line | line <- imports, line `notElem` expectedImports]
    <> [BootstrapImportRefusal "missing import" | length imports /= length expectedImports]
    <> [BootstrapControlFlowRefusal line | line <- stripped, any (`Text.isPrefixOf` line) forbiddenControl]
    <> [BootstrapSyntaxRefusal line | line <- stripped, any (`Text.isInfixOf` line) unsupported,
        line /= "class BootstrapAdapter:"]
    <> [problem | Left problem <- [parseStatementTree source]]
    <> [problem | Left problem <- parsedExpressions]
    <> [BootstrapDynamicCall call | call <- calls, call `elem` dynamic]
    <> [BootstrapEffectOutsideAdapter line | line <- effectOutside]
    <> [BootstrapUnresolvedCall call | call <- calls, call `notElem` allowedCalls]

effectCall :: Text -> Bool
effectCall call =
  any (`Text.isPrefixOf` call) ["subprocess.", "urllib.request.", "os.execv", "os.system"]
    || call `elem` ["platform.system", "platform.machine"]
    || any (`Text.isSuffixOf` call)
      [".resolve", ".is_file", ".read_bytes", ".read", ".write_bytes", ".mkdir", ".chmod"]

callSites :: Bool -> Statement -> [(Bool, Text, Text)]
callSites insideAdapter statement = case statement of
  Leaf line -> fromLine insideAdapter line
  Block header children ->
    fromLine insideAdapter header
      <> concatMap (callSites (insideAdapter || header == "class BootstrapAdapter:")) children
 where
  fromLine inside line = case parseStatementExpression line of
    Left _ -> []
    Right Nothing -> []
    Right (Just parsed) -> [(inside, line, call) | call <- expressionCalls parsed]

-- | A closed indentation and statement grammar for the pinned bootstrap.
-- Expressions remain bounded by the exact-byte check and their direct calls
-- are extracted separately above.
data Statement
  = Block Text [Statement]
  | Leaf Text
  deriving (Eq, Show)

parseStatementTree :: Text -> Either BootstrapRefusal [Statement]
parseStatementTree source = do
  (tree, remaining) <- parseBlock 0 significant
  case remaining of
    [] -> Right tree
    (_, line) : _ -> Left (BootstrapSyntaxRefusal line)
 where
  significant =
    [(Text.length (Text.takeWhile (== ' ') line), Text.strip line)
    | line <- Text.lines source
    , let stripped = Text.strip line
    , not (Text.null stripped || "#" `Text.isPrefixOf` stripped)]

parseBlock :: Int -> [(Int, Text)] -> Either BootstrapRefusal ([Statement], [(Int, Text)])
parseBlock indentation rows = case rows of
  [] -> Right ([], [])
  (level, line) : rest
    | level < indentation -> Right ([], rows)
    | level /= indentation || level `mod` 4 /= 0 -> Left (BootstrapSyntaxRefusal line)
    | "\t" `Text.isInfixOf` line -> Left (BootstrapSyntaxRefusal line)
    | opensBlock line -> do
        (children, afterChildren) <- parseBlock (indentation + 4) rest
        if null children then Left (BootstrapSyntaxRefusal line) else do
          (siblings, remaining) <- parseBlock indentation afterChildren
          Right (Block line children : siblings, remaining)
    | admittedLeaf line -> do
        (siblings, remaining) <- parseBlock indentation rest
        Right (Leaf line : siblings, remaining)
    | otherwise -> Left (BootstrapSyntaxRefusal line)

opensBlock :: Text -> Bool
opensBlock line =
  Text.isSuffixOf ":" line
    && any (`Text.isPrefixOf` line) ["class ", "def ", "if "]

admittedLeaf :: Text -> Bool
admittedLeaf line =
  any (`Text.isPrefixOf` line) ["import ", "from ", "return ", "raise "]
    || " = " `Text.isInfixOf` line
    || ("(" `Text.isInfixOf` line && ")" `Text.isSuffixOf` line)

-- This bounded expression grammar is deliberately smaller than Python. It
-- accepts every expression in the pinned bootstrap and refuses unknown forms
-- before the final byte-identity check. Calls are read from the expression
-- tree, including nested arguments, rather than from token-shaped substrings.
data Expression
  = Name Text
  | Literal
  | Attribute Expression Text
  | Invoke Expression [Expression]
  | Subscript Expression [Expression]
  | Collection [Expression]
  | Binary Expression Expression
  deriving (Eq, Show)

parseStatementExpression :: Text -> Either BootstrapRefusal (Maybe Expression)
parseStatementExpression line
  | any (`Text.isPrefixOf` line) ["import ", "from ", "def ", "class "] = Right Nothing
  | "if " `Text.isPrefixOf` line && ":" `Text.isSuffixOf` line = Just <$> parseExpressionText (Text.dropEnd 1 (Text.drop 3 line))
  | "return " `Text.isPrefixOf` line = Just <$> parseExpressionText (Text.drop 7 line)
  | "raise " `Text.isPrefixOf` line = Just <$> parseExpressionText (Text.drop 6 line)
  | otherwise = Just <$> parseExpressionText line

parseExpressionText :: Text -> Either BootstrapRefusal Expression
parseExpressionText source = case [result | (result, "") <- readP_to_S (statementExpression <* skipSpaces <* eof) (Text.unpack source)] of
  [] -> Left (BootstrapSyntaxRefusal source)
  results -> Right (last results)

statementExpression :: ReadP Expression
statementExpression = do
  left <- expression
  (do _ <- symbol "="; right <- expression; pure (Binary left right)) <++ pure left

expression :: ReadP Expression
expression = chainl1 equality (Binary <$ keyword "and")

equality :: ReadP Expression
equality = chainl1 addition (Binary <$ (symbol "==" <++ symbol "!="))

addition :: ReadP Expression
addition = chainl1 division (Binary <$ symbol "+")

division :: ReadP Expression
division = chainl1 postfix (Binary <$ symbol "/")

postfix :: ReadP Expression
postfix = atom >>= suffix
 where
  suffix base =
    (do _ <- symbol "."; field <- identifier; suffix (Attribute base field))
      <++ (do arguments <- parens (argument `sepBy` symbol ","); suffix (Invoke base arguments))
      <++ (do indices <- brackets ((expression <++ pure Literal) `sepBy` symbol ":"); suffix (Subscript base indices))
      <++ pure base

atom :: ReadP Expression
atom =
  (Literal <$ quotedString)
    <++ (Literal <$ lexeme (munch1 isDigit))
    <++ (Name <$> identifier)
    <++ (Collection <$> parens (expression `sepBy` symbol ","))
    <++ (Collection <$> brackets (expression `sepBy` symbol ","))
    <++ (do _ <- symbol "{"; pairs <- mapping `sepBy` symbol ","; _ <- symbol "}";
            pure (Collection (concat [[key, value] | (key, value) <- pairs])))
 where
  mapping = do key <- expression; _ <- symbol ":"; value <- expression; pure (key, value)

argument :: ReadP Expression
argument = (do _ <- identifier; _ <- symbol "="; expression) <++ expression

parens :: ReadP a -> ReadP a
parens parser = symbol "(" *> parser <* symbol ")"

brackets :: ReadP a -> ReadP a
brackets parser = symbol "[" *> parser <* symbol "]"

identifier :: ReadP Text
identifier = lexeme $ do
  initial <- satisfy (\character -> isAlpha character || character == '_')
  rest <- munch (\character -> isAlphaNum character || character == '_')
  pure (Text.pack (initial : rest))

quotedString :: ReadP ()
quotedString = lexeme $ do
  _ <- char '"'
  let body = do
        character <- get
        case character of
          '"' -> pure ()
          '\\' -> get *> body
          _ -> body
  body

keyword :: String -> ReadP ()
keyword word = lexeme $ do
  _ <- string word
  remaining <- look
  case remaining of
    character : _ | isAlphaNum character || character == '_' -> pfail
    _ -> pure ()

symbol :: String -> ReadP ()
symbol value = lexeme (string value *> pure ())

lexeme :: ReadP a -> ReadP a
lexeme parser = skipSpaces *> parser <* skipSpaces

expressionCalls :: Expression -> [Text]
expressionCalls expression' = case expression' of
  Name _ -> []
  Literal -> []
  Attribute base _ -> expressionCalls base
  Invoke target arguments -> callName target : expressionCalls target <> concatMap expressionCalls arguments
  Subscript base indices -> expressionCalls base <> concatMap expressionCalls indices
  Collection values -> concatMap expressionCalls values
  Binary left right -> expressionCalls left <> expressionCalls right

callName :: Expression -> Text
callName expression' = case expression' of
  Name name -> name
  Attribute base field -> case qualifiedName base of
    Just prefix -> prefix <> "." <> field
    Nothing -> "." <> field
  _ -> "<dynamic-call>"

qualifiedName :: Expression -> Maybe Text
qualifiedName expression' = case expression' of
  Name name -> Just name
  Attribute base field -> (<> ("." <> field)) <$> qualifiedName base
  _ -> Nothing

renderBootstrapRefusal :: BootstrapRefusal -> Text
renderBootstrapRefusal refusal = case refusal of
  BootstrapDigestMismatch digest -> "BootstrapDigestMismatch: " <> digest
  BootstrapNonUtf8 -> "BootstrapNonUtf8"
  BootstrapMissing -> "BootstrapMissing"
  BootstrapImportRefusal detail -> "BootstrapImportRefusal: " <> detail
  BootstrapSyntaxRefusal detail -> "BootstrapSyntaxRefusal: " <> detail
  BootstrapUnresolvedCall detail -> "BootstrapUnresolvedCall: " <> detail
  BootstrapDynamicCall detail -> "BootstrapDynamicCall: " <> detail
  BootstrapControlFlowRefusal detail -> "BootstrapControlFlowRefusal: " <> detail
  BootstrapEffectOutsideAdapter detail -> "BootstrapEffectOutsideAdapter: " <> detail

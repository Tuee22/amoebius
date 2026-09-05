module Main (main) where

import Data.List (nub)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.ParserCombinators.ReadP

data SExp = Atom String | List [SExp] deriving stock (Eq, Show)
data Value = B Bool | I Integer deriving stock (Eq, Show)
data Sort = BoolSort | IntSort deriving stock (Eq, Show)

main :: IO ()
main = do
  source <- getContents
  case parseMany source of
    Left problem -> hPutStrLn stderr problem >> exitFailure
    Right forms -> case solve forms of
      Left problem -> hPutStrLn stderr problem >> exitFailure
      Right satisfiable -> do
        putStrLn (if satisfiable then "sat" else "unsat")
        if satisfiable && any isGetModel forms then putStrLn "(model)" else pure ()

solve :: [SExp] -> Either String Bool
solve forms = do
  declarations <- traverse declaration [form | form@(List [Atom "declare-const", _, _]) <- forms]
  let assertions = [expression | List [Atom "assert", expression] <- forms]
      constants = concatMap integers forms
      integerDomain = nub ([-2 .. 4] <> constants <> map (subtract 1) constants <> map (+ 1) constants)
      domains = [case sort of BoolSort -> [B False, B True]; IntSort -> map I integerDomain | (_, sort) <- declarations]
      environments = [Map.fromList (zip (map fst declarations) values) | values <- sequence domains]
  or <$> traverse (satisfies assertions) environments

declaration :: SExp -> Either String (String, Sort)
declaration (List [Atom "declare-const", Atom name, Atom "Bool"]) = Right (name, BoolSort)
declaration (List [Atom "declare-const", Atom name, Atom "Int"]) = Right (name, IntSort)
declaration form = Left ("unsupported declaration: " <> show form)

satisfies :: [SExp] -> Map String Value -> Either String Bool
satisfies assertions environment = and <$> traverse one assertions
 where one expression = eval environment expression >>= asBool

eval :: Map String Value -> SExp -> Either String Value
eval _ (Atom "true") = Right (B True)
eval _ (Atom "false") = Right (B False)
eval environment (Atom name) = case Map.lookup name environment of
  Just value -> Right value
  Nothing -> maybe (Left ("unknown atom: " <> name)) (Right . I) (readInteger name)
eval environment (List [Atom "not", value]) = B . not <$> (eval environment value >>= asBool)
eval environment (List (Atom "and" : values)) = B . and <$> traverse (evalBool environment) values
eval environment (List (Atom "or" : values)) = B . or <$> traverse (evalBool environment) values
eval environment (List [Atom "=>", left, right]) = do
  a <- evalBool environment left
  b <- evalBool environment right
  pure (B (not a || b))
eval environment (List [Atom "=", left, right]) = B <$> ((==) <$> eval environment left <*> eval environment right)
eval environment (List [Atom "distinct", left, right]) = B <$> ((/=) <$> eval environment left <*> eval environment right)
eval environment (List [Atom "+", left, right]) = I <$> ((+) <$> evalInt environment left <*> evalInt environment right)
eval environment (List [Atom "-", value]) = I . negate <$> evalInt environment value
eval environment (List [Atom "-", left, right]) = I <$> ((-) <$> evalInt environment left <*> evalInt environment right)
eval environment (List [Atom "<", left, right]) = compareInt environment (<) left right
eval environment (List [Atom "<=", left, right]) = compareInt environment (<=) left right
eval environment (List [Atom ">", left, right]) = compareInt environment (>) left right
eval environment (List [Atom ">=", left, right]) = compareInt environment (>=) left right
eval environment (List [Atom "ite", condition, whenTrue, whenFalse]) = do
  selected <- evalBool environment condition
  eval environment (if selected then whenTrue else whenFalse)
eval _ expression = Left ("unsupported expression: " <> show expression)

compareInt :: Map String Value -> (Integer -> Integer -> Bool) -> SExp -> SExp -> Either String Value
compareInt environment predicate left right = B <$> (predicate <$> evalInt environment left <*> evalInt environment right)

evalBool :: Map String Value -> SExp -> Either String Bool
evalBool environment expression = eval environment expression >>= asBool

evalInt :: Map String Value -> SExp -> Either String Integer
evalInt environment expression = eval environment expression >>= asInt

asBool :: Value -> Either String Bool
asBool (B value) = Right value
asBool value = Left ("expected Bool, got " <> show value)

asInt :: Value -> Either String Integer
asInt (I value) = Right value
asInt value = Left ("expected Int, got " <> show value)

integers :: SExp -> [Integer]
integers (Atom atom) = maybe [] pure (readInteger atom)
integers (List values) = concatMap integers values

readInteger :: String -> Maybe Integer
readInteger text = case reads text of
  [(value, "")] -> Just value
  _ -> Nothing

isGetModel :: SExp -> Bool
isGetModel (List [Atom "get-model"]) = True
isGetModel _ = False

parseMany :: String -> Either String [SExp]
parseMany source = case [value | (value, rest) <- readP_to_S (spaces *> many (sexp <* spaces) <* eof) source, null rest] of
  [value] -> Right value
  _ -> Left "malformed SMT-LIB input"

sexp :: ReadP SExp
sexp = list <++ atom
 where
  list = List <$> between (char '(' *> spaces) (spaces *> char ')') (many (sexp <* spaces))
  atom = Atom <$> munch1 (\character -> character /= '(' && character /= ')' && character /= ';' && character > ' ')

spaces :: ReadP ()
spaces = skipMany (skipSpaces1 <++ comment)
 where
  skipSpaces1 = satisfy (<= ' ') >> pure ()
  comment = char ';' >> munch (/= '\n') >> pure ()

{-# LANGUAGE OverloadedStrings #-}

-- The parser's decisions and exact source spans are judged by the literal
-- expectation registry that preceded its implementation.
module DslExtensionAst (extensionAstRows) where

import Data.List (sort)
import Data.Text qualified as Text
import DslExtensionsExpected
import DslParse
import System.FilePath ((</>))

extensionAstRows :: FilePath -> IO [Row]
extensionAstRows directory = do
  inventory <- readText (directory </> "inventory.tsv")
  cases <- mapM judge astExpectations
  pairs <- mapM paired astPairs
  pure (expectEqual "astcheck.complete-discovery" (sort (map nameOf astExpectations))
    (sort . Text.lines <$> inventory) : cases <> pairs)
 where
  nameOf expected = case expected of Admitted name -> name; Refused name _ _ _ _ -> name
  observed name = readText (directory </> Text.unpack name <> ".tsv")
  judge expected = do
    actual <- observed (nameOf expected)
    pure $ case expected of
      Admitted name -> expectEqual ("astcheck." <> name) "accepted\tTrue\n" actual
      Refused name reason node line column -> check ("astcheck." <> name)
        (maybe False (\value -> case Text.lines value of
          "refused" : violations -> Text.intercalate ":"
            ["Contribution.hs", Text.pack (show line), Text.pack (show column), reason, node] `elem` violations
          _ -> False) actual) (maybe "missing verdict" id actual)
  paired (negative, positive) = do
    bad <- observed negative
    good <- observed positive
    pure (check ("astcheck.pair." <> negative)
      (maybe False (Text.isPrefixOf "refused\n") bad && good == Just "accepted\tTrue\n") "paired control incomplete")

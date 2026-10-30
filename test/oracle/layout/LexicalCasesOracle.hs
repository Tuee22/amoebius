{-# LANGUAGE OverloadedStrings #-}
-- Separately authored whole-AST compatibility expectations. Supplied locations
-- qualify pure observations only; this module grants no native capture result.
module LexicalCasesOracle
  ( lexicalCompatibilityChecks, lexicalCompatibilityNames, lexicalCompatibilityExampleChecks, runLexicalCompatibilityOracle ) where
import StaticTextExpected
  (parseReference,referenceCompatibilityRows,referenceCompatibilityFacts,referenceCompatibilitySummary,referenceEmptyLetGroups)
import Control.Exception (IOException,throwIO,try)
import Control.Monad (forM,unless)
import Crypto.Hash.SHA256 qualified as Hash
import Data.ByteString qualified as Bytes
import Data.List (sort)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import Numeric (showHex)
import System.Directory (listDirectory)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Error (isDoesNotExistError)
import Text.Read (readMaybe)

type Summary=(Maybe Text,[Text],Int,[Text])
type CaseOutcome=(Text,Text,Text,Either (Text,Text) ())
type GroupRows=[(Text,Text,Maybe Text,Int)]
type DeclarationKeys=[(Text,[Text])]

expectedAliasDeclarationKeys :: DeclarationKeys
expectedAliasDeclarationKeys=
  [("value",["value","Supplied.value"])
  ,("first",["first","Supplied.first"])
  ,("second",["second","Supplied.second"])]

caseRoles :: Text -> [Text]
caseRoles name=["source","queries","identities","spans","literal-contract","outcome"]
  <> ["local-groups" | "empty-let." `Text.isPrefixOf` name]
  <> ["declaration-keys" | "alias." `Text.isPrefixOf` name]

lexicalCompatibilityNames :: [Text]
lexicalCompatibilityNames = ["lexical.discovery"]
  <> ["lexical."<>name<>"."<>role | (name,_,_,_)<-inputs,role<-caseRoles name]

runLexicalCompatibilityOracle :: FilePath -> IO ()
runLexicalCompatibilityOracle directory=do
  checks<-lexicalCompatibilityChecks directory
  mapM_ (\(name,green,detail)->TextIO.putStrLn (Text.intercalate "\t" [name,if green then "green" else "red",detail])) checks
  unless (all (\(_,green,_)->green) checks) exitFailure

lexicalCompatibilityExampleChecks :: [Text] -> [(Text,Bool,Text)]
lexicalCompatibilityExampleChecks report=
  [("lexical.product-examples",sort observed==sort expected,Text.pack (show observed))]
 where
  observed=[fields | row<-report,"lexical-compatibility-example":fields<-[Text.splitOn "\t" row]]
  expected=[[name,flavor,digest (Encoding.encodeUtf8 source)] | (name,source,flavor,_)<-inputs]

lexicalCompatibilityChecks :: FilePath -> IO [(Text,Bool,Text)]
lexicalCompatibilityChecks directory=do
  let owner=directory </> "lexical"
      names=[name | (name,_,_,_)<-inputs]
  supplied<-readValue (owner </> "cases.data") :: IO (Maybe [(Text,Text)])
  owned<-sort <$> listDirectory owner
  let discovery=("lexical.discovery",supplied==Just [(name,flavor) | (name,_,flavor,_)<-inputs]
        && owned==sort ("cases.data":[Text.unpack name<>suffix | name<-names,
          suffix<-["",".data",".outcome.data"]<>[".groups.data" | "empty-let." `Text.isPrefixOf` name]
            <>[".declaration-keys.data" | "alias." `Text.isPrefixOf` name]]),"closed supplied-AST case inventory")
  rows<-concat <$> forM inputs (\(name,source,flavor,primary)->do
    bytes<-optionalText (owner </> Text.unpack name </> "Fixture.hs")
    nodes<-readValue (owner </> Text.unpack name<>".data") :: IO (Maybe ([Text],[Text],[Text],[Text]))
    outcome<-readValue (owner </> Text.unpack name<>".outcome.data") :: IO (Maybe CaseOutcome)
    groups<-if "empty-let." `Text.isPrefixOf` name
      then readValue (owner </> Text.unpack name<>".groups.data") :: IO (Maybe GroupRows)
      else pure Nothing
    declarationKeys<-if "alias." `Text.isPrefixOf` name
      then readValue (owner </> Text.unpack name<>".declaration-keys.data") :: IO (Maybe DeclarationKeys)
      else pure Nothing
    let native=maybe (Left "IndependentCompatibilitySourceUnavailable") (parseReference "Fixture.hs" . Encoding.encodeUtf8) bytes
        expected=native >>= referenceCompatibilityRows flavor
        facts=native >>= referenceCompatibilityFacts flavor
        summary=native >>= referenceCompatibilitySummary flavor
        outcomeOkay=outcome==Just ("lexical-case-outcome.v1",name,flavor,Right ())
        queryOkay=outcomeOkay && case (nodes,expected) of (Just (actual,_,_,_),Right wanted)->actual==wanted;_->False
        identityOkay=case (nodes,facts) of
          (Just (actual,ids,paths,locations),Right wanted)->outcomeOkay && (ids,paths,locations)==wanted
            && not (null ids) && length actual==length ids && length ids==length paths && length ids==length locations
            && Set.size (Set.fromList ids)==length ids && Set.size (Set.fromList paths)==length paths
          _->False
        spansOkay=outcomeOkay && case nodes of
          Just (_,_,_,locations) | flavor=="PreserveSuppliedSpans"->not (null locations) && all ("RealSrcSpan" `Text.isPrefixOf`) locations
                                | flavor=="ShareHelpfulSpans"->Set.size (Set.fromList locations)==1 && all ("RealSrcSpan" `Text.isPrefixOf`) locations
                                | flavor=="RemoveHelpfulSpans"->Set.fromList locations==Set.singleton "UnhelpfulSpan UnhelpfulNoLocationInfo"
          _->False
        groupsOkay=outcomeOkay && case (groups,native >>= referenceEmptyLetGroups flavor) of
          (Just actual,Right wanted)->actual==wanted
          _->False
        declarationKeysOkay=outcomeOkay && bytes==Just source && declarationKeys==Just expectedAliasDeclarationKeys
        check role green=("lexical."<>name<>"."<>role,green,"separate full-module relations and literal compatibility contract")
        outcomeCheck=("lexical."<>name<>".outcome",outcomeOkay,Text.pack (show outcome))
    pure ([check "source" (bytes==Just source),check "queries" queryOkay,check "identities" identityOkay,
      check "spans" spansOkay,check "literal-contract" (summary==Right primary),outcomeCheck]
      <> [check "local-groups" groupsOkay | "empty-let." `Text.isPrefixOf` name]
      <> [check "declaration-keys" declarationKeysOkay | "alias." `Text.isPrefixOf` name]))
  pure (discovery:rows)

readValue :: (Read value,Show value) => FilePath -> IO (Maybe value)
readValue path=do
  contents<-optionalText path
  pure (case contents of
    Just text->case readMaybe (Text.unpack text) of Just value | Text.stripEnd text==Text.pack (show value)->Just value;_->Nothing
    Nothing->Nothing)

-- Missing or malformed subject observations make named judgments red. Other IO
-- failures and oracle implementation exceptions retain their actual failure.
optionalText :: FilePath -> IO (Maybe Text)
optionalText path=do
  attempted<-try (Bytes.readFile path) :: IO (Either IOException Bytes.ByteString)
  case attempted of
    Left problem | isDoesNotExistError problem->pure Nothing
                 | otherwise->throwIO problem
    Right bytes->pure (either (const Nothing) Just (Encoding.decodeUtf8' bytes))
digest :: DataBytes -> Text
digest=Text.pack.concatMap (\byte->let digits=showHex byte "" in replicate (2-length digits) '0'<>digits).Bytes.unpack.Hash.hash

type DataBytes=Bytes.ByteString

inputs :: [(Text,Text,Text,Summary)]
inputs=[(name<>suffix,header<>source,flavor,primary name flavor)
  | (name,source)<-sources
  , (suffix,flavor)<-[(".native","PreserveSuppliedSpans"),(".shared","ShareHelpfulSpans"),(".unhelpful","RemoveHelpfulSpans")]]
 where
  header="{-# LANGUAGE OverloadedStrings #-}\nmodule Supplied where\n"
  sources=
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
  value literal dependencies count=(Just literal,dependencies,count,[])
  refusal dependencies count issues=(Nothing,dependencies,count,issues)
  primary name flavor=case name of
    "alias" | flavor=="PreserveSuppliedSpans"->value "end" ["text","follow","text","follow","text"] 1
            | otherwise->refusal ["text","follow","text","follow"] 0 ["cycle"]
    "where" | flavor=="PreserveSuppliedSpans"->value "end" ["text","follow","text","follow","text"] 1
            | otherwise->refusal ["text","follow","text","follow"] 0 ["cycle"]
    "cycle" | flavor=="PreserveSuppliedSpans"->refusal ["text","follow","text","follow","text","follow"] 0 ["cycle"]
            | otherwise->refusal ["text","follow","text","follow"] 0 ["cycle"]
    "repeated"->refusal ["text"] 0 ["unsupported-text"]
    "let"->value "inner" ["text","text","follow","text"] 1
    "parameters"->refusal ["text","head","text"] 0 ["nonvalue"]
    "duplicate"->value "first" ["text"] 1
    "qualifiers"->refusal ["text","head"] 0 ["ambiguous-qualifier","operation"]
    "guarded"->refusal ["text"] 0 ["unknown"]
    "concat"->refusal ["text","head","follow","head","head","follow","head","list","text","text"] 1 ["unknown"]
    "empty-let"->value "empty" ["text","text"] 1
    _->error "IndependentCompatibilityCaseUnknown"

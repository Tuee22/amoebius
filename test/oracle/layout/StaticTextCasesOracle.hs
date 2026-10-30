{-# LANGUAGE OverloadedStrings #-}
-- Independent input bytes, literal trace expectations and native capture pairs.
module StaticTextCasesOracle
  ( staticTextChecks, staticTextCaseNames, staticTextExampleChecks, runStaticTextOracle ) where
import StaticTextExpected (parseReference,referenceModuleName,referenceRows,referenceScalarContract)
import StaticTextCaptureOracle (staticTextReference)
import Control.Exception (IOException,throwIO,try)
import Control.Monad (forM,unless)
import Data.ByteString qualified as Bytes
import Crypto.Hash.SHA256 qualified as Hash
import Data.List (nub,sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import System.Directory (listDirectory)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Error (isDoesNotExistError)
import System.PosixCompat.Files (fileMode,getSymbolicLinkStatus,isRegularFile,isSymbolicLink,readSymbolicLink)
import Data.Bits ((.&.))
import Text.Read (readMaybe)
import Numeric (showHex)

type Finding=(Text,Text,Text)
type Observation=(Text,Text)
type Summary=(Maybe Text,[Text],Int,[Text])
type NativeResult=Either (Text,Text) ([Finding],[Observation])

runStaticTextOracle :: [(Text,Text,Text,Text,[(Int,Text)])] -> FilePath -> IO ()
runStaticTextOracle catalogue directory=do
  checks<-staticTextChecks catalogue directory
  mapM_ (\(name,green,detail)->TextIO.putStrLn (Text.intercalate "\t" [name,if green then "green" else "red",detail])) checks
  unless (all (\(_,green,_)->green) checks) exitFailure

staticTextCaseNames :: [Text]
staticTextCaseNames = ["static-text.discovery"]
  <> ["static-text."<>name<>"."<>role | (name,_,_)<-normalInputs,role<-["source","observations","findings","literal-contract"]]
  <> ["static-text."<>name<>"."<>role | name<-captureNames,role<-["source","observations","findings"]]
  <> ["static-text."<>name<>"."<>role | name<-negativeNames,role<-["source","observations","findings"]]

staticTextExampleChecks :: [Text] -> [(Text,Bool,Text)]
staticTextExampleChecks report=
  [("static-text.product-examples",sort observed==sort [[name,fixture] | (name,_,_)<-normalInputs],Text.pack (show observed))
  ,("static-text.capture-examples",sort captured==sort [[name,fixture] | name<-captureNames],Text.pack (show captured))]
 where observed=[fields | row<-report,"static-text-example":fields<-[Text.splitOn "\t" row]]
       captured=[fields | row<-report,"static-text-capture-example":fields<-[Text.splitOn "\t" row]]

staticTextChecks :: [(Text,Text,Text,Text,[(Int,Text)])] -> FilePath -> IO [(Text,Bool,Text)]
staticTextChecks catalogue directory=do
  let owner=directory </> "static-text"
      allNames=[name | (name,_,_)<-normalInputs]<>captureNames<>negativeNames
      expectedCases=[(name,[Text.unpack fixture]) | (name,_,_)<-normalInputs]
        <> [(name,[Text.unpack fixture]) | name<-captureNames]
        <> [("manifest-empty",[]),("manifest-duplicate",replicate 2 (Text.unpack fixture)),("source-extra",[Text.unpack fixture]),("source-symlink",[Text.unpack fixture]),("root-empty",[])]
  supplied<-readValue (owner </> "cases.data") :: IO (Maybe [(Text,[FilePath])])
  owned<-sort <$> listDirectory owner
  let expectedOwned=sort ("cases.data":[Text.unpack name<>suffix | name<-allNames,suffix<-["",".data"]])
      discovery=("static-text.discovery",supplied==Just expectedCases && length allNames==length (nub allNames) && owned==expectedOwned,"closed case and owned-path inventory")
  normal<-concat <$> forM normalInputs (\(name,expectedBytes,summary)->do
    let root=owner </> Text.unpack name
    sourceOkay<-sourceMatches root [(fixture,expectedBytes)] False
    actual<-readValue (owner </> Text.unpack name<>".data") :: IO (Maybe NativeResult)
    expected<-staticTextReference catalogue root [Text.unpack fixture]
    let wantedSummary=case parseReference (Text.unpack fixture) expectedBytes of
          Left _->[]
          Right native->referenceScalarContract catalogue [referenceModuleName native] native
        observedOkay=case (actual,expected) of (Just (Right (_,observations)),Right (_,wanted))->observations==wanted;_->False
        findingsOkay=case (actual,expected) of (Just (Right (findings,_)),Right (wanted,_))->findings==wanted;_->False
        check role green=("static-text."<>name<>"."<>role,green,"separate bytes, native reference and literal contract"<>resultFailure actual)
    pure [check "source" sourceOkay,check "observations" observedOkay,check "findings" findingsOkay,check "literal-contract" (wantedSummary==summary)])
  negatives<-concat <$> forM negativeNames (\name->do
    let root=owner </> Text.unpack name
        inputs=sort ([(fixture,0o600,controlBytes) | name/="root-empty"]<>[("Extra.hs",0o600,extraBytes) | name=="source-extra"])
        requested=if name `elem` ["manifest-empty","root-empty"] then [] else if name=="manifest-duplicate" then [fixture,fixture] else [fixture]
    sourceOkay<-sourceMatches root [(path,bytes) | (path,_,bytes)<-inputs] (name=="source-symlink")
    actual<-readValue (owner </> Text.unpack name<>".data") :: IO (Maybe NativeResult)
    let queries=case parseReference (Text.unpack fixture) controlBytes of
          Left _->[]
          Right native->concat [referenceRows catalogue [referenceModuleName native] (Text.unpack fixture) native | _<-requested]
        expectedObservations=[("source-opening",captureProjection [(Text.unpack path,mode,bytes) | (path,mode,bytes)<-inputs])
          ,("source-manifest",Text.pack (show (map Text.unpack requested)))]
          <>[("static-text-observation",query) | query<-queries]
          <>[("source-closing",captureProjection [(Text.unpack path,mode,bytes) | (path,mode,bytes)<-inputs])]
        observedOkay=case actual of
          Just (Right (_,observations))
            | name=="source-symlink"->symlinkObservations requested observations
            | otherwise->observations==expectedObservations
          _->False
        findingsOkay=case actual of
          Just (Right (findings,_))
            | name=="source-symlink"->symlinkFindings findings
            | name=="root-empty"->findings==[permanentFinding,("StaticTextHaskellInventoryEmpty","source","A native source-text observation requires a Haskell input.")]
            | otherwise->findings==[permanentFinding,("StaticTextSourceInventoryMismatch","source","The supplied paths differ from the complete physical source inventory.")]
          _->False
        check role green=("static-text."<>name<>"."<>role,green,"capture-control paired with one declared source/manifest change"<>resultFailure actual)
    pure [check "source" sourceOkay,check "observations" observedOkay,check "findings" findingsOkay])
  captures<-concat <$> forM captureNames (captureChecks catalogue owner)
  pure (discovery:normal<>captures<>negatives)
 where
  symlinkObservations requested observations=case observations of
    [("source-opening",opening),("source-manifest",manifest),("source-closing",closing)]->
      opening==closing && manifest==Text.pack (show (map Text.unpack requested))
        && case readMaybe (Text.unpack opening) :: Maybe (Text,Text,Text) of
          Just ("StaticTextCaptureUnavailable","source",detail)->"StaticTextSourceKindUnavailable: Link.hs" `Text.isInfixOf` detail
          _->False
    _->False
  symlinkFindings findings=case findings of
    [permanent,("HaskellSourceUnreadable","Fixture.hs",message),("StaticTextCaptureUnavailable","source",opening),("StaticTextCaptureUnavailable","source",closing)]->
      permanent==permanentFinding && message=="Existing SourceGraph source acquisition refused."
        && opening==closing && "StaticTextSourceKindUnavailable: Link.hs" `Text.isInfixOf` opening
    _->False

captureChecks :: [(Text,Text,Text,Text,[(Int,Text)])] -> FilePath -> Text -> IO [(Text,Bool,Text)]
captureChecks catalogue owner name=do
  let root=owner </> Text.unpack name
      before=[("Fixture.hs",0o600,controlBytes)] :: [(FilePath,Integer,Bytes.ByteString)]
      after=case name of
        "closing-mode"->[("Fixture.hs",0o644,controlBytes)]
        "closing-bytes"->[("Fixture.hs",0o600,controlBytes<>"\n-- closing change\n")]
        "closing-added"->[("Extra.hs",0o600,extraBytes),("Fixture.hs",0o600,controlBytes)]
        "closing-removed"->[]
        _->before
      queries=case parseReference "Fixture.hs" controlBytes of
        Left _->[]
        Right native->referenceRows catalogue [referenceModuleName native] "Fixture.hs" native
      prefix=[("source-opening",captureProjection before),("source-manifest",Text.pack (show ["Fixture.hs" :: FilePath]))]
        <>[("static-text-observation",query) | query<-queries]
      wanted=prefix<>[("source-closing",captureProjection after)]
  sourceOkay<-if name=="closing-symlink" then do
      entries<-listDirectory root
      status<-getSymbolicLinkStatus (root </> "Fixture.hs")
      target<-readSymbolicLink (root </> "Fixture.hs")
      pure (entries==["Fixture.hs"] && isSymbolicLink status && target=="Missing.hs")
    else sourceMatchesModes root after
  actual<-readValue (owner </> Text.unpack name<>".data") :: IO (Maybe NativeResult)
  let observationsOkay=case actual of
        Just (Right (_,observations))
          | name=="closing-symlink"->
              take (length prefix) observations==prefix && length observations==length prefix+1
                && case last observations of
                  ("source-closing",encoded)->case readMaybe (Text.unpack encoded) :: Maybe (Text,Text,Text) of
                    Just ("StaticTextCaptureUnavailable","source",detail)->"StaticTextSourceKindUnavailable: Fixture.hs" `Text.isInfixOf` detail
                    _->False
                  _->False
          | otherwise->observations==wanted
        _->False
      findingsOkay=case actual of
        Just (Right (findings,_))
          | name=="closing-control"->null findings
          | name=="closing-symlink"->case findings of
              [permanent,("StaticTextCaptureUnavailable","source",detail)]->permanent==permanentFinding && "StaticTextSourceKindUnavailable: Fixture.hs" `Text.isInfixOf` detail
              _->False
          | otherwise->findings==[permanentFinding,("StaticTextSourceChanged","source","The complete closing source bytes or modes differ.")]
        _->False
      check role green=("static-text."<>name<>"."<>role,green,"actual declared edit between native observation and closing acquisition"<>resultFailure actual)
  pure [check "source" sourceOkay,check "observations" observationsOkay,check "findings" findingsOkay]

captureProjection :: [(FilePath,Integer,Bytes.ByteString)] -> Text
captureProjection inputs=Text.pack (show [(path,mode,Bytes.length bytes,digest bytes) | (path,mode,bytes)<-inputs])
 where digest=Text.pack.concatMap (\byte->let hex=showHex byte "" in replicate (2-length hex) '0'<>hex).Bytes.unpack.Hash.hash

sourceMatchesModes :: FilePath -> [(FilePath,Integer,Bytes.ByteString)] -> IO Bool
sourceMatchesModes root inputs=do
  entries<-sort <$> listDirectory root
  checks<-forM inputs $ \(path,mode,expected)->do
    status<-getSymbolicLinkStatus (root </> path)
    bytes<-Bytes.readFile (root </> path)
    pure (isRegularFile status && not (isSymbolicLink status) && toInteger (fileMode status .&. 0o7777)==mode && bytes==expected)
  pure (and checks && entries==sort [path | (path,_,_)<-inputs])

sourceMatches :: FilePath -> [(Text,Bytes.ByteString)] -> Bool -> IO Bool
sourceMatches root inputs linked=do
  entries<-sort <$> listDirectory root
  fileChecks<-forM inputs $ \(path,expected)->do
    status<-getSymbolicLinkStatus (root </> Text.unpack path)
    bytes<-Bytes.readFile (root </> Text.unpack path)
    pure (isRegularFile status && not (isSymbolicLink status) && fileMode status .&. 0o7777==0o600 && bytes==expected)
  linkOkay<-if linked then do
    status<-getSymbolicLinkStatus (root </> "Link.hs")
    target<-readSymbolicLink (root </> "Link.hs")
    pure (isSymbolicLink status && target==Text.unpack fixture)
    else pure True
  pure (and fileChecks && linkOkay && entries==sort (map (Text.unpack.fst) inputs<>["Link.hs" | linked]))

readValue :: (Read value,Show value) => FilePath -> IO (Maybe value)
readValue path=do
  attempted<-try (Bytes.readFile path) :: IO (Either IOException Bytes.ByteString)
  case attempted of
    Left problem | isDoesNotExistError problem->pure Nothing
                 | otherwise->throwIO problem
    Right bytes->pure $ case Encoding.decodeUtf8' bytes of
      Left _->Nothing
      Right content->case readMaybe (Text.unpack content) of
        Just value | Text.stripEnd content==Text.pack (show value)->Just value
        _->Nothing

resultFailure :: Maybe NativeResult -> Text
resultFailure actual=case actual of
  Just (Left problem)->"; actual-subject-error="<>Text.pack (show problem)
  Nothing->"; actual-subject-result-unavailable"
  Just (Right _)->""

fixture :: Text
fixture="Fixture.hs"
negativeNames :: [Text]
negativeNames=["manifest-empty","manifest-duplicate","source-extra","source-symlink","root-empty"]
captureNames :: [Text]
captureNames=["closing-control","closing-mode","closing-bytes","closing-added","closing-removed","closing-symlink"]
permanentFinding :: Finding
permanentFinding=("StaticTextBoundaryUnavailable","layout-report","Complete source capture, closing recheck, native syntax/byte observation and independent qualification remain unavailable.")
controlBytes,extraBytes :: Bytes.ByteString
controlBytes="module StaticTextFixture where\nimport System.IO (readFile)\nvalue = readFile \"control\"\n"
extraBytes="module Extra where\nextra = ()\n"

-- Inputs and semantic traces are separately authored oracle values. A demanded
-- query stops at the declared failure and retains repeated dependency events.
normalInputs :: [(Text,Bytes.ByteString,[Summary])]
normalInputs=[(name,Encoding.encodeUtf8 (header<>body),expected) | (name,body,expected)<-textInputs]
  <>[("invalid-utf8",Bytes.pack [255,254,10],[]),("capture-control",controlBytes,[value "control" ["text"] 1])]
  <>[("pattern-shadows-prelude","module StaticTextFixture where\n(readFile, other) = (undefined, ())\nvalue = readFile \"shadowed\"\n",[])
    ,("selector-shadows-prelude","module StaticTextFixture where\ndata Box = Box { readFile :: String -> String }\nvalue = readFile undefined \"shadowed\"\n",[])
    ,("class-shadows-prelude","module StaticTextFixture where\nclass C a where\n  readFile :: a -> IO String\nvalue = readFile \"shadowed\"\n",[])
    ,("foreign-shadows-prelude","module StaticTextFixture where\nforeign import ccall unsafe \"puts\" readFile :: String -> IO ()\nvalue = readFile \"shadowed\"\n",[])]
 where
  header="{-# LANGUAGE OverloadedStrings #-}\nmodule StaticTextFixture where\nimport System.IO (readFile)\nimport System.Directory (copyFile)\nimport qualified Data.Text as T\n"
  value text dependencies literals=(Just text,dependencies,literals,[])
  refused dependencies literals reasons=(Nothing,dependencies,literals,reasons)
  textInputs=
    [("literal","value = readFile \"left\"\n",[value "left" ["text"] 1])
    ,("append","value = readFile (\"left\" <> \"right\")\n",[value "leftright" ["text","text","head","text","text"] 2])
    ,("append-left-unknown","value = readFile (unknown <> \"right\")\n",[refused ["text","text","head","text"] 0 ["unknown"]])
    ,("append-right-unknown","value = readFile (\"left\" <> unknown)\n",[refused ["text","text","head","text","text"] 1 ["unknown"]])
    ,("alias-repeated","value = readFile (name <> name)\nname = \"repeat\"\n",[value "repeatrepeat" ["text","text","head","text","follow","text","text","follow","text"] 2])
    ,("identity","value = readFile (id \"path\")\n",[value "path" ["text","text","head","text"] 1])
    ,("text-pack-unpack","value = readFile (T.unpack (T.pack \"path\"))\n",[value "path" ["text","text","head","text","text","head","text"] 1])
    ,("concat","value = readFile (concat [\"a\",\"b\"])\n",[value "ab" ["text","text","head","head","list","text","text"] 2])
    ,("concat-short-circuit","value = readFile (concat [\"a\",unknown,\"ignored\"])\n",[refused ["text","text","head","head","list","text","text"] 1 ["unknown"]])
    ,("characters","value = readFile ['a','b']\n",[value "ab" ["text","character","character"] 2])
    ,("non-character","value = readFile ['a',unknown,'c']\n",[refused ["text","character","character"] 1 ["non-character"]])
    ,("type-signature","value = readFile (\"path\" :: String)\n",[value "path" ["text","text","text"] 1])
    ,("let-shadow","value = readFile (let name = \"inner\" in name)\nname = \"outer\"\n",[value "inner" ["text","text","text","follow","text"] 1])
    ,("where-alias","value = readFile name where name = \"where\"\n",[value "where" ["text","follow","text"] 1])
    ,("parameter-shadow","value name = readFile name\nname = \"outer\"\n",[refused ["text"] 0 ["nonvalue"]])
    ,("function-nonvalue","value = readFile name\nname argument = argument\n",[refused ["text"] 0 ["nonvalue"]])
    ,("duplicate-declarations","value = readFile name\nname = \"one\"\nname = \"two\"\n",[refused ["text"] 0 ["duplicate"]])
    ,("alias-cycle","value = readFile one\none = two\ntwo = one\n",[refused ["text","follow","text","follow","text","follow"] 0 ["cycle"]])
    ,("line-pragma-refusal","value = readFile one\n{-# LINE 1 \"Alias.hs\" #-}\none = two\n{-# LINE 1 \"Alias.hs\" #-}\ntwo = one\n",[])
    ,("ambiguous-qualifier","import qualified Data.Text.Lazy as T\nvalue = readFile (T.unpack \"path\")\n",[refused ["text","text","head"] 0 ["ambiguous-qualifier","operation"]])
    ,("qualified-sink","import qualified System.IO as IO\nvalue = IO.readFile \"qualified\"\n",replicate 2 (value "qualified" ["text"] 1))
    ,("sink-alias","value = reader \"alias\"\nreader = readFile\n",[value "alias" ["text"] 1])
    ,("parenthesized-sink","value = (readFile) (\"parenthesized\")\n",[value "parenthesized" ["text","text"] 1])
    ,("partial-sink","value = copyFile \"source\"\n",[value "source" ["text"] 1])
    ,("full-sink","value = copyFile \"source\" \"destination\"\n",[value "source" ["text"] 1,value "destination" ["text"] 1,value "source" ["text"] 1])
    ,("repeated-uses","value = do { readFile \"same\"; readFile \"same\" }\n",replicate 2 (value "same" ["text"] 1))
    ,("escaped-unicode","value = readFile \"雪\\tline\\n\\\"quote\"\n",[value "雪\tline\n\"quote" ["text"] 1])
    ,("syntax-refusal","value = readFile (\n",[])]

{-# LANGUAGE OverloadedStrings #-}
-- Independent opaque-client sources, build-plan binding and exact compiler
-- diagnostics. A nonzero return alone never establishes a refusal.
module StaticTextSurfaceOracle
  ( surfaceChecks,surfaceNames,surfaceExampleChecks,runSurfaceOracle ) where
import Control.Monad (forM,unless)
import Crypto.Hash.SHA256 qualified as Hash
import Data.Aeson (Value,eitherDecodeStrict',withObject,(.:),(.:?),(.!=))
import Data.Aeson.Types (Parser,parseEither)
import Data.ByteString qualified as Bytes
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import Numeric (showHex)
import System.Directory (makeAbsolute)
import System.Directory (listDirectory)
import System.Exit (ExitCode(..),exitFailure)
import System.FilePath ((</>))
import Text.Read (readMaybe)

type Record=([String],Bytes.ByteString,Either String (ExitCode,String,String),Bytes.ByteString)
data Diagnostic=Diagnostic Text Text Int FilePath Int Int Int Int [Text]

surfaceNames :: [Text]
surfaceNames=["opaque.discovery","opaque.context"]<>["opaque."<>name<>"."<>role | (name,_)<-sources,role<-["source","command","compiler"]]

runSurfaceOracle :: FilePath -> IO ()
runSurfaceOracle directory=do
  checks<-surfaceChecks directory
  mapM_ (\(name,green,detail)->TextIO.putStrLn (Text.intercalate "\t" [name,if green then "green" else "red",detail])) checks
  unless (all (\(_,green,_)->green) checks) exitFailure

surfaceExampleChecks :: [Text] -> [(Text,Bool,Text)]
surfaceExampleChecks report=[("opaque.product-examples",sort actual==sort expected,Text.pack (show actual))]
 where
  actual=[fields | row<-report,"opaque-surface-example":fields<-[Text.splitOn "\t" row]]
  expected=[[name,digest (Encoding.encodeUtf8 source)] | (name,source)<-sources]

surfaceChecks :: FilePath -> IO [(Text,Bool,Text)]
surfaceChecks directory=do
  let owner=directory </> "static-text-surface"
  names<-readValue (owner </> "cases.data") :: IO (Maybe [Text])
  context<-readValue (owner </> "context.data") :: IO (Maybe (FilePath,FilePath,Text))
  (image,buildRoot,unit)<-maybe (fail "OpaqueContextUnavailable") pure context
  planBytes<-Bytes.readFile (buildRoot </> "cache/plan.json")
  (selected,plannedImage)<-either fail pure (eitherDecodeStrict' planBytes >>= parseEither planIdentity)
  actualImage<-makeAbsolute image
  expectedImage<-makeAbsolute plannedImage
  let contextOkay=unit==selected && actualImage==expectedImage
  owned<-sort <$> listDirectory owner
  observed<-forM sources $ \(name,source)->do
    supplied<-readValue (owner </> Text.unpack name<>".data") :: IO (Maybe Record)
    bytes<-Bytes.readFile (owner </> Text.unpack name </> "Client.hs")
    pure (name,source,supplied,bytes)
  let sourceOkay source supplied actual=case supplied of
        Just (_,before,_,after)->before==Encoding.encodeUtf8 source && before==after && actual==before
        _->False
      arguments name=["exec","--jobs=1","--builddir="<>buildRoot,"--","ghc","-j1","-fdiagnostics-as-json",
        "-fno-code","-fforce-recomp","-XGHC2024","-package-id",Text.unpack unit,"-outputdir",
        owner </> Text.unpack name </> "objects",owner </> Text.unpack name </> "Client.hs"]
      commandOkay name supplied=case supplied of Just (actual,_,_,_)->actual==arguments name;_->False
      getter=case [item | item@(name,_,_,_)<-observed,name=="getters"] of
        [(_,source,supplied,actual)]->contextOkay && sourceOkay source supplied actual && commandOkay "getters" supplied && successful supplied
        _->False
      check name role green=("opaque."<>name<>"."<>role,green,"actual selected unit, unchanged client and exact compiler diagnostic")
      perClient=concat [ [check name "source" (sourceOkay source supplied actual)
        ,check name "command" (contextOkay && commandOkay name supplied)
        ,check name "compiler" (if name=="getters" then getter else getter && rejected (owner </> Text.unpack name </> "Client.hs") name supplied)]
        | (name,source,supplied,actual)<-observed]
      allNames=map fst sources
      expectedOwned=sort (["cases.data","context.data"]<>[Text.unpack name<>suffix | name<-allNames,suffix<-["",".data"]])
  pure ([ ("opaque.discovery",names==Just allNames && owned==expectedOwned,"closed client inventory")
        , ("opaque.context",contextOkay,"actual suite image and layout unit from the current build plan") ]<>perClient)

successful :: Maybe Record -> Bool
successful supplied=case supplied of
  Just (_,_,Right (ExitSuccess,_,stderrText),_)->case diagnostics stderrText of Right []->True;_->False
  _->False

rejected :: FilePath -> Text -> Maybe Record -> Bool
rejected path name supplied=case (lookup name negatives,supplied) of
  (Just (code,target,end,phrases),Just (_,_,Right (ExitFailure 1,_,stderrText),_))->case diagnostics stderrText of
    Right [Diagnostic "ghc-9.12.4" "Error" observed file 4 9 4 column messages]->
      observed==code && file==path && column==end && all (`Text.isInfixOf` Text.intercalate "\n" messages) (target:phrases)
    _->False
  _->False

diagnostics :: String -> Either String [Diagnostic]
diagnostics output=traverse (\line->eitherDecodeStrict' (Encoding.encodeUtf8 line) >>= parseEither parseDiagnostic)
  [line | line<-Text.lines (Text.pack output),"{" `Text.isPrefixOf` line]

parseDiagnostic :: Value -> Parser Diagnostic
parseDiagnostic=withObject "Diagnostic" $ \value->do
  version<-value .: "ghcVersion"
  severity<-value .: "severity"
  code<-value .: "code"
  messages<-value .: "message"
  (file,line,column,endLine,endColumn)<-value .: "span" >>= withObject "Span" (\span_->do
    file<-span_ .: "file"
    (line,column)<-span_ .: "start" >>= withObject "Start" (\start->(,) <$> start .: "line" <*> start .: "column")
    (endLine,endColumn)<-span_ .: "end" >>= withObject "End" (\end->(,) <$> end .: "line" <*> end .: "column")
    pure (file,line,column,endLine,endColumn))
  pure (Diagnostic version severity code file line column endLine endColumn messages)

planIdentity :: Value -> Parser (Text,FilePath)
planIdentity=withObject "Plan" $ \plan->do
  rows<-plan .: "install-plan"
  selected<-mapM (withObject "Unit" (\row->(,,,) <$> (row .: "pkg-name" :: Parser Text)
    <*> (row .:? "component-name" .!= "" :: Parser Text) <*> (row .: "id" :: Parser Text)
    <*> (row .:? "bin-file" :: Parser (Maybe FilePath)))) rows
  case ([unit | ("amoebius","lib:layout",unit,_)<-selected],[image | ("amoebius","test:layout-suite",_,Just image)<-selected]) of
    ([unit],[image])->pure (unit,image)
    _->fail "OpaquePlanIdentityNotUnique"

readValue :: (Read value,Show value) => FilePath -> IO (Maybe value)
readValue path=do
  contents<-TextIO.readFile path
  pure (case readMaybe (Text.unpack contents) of Just value | Text.stripEnd contents==Text.pack (show value)->Just value;_->Nothing)
digest :: Bytes.ByteString -> Text
digest=Text.pack.concatMap (\byte->let hex=showHex byte "" in replicate (2-length hex) '0'<>hex).Bytes.unpack.Hash.hash

sources :: [(Text,Text)]
sources=[(name,header<>body) | (name,body)<-
  [("getters","result = staticTextCheckName\nfinding = staticTextFindingCode\nobservation = staticTextObservationValue\n")
  ,("result-constructor","value = StaticTextCheckResult\n")
  ,("finding-constructor","value = StaticTextFinding\n")
  ,("observation-constructor","value = StaticTextObservation\n")
  ,("result-read","value = read \"value\" :: StaticTextCheckResult\n")
  ,("finding-read","value = read \"value\" :: StaticTextFinding\n")
  ,("observation-read","value = read \"value\" :: StaticTextObservation\n")
  ,("result-generic","value = from (undefined :: StaticTextCheckResult)\n")
  ,("finding-generic","value = from (undefined :: StaticTextFinding)\n")
  ,("observation-generic","value = from (undefined :: StaticTextObservation)\n")
  ,("hidden-field","value = internalStaticTextCheckName\n")
  ,("capture-state","value = CaptureClosed\n")]]
 where header="module Client where\nimport Amoebius.Layout.SourceGraph\nimport GHC.Generics (from)\n"

negatives :: [(Text,(Int,Text,Int,[Text]))]
negatives=
  [("result-constructor",(1928,"StaticTextCheckResult",30,["Illegal term-level use","Amoebius.Layout.SourceGraph"]))
  ,("finding-constructor",(1928,"StaticTextFinding",26,["Illegal term-level use","Amoebius.Layout.SourceGraph"]))
  ,("observation-constructor",(1928,"StaticTextObservation",30,["Illegal term-level use","Amoebius.Layout.SourceGraph"]))
  ,("result-read",(39999,"Read StaticTextCheckResult",13,["No instance for","use of `read'"]))
  ,("finding-read",(39999,"Read StaticTextFinding",13,["No instance for","use of `read'"]))
  ,("observation-read",(39999,"Read StaticTextObservation",13,["No instance for","use of `read'"]))
  ,("result-generic",(39999,"StaticTextCheckResult",13,["No instance for","GHC.Internal.Generics.Generic","use of `from'"]))
  ,("finding-generic",(39999,"StaticTextFinding",13,["No instance for","GHC.Internal.Generics.Generic","use of `from'"]))
  ,("observation-generic",(39999,"StaticTextObservation",13,["No instance for","GHC.Internal.Generics.Generic","use of `from'"]))
  ,("hidden-field",(88464,"internalStaticTextCheckName",36,["Variable not in scope"]))
  ,("capture-state",(88464,"CaptureClosed",22,["Data constructor not in scope"]))]

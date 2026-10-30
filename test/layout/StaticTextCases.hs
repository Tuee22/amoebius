{-# LANGUAGE OverloadedStrings #-}
-- Native producer cases. Compiler-bearing cases are always executed serially.
module StaticTextCases (runStaticTextCases) where
import Amoebius.Layout.PackageMap (emptyPackageCatalog)
import Amoebius.Layout.SourceGraph
  ( sourceGraphWithPackageCatalogChecked, staticTextExamples, staticTextExamplePath
  , staticTextCaptureExamples, observeStaticTextCaptureExample
  , StaticTextCheckResult
  , staticTextCheckFindings, staticTextCheckObservations
  , staticTextFindingCode, staticTextFindingSubject, staticTextFindingDetail
  , staticTextObservationKey, staticTextObservationValue )
import Control.Exception (SomeAsyncException,SomeException,displayException,evaluate,fromException,throwIO,try)
import Control.Monad (forM)
import Data.ByteString qualified as Bytes
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, createFileLink)
import System.FilePath ((</>))
import System.PosixCompat.Files (setFileMode)

type NativeResult=Either (Text,Text) ([(Text,Text,Text)],[(Text,Text)])

runStaticTextCases :: FilePath -> IO ()
runStaticTextCases directory = do
  let owner=directory </> "static-text"
  createDirectoryIfMissing True owner
  normal <- forM staticTextExamples $ \(name,bytes)->do
    let tree=owner </> Text.unpack name
    createDirectoryIfMissing True tree
    Bytes.writeFile (tree </> staticTextExamplePath) bytes
    setFileMode (tree </> staticTextExamplePath) 0o600
    observe owner name tree [staticTextExamplePath]
  captures <- forM staticTextCaptureExamples $ \(name,edit)->do
    let tree=owner </> Text.unpack name
    bytes<-controlBytes
    createDirectoryIfMissing True tree
    Bytes.writeFile (tree </> staticTextExamplePath) bytes
    setFileMode (tree </> staticTextExamplePath) 0o600
    retain owner name [staticTextExamplePath] "capture" (observeStaticTextCaptureExample tree edit)
  paired <- forM ["manifest-empty","manifest-duplicate","source-extra","source-symlink","root-empty"] $ \name->do
    let tree=owner </> Text.unpack name
    bytes<-controlBytes
    createDirectoryIfMissing True tree
    if name=="root-empty" then pure () else do
      Bytes.writeFile (tree </> staticTextExamplePath) bytes
      setFileMode (tree </> staticTextExamplePath) 0o600
    if name=="source-extra" then do
      Bytes.writeFile (tree </> "Extra.hs") "module Extra where\nextra = ()\n"
      setFileMode (tree </> "Extra.hs") 0o600
    else pure ()
    if name=="source-symlink" then createFileLink staticTextExamplePath (tree </> "Link.hs") else pure ()
    let paths=case name of
          "manifest-empty"->[]
          "root-empty"->[]
          "manifest-duplicate"->[staticTextExamplePath,staticTextExamplePath]
          _->[staticTextExamplePath]
    observe owner name tree paths
  TextIO.writeFile (owner </> "cases.data") (Text.pack (show (normal<>captures<>paired))<>"\n")
 where
  controlBytes=case lookup "capture-control" staticTextExamples of
    Just control->pure control
    Nothing->fail "StaticTextCaptureControlUnavailable"
  observe owner name tree paths = retain owner name paths "query" $ do
    (_,_,result)<-sourceGraphWithPackageCatalogChecked tree paths Map.empty Map.empty emptyPackageCatalog Map.empty
    pure result
  retain owner name paths stage action = do
    serialized<-observeResult stage action
    _<-evaluate (Text.length serialized)
    TextIO.writeFile (owner </> Text.unpack name<>".data") (serialized<>"\n")
    pure (name,paths)

-- A failed subject query remains an explicit observation, never empty findings.
-- Force the complete healthy payload while the actual subject action is caught.
observeResult :: Text -> IO StaticTextCheckResult -> IO Text
observeResult stage action=do
  attempted<-try (do
    result<-action
    let findings=[(staticTextFindingCode item,Text.pack (staticTextFindingSubject item),staticTextFindingDetail item)
          | item<-staticTextCheckFindings result]
        observations=[(staticTextObservationKey item,staticTextObservationValue item) | item<-staticTextCheckObservations result]
        serialized=Text.pack (show (Right (findings,observations) :: NativeResult))
    _<-evaluate (Text.length serialized)
    pure serialized) :: IO (Either SomeException Text)
  case attempted of
    Right serialized->pure serialized
    Left problem->case fromException problem :: Maybe SomeAsyncException of
      Just _->throwIO problem
      Nothing->pure (Text.pack (show (Left (stage,Text.pack (displayException problem)) :: NativeResult)))

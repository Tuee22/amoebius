{-# LANGUAGE OverloadedStrings #-}
-- Actual compiler clients. Serial execution is fixed, including all negatives.
module StaticTextSurfaceCases (runStaticTextSurfaceCases) where
import Amoebius.Layout.SourceGraph (staticTextSurfaceExamples)
import Control.Exception (IOException,try)
import Control.Monad (filterM,forM)
import Data.Aeson (eitherDecodeStrict',withObject,(.:),(.:?),(.!=))
import Data.Aeson.Types (parseEither)
import Data.ByteString qualified as Bytes
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing,doesFileExist)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode)
import System.FilePath (takeDirectory,(</>))
import System.Process (readProcessWithExitCode)

runStaticTextSurfaceCases :: FilePath -> IO ()
runStaticTextSurfaceCases directory=do
  let owner=directory </> "static-text-surface"
  createDirectoryIfMissing True owner
  image<-getExecutablePath
  candidates<-filterM (doesFileExist.(</> "cache/plan.json")) (ancestors (takeDirectory image))
  buildRoot<-case candidates of [root]->pure root;_->fail "SurfaceBuildRootNotUnique"
  plan<-Bytes.readFile (buildRoot </> "cache/plan.json")
  unit<-either fail pure (eitherDecodeStrict' plan >>= parseEither layoutUnit)
  TextIO.writeFile (owner </> "context.data") (Text.pack (show (image,buildRoot,unit))<>"\n")
  names<-forM staticTextSurfaceExamples $ \(name,source)->do
    let root=owner </> Text.unpack name
        path=root </> "Client.hs"
        args=["exec","-v0","--jobs=1","--builddir="<>buildRoot,"--","ghc","-j1","-fdiagnostics-as-json",
          "-fno-code","-fforce-recomp","-XGHC2024","-package-id",Text.unpack unit,"-outputdir",root </> "objects",path]
    createDirectoryIfMissing True (root </> "objects")
    Bytes.writeFile path (Encoding.encodeUtf8 source)
    before<-Bytes.readFile path
    observed<-try (readProcessWithExitCode "cabal" args "") :: IO (Either IOException (ExitCode,String,String))
    after<-Bytes.readFile path
    TextIO.writeFile (owner </> Text.unpack name<>".data") (Text.pack (show (args,before,either (Left . show) Right observed,after))<>"\n")
    pure name
  TextIO.writeFile (owner </> "cases.data") (Text.pack (show names)<>"\n")
 where
  ancestors path=path:if takeDirectory path==path then [] else ancestors (takeDirectory path)
  layoutUnit=withObject "Plan" $ \plan->do
    rows<-plan .: "install-plan"
    units<-mapM (withObject "PlanUnit" (\row->do
      package<-row .: "pkg-name"
      component<-row .:? "component-name" .!= ""
      identity<-row .: "id"
      pure (package::Text,component::Text,identity::Text))) rows
    case [identity | ("amoebius","lib:layout",identity)<-units] of
      [identity]->pure identity
      _->fail "SurfaceLayoutUnitNotUnique"

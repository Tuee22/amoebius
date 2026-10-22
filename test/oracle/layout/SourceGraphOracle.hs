{-# LANGUAGE OverloadedStrings #-}
-- Independent snapshot acquisition, byte/mode expectations and graph controls.
module SourceGraphOracle (Snapshot, originalSnapshot, sourceGraphChecks, sourceGraphExampleChecks, runSourceGraphOracle) where

import Control.Exception (IOException, try)
import Control.Monad (forM, unless)
import Crypto.Hash.SHA256 qualified as Hash
import Data.Bits ((.&.), xor)
import Data.ByteString qualified as Bytes
import Data.List (intercalate, nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import Numeric (showHex)
import System.Directory (doesDirectoryExist, doesPathExist, getCurrentDirectory, listDirectory, pathIsSymbolicLink)
import System.Exit (exitFailure)
import System.FilePath (takeExtension, (</>))
import System.PosixCompat.Files (fileMode, getSymbolicLinkStatus, isRegularFile)
import Text.Read (readMaybe)

type Snapshot = [(FilePath,Text,Integer,Text)]
type Observation = (Text,Text,Snapshot,Snapshot,[Text],[Text],[Text])

runSourceGraphOracle :: FilePath -> IO ()
runSourceGraphOracle directory = do
  checks <- sourceGraphChecks directory
  mapM_ (\(name,green,detail) -> TextIO.putStrLn (Text.intercalate "\t" [name,if green then "green" else "red",detail])) checks
  unless (all (\(_,green,_) -> green) checks) exitFailure

sourceGraphChecks :: FilePath -> IO [(Text,Bool,Text)]
sourceGraphChecks directory = do
  root <- getCurrentDirectory
  acquisition <- try (snapshot root []) :: IO (Either IOException Snapshot)
  baseline <- readValue (directory </> "source-graph-baseline.data") :: IO (Maybe (Snapshot,Snapshot))
  observed <- readValue (directory </> "source-graph.data") :: IO (Maybe [Observation])
  whole <- readValue (directory </> "source-graph-whole.data") :: IO (Maybe ([Text],[Text]))
  controls <- readValue (directory </> "source-graph-controls.data") :: IO (Maybe [(Text,[Text])])
  cleanup <- readValue (directory </> "source-graph-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory </> "source-graph-tree")
  let original = either (const []) id acquisition
      paths = [path | (path,_,_,_) <- original]
      rows = maybe [] id observed
      complete = not (null original) && original == sort original && length paths == length (nub paths)
        && all (\(_,kind,_,identity) -> kind == "regular" && Text.length identity == 64) original
        && baseline == Just (original,original)
        && all (`elem` paths) ["src/Amoebius/Layout/Report.hs","src/Amoebius/Layout/SourceGraph.hs","test/layout/SourceGraphCases.hs","test/oracle/layout/SourceGraphOracle.hs"]
      fixtureMode = case [mode | (path,_,mode,_) <- original,path == "test/layout/SourceGraphCases.hs"] of [mode] -> mode; _ -> 0
      reference = sort (original <> [(target,"regular",fixtureMode,digestText cleanSource)])
      expected name role =
        let negative = role == "negative"
            change body = sort (original <> [(target,"regular",fixtureMode,digestText body)])
            actual = if not negative then reference else case name of
              "path-omitted" -> original
              "mode-changed" -> reference
              "bytes-changed" -> change (cleanSource <> "\n-- changed source bytes\n")
              "foreign-behavior-disguised" -> change foreignSource
              "effect-unattributed" -> change effectSource
              _ -> []
            expectedReference = if negative && name == "mode-changed"
              then sort (original <> [(target,"regular",fixtureMode `xor` 0o100,digestText cleanSource)])
              else if negative && name `elem` ["foreign-behavior-disguised","effect-unattributed"] then actual else reference
            refusals = [code <> "\t" <> Text.pack target | negative, Just code <- [lookup name [("path-omitted","SourceSnapshotPathMissing"),("mode-changed","SourceSnapshotModeChanged"),("bytes-changed","SourceSnapshotBytesChanged")]]]
            graphFindings = ["HaskellSourceUnparsable\t" <> Text.pack target | negative && name == "foreign-behavior-disguised"]
        in (expectedReference,actual,refusals,graphFindings)
      validRow name role = case [(ref,actual,findings,graphFindings,graphRows) | (key,control,ref,actual,findings,graphFindings,graphRows) <- rows,key == name,control == role] of
        [(ref,actual,findings,graphFindings,graphRows)] -> complete && (ref,actual,findings,graphFindings) == expected name role
          && graphMatches name role graphRows
        _ -> False
      expectedControls = case original of
        (path,_,_,_) : _ -> Just [("empty-reference","SourceSnapshotReferenceEmpty\tsource" : ["SourceSnapshotPathUnexpected\t" <> Text.pack p | p <- paths])
          ,("empty-observation","SourceSnapshotObservedEmpty\tsource" : ["SourceSnapshotPathMissing\t" <> Text.pack p | p <- paths])
          ,("duplicate",["SourceSnapshotDuplicate\t" <> Text.pack path])
          ,("kind",["SourceSnapshotKindChanged\t" <> Text.pack path])]
        [] -> Nothing
      wholeValid = case whole of
        Just ([],graphRows) -> [row | row <- graphRows,"graph-stage\t" `Text.isPrefixOf` row] == ["graph-stage\tresolved"]
          && sort [Text.unpack path | row <- graphRows,["graph-file",path,_] <- [Text.splitOn "\t" row]] == sort (filter ((== ".hs") . takeExtension) paths)
          && null [row | row <- graphRows,graphEvidence row,not ("graph-stage\t" `Text.isPrefixOf` row || "graph-file\t" `Text.isPrefixOf` row)]
        _ -> False
      check name green detail = ("source-graph." <> name,green,detail)
  pure (check "discovery" (complete && wholeValid && sort [(key,role) | (key,role,_,_,_,_,_) <- rows] == sort [(key,role) | key <- keys,role <- ["positive","negative"]])
      (Text.pack (show (length paths, fmap (\(a,b) -> (length a,length b)) baseline, fmap (\(fs,rs) -> (fs,length rs)) whole)))
    : [check (key <> "." <> role) (validRow key role) (Text.pack (show [(length actual,fs,gfs,filter graphEvidence rs) | (name,control,_,actual,fs,gfs,rs) <- rows,name == key,control == role])) | key <- keys,role <- ["positive","negative"]]
    <> [check "control.inventory" (complete && controls == expectedControls) "empty, duplicate and changed-kind references are refused exactly"
       ,check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup,present)))])

graphMatches :: Text -> Text -> [Text] -> Bool
graphMatches name role rows
  | name `notElem` ["foreign-behavior-disguised","effect-unattributed"] = null rows
  | role == "negative" && name == "foreign-behavior-disguised" = filter graphEvidence rows == ["graph-stage\tpartial-calls"]
  | role == "negative" = filter graphEvidence rows ==
      ["graph-stage\tpartial-calls"
      ,"graph-file\t" <> Text.pack target <> "\tSnapshotControl"
      ,"graph-import-unresolved\ttest:source-graph\t" <> Text.pack target <> "\tMissing.Effect\tcomponent-not-in-plan"
      ,"graph-call-site-opaque\ttest:source-graph\t" <> Text.pack target <> "\tvalue\t4:9-4:18\teffect\tunattributed"]
  | otherwise = filter graphEvidence rows == ["graph-stage\tresolved","graph-file\t" <> Text.pack target <> "\tSnapshotControl"]

graphEvidence :: Text -> Bool
graphEvidence row = any (`Text.isPrefixOf` row) ["graph-stage\t","graph-file\t","graph-import-unresolved\t","graph-import-standalone-unresolved\t","graph-call-site-opaque\t","graph-unscanned\t","graph-unscanned-declaration\t"]

sourceGraphExampleChecks :: [Text] -> [(Text,Bool,Text)]
sourceGraphExampleChecks report = [("source-graph.product-examples",sort observed == sort [[key,Text.pack target] | key <- keys],Text.pack (show observed))]
 where observed = [fields | row <- report,"source-graph-example" : fields <- [Text.splitOn "\t" row]]

originalSnapshot :: FilePath -> IO Snapshot
originalSnapshot root = snapshot root []

snapshot :: FilePath -> [FilePath] -> IO Snapshot
snapshot root pieces = do
  names <- sort <$> listDirectory (root </> intercalate "/" pieces)
  sort . concat <$> forM names (\name -> do
    let next = pieces <> [name]
        path = intercalate "/" next
        absolute = root </> path
    linked <- pathIsSymbolicLink absolute
    directory <- doesDirectoryExist absolute
    if null pieces && (name == ".git" || directory && not linked && name `elem` [".build",".data",".test_data","dist-newstyle","validation-records"])
      then pure [] else if directory && not linked then snapshot root next else do
        status <- getSymbolicLinkStatus absolute
        unless (not linked && isRegularFile status) (fail "SourceGraphOracleNode")
        bytes <- Bytes.readFile absolute
        pure [(path,"regular",toInteger (fileMode status .&. 0o7777),digest bytes)])

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  content <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) content)

digestText :: Text -> Text
digestText = digest . Encoding.encodeUtf8
digest :: Bytes.ByteString -> Text
digest = Text.pack . concatMap (\byte -> let value = showHex byte "" in if length value == 1 then '0' : value else value) . Bytes.unpack . Hash.hash
keys :: [Text]
keys = ["path-omitted","mode-changed","bytes-changed","foreign-behavior-disguised","effect-unattributed"]
target :: FilePath
target = "test/SnapshotControl.hs"
cleanSource, foreignSource, effectSource :: Text
cleanSource = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule SnapshotControl where\nvalue = ()\n"
foreignSource = "print('foreign behavior')\n"
effectSource = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule SnapshotControl where\nimport Missing.Effect (effect)\nvalue = effect ()\n"

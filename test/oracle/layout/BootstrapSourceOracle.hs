{-# LANGUAGE OverloadedStrings #-}
-- Independent whole-source inventory, exact bootstrap bytes and static graph.
module BootstrapSourceOracle
  ( bootstrapSourceChecks, bootstrapSourceExampleChecks, runBootstrapSourceOracle
  , expectedBootstrapCalls, expectedBootstrapEffects ) where

import SourceGraphOracle (Snapshot, originalSnapshot)
import Control.Exception (IOException, try)
import Control.Monad (unless)
import Crypto.Hash.SHA256 qualified as Hash
import Data.ByteString qualified as Bytes
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import Numeric (showHex)
import System.Directory (doesPathExist, getCurrentDirectory)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Text.Read (readMaybe)

type Observation = (Text,Text,Snapshot,Text,Either Text [Text])
type Control = (Text,Snapshot,[FilePath],Text,Either Text [Text])

runBootstrapSourceOracle :: FilePath -> IO ()
runBootstrapSourceOracle directory = do
  checks <- bootstrapSourceChecks directory
  mapM_ (\(name,green,detail) -> TextIO.putStrLn (Text.intercalate "\t" [name,if green then "green" else "red",detail])) checks
  unless (all (\(_,green,_) -> green) checks) exitFailure

bootstrapSourceChecks :: FilePath -> IO [(Text,Bool,Text)]
bootstrapSourceChecks directory = do
  root <- getCurrentDirectory
  acquired <- try (originalSnapshot root) :: IO (Either IOException Snapshot)
  acquiredBytes <- try (Bytes.readFile (root </> target)) :: IO (Either IOException Bytes.ByteString)
  baseline <- readValue (directory </> "bootstrap-source-baseline.data") :: IO (Maybe (Snapshot,Snapshot))
  observed <- readValue (directory </> "bootstrap-source.data") :: IO (Maybe [Observation])
  controls <- readValue (directory </> "bootstrap-source-controls.data") :: IO (Maybe [Control])
  cleanup <- readValue (directory </> "bootstrap-source-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory </> "bootstrap-source-tree")
  let original = either (const []) id acquired
      paths = [path | (path,_,_,_) <- original]
      body = either (const Nothing) (either (const Nothing) Just . Encoding.decodeUtf8') acquiredBytes
      source = maybe "" id body
      rows = maybe [] id observed
      complete = not (null original) && original == sort original && length paths == length (nub paths)
        && baseline == Just (original,original) && body /= Nothing
        && either (const False) ((== admittedDigest) . digest) acquiredBytes
        && Text.count argv source == 1
        && all (`elem` paths) ["src/Amoebius/Layout/PbGrammar.hs","test/layout/BootstrapSourceCases.hs","test/oracle/layout/BootstrapSourceOracle.hs"]
      sourceFor name role = if role == "positive" then source else case name of
        "bootstrap-byte-changed" -> source <> "\n# whole-source byte change\n"
        "bootstrap-extra-role" -> source <> "\nif sys.argv[1] == \"help\":\n    main()\n"
        "bootstrap-argv-rewritten" -> Text.replace argv "    bootstrap(adapter, [])" source
        _ -> ""
      snapshotFor changed = [(path,kind,mode,if path == target then digestText changed else fingerprint) | (path,kind,mode,fingerprint) <- original]
      expectedOutcome name role = if role == "positive" then Right graphRows
        else Left ("BootstrapDigestMismatch: " <> digestText (sourceFor name role))
      validCase name role = case [(snapshot,bytes,outcome) | (key,control,snapshot,bytes,outcome) <- rows,key == name,control == role] of
        [(snapshot,bytes,outcome)] -> complete && snapshot == snapshotFor (sourceFor name role)
          && bytes == sourceFor name role && withoutInventory outcome == expectedOutcome name role
        _ -> False
      projected (Left _) = True
      projected (Right output) = [Text.unpack path | row <- output,["bootstrap-source-path",path] <- [Text.splitOn "\t" row]] == paths
        && all (\row -> not ("bootstrap-source-path\t" `Text.isPrefixOf` row) || length (Text.splitOn "\t" row) == 2) output
      fixtureMode = case [mode | (path,_,mode,_) <- original,path == "test/layout/BootstrapSourceCases.hs"] of [mode] -> mode; _ -> 0
      addedSnapshot = sort (original <> [(extra,"regular",fixtureMode,digestText "module Extra where\n")])
      expectedControls =
        [("missing",filter (\(path,_,_,_) -> path /= target) original,filter (/= target) paths,"",Left "BootstrapMissing")
        ,("extra",addedSnapshot,sort (paths <> [extra]),source,Left "BootstrapInventoryRefusal: pb/__main__.py,pb/extra.hs")
        ,("duplicate",original,paths <> take 1 paths,source,Left "BootstrapInventoryRefusal: duplicate source path")
        ,("empty",original,[],source,Left "BootstrapInventoryRefusal: empty source inventory")]
      check name green detail = ("bootstrap-source." <> name,green,detail)
  pure (check "discovery" (complete && sort [(key,role) | (key,role,_,_,_) <- rows] == sort [(key,role) | key <- keys,role <- ["positive","negative"]]
        && all (\(_,_,_,_,outcome) -> projected outcome) rows)
        (Text.pack (show (length paths, fmap (\(a,b) -> (length a,length b)) baseline, [(key,role) | (key,role,_,_,_) <- rows])))
    : [check (key <> "." <> role) (validCase key role)
        (Text.pack (show [(length snapshot,withoutInventory outcome) | (name,control,snapshot,_,outcome) <- rows,name == key,control == role]))
      | key <- keys,role <- ["positive","negative"]]
    <> [check "control.inventory" (complete && controls == Just expectedControls) "missing, extra, duplicate and empty source boundaries"
       ,check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup,present)))])

withoutInventory :: Either Text [Text] -> Either Text [Text]
withoutInventory = fmap (filter (not . Text.isPrefixOf "bootstrap-source-path\t"))

bootstrapSourceExampleChecks :: [Text] -> [(Text,Bool,Text)]
bootstrapSourceExampleChecks report = [("bootstrap-source.product-examples",sort observed == sort [[key,Text.pack target] | key <- keys],Text.pack (show observed))]
 where observed = [fields | row <- report,"bootstrap-source-example" : fields <- [Text.splitOn "\t" row]]

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  text <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) text)

digestText :: Text -> Text
digestText = digest . Encoding.encodeUtf8
digest :: Bytes.ByteString -> Text
digest = Text.pack . concatMap (\byte -> let value = showHex byte "" in if length value == 1 then '0' : value else value) . Bytes.unpack . Hash.hash
target, extra :: FilePath
target = "pb/__main__.py"
extra = "pb/extra.hs"
argv, admittedDigest :: Text
argv = "    bootstrap(adapter, sys.argv[1:])"
admittedDigest = "1dc366fbf309694dcab66915a9449cca1fe79a547aba565f26049915e027ac7a"
keys :: [Text]
keys = ["bootstrap-byte-changed","bootstrap-extra-role","bootstrap-argv-rewritten"]
graphRows :: [Text]
graphRows = sort ([Text.intercalate "\t" ["bootstrap-call",owner,call] | (owner,call) <- expectedBootstrapCalls]
  <> [Text.intercalate "\t" ["bootstrap-effect",owner,call] | (owner,call) <- expectedBootstrapEffects])

expectedBootstrapCalls :: [(Text, Text)]
expectedBootstrapCalls =
  [ ("BootstrapAdapter.capture", "subprocess.run")
  , ("BootstrapAdapter.ensure_ghcup", "response.read")
  , ("BootstrapAdapter.ensure_ghcup", "target.chmod")
  , ("BootstrapAdapter.ensure_ghcup", "target.is_file")
  , ("BootstrapAdapter.ensure_ghcup", "target.parent.mkdir")
  , ("BootstrapAdapter.ensure_ghcup", "target.write_bytes")
  , ("BootstrapAdapter.ensure_ghcup", "urllib.request.urlopen")
  , ("BootstrapAdapter.environment", "cache.mkdir")
  , ("BootstrapAdapter.environment", "home.mkdir")
  , ("BootstrapAdapter.environment", "str")
  , ("BootstrapAdapter.environment", "temporary.mkdir")
  , ("BootstrapAdapter.handoff", "os.execv")
  , ("BootstrapAdapter.platform", "platform.machine")
  , ("BootstrapAdapter.platform", "platform.system")
  , ("BootstrapAdapter.repository_root", ".resolve")
  , ("BootstrapAdapter.repository_root", "Path")
  , ("BootstrapAdapter.run", "subprocess.run")
  , ("bootstrap", "adapter.capture")
  , ("bootstrap", "adapter.ensure_ghcup")
  , ("bootstrap", "adapter.environment")
  , ("bootstrap", "adapter.handoff")
  , ("bootstrap", "adapter.platform")
  , ("bootstrap", "adapter.repository_root")
  , ("bootstrap", "adapter.run")
  , ("bootstrap", "binary_bytes.decode")
  , ("bootstrap", "binary_text.strip")
  , ("bootstrap", "ghcup_version_bytes.decode")
  , ("bootstrap", "ghc_version_bytes.decode")
  , ("bootstrap", "RuntimeError")
  , ("bootstrap", "select_artifact")
  , ("bootstrap", "str")
  , ("main", "BootstrapAdapter")
  , ("main", "bootstrap")
  , ("module", "main")
  , ("select_artifact", "RuntimeError")
  ]

expectedBootstrapEffects :: [(Text, Text)]
expectedBootstrapEffects =
  [ ("BootstrapAdapter.capture", "subprocess.run")
  , ("BootstrapAdapter.ensure_ghcup", "response.read")
  , ("BootstrapAdapter.ensure_ghcup", "target.chmod")
  , ("BootstrapAdapter.ensure_ghcup", "target.is_file")
  , ("BootstrapAdapter.ensure_ghcup", "target.parent.mkdir")
  , ("BootstrapAdapter.ensure_ghcup", "target.write_bytes")
  , ("BootstrapAdapter.ensure_ghcup", "urllib.request.urlopen")
  , ("BootstrapAdapter.environment", "cache.mkdir")
  , ("BootstrapAdapter.environment", "home.mkdir")
  , ("BootstrapAdapter.environment", "temporary.mkdir")
  , ("BootstrapAdapter.handoff", "os.execv")
  , ("BootstrapAdapter.platform", "platform.machine")
  , ("BootstrapAdapter.platform", "platform.system")
  , ("BootstrapAdapter.repository_root", ".resolve")
  , ("BootstrapAdapter.run", "subprocess.run")
  ]


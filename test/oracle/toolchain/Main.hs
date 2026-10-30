{-# LANGUAGE OverloadedStrings #-}
-- | Independent version and probe expectations. No product dependency.
module Main (main) where
import Control.Monad (forM, unless, when)
import Control.Exception (IOException, evaluate, throwIO, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (Value (..), eitherDecodeStrict)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as Bytes
import Data.Foldable (toList)
import Data.Map.Strict qualified as Map
import Data.List (sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)
import Numeric.Natural (Natural)
import Text.Read (readMaybe)
import System.Directory (XdgDirectory (XdgConfig), canonicalizePath, doesDirectoryExist, doesFileExist, doesPathExist, findExecutable, getAppUserDataDirectory, getCurrentDirectory, getFileSize, getXdgDirectory, listDirectory, makeAbsolute, pathIsSymbolicLink)
import System.FilePath (isAbsolute, makeRelative, splitDirectories, takeFileName, (</>))
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode (..), exitFailure, exitWith)
import System.IO (hFlush, hSetEncoding, hSetNewlineMode, noNewlineTranslation, stderr, stdout, utf8)
import System.IO.Error (isDoesNotExistError)
import VersionExpectations (versionCases)
import Admission (admissionChecks)
import ProbeSource (probeSourceChecks)
import VendorSource (vendorSourceChecks)
import Inventory (toolchainInventoryNames)

main :: IO ()
main = do
  supplied <- getArgs
  when (any (`elem` supplied) ["--oracle-invocation", "--oracle-inventory"]) $ do
    hSetEncoding stderr utf8
    hSetNewlineMode stderr noNewlineTranslation
  (invocation, arguments) <- invocationArguments supplied
  inventory <- inventoryRequest invocation arguments
  case inventory of
    Just (challenge, withBinary) -> emitInventory challenge withBinary
    Nothing -> case invocation of
      Nothing -> legacyMain arguments
      Just challenge -> runNormalInvocation challenge arguments

inventoryRequest :: Maybe Text -> [String] -> IO (Maybe (Text, Bool))
inventoryRequest invocation arguments
  | "--oracle-inventory" `notElem` arguments = pure Nothing
  | otherwise = case (invocation, arguments) of
      (Just challenge, ["--oracle-inventory", "toolchain.full.v1"]) -> pure (Just (challenge, False))
      (Just challenge, ["--oracle-inventory", "toolchain.gate.v1"]) -> pure (Just (challenge, True))
      (Nothing, _) -> invocationFailure "InvocationRequired"
      (Just _, ["--oracle-inventory", _]) -> invocationFailure "InventoryProfileUnknown"
      _ -> invocationFailure "InventoryArguments"

emitInventory :: Text -> Bool -> IO ()
emitInventory challenge withBinary = do
  let names = toolchainInventoryNames withBinary
      prefix = Text.unlines [name <> "\tgreen\tdeclared" | name <- names]
      count = foldr (const (+ 1)) 0 names :: Natural
  emitCompletion challenge prefix count "all-green" "-"
  exitWith ExitSuccess

-- Preserve the old unflagged file, directory and specialized diagnostics.
legacyMain :: [String] -> IO ()
legacyMain arguments =
  case arguments of
    ["--native-tool-versions", directory] -> admissionChecks directory >>= emit
    ["--native-config-origin", directory] -> do
      absolute <- makeAbsolute directory
      origins <- nativeConfigOriginChecks absolute
      (compatible,observed) <- nativeConfigCompatibility absolute
      emit (("native-config.compatibility",compatible,observed) : origins)
    ["--probe-source", directory] -> probeSourceChecks directory >>= emit
    ["--vendor-source", directory] -> vendorSourceChecks directory >>= emit
    [input] -> toolchainChecks input
    _ -> exitFailure

emit :: [(Text, Bool, Text)] -> IO ()
emit rows = do
  mapM_ (\(name, green, observed) -> TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", observed])) rows
  unless (all (\(_, green, _) -> green) rows) exitFailure

-- Gated completion is only for the original full-directory normal route.
runNormalInvocation :: Text -> [String] -> IO ()
runNormalInvocation challenge arguments = do
  (withBinary, supplied) <- case arguments of
    [path] -> pure (True, path)
    ["--oracle-profile", "toolchain.full.v1", path] -> pure (False, path)
    ["--oracle-profile", "toolchain.gate.v1", path] -> pure (True, path)
    _ -> invocationFailure "InvocationArguments"
  input <- makeAbsolute supplied
  present <- doesDirectoryExist input
  unless present (invocationFailure "InvocationDirectoryRequired")
  contents <- requiredRead challenge (input </> "toolchain.tsv")
  ledger <- toolchainRows input True withBinary contents
  let prefix = Text.unlines (map renderCompletionRow ledger)
      count = foldr (const (+ 1)) 0 ledger :: Natural
      green = all (\(_, okay, _) -> okay) ledger
  emitCompletion challenge prefix count (if green then "all-green" else "some-red") "-"
  exitWith (if green then ExitSuccess else ExitFailure 1)

-- A supplied leading invocation opts into bookkeeping, not a gate authority seal.
invocationArguments :: [String] -> IO (Maybe Text, [String])
invocationArguments arguments = case arguments of
  "--oracle-invocation" : challenge : rest
    | "--oracle-invocation" `elem` rest -> invocationFailure "InvocationRepeated"
    | length challenge /= 64 || not (all lowerHex challenge) -> invocationFailure "InvocationMalformed"
    | otherwise -> pure (Just (Text.pack challenge), rest)
  ["--oracle-invocation"] -> invocationFailure "InvocationValueMissing"
  _ | "--oracle-invocation" `elem` arguments -> invocationFailure "InvocationPosition"
    | otherwise -> pure (Nothing, arguments)
 where lowerHex character = ('0' <= character && character <= '9') || ('a' <= character && character <= 'f')

invocationFailure :: String -> IO a
invocationFailure reason = do
  TextIO.hPutStrLn stderr ("oracle-toolchain: " <> Text.pack reason)
  exitWith (ExitFailure 2)

-- Only this actual primary read's missing IOException earns a missing marker.
requiredRead :: Text -> FilePath -> IO Text
requiredRead challenge path = do
  attempted <- try (TextIO.readFile path >>= \contents -> evaluate (Text.length contents) >> pure contents) :: IO (Either IOException Text)
  case attempted of
    Right contents -> pure contents
    Left problem | isDoesNotExistError problem -> do
      TextIO.hPutStrLn stderr (Text.pack (show problem))
      hFlush stderr
      emitCompletion challenge "" 0 "required-input-missing" (Text.pack (show (Text.pack path)))
      exitWith (ExitFailure 1)
    Left problem -> throwIO problem

renderCompletionRow :: (Text, Bool, Text) -> Text
renderCompletionRow (name, green, observed) =
  Text.intercalate "\t" [name, if green then "green" else "red", observed]

emitCompletion :: Text -> Text -> Natural -> Text -> Text -> IO ()
emitCompletion challenge prefix count purpose locus = do
  let digest = shaBytes (Encoding.encodeUtf8 prefix)
      footer = Text.intercalate "\t"
        ["oracle.protocol.complete.v1", "green", "retained-text-utf8.v1", challenge,
         Text.pack (show count), digest, purpose, locus] <> "\n"
  _ <- evaluate (Text.length prefix)
  _ <- evaluate (Text.length footer)
  hSetEncoding stdout utf8
  hSetNewlineMode stdout noNewlineTranslation
  TextIO.hPutStr stdout prefix
  hFlush stdout
  TextIO.hPutStr stdout footer
  hFlush stdout

toolchainChecks :: FilePath -> IO ()
toolchainChecks supplied = do
  input <- makeAbsolute supplied
  directory <- doesDirectoryExist input
  observed <- try (TextIO.readFile (if directory then input <> "/toolchain.tsv" else input)) :: IO (Either IOException Text)
  contents <- case observed of
    Left _ -> TextIO.putStrLn "observation.toolchain\tred\trequired toolchain.tsv is unreadable" >> exitFailure
    Right bytes -> pure bytes
  complete <- toolchainRows input directory True contents
  emit complete

-- The SAME actual old core/secondary judgments, in their original IO order.
-- The gated caller supplies its forced first primary read; later explicit
-- secondary rereads retain their original operations and catches below.
toolchainRows :: FilePath -> Bool -> Bool -> Text -> IO [(Text, Bool, Text)]
toolchainRows input directory withBinary contents = do
  codegen <- if directory then codegenEvidence input else pure (False,"actual codegen observation requires its directory")
  let rows = Map.fromList [(key, Text.intercalate "\t" rest) | line <- Text.lines contents, key : rest <- [Text.splitOn "\t" line]]
      value key = Map.findWithDefault "<absent>" key rows
      exact key expected = (key, value key == expected, value key)
      prefix key expected = (key, expected `Text.isPrefixOf` value key, value key)
      ledger = [exact ("version.case." <> Text.pack (show index)) (Text.intercalate "|" [tool, raw, verdict]) | (index, (tool, raw, verdict)) <- zip [1 :: Int ..] versionCases]
        <> [("version.discovery", length [key | key <- Map.keys rows, "version.case." `Text.isPrefixOf` key] == length versionCases, "version case inventory")]
        <> [exact "versions.verdict" "accepted", exact "second.verdict" "none", exact "report.versions.verdict" "accepted", exact "report.request.positive" "accepted", exact "report.request.negative" "ToolVersionMismatch: ghc", exact "negative.ReportUnknownArgument" "toolchain-report: unknown argument --bogus",
           exact "report.probe.decode.positive" "decoded amoebius/3/True", exact "report.probe.decode.mistyped" "refused type-error", exact "report.probe.sim.clean" "b:2", exact "report.probe.sim.perturbed" "a:1", exact "report.probe.codegen.link-token" "0a08616d6f65626975731003", exact "report.probe.bridge.files" "Amoebius/Toolchain/Probe.purs", exact "report.provenance.fork-modules" "17", exact "probe.decode.positive" "decoded amoebius/3/True", prefix "probe.decode.mistyped" "refused type-error", exact "probe.sim.clean" "b:2", exact "probe.sim.perturbed" "a:1", exact "fork.modules" "17", exact "fork.problems" "none", exact "layout.problems" "none", exact "upstream.verdict" "acquired"
           , ("probe.codegen.files",value "probe.codegen.files" == "Proto/Probe.hs,Proto/Probe_Fields.hs" && fst codegen,snd codegen)
           , ("plan.packages", all (`elem` Text.splitOn "," (value "plan.packages")) ["dhall", "io-classes", "io-sim", "proto-lens", "proto-lens-runtime", "purescript-bridge", "tar", "zlib"], value "plan.packages")
           , exact "report.provenance.upstream" "supernova-0.0.3 2e2f01be19b08128cd8549befcc1da3fea172b1f5b3471845d05ef8dc06dda33"]
        <> [prefix ("negative." <> key) expected | (key, expected) <- [("MissingTool", "ToolMissing"), ("MalformedVersion", "ToolVersionMalformed"), ("UnsupportedVersion", "ToolVersionMismatch"), ("UnsupportedGhcupVersion", "ToolVersionMismatch"), ("FailedVersionCommand", "ToolCommandFailed"), ("TrackedResolutionOutput", "TrackedResolutionOutput"), ("TrackedProbeInput", "TrackedProbeInput"), ("MutableIdentity", "MutableIdentity"), ("TopLevelVendor", "TopLevelVendor"), ("AbsentTool", "AbsentTool"), ("OutOfRangeVersion", "OutOfRangeVersion"), ("NoPlatformAsset", "NoPlatformAsset"), ("UpstreamDigestMismatch", "DigestMismatch")]]
        <> [exact "negative.MissingDependency" "MissingDependency: amoebius-absent-probe", exact "report.probe.source.findings" "", exact "report.provenance.layout" "", exact "report.resolution.source.findings" ""]
        <> [("report.probe.discovery", sort [key | line <- Text.lines contents, key : _ <- [Text.splitOn "\t" line], "report.probe." `Text.isPrefixOf` key]
             == sort ["report.probe." <> key | key <- ["decode.positive", "decode.mistyped", "sim.clean", "sim.perturbed", "codegen.link-token", "bridge.files", "source.findings"]], "exact shipped-report probe inventory")]
        <> [exact "report.plan.steps" "ensure ghc 9.12.4 versioned via ghcup; ensure cabal-install 3.16.1.0 managed via ghcup; ensure proto-lens-protoc 0.9.0.1 managed via cabal-install; ensure protoc 3.21.12 managed via package-manager"]
        <> [exact "plan.steps" "ensure ghc 9.12.4 versioned via ghcup; ensure cabal-install 3.16.1.0 managed via ghcup; ensure proto-lens-protoc 0.9.0.1 managed via cabal-install; ensure protoc 3.21.12 managed via package-manager"]
        <> [exact "child.absent.exit" "127", exact "child.absent.stdout" "", prefix "child.absent.stderr" "executable not found:", exact "child.failed-cwd.exit" "127", exact "child.failed-cwd.stdout" "", ("child.failed-cwd.stderr", not (Text.null (value "child.failed-cwd.stderr")), "spawn error observed")]
        <> [exact "second.mismatch.ghcup" "AcquisitionsDisagree: ghcup.version 0.1.50.2 /= 0.2.6.2", exact "second.mismatch.compiler" "AcquisitionsDisagree: compiler.version 9.12.4 /= 9.10.1", exact "second.cabal-version" "none", exact "versions.cabal-report-unavailable" "accepted"]
        <> [exact "report.cli.unknown.exit" "2", prefix "report.cli.unknown.stderr" "toolchain-report: unknown argument --bogus", exact "report.cli.emit.exit" "0", exact "report.cli.run.exit" "0", exact "report.cli.run.stdout" ""]
  binary <- if directory && withBinary then binaryRows input else pure []
  cli <- if directory then cliRows input else pure []
  admission <- if directory then admissionChecks input else pure []
  source <- if directory then probeSourceChecks input else pure []
  vendor <- if directory then vendorSourceChecks input else pure []
  semantics <- if directory then semanticRows input else pure []
  resolution <- if directory then resolutionRows input else pure []
  upstream <- if directory then upstreamRows input else pure []
  let complete = ledger <> binary <> cli <> admission <> source <> vendor <> semantics <> resolution <> upstream
  pure complete

cliRows :: FilePath -> IO [(Text, Bool, Text)]
cliRows directory = do
  let request = directory <> "/cli/request/deep/request.tsv"
      report = directory <> "/cli/output/deep/report.tsv"
  requestBytes <- outputRead request
  reportBytes <- maybe "" id <$> outputRead report
  let values = Map.fromList [(key, value) | line <- Text.lines reportBytes, [key, value] <- [Text.splitOn "\t" line]]
      check name condition = (name, condition, if condition then "ok" else "report contract differs")
  firstPlan <- rawPlan (directory <> "/cli/acquired/plan-a/dist/cache/plan.json")
  secondPlan <- rawPlan (directory <> "/cli/acquired/plan-b/dist/cache/plan.json")
  firstCompatibility <- compatiblePlan (directory <> "/cli/acquired/plan-a/dist/cache/plan.json")
  secondCompatibility <- compatiblePlan (directory <> "/cli/acquired/plan-b/dist/cache/plan.json")
  let transport label planRoot = case Map.lookup (label <> ".child") values >>= readMaybe . Text.unpack of
        Just child -> resolutionContext (planRoot </> "probe-plan/.build") (childArgv child)
        Nothing -> pure (False,"reported child missing")
  firstTransport <- transport "acquisition.plan-a" (directory </> "cli/acquired/plan-a")
  secondTransport <- transport "acquisition.plan-b" (directory </> "cli/acquired/plan-b")
  let planMatches label result admitted compatible = fst admitted && fst compatible && case result of
        Just (units, packages, digest) -> Map.lookup (label <> ".verdict") values == Just "accepted"
          && Map.lookup (label <> ".units") values == Just (Text.intercalate "," units)
          && Map.lookup (label <> ".packages") values == Just (Text.intercalate "," packages)
          && Map.lookup (label <> ".sha256") values == Just digest
          && case Map.lookup (label <> ".child") values >>= readMaybe . Text.unpack of
               Just child -> childExit child == 0 && Just (Text.pack (childExecutable child)) == Map.lookup "package-tool.executable" values
                 && serialResolution (Map.findWithDefault "" "compiler.executable" values) (childArgv child)
               Nothing -> False
        _ -> False
  pure [check "report.cli.request" (requestBytes == Just "label\t0b5e17e11a0c0ffee0de1e9a7e5ba5ed\nghc.requested-version\t9.12.4\n")
       , check "report.cli.label" (Map.lookup "request.label" values == Just "cli-fixture")
       , check "report.cli.refusal" (Map.lookup "request.verdict" values == Just "ToolVersionMismatch: ghc")
       , check "report.cli.acquisition" (Map.lookup "acquisition.verdict" values == Just "agree")
       , check "report.cli.native" (Map.lookup "versions.verdict" values == Just "accepted" && Map.lookup "compiler.version" values == Just "9.12.4")
       , ("case:report.cli.plan-a",planMatches "acquisition.plan-a" firstPlan firstTransport firstCompatibility,Text.pack (show (snd firstTransport,snd firstCompatibility)))
       , ("case:report.cli.plan-b",planMatches "acquisition.plan-b" secondPlan secondTransport secondCompatibility,Text.pack (show (snd secondTransport,snd secondCompatibility)))
       , check "case:report.cli.plans-agree" (firstPlan /= Nothing && firstPlan == secondPlan && Map.lookup "acquisition.plans.verdict" values == Just "agree")
       , check "case:report.cli.source" (Map.lookup "resolution.source.findings" values == Just "")]

 where
  outputRead path = do
    attempted <- try (TextIO.readFile path >>= \contents -> evaluate (Text.length contents) >> pure contents) :: IO (Either IOException Text)
    case attempted of
      Right contents -> pure (Just contents)
      Left original | isDoesNotExistError original -> pure Nothing
                    | otherwise -> throwIO original

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  bytes <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) bytes)

codegenEvidence :: FilePath -> IO (Bool,Text)
codegenEvidence directory = do
  attempted <- try inspect :: IO (Either IOException (Bool,Text))
  pure (either (\problem -> (False,Text.pack (show problem))) id attempted)
 where
  inspect = do
    let root = directory </> "proto"
        output = root </> "generated"
        target = directory </> "tools/proto-lens-protoc"
        expectedPaths = ["Proto/Probe.hs","Proto/Probe_Fields.hs"]
        expectedSchema = "syntax = \"proto3\";\npackage amoebius.probe;\nmessage ProbeMessage {\n  string name = 1;\n  uint32 replicas = 2;\n}\n"
    observed <- readValue (directory </> "codegen.data") :: IO (Maybe (Either Text ([FilePath],ChildObservation),Text,[(FilePath,Text,Text)]))
    process <- readValue (root </> "codegen-process.data") :: IO (Maybe (ChildObservation,String,String))
    installed <- readValue (directory </> "install-positive.data") :: IO (Maybe (Either Text (FilePath,Maybe ChildObservation)))
    native <- findExecutable "protoc"
    actualSchema <- Bytes.readFile (root </> "probe.proto")
    files <- inventory output
    actual <- forM files $ \(path,_,digest) -> (path,digest,) <$> Bytes.readFile (output </> path)
    confined <- and <$> mapM (within directory) [root,output,target]
    case (observed,process,installed,native) of
      (Just (Right (reported,returned),schema,recorded),Just (child,stdout,stderr),Just (Right (selected,_)),Just executable) -> do
        executableHash <- shaBytes <$> Bytes.readFile executable
        let matchingBytes = [(path,digest,Encoding.encodeUtf8 bytes) | (path,digest,bytes) <- recorded] == actual
            moduleBytes path = case [bytes | (name,_,bytes) <- recorded, name == path] of [bytes] -> bytes; _ -> ""
            mainModule = moduleBytes "Proto/Probe.hs"
            fieldModule = moduleBytes "Proto/Probe_Fields.hs"
            compact = Text.unwords . Text.words
            declarations bytes = [Text.words line | line <- Text.lines bytes, "module" : _ <- [Text.words line]]
            mainDeclaration = case declarations mainModule of [["module","Proto.Probe","("]] -> True; _ -> False
            fieldDeclaration = declarations fieldModule == [["module","Proto.Probe_Fields","where"]]
            mainFields = all (`Text.isInfixOf` compact mainModule)
              ["data ProbeMessage","instance Data.ProtoLens.Field.HasField ProbeMessage \"name\" Data.Text.Text where"
              ,"instance Data.ProtoLens.Field.HasField ProbeMessage \"replicas\" Data.Word.Word32 where"
              ,"messageName _ = Data.Text.pack \"amoebius.probe.ProbeMessage\""
              ,"(Data.ProtoLens.Tag 1, name__field_descriptor)","(Data.ProtoLens.Tag 2, replicas__field_descriptor)"]
            fieldLenses = all (`Text.isInfixOf` compact fieldModule)
              ["name = Data.ProtoLens.Field.field @\"name\"","replicas = Data.ProtoLens.Field.field @\"replicas\""]
            okay = confined && reported == expectedPaths && map (\(path,_,_) -> path) recorded == expectedPaths
              && map (\(path,_,_) -> path) files == expectedPaths && matchingBytes
              && schema == expectedSchema && actualSchema == Encoding.encodeUtf8 expectedSchema
              && returned == child && childExit child == 0 && selected == target
              && childTool child == Text.pack executable && childExecutable child == executable && childDigest child == executableHash
              && childArgv child == ["--plugin=protoc-gen-haskell=" <> Text.pack target,"--haskell_out=" <> Text.pack output,"-I",Text.pack root,"probe.proto"]
              && mainDeclaration && fieldDeclaration && mainFields && fieldLenses
        pure (okay,Text.pack (show (reported,returned,child,stdout,stderr,schema,recorded,files,executableHash)))
      _ -> pure (False,Text.pack (show (observed,process,installed,native)))

semanticRows :: FilePath -> IO [(Text, Bool, Text)]
semanticRows directory = do
  simulation <- readValue (directory <> "/simulation.data") :: IO (Maybe [(Text, [(Text, Int, Int)], Maybe Text, Either Text Text, Text)])
  planner <- readValue (directory <> "/planner-pairs.data") :: IO (Maybe [(Text, Text, Text, [(Text, [Int])], [Text], Either [Text] [Text])])
  sources <- readValue (directory <> "/resolution-sources.data") :: IO (Maybe ([(Text, Text, FilePath, Text, [FilePath], [Text])], Bool))
  serial <- readValue (directory <> "/serial-arguments.data") :: IO (Maybe ([([String],[String])],[([String],[String])]))
  installation <- installObservations directory
  nativeConfig <- nativeConfigPairs directory
  let refusal = "SimulationNoOutput: simulation completed without a terminal value"
      expectedSimulation = [("positive", [("a",10,1),("b",20,2)], Just "b:2", Right "b:2", "b:2")
        ,("negative", [], Nothing, Left refusal, refusal)]
      assets = ["ghc@9.12.4:example-native", "cabal-install@3.16.1.0:example-native", "proto-lens-protoc@0.9.0.1:example-native", "protoc@3.21.12:example-native"]
      ensured = Right ["ensure ghc 9.12.4 versioned via ghcup"]
      expectedPlanner = [("absent-tool","positive","example-native",[],assets,ensured)
        ,("absent-tool","negative","example-native",[],[],Left ["AbsentTool: ghc; remedy: supply catalogue asset for ghc >=9.12.4 && <9.13"])
        ,("out-of-range","positive","example-native",[("ghc",[9,12,4])],assets,Right ["present ghc 9.12.4"])
        ,("out-of-range","negative","example-native",[("ghc",[9,10,1])],assets,Left ["OutOfRangeVersion: ghc 9.10.1; remedy: replace inventory version of ghc with >=9.12.4 && <9.13"])
        ,("platform-asset","positive","example-native",[],assets,ensured)
        ,("platform-asset","negative","unsupported-unknown",[],assets,Left ["NoPlatformAsset: ghc unsupported-unknown; remedy: supply catalogue asset for ghc >=9.12.4 && <9.13 on unsupported-unknown"])]
      freeze = "constraints: dhall >=1.42 && <1.43\n"
      expectedSources = [("freeze","positive",".build/cabal.project.freeze",freeze,[],[])
        ,("freeze","negative","cabal.project.freeze",freeze,["cabal.project.freeze"],["TrackedResolutionOutput: cabal.project.freeze"])
        ,("package-pin","positive","cabal.project","packages: .\n",["cabal.project"],[])
        ,("package-pin","negative","cabal.project","constraints: dhall ==1.42.3\n",["cabal.project"],["TrackedPackagePin: cabal.project"])
        ,("developer-home","positive","cabal.project.local","with-compiler: ghc\n",["cabal.project.local"],[])
        ,("developer-home","negative","cabal.project.local","with-compiler: /home/developer/ghc\n",["cabal.project.local"],["DeveloperHomePath: cabal.project.local"])
        ,("multiline-pin","positive","cabal.project","constraints:\n  dhall >=1.42 && <1.43, -- == is a comment\n  io-sim >=1.10 && <1.11\n",["cabal.project"],[])
        ,("multiline-pin","negative","cabal.project","constraints:\n  dhall >=1.42 && <1.43, -- == is a comment\n  io-sim ==1.10.1.0\n",["cabal.project"],["TrackedPackagePin: cabal.project"])
        ,("comment-only","positive","cabal.project","-- constraints: dhall ==1.42.3\n",["cabal.project"],[])
        ,("comment-only","negative","cabal.project","constraints: dhall ==1.42.3\n",["cabal.project"],["TrackedPackagePin: cabal.project"])]
      fixed = ["--offline","--jobs=1","--with-compiler=/native/ghc","--ghc-options=-j1"]
      expectedSerial =
        ([(["build","--dry-run"],["build","--dry-run"] <> fixed)
         ,(["build","-j","16","--jobs=8","--ghc-options=-O0 -j4","--","-j7"],["build","--ghc-options=-O0"] <> fixed <> ["--","-j7"])
         ,(["run","--with-compiler=/foreign/ghc","--with-ghc","foreign","-wother","-j8","--","--jobs=12"],["run"] <> fixed <> ["--","--jobs=12"])
         ,(["build","-j","--jobs"],["build"] <> fixed)
         ,(["build","--offline=False","--online","true","--no-offline","--offline","False","--online=False","--no-offline=true","--","--online"],["build"] <> fixed <> ["--","--online"])]
        ,[(["-fno-code"],["-fno-code","-j1"]),(["-fno-code","-j","12","--","-j9"],["-fno-code","-j1","--","-j9"]),(["-j","-O0"],["-O0","-j1"])])
      check name okay detail = ("case:" <> name, okay, Text.pack (show detail))
  pure [check "simulation.terminal-pair" (simulation == Just expectedSimulation) simulation
       ,check "planner.paired-remedies" (planner == Just expectedPlanner) planner
       ,check "resolution.source-pairs" (sources == Just (expectedSources, True)) sources
       ,check "build.fixed-serial-arguments" (serial == Just expectedSerial && fst installation && fst nativeConfig) (serial,snd installation,snd nativeConfig)]

nativeConfigPairs :: FilePath -> IO (Bool,Text)
nativeConfigPairs directory = do
  (compatible,observed) <- nativeConfigCompatibility directory
  origins <- nativeConfigOriginChecks directory
  pure (compatible && all (\(_,green,_) -> green) origins,Text.pack (show (observed,origins)))

nativeConfigCompatibility :: FilePath -> IO (Bool,Text)
nativeConfigCompatibility directory = do
  observed <- readValue (directory </> "native-config.data") :: IO (Maybe [(Text,Either Text FilePath,Text,Bool,Bool)])
  let owner = directory </> "native-config-cases"
      existing = owner </> "explicit.config"
      missing = owner </> "explicit-missing.config"
  okay <- case observed of
    Just [("existing",Right actual,"-- supplied read-only native configuration\n",False,False)
         ,("implicit-missing",Right generated,"",False,False)
         ,("explicit-missing",Left reason,"",False,False)] -> do
      confined <- within owner generated
      bytes <- try (Bytes.readFile generated) :: IO (Either IOException Bytes.ByteString)
      absent <- not <$> doesPathExist missing
      pure (actual == existing && confined && "native-cabal-config-" `Text.isPrefixOf` Text.pack (takeFileName generated)
        && bytes == Right Bytes.empty && absent && reason == "user error (NativeCabalConfigAbsent: " <> Text.pack missing <> ")")
    _ -> pure False
  pure (okay,Text.pack (show observed))

-- Independent native selector expectations. The operation names and ordering
-- are literal; this oracle has no product or validator dependency.
type NativeConfigOriginRow = (Text,FilePath,[(String,Maybe (Either String String))],Maybe String,Maybe FilePath,Maybe String,Either String FilePath,Either Text FilePath,Bool)
nativeConfigOriginChecks :: FilePath -> IO [(Text,Bool,Text)]
nativeConfigOriginChecks directory = do
  observed <- readValue (directory </> "native-config-origin.data") :: IO (Maybe [NativeConfigOriginRow])
  current <- getCurrentDirectory
  frame <- canonicalizePath current
  build <- canonicalizePath (frame </> ".build")
  owned <- canonicalizePath (directory </> "native-config-cases")
  let owner = directory </> "native-config-cases"
      existing = owner </> "explicit.config"
      missing = owner </> "explicit-missing.config"
      implicit = owner </> "implicit-missing/config"
      names = ["explicit-present","implicit-fresh","explicit-missing","explicit-empty","owner-outside"]
      step tag path = tag <> " " <> show path
      returned operation value = (operation,Just (Right value))
      pathReturn = ("ConfigPathReturn " <>) . show
      prefix ownerInput physicalOwner =
        [returned "ConfigCurrentDirectory" (pathReturn current)
        ,returned (step "ConfigCanonicalFrame" current) (pathReturn frame)
        ,returned (step "ConfigCanonicalBuild" (frame </> ".build")) (pathReturn build)
        ,returned (step "ConfigCanonicalOwner" ownerInput) (pathReturn physicalOwner)
        ,returned (step "ConfigOwnerDirectory" physicalOwner) "ConfigBoolReturn True"]
      policy physicalOwner = "ConfigOwnerPolicy " <> show frame <> " " <> show build <> " " <> show physicalOwner <> " True"
      base = prefix owner owned <> [returned (policy owned) "ConfigUnitReturn"]
      explicit value = returned "ConfigLookupExplicit" ("ConfigLookupReturn (Just " <> show value <> ")")
      missingError value = "user error (NativeCabalConfigAbsent: " <> value <> ")"
      judge (name,input,steps,selection,operand,origin,result,compatibility,sameCause) = do
        let common expectedInput expectedSteps expectedSelection expectedOperand expectedOrigin expectedResult =
              input == expectedInput && steps == expectedSteps && selection == expectedSelection
              && operand == expectedOperand && origin == expectedOrigin && result == expectedResult
              && compatibility == either (Left . Text.pack) Right expectedResult && sameCause
            explicitBase value present = base <> [explicit value
              ,returned (step "ConfigSelectedFilePresent" value) ("ConfigBoolReturn " <> show present)]
            refused value = let reason = missingError value in common owner
                  (explicitBase value False <> [(step "ConfigExplicitMissing" value,Just (Left reason))])
                  (Just "ExplicitConfigSelection") (Just value) Nothing (Left reason)
        okay <- case name of
          "explicit-present" -> pure (common owner
            (explicitBase existing True <> [returned (step "ConfigSelectedAbsolute" existing) (pathReturn existing)])
            (Just "ExplicitConfigSelection") (Just existing) (Just "ExistingSelectedConfig") (Right existing))
          "implicit-fresh" -> case result of
            Right generated -> do
              confined <- within owner generated
              bytes <- try (Bytes.readFile generated) :: IO (Either IOException Bytes.ByteString)
              absent <- not <$> doesPathExist (owner </> "implicit-missing")
              pure (confined && bytes == Right Bytes.empty && absent
                && "native-cabal-config-" `Text.isPrefixOf` Text.pack (takeFileName generated)
                && common owner (base <>
                  [returned "ConfigLookupExplicit" "ConfigLookupReturn Nothing"
                  ,returned "ConfigLookupCabalDirectory" ("ConfigLookupReturn (Just " <> show (owner </> "implicit-missing") <> ")")
                  ,returned (step "ConfigSelectedFilePresent" implicit) "ConfigBoolReturn False"
                  ,returned (step "ConfigFreshOpen" owned <> " \"native-cabal-config-\"") ("ConfigFreshOpenReturn " <> show generated)
                  ,returned (step "ConfigFreshClose" generated) "ConfigUnitReturn"])
                  (Just "CabalDirectoryConfigSelection") (Just implicit) (Just "FreshImplicitConfig") (Right generated))
            Left _ -> pure False
          "explicit-missing" -> pure (refused missing)
          "explicit-empty" -> pure (refused "")
          "owner-outside" -> let reason = "user error (NativeCabalConfigOwnerOutsideBuild)" in
            pure (common current (prefix current frame <> [(policy frame,Just (Left reason))]) Nothing Nothing Nothing (Left reason))
          _ -> pure False
        pure ("native-config.origin." <> name,okay,Text.pack (show (steps,result,sameCause)))
  rows <- maybe (pure []) (mapM judge) observed
  pure (("native-config.origin.discovery",maybe False (\values -> [name | (name,_,_,_,_,_,_,_,_) <- values] == names) observed,"exact five actual selector controls") : rows)

-- Resolve Cabal's external configuration selection independently. A missing
-- implicit default is represented only by an empty file under this owner.
nativePathConfig :: FilePath -> [Text] -> IO Bool
nativePathConfig owner argv = case argv of
  flag : _ | Just selected <- Text.stripPrefix "--config-file=" flag -> do
    explicit <- lookupEnv "CABAL_CONFIG"
    cabalDirectory <- lookupEnv "CABAL_DIR"
    defaultPath <- case cabalDirectory of
      Just root -> pure (root </> "config")
      Nothing -> do
        legacy <- getAppUserDataDirectory "cabal"
        legacyPresent <- doesDirectoryExist legacy
        xdg <- getXdgDirectory XdgConfig ("cabal" </> "config")
        xdgPresent <- doesFileExist xdg
        pure (if legacyPresent && not xdgPresent then legacy </> "config" else xdg)
    let expected = maybe defaultPath id explicit
    present <- doesFileExist expected
    if present then (== Text.unpack selected) <$> makeAbsolute expected else case explicit of
      Just _ -> pure False
      Nothing -> do
        confined <- within owner (Text.unpack selected)
        bytes <- try (Bytes.readFile (Text.unpack selected)) :: IO (Either IOException Bytes.ByteString)
        pure (confined && "native-cabal-config-" `Text.isPrefixOf` Text.pack (takeFileName (Text.unpack selected)) && bytes == Right Bytes.empty)
  _ -> pure False

resolutionContext :: FilePath -> [Text] -> IO (Bool,Text)
resolutionContext owner argv = do
  config <- nativePathConfig owner argv
  temporary <- nativeTemporaryEvidence owner
  pure (config && fst temporary,Text.pack (show (argv,snd temporary)))

nativeTemporaryEvidence :: FilePath -> IO (Bool,Text)
nativeTemporaryEvidence owner = do
  observed <- try (TextIO.readFile (owner </> "native-query-environment.tsv")) :: IO (Either IOException Text)
  root <- canonicalizePath owner
  temporary <- canonicalizePath (owner </> "native-cabal-tmp")
  present <- doesDirectoryExist temporary
  let confined = makeRelative root temporary == "native-cabal-tmp"
      expected = [(key,Text.pack temporary) | key <- ["TMPDIR","TMP","TEMP"]]
  pure (present && confined && either (const False) ((== expected) . table) observed,Text.pack (show observed))

-- Observe both a usable code generator and an actual absent-package install.
-- The latter must reach the solver in an owned offline context, rather than
-- succeeding through a PATH lookup or failing on command-line/configuration use.
installObservations :: FilePath -> IO (Bool, Text)
installObservations directory = do
  result <- try inspect :: IO (Either IOException (Bool,Text))
  pure (either (\problem -> (False,Text.pack (show problem))) id result)
 where
  inspect = do
    transcript <- table <$> TextIO.readFile (directory </> "toolchain.tsv")
    positive <- readValue (directory </> "install-positive.data") :: IO (Maybe (Either Text (FilePath,Maybe ChildObservation)))
    negative <- readValue (directory </> "install-fallback.data") :: IO (Maybe ((Text,Text,Text),Bool))
    let compiler = maybe "" id (one "compiler.executable" transcript)
        version = maybe "" id (one "compiler.version" transcript)
        cabal = maybe "" id (one "package-tool.executable" transcript)
        owner = directory </> "tools"
        absent = "amoebius-absent-tool-4391860a"
    materialization <- TextIO.readFile (owner </> ".build/tool-materialization.tsv")
    first <- case (positive,one "kind" (table materialization)) of
      (Just (Right (target,Nothing)),Just "path-copy") -> do
        let rows = table materialization
        source <- maybe (fail "copy source missing") (pure . Text.unpack) (one "source" rows)
        found <- findExecutable "proto-lens-protoc"
        sourceHash <- shaBytes <$> Bytes.readFile source
        targetHash <- shaBytes <$> Bytes.readFile target
        pure (sort (map fst rows) == sort ["kind","source","source-sha256","target","target-sha256"]
          && found == Just source && source /= target
          && target == owner </> "proto-lens-protoc" && one "target" rows == Just (Text.pack target)
          && one "source-sha256" rows == Just sourceHash && one "target-sha256" rows == Just targetHash
          && sourceHash == targetHash,materialization)
      (Just (Right (target,Just child)),Just "isolated-install") -> do
        (okay,evidence) <- inspectInstall compiler version cabal owner "proto-lens-protoc" True (Just child)
        pure (okay && target == owner </> "proto-lens-protoc"
          && table materialization == [("kind","isolated-install"),("context",Text.pack (owner </> ".build/install-context"))],materialization <> evidence)
      _ -> pure (False,Text.pack (show positive) <> materialization)
    second <- inspectInstall compiler version cabal (directory </> "tools-missing") absent False Nothing
    missingExecutable <- doesPathExist (directory </> "tools-missing" </> Text.unpack absent)
    let refused = case negative of
          Just (("ToolInstallFailed",package,detail),False) -> package == absent && not (Text.null detail) && not missingExecutable
          _ -> False
    pure (fst first && fst second && refused,Text.pack (show (positive,negative,snd first,snd second)))

table :: Text -> [(Text,Text)]
table bytes = [(key,Text.intercalate "\t" rest) | line <- Text.lines bytes, key : rest <- [Text.splitOn "\t" line]]

one :: Text -> [(Text,Text)] -> Maybe Text
one key rows = case [value | (name,value) <- rows, name == key] of [value] -> Just value; _ -> Nothing

inspectInstall :: Text -> Text -> Text -> FilePath -> Text -> Bool -> Maybe ChildObservation -> IO (Bool,Text)
inspectInstall compiler version cabal owner package success returned = do
  let context = owner </> ".build/install-context"
      paths = ["config","home","tmp","cabal-dir","xdg-cache-home","xdg-config-home","xdg-data-home","xdg-state-home","store","build","logs","world","summary","native-db-query-build"
        ,"source-plan","local-project","local-plan","source-build","source-directory"]
  baseCaptured <- forM [owner </> ".build/native-build.tsv",context </> "context.tsv",context </> "environment.tsv",context </> "cabal.config"
    ,context </> "cache-copy.tsv",context </> "cache-query.data",context </> "native-db-query.data",context </> "native-query-environment.tsv",context </> "source-plan-query.data"] $ \path -> (path,) <$> TextIO.readFile path
  let rows = table (maybe "" id (lookup (context </> "context.tsv") baseCaptured))
      location key = maybe "" Text.unpack (one key rows)
  sourceCaptured <- forM [location key | success, key <- ["source-plan","local-project","local-plan"]] $ \path -> (path,) <$> TextIO.readFile path
  let captured = baseCaptured <> sourceCaptured
      bytes path = maybe "" id (lookup path captured)
      trace = table (bytes (owner </> ".build/native-build.tsv"))
      requested = one "requested.argv" trace >>= readMaybe . Text.unpack :: Maybe [Text]
      effective = one "effective.argv" trace >>= readMaybe . Text.unpack :: Maybe [Text]
      exit = one "effective.exit" trace >>= readMaybe . Text.unpack :: Maybe Int
      stdout = one "effective.stdout" trace >>= readMaybe . Text.unpack :: Maybe String
      stderr = one "effective.stderr" trace >>= readMaybe . Text.unpack :: Maybe String
      query = readMaybe (Text.unpack (bytes (context </> "cache-query.data"))) :: Maybe (ChildObservation,String,String)
      databaseQuery = readMaybe (Text.unpack (bytes (context </> "native-db-query.data"))) :: Maybe (ChildObservation,String,String)
      manifest = mapM manifestRow (Text.lines (bytes (context </> "cache-copy.tsv")))
      environment = table (bytes (context </> "environment.tsv"))
      forced = [("HOME","home"),("CABAL_DIR","cabal-dir"),("XDG_CACHE_HOME","xdg-cache-home"),("XDG_CONFIG_HOME","xdg-config-home")
        ,("XDG_DATA_HOME","xdg-data-home"),("XDG_STATE_HOME","xdg-state-home"),("TMPDIR","tmp"),("TMP","tmp"),("TEMP","tmp")]
      allowedEnvironment = map fst forced <> ["GHC_ENVIRONMENT","LC_ALL","PATH","LANG","SystemRoot","SYSTEMROOT","WINDIR","COMSPEC","PATHEXT"]
      configPath key = Text.pack (location key)
      configLines = ["repository hackage.haskell.org","  url: https://hackage.haskell.org/","  secure: True"
        ,"remote-repo-cache: " <> Text.pack (context </> "cache-input")]
        <> [key <> ": " <> configPath field | (key,field) <- [("store-dir","store"),("logs-dir","logs"),("world-file","world"),("build-summary","summary")]]
        <> ["remote-build-reporting: none","jobs: 1","offline: True"]
  physicalOwner <- canonicalizePath owner
  confined <- and <$> mapM (within physicalOwner . location) paths
  cacheAbsent <- not <$> doesPathExist (context </> "cache-input")
  nativeDatabasePresent <- doesDirectoryExist (location "native-db")
  cabalHash <- shaBytes <$> Bytes.readFile (Text.unpack cabal)
  actualCache <- inventory (location "cache.source")
  let transport = sort (map fst trace) == sort ["requested.argv","effective.argv","effective.executable","effective.exit","effective.stdout","effective.stderr"] && case (requested,effective,exit,stdout,stderr) of
        (Just intent,Just argv,Just code,Just _,Just err) -> "install" `elem` intent && package <> ":" <> package `elem` intent
          && "--constraint=" <> package <> " source" `elem` intent
          && installArguments rows compiler owner package success argv
          && one "effective.executable" trace == Just cabal
          && (if success then code == 0 else code > 0 && code /= 127
            && ("unknown package \"" <> package <> "\".") `elem` map (Text.toLower . Text.strip) (Text.lines (Text.pack err)))
          && maybe (not success) (\child -> childExecutable child == Text.unpack cabal && childDigest child == cabalHash && childExit child == code && childArgv child == argv) returned
        _ -> False
      contextOkay = one "owner" rows == Just (Text.pack owner) && one "config" rows == Just (Text.pack (context </> "cabal.config"))
        && sort (map fst rows) == sort (["owner","cache.source","cache.target","cache.files","cache.removed","native-store","native-db"] <> paths
          <> [key | success, key <- ["source.package","source.version","source.sha256","source.cached-archive","source.archive"]])
        && confined && one "cache.target" rows == Just (Text.pack (context </> "cache-input/hackage.haskell.org"))
        && one "cache.removed" rows == Just "True" && cacheAbsent
        && Text.lines (bytes (context </> "cabal.config")) == configLines
        && length environment == Map.size (Map.fromList environment) && all ((`elem` allowedEnvironment) . fst) environment
        && all (\(key,path) -> one key environment == Just (Text.pack (location path))) forced
        && one "GHC_ENVIRONMENT" environment == Just "-" && one "LC_ALL" environment == Just "C.UTF-8"
      cacheOkay = case manifest of
        Just copied -> not (null copied) && sort [(path,count,digest) | (path,count,digest,_) <- copied] == sort actualCache
          && all (\(_,_,a,b) -> a == b) copied && one "cache.files" rows == Just (Text.pack (show (length copied)))
        _ -> False
  queriesOkay <- case (query,databaseQuery) of
    (Just (child,out,_),Just (dbChild,dbOut,_)) -> do
      compilerPath <- canonicalizePath (Text.unpack compiler)
      queryConfigOkay <- nativePathConfig context (childArgv child)
      temporary <- nativeTemporaryEvidence context
      case (eitherDecodeStrict (Encoding.encodeUtf8 (Text.pack out)),eitherDecodeStrict (Encoding.encodeUtf8 (Text.pack dbOut))) of
        (Right cacheValue,Right databaseValue) -> case (jsonText "remote-repo-cache" cacheValue,jsonText "store-dir" cacheValue,jsonField "compiler" databaseValue) of
          (Just cache,Just store,Just metadata) -> case (jsonText "path" metadata,jsonText "flavour" metadata,jsonText "id" metadata,jsonText "store-path" metadata) of
            (Just observedCompiler,Just flavour,Just identifier,Just compilerStore) -> do
              observedPath <- canonicalizePath (Text.unpack observedCompiler)
              source <- canonicalizePath (Text.unpack cache </> "hackage.haskell.org")
              actualSource <- canonicalizePath (location "cache.source")
              database <- canonicalizePath (Text.unpack compilerStore </> "package.db")
              insideStore <- within (Text.unpack store) database
              present <- doesDirectoryExist database
              pure (queryConfigOkay && fst temporary && childExecutable child == Text.unpack cabal && childDigest child == cabalHash && childExit child == 0
                && drop 1 (childArgv child) == ["path","--ignore-project","--output-format=json","--offline","--jobs=1","--remote-repo-cache","--store-dir"]
                && isAbsolute (Text.unpack cache) && isAbsolute (Text.unpack store) && actualSource == source && one "native-store" rows == Just store
                && childExecutable dbChild == Text.unpack cabal && childDigest dbChild == cabalHash && childExit dbChild == 0
                && childArgv dbChild == ["--config-file=" <> Text.pack (location "config"),"--store-dir=" <> store,"path","--ignore-project","--output-format=json","--remote-repo-cache","--compiler-info"
                   ,"--with-compiler=" <> compiler,"--builddir=" <> Text.pack (location "native-db-query-build"),"--offline","--jobs=1"]
                && jsonText "remote-repo-cache" databaseValue == Just (Text.pack (context </> "cache-input"))
                && observedPath == compilerPath && flavour == "ghc" && identifier == "ghc-" <> version && isAbsolute (Text.unpack compilerStore) && insideStore
                && one "native-db" rows == Just (if present then Text.pack database else "") && nativeDatabasePresent == present)
            _ -> pure False
          _ -> pure False
        _ -> pure False
    _ -> pure False
  sources <- installSources rows compiler cabal cabalHash owner package success captured actualCache
  pure (transport && contextOkay && cacheOkay && queriesOkay && fst sources,Text.pack (show (captured,snd sources)))
 where
  manifestRow line = case Text.splitOn "\t" line of
    [path,count,source,copied] -> (Text.unpack path,,source,copied) <$> (readMaybe (Text.unpack count) :: Maybe Integer)
    _ -> Nothing

-- The repository solver selects source bytes; the final local solver may
-- re-sdist them. Judge each real plan and its own archive, without equating
-- either their unit graphs or their compressed archive hashes.
installSources :: [(Text,Text)] -> Text -> Text -> Text -> FilePath -> Text -> Bool -> [(FilePath,Text)] -> [(FilePath,Integer,Text)] -> IO (Bool,Text)
installSources context compiler cabal cabalHash owner package success captured cache = do
  let location key = maybe "" Text.unpack (one key context)
      bytes path = maybe "" id (lookup path captured)
      query = readMaybe (Text.unpack (bytes (owner </> ".build/install-context/source-plan-query.data"))) :: Maybe (ChildObservation,String,String)
      trace = table (bytes (owner </> ".build/native-build.tsv"))
      sourceChild child = childExecutable child == Text.unpack cabal && childDigest child == cabalHash
        && installArguments context compiler owner package False (childArgv child)
  case query of
    Nothing -> pure (False,"actual repository dry-run observation missing")
    Just (child,out,err) | not success -> do
      leftovers <- mapM (doesPathExist . location) ["source-plan","local-project","local-plan","source-directory"]
      let sameActual = one "effective.argv" trace == Just (Text.pack (show (childArgv child)))
            && one "effective.exit" trace == Just (Text.pack (show (childExit child)))
            && one "effective.stdout" trace == Just (Text.pack (show out)) && one "effective.stderr" trace == Just (Text.pack (show err))
      pure (sourceChild child && childExit child > 0 && childExit child /= 127 && sameActual && not (or leftovers)
        ,Text.pack (show (child,out,err,leftovers)))
    Just (child,_,_) -> do
      let sourceValue = either (const Nothing) Just (eitherDecodeStrict (Encoding.encodeUtf8 (bytes (location "source-plan"))) :: Either String Value)
          localValue = either (const Nothing) Just (eitherDecodeStrict (Encoding.encodeUtf8 (bytes (location "local-plan"))) :: Either String Value)
          roots value = case jsonField "install-plan" value of
            Just (Array units) -> let chosenRows = filter ((== Just package) . jsonText "pkg-name") (toList units)
              in if null chosenRows then Nothing else Just chosenRows
            _ -> Nothing
          sourceRoot row = do
            version <- jsonText "pkg-version" row
            digest <- jsonText "pkg-src-sha256" row
            source <- jsonField "pkg-src" row
            repository <- jsonField "repo" source
            if jsonText "type" row == Just "configured" && jsonText "type" source == Just "repo-tar"
              && jsonText "type" repository == Just "secure-repo" && jsonText "uri" repository == Just "https://hackage.haskell.org/"
              then Just (version,digest) else Nothing
          selected = sourceValue >>= roots >>= mapM sourceRoot
          unique = maybe [] (Map.keys . Map.fromList . map (,())) selected
      case (unique,localValue >>= roots) of
        ([(version,digest)],Just localRoots) -> do
          let relative = Text.unpack package </> Text.unpack version </> Text.unpack (package <> "-" <> version <> ".tar.gz")
              persistent = location "source-directory" </> Text.unpack (package <> "-" <> version <> ".tar.gz")
              expectedCached = location "cache.target" </> relative
              safeVersion = not (Text.null version) && all (\part -> not (Text.null part) && Text.all (`elem` ("0123456789" :: String)) part) (Text.splitOn "." version)
              safeDigest = Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest
              declared = one "source.package" context == Just package && one "source.version" context == Just version
                && one "source.sha256" context == Just digest && one "source.archive" context == Just (Text.pack persistent)
                && one "source.cached-archive" context == Just (Text.pack expectedCached)
              sourceExecutable = maybe False (any ((== Just ("exe:" <> package)) . jsonText "component-name")) (sourceValue >>= roots)
              project = bytes (location "local-project") == "packages: " <> Text.pack (show persistent) <> "\n"
          persistentConfined <- within owner persistent
          retainedHash <- if safeVersion && safeDigest && declared && persistentConfined then shaBytes <$> Bytes.readFile persistent else pure ""
          sourceActual <- TextIO.readFile (location "source-build" </> "cache/plan.json")
          localActual <- TextIO.readFile (location "build" </> "cache/plan.json")
          sourcePlan <- rawPlan (location "source-plan")
          localPlan <- rawPlan (location "local-plan")
          localEvidence <- forM localRoots $ \row -> case (jsonText "pkg-version" row,jsonText "pkg-src-sha256" row,jsonField "pkg-src" row) of
            (Just actualVersion,Just actualDigest,Just source) -> case jsonText "path" source of
              Just path -> do
                let archive = if isAbsolute (Text.unpack path) then Text.unpack path else owner </> Text.unpack path
                confined <- within owner archive
                let admitted = jsonText "type" row == Just "configured" && jsonText "type" source == Just "local-tar" && actualVersion == version && confined
                actualHash <- if admitted then shaBytes <$> Bytes.readFile archive else pure ""
                pure (admitted && not (Text.null actualHash) && actualHash == actualDigest,(archive,actualHash))
              _ -> pure (False,("",""))
            _ -> pure (False,("",""))
          executableEvidence <- case [row | row <- localRoots, jsonText "component-name" row == Just ("exe:" <> package)] of
            [row] -> case jsonText "bin-file" row of
              Just path -> do
                let binary = if isAbsolute (Text.unpack path) then Text.unpack path else owner </> Text.unpack path
                    target = owner </> Text.unpack package
                confined <- within owner binary
                builtHash <- if confined then shaBytes <$> Bytes.readFile binary else pure ""
                installedHash <- if confined then shaBytes <$> Bytes.readFile target else pure ""
                pure (confined && not (Text.null builtHash) && builtHash == installedHash,(binary,builtHash,target,installedHash))
              _ -> pure (False,("","","",""))
            _ -> pure (False,("","","",""))
          let cached = [(count,actualDigest) | (path,count,actualDigest) <- cache, path == relative]
              cacheMatches = case cached of [(count,actualDigest)] -> count > 0 && actualDigest == digest; _ -> False
              localUnique = Map.size (Map.fromList [(observation,()) | (_,observation) <- localEvidence]) == 1
              okay = sourceChild child && childExit child == 0 && safeVersion && safeDigest && declared && sourceExecutable && project
                && persistentConfined && retainedHash == digest && cacheMatches
                && sourceActual == bytes (location "source-plan") && localActual == bytes (location "local-plan")
                && sourcePlan /= Nothing && localPlan /= Nothing && all fst localEvidence && localUnique && fst executableEvidence
          pure (okay,Text.pack (show (version,digest,persistent,retainedHash,cached,sourcePlan,localPlan,localEvidence,executableEvidence)))
        _ -> pure (False,"actual repository/local root selection differs")

installArguments :: [(Text,Text)] -> Text -> FilePath -> Text -> Bool -> [Text] -> Bool
installArguments context compiler owner package local argv =
  let location key = maybe "" id (one key context)
      required = [("--config-file=",location "config"),("--store-dir=",location "store"),("--installdir=",Text.pack owner)
        ,("--builddir=",location (if local then "build" else "source-build")),("--build-summary=",location "summary"),("--build-log=",location "logs" <> "/$pkgid.log")
        ,("--with-compiler=",compiler),("--jobs=","1"),("--ghc-options=","-j1")]
        <> [("--project-file=",location "local-project") | local]
      selector = package <> (if local then ":exe:" else ":") <> package
      flags = ["install",selector,"--constraint=" <> package <> " source","--install-method=copy","--overwrite-policy=always","--remote-build-reporting=none","--offline"]
        <> [flag | not local, flag <- ["--ignore-project","--dry-run"]]
      databases = ["clear","global"] <> [location "native-db" | not (Text.null (location "native-db"))]
      values prefix = [value | argument <- argv, Just value <- [Text.stripPrefix prefix argument]]
      allowed = flags <> ["-v0"] <> [prefix <> value | (prefix,value) <- required] <> map ("--package-db=" <>) databases
  in not (Text.null compiler) && all (\(prefix,value) -> values prefix == [value]) required
    && all (\flag -> length (filter (== flag) argv) == 1) flags && values "--package-db=" == databases
    && all (`elem` allowed) argv
    && "--config-file=" <> location "config" `elem` takeWhile (/= "install") argv
    && "--store-dir=" <> location "store" `elem` takeWhile (/= "install") argv

within :: FilePath -> FilePath -> IO Bool
within root path = do
  physicalRoot <- canonicalizePath root
  physicalPath <- canonicalizePath path
  let relative = makeRelative physicalRoot physicalPath
  pure (not (null path) && not (isAbsolute relative) && ".." `notElem` splitDirectories relative)

inventory :: FilePath -> IO [(FilePath,Integer,Text)]
inventory root = walk ""
 where
  walk relative = do
    let path = root </> relative
    linked <- pathIsSymbolicLink path
    if linked then fail "repository input contains symlink" else do
      directory <- doesDirectoryExist path
      if directory then do
        names <- sort <$> listDirectory path
        concat <$> mapM (walk . (relative </>)) names
      else do
        regular <- doesFileExist path
        unless regular (fail "repository input is not regular")
        count <- getFileSize path
        digest <- shaBytes <$> Bytes.readFile path
        pure [(relative,count,digest)]

jsonField :: Text -> Value -> Maybe Value
jsonField key (Object fields) = KeyMap.lookup (Key.fromText key) fields
jsonField _ _ = Nothing

jsonText :: Text -> Value -> Maybe Text
jsonText key value = case jsonField key value of Just (String text) -> Just text; _ -> Nothing

type NativePlan = ([Text], [Text], Text, Int, [Text])

-- Independent grammar for the public transport observation, not a product import.
data ChildObservation = ChildRecord
  { childTool :: Text, childExecutable :: FilePath, childDigest :: Text, childArgv :: [Text], childExit :: Int }
  deriving (Eq, Read, Show)

serialResolution :: Text -> [Text] -> Bool
serialResolution compiler argv = not (Text.null compiler) && case argv of
  config : command | Just path <- Text.stripPrefix "--config-file=" config, not (Text.null path)
    , length (filter ("--config-file=" `Text.isPrefixOf`) argv) == 1 -> case splitAt (length command - 4) command of
      (["build","--dry-run","-v0",builddir], fixed) -> "--builddir=" `Text.isPrefixOf` builddir
        && fixed == ["--offline","--jobs=1","--with-compiler=" <> compiler,"--ghc-options=-j1"]
      _ -> False
  _ -> False

resolutionRows :: FilePath -> IO [(Text, Bool, Text)]
resolutionRows directory = do
  observed <- readValue (directory <> "/resolution.data") :: IO (Maybe (Either Text NativePlan, Either Text NativePlan, [Text], [Text], Either Text (), Bool, [(FilePath,Text)], [(FilePath,Text)], [FilePath], Int))
  root <- getCurrentDirectory
  outside <- readValue (directory <> "/resolution-root.data") :: IO (Maybe (FilePath,Either Text (),Bool))
  outsidePresent <- doesPathExist (root </> "amoebius-resolution-refused")
  transcript <- try (TextIO.readFile (directory <> "/toolchain.tsv")) :: IO (Either IOException Text)
  let compiler = either (const "") (\bytes -> case [value | line <- Text.lines bytes, ["compiler.executable",value] <- [Text.splitOn "\t" line]] of [value] -> value; _ -> "") transcript
  a <- rawPlan (directory <> "/resolve-a/dist/cache/plan.json")
  b <- rawPlan (directory <> "/resolve-b/dist/cache/plan.json")
  firstCompatibility <- compatiblePlan (directory <> "/resolve-a/dist/cache/plan.json")
  secondCompatibility <- compatiblePlan (directory <> "/resolve-b/dist/cache/plan.json")
  firstTransport <- case observed of Just (Right (_,_,_,_,argv),_,_,_,_,_,_,_,_,_) -> resolutionContext (directory </> "resolve-a/probe-plan/.build") argv; _ -> pure (False,"first plan missing")
  secondTransport <- case observed of Just (_,Right (_,_,_,_,argv),_,_,_,_,_,_,_,_) -> resolutionContext (directory </> "resolve-b/probe-plan/.build") argv; _ -> pure (False,"second plan missing")
  let check name okay = ("case:resolution." <> name, okay, if okay then "observed" else "actual plan/action differs")
  pure $ case observed of
    Just (Right (ua,pa,da,ea,aa), Right (ub,pb,db,eb,ab), agreement, disagreement, dropped, created, before, after, generated, ignored) ->
      [("case:resolution.first-plan",a == Just (ua,pa,da) && ea == 0 && serialResolution compiler aa && fst firstCompatibility && fst firstTransport,Text.pack (show (snd firstTransport,snd firstCompatibility)))
      ,("case:resolution.second-plan",b == Just (ub,pb,db) && eb == 0 && serialResolution compiler ab && fst secondCompatibility && fst secondTransport,Text.pack (show (snd secondTransport,snd secondCompatibility)))
      ,check "agreement" (not (null ua) && (ua,pa,da) == (ub,pb,db) && agreement == [])
      ,check "disagreement" (disagreement == ["PlansDisagree: units","PlansDisagree: packages","PlansDisagree: digest"])
      ,check "dropped-allowance" (dropped == Left "MissingCompatibilityAllowance: dhall" && not created)
      ,check "outside-root" (outside == Just (root </> "amoebius-resolution-refused",Left ("ResolutionRootOutsideBuild: " <> Text.pack (root </> "amoebius-resolution-refused")),False) && not outsidePresent)
      ,check "authored-unchanged" (not (null before) && before == after && length before == Map.size (Map.fromList before))
      ,check "generated-ignored" (ignored == 0 && not (null generated)
        && all (\path -> any (`Text.isPrefixOf` Text.pack path) [Text.pack (directory <> "/resolve-a/"), Text.pack (directory <> "/resolve-b/")]) generated)]
    _ -> [check name False | name <- ["first-plan","second-plan","agreement","disagreement","dropped-allowance","outside-root","authored-unchanged","generated-ignored"]]

-- Decode the external Cabal plan independently of the product's Plan type and
-- rederive the newline-framed identity digest from the actual JSON bytes.
rawPlan :: FilePath -> IO (Maybe ([Text], [Text], Text))
rawPlan path = do
  bytes <- try (Bytes.readFile path) :: IO (Either IOException Bytes.ByteString)
  pure $ do
    input <- either (const Nothing) Just bytes
    value <- either (const Nothing) Just (eitherDecodeStrict input :: Either String Value)
    units <- case field "install-plan" value of Just (Array rows) -> mapM unit (toList rows); _ -> Nothing
    let identities = sort (map fst units)
        packages = Map.keys (Map.fromList [(package, ()) | (_,package) <- units])
        digest = shaBytes (Encoding.encodeUtf8 (Text.intercalate "\n" identities <> "\n"))
    if null units || length identities /= Map.size (Map.fromList [(identity, ()) | identity <- identities])
      then Nothing else Just (identities, packages, digest)
 where
  field key value = case value of Object fields -> KeyMap.lookup key fields; _ -> Nothing
  text key value = case field key value of Just (String result) -> Just result; _ -> Nothing
  unit value = (,) <$> text "id" value <*> text "pkg-name" value

-- Cabal unit IDs are opaque and can abbreviate package names. Compatibility
-- belongs to the external plan's separately named package/version fields.
compatiblePlan :: FilePath -> IO (Bool,Text)
compatiblePlan path = do
  bytes <- try (Bytes.readFile path) :: IO (Either IOException Bytes.ByteString)
  let observed = do
        input <- either (const Nothing) Just bytes
        value <- either (const Nothing) Just (eitherDecodeStrict input :: Either String Value)
        case jsonField "install-plan" value of
          Just (Array rows) -> mapM (\row -> (,) <$> jsonText "pkg-name" row <*> jsonText "pkg-version" row) (toList rows)
          _ -> Nothing
      requirements = [("dhall",[1,42],[1,43]),("io-sim",[1,10],[1,11]),("io-classes",[1,10],[1,11]),
        ("proto-lens",[0,7],[0,8]),("proto-lens-runtime",[0,7],[0,8]),("purescript-bridge",[0,15],[0,16]),("tar",[0,6],[0,8]),("zlib",[0,7],[0,8])]
  pure (maybe False (\rows -> all (admitted rows) requirements) observed,Text.pack (show observed))
 where
  admitted rows (package,lower,upper) =
    let versions = [mapM (readMaybe . Text.unpack :: Text -> Maybe Int) (Text.splitOn "." version) | (name,version) <- rows, name == package]
    in not (null versions) && all (maybe False (\version -> version >= lower && version < upper)) versions

shaBytes :: Bytes.ByteString -> Text
shaBytes bytes = Text.pack (concatMap (\byte -> let hex = showHex byte "" in replicate (2-length hex) '0' <> hex)
  (Bytes.unpack (SHA256.hash bytes)))

type Upstream = (Text,Text,Text,Int,FilePath,Text,FilePath,Maybe (Int,[Text]),[(Text,FilePath,Text)])

-- Independent public rendering grammar. Actions still have to agree with the
-- actual archive and filesystem observations below before these rows qualify.
data UpstreamActionObservation
  = CachedArchiveRead FilePath Text
  | ArchiveDirectoryCreated FilePath
  | ArchiveFileWritten FilePath Text
  deriving (Show)

expectedAcquiredRows :: Text -> Text -> Upstream -> Maybe [(Text,Text)]
expectedAcquiredRows cabal cabalHash (name,version,treeDigest,count,archive,archiveDigest,root,query,actions) = do
  actualActions <- mapM action actions
  cacheQuery <- case query of
    Nothing -> Just (Nothing :: Maybe ChildObservation)
    Just (code,argv) | not (Text.null cabal) && not (Text.null cabalHash) ->
      Just (Just (ChildRecord cabal (Text.unpack cabal) cabalHash argv code))
    _ -> Nothing
  pure [("upstream.identity",name <> "-" <> version)
       ,("upstream.root",Text.pack root)
       ,("upstream.tree-sha256",treeDigest)
       ,("upstream.files",Text.pack (show count))
       ,("upstream.archive",Text.pack archive)
       ,("upstream.archive-sha256",archiveDigest)
       ,("upstream.cache-query",Text.pack (show cacheQuery))
       ,("upstream.actions",Text.pack (show actualActions))]
 where
  action ("read",path,digest) = Just (CachedArchiveRead path digest)
  action ("directory",path,"") = Just (ArchiveDirectoryCreated path)
  action ("file",path,digest) = Just (ArchiveFileWritten path digest)
  action _ = Nothing

upstreamRows :: FilePath -> IO [(Text, Bool, Text)]
upstreamRows directory = do
  observed <- readValue (directory <> "/upstream.data") :: IO (Maybe (Either Text Upstream, Either Text Upstream, Either Text (), Bool, Either Text (), Bool))
  identities <- readValue (directory <> "/upstream-identities.data") :: IO (Maybe [(String,Text,Bool)])
  roots <- readValue (directory <> "/upstream-roots.data") :: IO (Maybe [(Text,Text,Bool)])
  rendered <- readValue (directory </> "upstream-rendered.data") :: IO (Maybe (Either Text [(Text,Text)],Either Text [(Text,Text)]))
  invalid <- readValue (directory </> "upstream-invalid.data") :: IO (Maybe (Text,Text,Bool))
  invalidCreated <- doesPathExist (directory </> "upstream-invalid")
  transcript <- try (TextIO.readFile (directory </> "toolchain.tsv")) :: IO (Either IOException Text)
  let cabal = either (const "") (maybe "" id . one "package-tool.executable" . table) transcript
  cabalBytes <- try (Bytes.readFile (Text.unpack cabal)) :: IO (Either IOException Bytes.ByteString)
  let check name okay = ("case:upstream." <> name, okay, if okay then "actual cached bytes/actions observed" else "cache or extraction differs")
      expectedDigest = "2e2f01be19b08128cd8549befcc1da3fea172b1f5b3471845d05ef8dc06dda33"
      cabalHash = either (const "") shaBytes cabalBytes
      rendererMatches actual value = case expectedAcquiredRows cabal cabalHash value of
        Just expected -> actual == Just (Right expected)
        Nothing -> False
  case observed of
    Just (Right a@(_,_,_,_,_,_,_,queryA,_), Right b@(_,_,_,_,_,_,_,queryB,_), mismatch, mismatchCreated, missing, missingCreated) -> do
      first <- inspectUpstream (directory </> "upstream") a
      second <- inspectUpstream (directory </> "upstream-second") b
      cacheConfigOkay <- case queryA of Just (_,argv) -> nativePathConfig directory argv; _ -> pure False
      queryTemporary <- nativeTemporaryEvidence directory
      root <- getCurrentDirectory
      let actualExpected = [("outside","UpstreamRootOutsideBuild: " <> Text.pack (root </> "amoebius-upstream-refused"),False)
            ,("symlink","UpstreamRootOutsideBuild: " <> Text.pack (directory </> "upstream-root-link" </> "amoebius-upstream-link-refused"),False)]
          invalidExpected = Just ("amoebius-other","CachedArchiveInvalid: unsafe archive path supernova-0.0.3",False)
      pure [("case:upstream.cache-positive",first && rendererMatches (fst <$> rendered) a,Text.pack (show (fst <$> rendered)))
           ,("case:upstream.supplied-cache-positive",second && rendererMatches (snd <$> rendered) b && roots == Just actualExpected
             && invalid == invalidExpected && not invalidCreated,Text.pack (show (snd <$> rendered,roots,invalid,invalidCreated)))
           ,("case:upstream.cache-only-query",cacheConfigOkay && fst queryTemporary && maybe False (\(code,argv) -> code == 0 && drop 1 argv == ["path","--ignore-project","--output-format=json","--offline","--jobs=1","--remote-repo-cache"]) queryA && queryB == Nothing,Text.pack (show (queryA,queryB,snd queryTemporary)))
           ,check "digest-negative" (mismatch == Left ("DigestMismatch: expected=" <> Text.replicate 64 "0" <> " observed=" <> expectedDigest) && not mismatchCreated)
           ,check "missing-cache-negative" (missing == Left ("CachedArchiveMissing: " <> Text.pack (directory </> "absent-upstream.tar.gz")) && not missingCreated)
           ,check "absent-identity" (identities == Just [("empty-name","AbsentIdentity: hackage:-0.0.3",False),("empty-version","AbsentIdentity: hackage:supernova-",False)])]
    _ -> pure [check name False | name <- ["cache-positive","supplied-cache-positive","cache-only-query","digest-negative","missing-cache-negative","absent-identity"]]

inspectUpstream :: FilePath -> Upstream -> IO Bool
inspectUpstream destination (name,version,digest,count,archive,archiveDigest,root,_,actions) = do
  observed <- try (do
    archiveBytes <- Bytes.readFile archive
    (directories,files) <- walk destination
    actualFiles <- mapM (\path -> (path,) . shaBytes <$> Bytes.readFile path) (sort files)
    let rows = [Text.pack (makeRelative root path) <> " " <> fileDigest | (path,fileDigest) <- actualFiles]
        calculated = shaBytes (Encoding.encodeUtf8 (Text.intercalate "\n" rows <> "\n"))
        expectedActions = ("read",archive,shaBytes archiveBytes)
          : [("directory",path,"") | path <- sortOn (\path -> (length (splitDirectories path),path)) directories]
          <> [("file",path,fileDigest) | (path,fileDigest) <- actualFiles]
    pure (name == "supernova" && version == "0.0.3" && root == destination </> "supernova-0.0.3"
      && digest == "2e2f01be19b08128cd8549befcc1da3fea172b1f5b3471845d05ef8dc06dda33"
      && count == 22 && length actualFiles == 22 && calculated == digest
      && archiveDigest == shaBytes archiveBytes && actions == expectedActions)) :: IO (Either IOException Bool)
  pure (observed == Right True)
 where
  walk path = do
    linked <- pathIsSymbolicLink path
    if linked then fail "upstream symlink" else do
      directory <- doesDirectoryExist path
      if not directory then pure ([],[path]) else do
        children <- sort <$> listDirectory path
        nested <- mapM (walk . (path </>)) children
        pure (path : concatMap fst nested,concatMap snd nested)

-- | Judge the runner's rewritten request independently, including its semantic
-- refusal. Echoing a nonce alone cannot satisfy this binary challenge.
binaryRows :: FilePath -> IO [(Text, Bool, Text)]
binaryRows directory = do
  let root = directory <> "/binary"
  present <- doesDirectoryExist root
  if not present then pure [] else do
    let input = root <> "/input/toolchain-request.tsv"
        output = root <> "/toolchain-report.tsv"
    hasInput <- doesFileExist input
    hasOutput <- doesFileExist output
    if not (hasInput && hasOutput) then pure [("binary.outputs-present", False, "input or report absent")] else do
      request <- rowsOf <$> TextIO.readFile input
      report <- rowsOf <$> TextIO.readFile output
      let values key rows = [value | (name, value) <- rows, name == key]
          label = values "label" request
          validNonce value = Text.length value == 32 && Text.all (\c -> c `elem` ['0'..'9'] || c `elem` ['a'..'f']) value
          exact name condition = (name, condition, if condition then "ok" else "input/report contract differs")
      pure [exact "binary.input-contract" (length request == 2 && values "ghc.requested-version" request == ["9.10.1"] && length label == 1 && all validNonce label)
           , exact "binary.nonce-recovered" (values "request.label" report == label && not (null label))
           , exact "binary.version-request-refused" (values "request.verdict" report == ["ToolVersionMismatch: ghc"])
           , exact "binary.native-versions-admitted" (values "versions.verdict" report == ["accepted"] && values "compiler.version" report == ["9.12.4"])]
 where
  rowsOf text = [(key, value) | line <- Text.lines text, [key, value] <- [Text.splitOn "\t" line]]

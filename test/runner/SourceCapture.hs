{-# LANGUAGE OverloadedStrings #-}

-- | Component observations from the real source-capture API. No verdicts.
module SourceCapture (sourceCaptureRows, sourceRewriteRows, sourceTreeRows) where

import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Runner.Observer (ObservedRun (..), observe)
import Control.Exception (bracket_)
import Control.Monad (forM, unless)
import Data.ByteString qualified as Bytes
import Data.IORef (newIORef, modifyIORef', atomicModifyIORef', readIORef)
import Data.Streaming.Filesystem (FileType (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory
  ( createDirectoryIfMissing, createDirectoryLink, createFileLink, doesDirectoryExist, doesFileExist, executable, findExecutable
  , getPermissions, makeAbsolute, removeDirectoryLink, removeFile, renameDirectory, renameFile, setPermissions )
import System.Exit (ExitCode (..), die)
import System.FilePath (isAbsolute, takeDirectory, (</>))

-- Links, failures and limits use supplied observations. Only ordinary files
-- are required from the native filesystem.
sourceTreeRows :: FilePath -> IO [[Text]]
sourceTreeRows output = do
  let native = output </> "source-tree-native"
  exists <- doesDirectoryExist native
  unless (not exists) (die "source-tree output must be fresh")
  createDirectoryIfMissing True (native </> "src/nested")
  mapM_ (\path -> TextIO.writeFile (native </> path) "ordinary source\n") ["src/A.hs", "src/nested/B.hs", "src/note.txt"]
  nativeFiles <- sourceAttempt (haskellFilesUnder native "src")
  model <- forM treeCases $ \(name, purpose, relative, kind, listing, fault) -> do
    stats <- newIORef ((0, 0, 0, 0, 0, 0) :: (Int, Int, Int, Int, Int, Int))
    let inspect path = do
          modifyIORef' stats (\(i,o,r,c,a,m) -> (i+1,o,r,c,a,m))
          if fault == Just ("inspect", path) then fail "fixture-inspect" else pure (kind path)
        entries :: FilePath -> (IO (Maybe FilePath) -> IO a) -> IO a
        entries path action
          | fault == Just ("open", path) = fail "fixture-open"
          | otherwise = bracket_
              (modifyIORef' stats (\(i,o,r,c,a,m) -> (i,o+1,r,c,a+1,max m (a+1))))
              (modifyIORef' stats (\(i,o,r,c,a,m) -> (i,o,r,c+1,a-1,m))) $ do
                queue <- newIORef (listing path)
                action $ do
                  modifyIORef' stats (\(i,o,r,c,a,m) -> (i,o,r+1,c,a,m))
                  if fault == Just ("read", path) then fail "fixture-read" else
                    atomicModifyIORef' queue (\names -> case names of [] -> ([], Nothing); x:xs -> (xs, Just x))
    result <- sourceAttempt (walkFilesUnderWith inspect entries purpose relative)
    metrics <- readIORef stats
    pure (row name result (Text.pack (show metrics)))
  pure (model <> [row "native" nativeFiles "-"] <> [["classify." <> name, Text.pack (show (classifyTreeNode linked contained kind)), "-", ""]
    | (name, linked, contained, kind) <-
      [("file",False,True,FTFile), ("directory",False,True,FTDirectory)
      ,("linked-file",True,True,FTFile), ("linked-directory",True,True,FTDirectory)
      ,("file-symlink-type",False,True,FTFileSym), ("directory-symlink-type",False,True,FTDirectorySym)
      ,("outside-file",False,False,FTFile), ("outside-directory",False,False,FTDirectory)
      ,("other",False,True,FTOther), ("linked-other",True,False,FTOther)]])
 where
  row name result metrics = [name, either id (const "files") result, metrics, either (const "") (Text.intercalate "\0" . map Text.pack) result]

type TreeCase = (Text, TreePurpose, FilePath, FilePath -> TreeNode, FilePath -> [FilePath], Maybe (Text, FilePath))

treeCases :: [TreeCase]
treeCases =
  [("normal",ScanSources,"src",normal,\p -> if p == "src" then ["z.hs","nested","a.hs","note.txt"] else ["b.hs"],Nothing)
  ,("reverse",ScanSources,"src",normal,\p -> if p == "src" then ["note.txt","a.hs","nested","z.hs"] else ["b.hs"],Nothing)
  ,("empty",ScanSources,"src",const TreeDirectory,const [],Nothing)
  ,("missing-scan",ScanSources,"src",const TreeMissing,const [],Nothing)
  ,("missing-copy",VerifyCopy,"src",const TreeMissing,const [],Nothing)
  ,("missing-archive",AuditArchive,"src",const TreeMissing,const [],Nothing)
  ,("root-file",ScanSources,"src",const TreeFile,const [],Nothing)
  ,("unsafe-root",ScanSources,"src",const TreeUnsafe,const [],Nothing)
  ,("unsafe-file",ScanSources,"src",child TreeUnsafe,const ["alias.hs"],Nothing)
  ,("unsafe-directory",ScanSources,"src",child TreeUnsafe,const ["alias"],Nothing)
  ,("missing-child",ScanSources,"src",child TreeMissing,const ["gone.hs"],Nothing)
  ,("unsafe-ancestor",ScanSources,"linked/oracle",const TreeUnsafe,const [],Nothing)
  ,("parent-root",ScanSources,"../outside",const TreeDirectory,const [],Nothing)
  ,("absolute-root",ScanSources,"/outside",const TreeDirectory,const [],Nothing)
  ,("windows-root",ScanSources,"C:outside",const TreeDirectory,const [],Nothing)
  ,("parent-entry",ScanSources,"src",normal,const [".."],Nothing)
  ,("nested-entry",ScanSources,"src",normal,const ["nested/evil.hs"],Nothing)
  ,("absolute-entry",ScanSources,"src",normal,const ["/evil.hs"],Nothing)
  ,("windows-entry",ScanSources,"src",normal,const ["C:evil.hs"],Nothing)
  ,("duplicate-entry",ScanSources,"src",child TreeFile,const ["a.hs","a.hs"],Nothing)
  ,("copy-generated",VerifyCopy,"",\p -> if p `elem` ["",".build"] then TreeDirectory else TreeFile,
      \p -> if null p then [".build","Input.hs"] else repeat "unobserved.hs",Nothing)
  ,("copy-generated-unsafe",VerifyCopy,"",\p -> if null p then TreeDirectory else TreeUnsafe,const [".build"],Nothing)
  ,("copy-generated-file",VerifyCopy,"",\p -> if null p then TreeDirectory else TreeFile,const [".build"],Nothing)
  ,("copy-nested-generated",VerifyCopy,"",\p -> if p == "sub/.build/Kept.hs" then TreeFile else TreeDirectory,
      \p -> case p of "" -> ["sub"]; "sub" -> [".build"]; _ -> ["Kept.hs"],Nothing)
  ,("archive-empty-root",AuditArchive,"",const TreeDirectory,const [],Nothing)
  ,("archive-empty-child",AuditArchive,"",const TreeDirectory,\p -> if null p then ["empty"] else [],Nothing)
  ,("inspect-failure",ScanSources,"src",child TreeFile,const ["Denied.hs"],Just ("inspect","src/Denied.hs"))
  ,("open-failure",ScanSources,"src",normal,const [],Just ("open","src"))
  ,("read-failure",ScanSources,"src",normal,const [],Just ("read","src"))
  ,("nested-open-failure",ScanSources,"src",const TreeDirectory,const ["nested"],Just ("open","src/nested"))
  ,("nested-read-failure",ScanSources,"src",const TreeDirectory,const ["nested"],Just ("read","src/nested"))
  ,("entries-at-limit",ScanSources,"",\p -> if null p then TreeDirectory else TreeFile,const (names 100000),Nothing)
  ,("entries-over-limit",ScanSources,"",\p -> if null p then TreeDirectory else TreeFile,const (map file [1..]),Nothing)
  ,("global-entry-limit",ScanSources,"",\p -> if p `elem` ["","left","right"] then TreeDirectory else TreeFile,
      \p -> if null p then ["left","right"] else names 50000,Nothing)
  ,("depth-at-limit",ScanSources,"src",deepKind,deep 127,Nothing)
  ,("depth-over-limit",ScanSources,"src",deepKind,deep 128,Nothing)
  ,("initial-depth-limit",ScanSources,Text.unpack (Text.intercalate "/" (replicate 129 "d")),const TreeDirectory,const [],Nothing)]
 where
  normal p = if p `elem` ["src","src/nested"] then TreeDirectory else TreeFile
  child kind p = if p == "src" then TreeDirectory else kind
  file n = "f-" <> show (n :: Int) <> ".hs"
  names count = map file [1..count]
  deepKind p = if "Leaf.hs" `Text.isSuffixOf` Text.pack p then TreeFile else TreeDirectory
  deep count p = if length (Text.splitOn "/" (Text.pack p)) == count then ["Leaf.hs"] else ["d"]

sourceRewriteRows :: FilePath -> IO [[Text]]
sourceRewriteRows output = do
  absolute <- makeAbsolute output
  exists <- doesDirectoryExist absolute
  if exists then die "source rewrite output must be fresh" else createDirectoryIfMissing True absolute
  let root = absolute </> "repo"
      originalBytes = Bytes.pack [0,255,10]
      changedBytes = Bytes.pack [0,254,10]
  createDirectoryIfMissing True root
  git root ["init", "--quiet"]
  Bytes.writeFile (root </> "binary.hs") originalBytes
  TextIO.writeFile (root </> "Program.hs") "module Fixture where\n"
  original <- acquired root
  TextIO.writeFile (root </> "Program.hs") "live input changed after acquisition\n"
  changed <- rewritten original "binary.hs" changedBytes
  copied <- materializeSource changed (absolute </> "copy") >>= either (die . Text.unpack) pure
  actualBytes <- Bytes.readFile (copied </> "binary.hs")
  actualOther <- TextIO.readFile (copied </> "Program.hs")
  copiedMode <- executable <$> getPermissions (copied </> "binary.hs")
  originalMode <- executable <$> getPermissions (root </> "binary.hs")
  checked <- verifySourceCopy changed copied
  oldChecked <- verifySourceCopy original copied
  TextIO.writeFile (root </> "Program.hs") "module Fixture where\n"
  Bytes.writeFile (root </> "binary.hs") changedBytes
  native <- acquired root
  restored <- rewritten changed "binary.hs" originalBytes
  source <- makeAbsolute "."
  let clone = absolute </> "clone"
  git source ["clone", "--quiet", "--shared", "--", source, clone]
  removeFile (clone </> "AGENTS.md")
  deleted <- acquired clone
  readme <- maybe (die "rewrite fixture README absent") pure (capturedSourceBytes deleted "README.md")
  deletedChanged <- rewritten deleted "README.md" (readme <> "\n")
  deletedCopy <- materializeSource deletedChanged (absolute </> "deleted-copy") >>= either (die . Text.unpack) pure
  deletedChecked <- verifySourceCopy deletedChanged deletedCopy
  present <- doesFileExist (deletedCopy </> "AGENTS.md")
  pure [[key, value] | (key, value) <-
    [("bytes", shown (Bytes.unpack actualBytes)), ("other-input", shown actualOther)
    ,("original-retained", shown (capturedSourceBytes original "binary.hs" == Just originalBytes))
    ,("inventory-retained", shown (capturedSourceFiles original == capturedSourceFiles changed))
    ,("mode-retained", shown (copiedMode == originalMode))
    ,("events-retained", shown (capturedSourceRuns original == capturedSourceRuns changed))
    ,("digest-changed", shown (capturedSourceDigest original /= capturedSourceDigest changed))
    ,("native-identity", shown (capturedSourceDigest changed == capturedSourceDigest native))
    ,("restored-identity", shown (capturedSourceDigest original == capturedSourceDigest restored))
    ,("copy-verified", either id (const "verified") checked)
    ,("original-refuses-copy", either id (const "verified") oldChecked)
    ,("missing-path", refusal (rewriteCapturedSource original "missing.hs" changedBytes))
    ,("unchanged-bytes", refusal (rewriteCapturedSource original "binary.hs" originalBytes))
    ,("deleted-path", refusal (rewriteCapturedSource deleted "AGENTS.md" "invented"))
    ,("tombstone-retained", shown ("AGENTS.md" `elem` capturedSourceFiles deletedChanged && capturedSourceBytes deletedChanged "AGENTS.md" == Nothing && not present))
    ,("tombstone-copy", either id (const "verified") deletedChecked)]]
 where
  acquired root = captureSource root >>= either (die . Text.unpack) pure
  rewritten snapshot path bytes = either (die . Text.unpack) pure (rewriteCapturedSource snapshot path bytes)
  shown :: Show value => value -> Text
  shown = Text.pack . show
  refusal = either id (const "rewritten")
  git root args = do
    run <- observe root "git" args
    unless (runExit run == ExitSuccess) (die "source rewrite fixture Git command failed")

sourceCaptureRows :: FilePath -> IO [[Text]]
sourceCaptureRows output = do
  absolute <- makeAbsolute output
  exists <- doesDirectoryExist absolute
  if exists then die "source-capture output must be fresh" else createDirectoryIfMissing True absolute
  let root = absolute </> "repo"
      empty = absolute </> "empty"
      broken = absolute </> "broken"
      payload = root </> "binary.hs"
  mapM_ (createDirectoryIfMissing True) [root, empty, broken]
  git root ["init", "--quiet"]
  git empty ["init", "--quiet"]
  TextIO.writeFile (broken </> ".git") "gitdir: missing\n"
  brokenResult <- captureSource broken
  emptyResult <- captureSource empty
  Bytes.writeFile payload (Bytes.pack [0,255,10])
  payloadMode <- getPermissions payload
  setPermissions payload payloadMode {executable = True}
  TextIO.writeFile (root </> "Program.hs") "module Main where\nmain :: IO ()\nmain = putStrLn \"captured\"\n"
  TextIO.writeFile (absolute </> "global-ignore") "binary.hs\n"
  git root ["config", "core.excludesFile", absolute </> "global-ignore"]
  baseline <- acquired root
  again <- acquired root
  Bytes.writeFile payload (Bytes.pack [0,254,10])
  changed <- acquired root
  Bytes.writeFile payload (Bytes.pack [0,255,10])
  permissions <- getPermissions payload
  setPermissions payload permissions {executable = not (executable permissions)}
  mode <- acquired root
  setPermissions payload permissions
  renameFile payload (root </> "renamed.hs")
  renamed <- acquired root
  renameFile (root </> "renamed.hs") payload
  createFileLink payload (root </> "alias.hs")
  linked <- captureSource root
  removeFile (root </> "alias.hs")
  createDirectoryIfMissing True (root </> "nested")
  nested <- captureSource (root </> "nested")
  let unknown = "validation-records/behavior.hs"
      known = "validation-records/generation-" <> replicate 16 'a' <> "/receipts/phase-00-"
        <> replicate 64 'b' <> "-" <> replicate 64 'c' <> "/candidate.tsv"
  mapM_ (\path -> createDirectoryIfMissing True (takeDirectory (root </> path)) >> Bytes.writeFile (root </> path) "input") [unknown, known]
  archive <- acquired root
  source <- makeAbsolute "."
  let clone = absolute </> "clone"
  git source ["clone", "--quiet", "--shared", "--", source, clone]
  indexed <- acquired clone
  original <- Bytes.readFile (clone </> "AGENTS.md")
  originalMode <- getPermissions (clone </> "AGENTS.md")
  removeFile (clone </> "AGENTS.md")
  deleted <- acquired clone
  Bytes.writeFile (clone </> "AGENTS.md") original
  setPermissions (clone </> "AGENTS.md") originalMode
  restored <- acquired clone
  copies <- sourceCopyRows absolute root baseline deleted
  pure
    ( [["inventory." <> name, either id (Text.intercalate "," . map Text.pack) (parseSourceInventory input)]
      | (name, input) <- [("clean", "b.hs\0a.hs\0"), ("empty", ""), ("unterminated", "a.hs")
        , ("duplicate", "a.hs\0a.hs\0"), ("parent", "../a.hs\0"), ("absolute", "/a.hs\0"), ("empty-entry", "a.hs\0\0")
        , ("windows-drive", "C:/a.hs\0"), ("windows-drive-relative", "C:a.hs\0"), ("windows-unc", "\\\\server\\share\\a.hs\0")
        , ("backslash", "a\\b.hs\0"), ("windows-device", "CON.hs\0")]]
      <> [ ["capture.broken-git", refusal brokenResult], ["capture.empty", refusal emptyResult]
         , ["capture.binary", maybe "absent" (Text.pack . show . Bytes.unpack) (capturedSourceBytes baseline "binary.hs")]
         , ["capture.global-ignore-visible", shown ("binary.hs" `elem` capturedSourceFiles baseline)]
         , ["capture.native-events", Text.pack (show (length (capturedSourceRuns baseline), all ((== ExitSuccess) . runExit) (capturedSourceRuns baseline))) ]
         , ["capture.native-executable", shown (all (isAbsolute . runExecutable) (capturedSourceRuns baseline))]
         , ["capture.same", equal baseline again], ["capture.byte-change", equal baseline changed]
         , ["capture.path-change", equal baseline renamed], ["capture.mode-change", equal baseline mode]
         , ["capture.symlink", refusal linked], ["capture.nested", refusal nested]
         , ["capture.deleted-recorded", shown ("AGENTS.md" `elem` capturedSourceFiles deleted && capturedSourceBytes deleted "AGENTS.md" == Nothing)]
         , ["capture.deleted-digest", equal indexed deleted], ["capture.restored-digest", equal indexed restored]
         , ["capture.unknown-archive-path", shown (unknown `elem` capturedSourceFiles archive)]
         , ["capture.canonical-archive-excluded", shown (known `notElem` capturedSourceFiles archive)]
         ] <> copies)
 where
  acquired root = captureSource root >>= either (die . Text.unpack) pure
  refusal = either id (const "captured")
  shown = Text.pack . show
  equal left right = shown (capturedSourceDigest left == capturedSourceDigest right)
  git root args = do
    run <- observe root "git" args
    unless (runExit run == ExitSuccess) (die "source-capture fixture Git command failed")

sourceCopyRows :: FilePath -> FilePath -> CapturedSource -> CapturedSource -> IO [[Text]]
sourceCopyRows output live snapshot deleted = do
  TextIO.writeFile (live </> "Program.hs") "module Main where\nmain :: IO ()\nmain = putStrLn \"live\"\n"
  let destination = output </> "captured-copy"
  copy <- materializeSource snapshot destination >>= either (die . Text.unpack) pure
  bytes <- Bytes.readFile (copy </> "binary.hs")
  permissions <- getPermissions (copy </> "binary.hs")
  initial <- verifySourceCopy snapshot copy
  reused <- materializeSource snapshot destination
  Bytes.writeFile (copy </> "binary.hs") "changed"
  changed <- verifySourceCopy snapshot copy
  Bytes.writeFile (copy </> "binary.hs") bytes
  setPermissions (copy </> "binary.hs") permissions {executable = False}
  mode <- verifySourceCopy snapshot copy
  setPermissions (copy </> "binary.hs") permissions
  removeFile (copy </> "binary.hs")
  missing <- verifySourceCopy snapshot copy
  createFileLink (live </> "binary.hs") (copy </> "binary.hs")
  link <- verifySourceCopy snapshot copy
  removeFile (copy </> "binary.hs")
  Bytes.writeFile (copy </> "binary.hs") bytes
  setPermissions (copy </> "binary.hs") permissions
  TextIO.writeFile (copy </> "unexpected.hs") "unexpected\n"
  extra <- verifySourceCopy snapshot copy
  removeFile (copy </> "unexpected.hs")
  createDirectoryLink live (copy </> "alias-dir")
  directoryLink <- verifySourceCopy snapshot copy
  removeDirectoryLink (copy </> "alias-dir")
  createDirectoryLink live (output </> "linked-parent")
  parentLink <- materializeSource snapshot (output </> "linked-parent" </> "copy")
  parentWritten <- doesDirectoryExist (live </> "copy")
  createDirectoryIfMissing True (copy </> ".build" </> "objects")
  TextIO.writeFile (copy </> ".build" </> "objects" </> "generated.hs") "generated\n"
  generated <- verifySourceCopy snapshot copy
  ghc <- findExecutable "ghc" >>= maybe (die "source-copy component needs native GHC") pure
  build <- observe copy ghc ["-v0", "-j1", "-outputdir", ".build/objects", "-o", ".build/program", "Program.hs"]
  run <- observe copy (copy </> ".build/program") []
  TextIO.writeFile (output </> "copy-processes.tsv") (Text.unlines
    [Text.intercalate "\t" [name, shown (runExecutable event), shown (runArgv event), shown (runCwd event)
      , shown (runEnvironmentPolicy event), shown (runExit event, runStdout event, runStderr event, runSpawnFailure event)]
    | (name, event) <- [("build", build), ("run", run)]])
  final <- verifySourceCopy snapshot copy
  renameDirectory (copy </> ".build") (copy </> ".build-backup")
  createDirectoryLink live (copy </> ".build")
  generatedLink <- verifySourceCopy snapshot copy
  removeDirectoryLink (copy </> ".build")
  renameDirectory (copy </> ".build-backup") (copy </> ".build")
  let explicitRoot = output </> "explicit-build-repo"
  createDirectoryIfMissing True (explicitRoot </> ".build")
  initialized <- observe explicitRoot "git" ["init", "--quiet"]
  unless (runExit initialized == ExitSuccess) (die "source-copy fixture Git command failed")
  TextIO.writeFile (explicitRoot </> ".build/declared.hs") "declared\n"
  explicitSource <- captureSource explicitRoot >>= either (die . Text.unpack) pure
  explicitCopy <- materializeSource explicitSource (output </> "explicit-build-copy") >>= either (die . Text.unpack) pure
  explicitClean <- verifySourceCopy explicitSource explicitCopy
  TextIO.writeFile (explicitCopy </> ".build/declared.hs") "changed\n"
  explicitChanged <- verifySourceCopy explicitSource explicitCopy
  deletedCopy <- materializeSource deleted (output </> "deleted-copy") >>= either (die . Text.unpack) pure
  tombstone <- doesFileExist (deletedCopy </> "AGENTS.md")
  deletedChecked <- verifySourceCopy deleted deletedCopy
  pure
    [ ["copy.bytes", shown (Bytes.unpack bytes)], ["copy.executable", shown (executable permissions)]
    , ["copy.initial", checked initial], ["copy.reused", either id (const "copied") reused]
    , ["copy.byte-change", checked changed], ["copy.mode-change", checked mode]
    , ["copy.missing", checked missing], ["copy.symlink", checked link], ["copy.extra", checked extra]
    , ["copy.directory-symlink", checked directoryLink], ["copy.parent-symlink", either id (const "copied") parentLink]
    , ["copy.parent-symlink-no-write", shown (not parentWritten)]
    , ["copy.generated-state", checked generated]
    , ["copy.native-build", shown (runExit build, runStdout build, runStderr build)]
    , ["copy.native-run", shown (runExit run, runStdout run, runStderr run)]
    , ["copy.native-origin", shown (runCwd build == copy && runCwd run == copy && isAbsolute (runExecutable build) && runExecutable run == copy </> ".build/program")]
    , ["copy.final", checked final], ["copy.generated-root-symlink", checked generatedLink]
    , ["copy.explicit-build-input", checked explicitClean], ["copy.explicit-build-changed", checked explicitChanged]
    , ["copy.deleted-absent", shown (not tombstone)], ["copy.deleted-verified", checked deletedChecked]
    ]
 where
  shown :: Show value => value -> Text
  shown = Text.pack . show
  checked = either id (const "verified")

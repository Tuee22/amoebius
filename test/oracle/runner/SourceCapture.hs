{-# LANGUAGE OverloadedStrings #-}

-- | Independent source-custody expectations, not legacy closure authority.
module SourceCapture (sourceCaptureChecks, sourceApiChecks, predecessorApiChecks, sourceRewriteChecks, sourceTreeChecks, sourceTreeJudge) where

import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (findExecutable, makeAbsolute)
import System.FilePath ((</>))
import NativeApi (nativeApiChecks)

sourceTreeChecks :: FilePath -> IO [(Text, Bool, Text)]
sourceTreeChecks directory = sourceTreeJudge . map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "source-tree.tsv")

-- Independent limits, expected paths and exact boundary call/close counts.
sourceTreeJudge :: [[Text]] -> [(Text, Bool, Text)]
sourceTreeJudge rows =
  let normal = ["src/a.hs","src/nested/b.hs","src/note.txt","src/z.hs"]
      deep count = Text.intercalate "/" (["src"] <> replicate count "d" <> ["Leaf.hs"])
      expected =
        [("normal","files","(6,2,7,2,0,2)",normal), ("reverse","files","(6,2,7,2,0,2)",normal)
        ,("empty","files","(1,1,1,1,0,1)",[]), ("missing-scan","files","(1,0,0,0,0,0)",[])]
        <> [(key,"SourceTreeUnsafe:src","(1,0,0,0,0,0)",[]) | key <- ["missing-copy","missing-archive","root-file","unsafe-root"]]
        <> [("unsafe-file","SourceTreeUnsafe:src/alias.hs","(2,1,1,1,0,1)",[])
           ,("unsafe-directory","SourceTreeUnsafe:src/alias","(2,1,1,1,0,1)",[])
           ,("missing-child","SourceTreeUnsafe:src/gone.hs","(2,1,1,1,0,1)",[])
           ,("unsafe-ancestor","SourceTreeUnsafe:linked/oracle","(1,0,0,0,0,0)",[])]
        <> [(key,"SourceTreePath","(0,0,0,0,0,0)",[]) | key <- ["parent-root","absolute-root","windows-root"]]
        <> [(key,"SourceTreeEntry","(1,1,1,1,0,1)",[]) | key <- ["parent-entry","nested-entry","absolute-entry","windows-entry"]]
        <> [("duplicate-entry","SourceTreeEntry","(2,1,2,1,0,1)",[])
           ,("copy-generated","files","(3,1,3,1,0,1)",["Input.hs"])
           ,("copy-generated-unsafe","SourceTreeUnsafe:.build","(2,1,1,1,0,1)",[])
           ,("copy-generated-file","SourceTreeUnsafe:.build","(2,1,1,1,0,1)",[])
           ,("copy-nested-generated","files","(4,3,6,3,0,3)",["sub/.build/Kept.hs"])
           ,("archive-empty-root","files","(1,1,1,1,0,1)",[])
           ,("archive-empty-child","SourceTreeEmpty:empty","(2,2,2,2,0,2)",[])
           ,("inspect-failure","fixture-inspect","(2,1,1,1,0,1)",[])
           ,("open-failure","fixture-open","(1,0,0,0,0,0)",[])
           ,("read-failure","fixture-read","(1,1,1,1,0,1)",[])
           ,("nested-open-failure","fixture-open","(2,1,1,1,0,1)",[])
           ,("nested-read-failure","fixture-read","(2,2,2,2,0,2)",[])
           ,("entries-at-limit","files","(100001,1,100001,1,0,1)",sort ["f-" <> Text.pack (show n) <> ".hs" | n <- [1..100000 :: Int]])
           ,("entries-over-limit","SourceTreeEntries","(100001,1,100001,1,0,1)",[])
           ,("global-entry-limit","SourceTreeEntries","(100001,3,100002,3,0,2)",[])
           ,("depth-at-limit","files","(128,127,254,127,0,127)",[deep 126])
           ,("depth-over-limit","SourceTreeDepth:" <> deep 127,"(128,128,128,128,0,128)",[])
           ,("initial-depth-limit","SourceTreeDepth:" <> Text.intercalate "/" (replicate 129 "d"),"(0,0,0,0,0,0)",[])
           ,("native","files","-",["src/A.hs","src/nested/B.hs"])]
        <> [("classify." <> key,kind,"-",[]) | (key,kind) <-
          [("file","TreeFile"),("directory","TreeDirectory"),("linked-file","TreeUnsafe"),("linked-directory","TreeUnsafe")
          ,("file-symlink-type","TreeUnsafe"),("directory-symlink-type","TreeUnsafe"),("outside-file","TreeUnsafe")
          ,("outside-directory","TreeUnsafe"),("other","TreeUnsafe"),("linked-other","TreeUnsafe")]]
      observed name = [(result,metrics,if Text.null paths then [] else Text.splitOn "\0" paths) | [key,result,metrics,paths] <- rows, key == name]
      keys = [key | [key,_,_,_] <- rows]
  in ("source-tree.discovery",sort keys == sort [key | (key,_,_,_) <- expected] && all ((==4) . length) rows,Text.pack (show (length keys)))
    : [("source-tree." <> key,observed key == [(result,metrics,paths)],
        Text.pack (show [(r,m,length ps) | (r,m,ps) <- observed key])) | (key,result,metrics,paths) <- expected]

sourceRewriteChecks :: FilePath -> IO [(Text, Bool, Text)]
sourceRewriteChecks directory = do
  rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile (directory </> "source-rewrite.tsv")
  let expected = [("bytes", "[0,254,10]"), ("other-input", "\"module Fixture where\\n\"")]
        <> [(name, "True") | name <- ["original-retained", "inventory-retained", "mode-retained", "events-retained", "digest-changed", "native-identity", "restored-identity", "tombstone-retained"]]
        <> [("copy-verified", "verified"), ("original-refuses-copy", "SourceCopyInputChanged:binary.hs")
           ,("missing-path", "SourceRewriteMissing"), ("unchanged-bytes", "SourceRewriteUnchanged")
           ,("deleted-path", "SourceRewriteMissing"), ("tombstone-copy", "verified")]
      observed name = [value | [key, value] <- rows, key == name]
  pure (("source-rewrite.discovery", sort [name | [name, _] <- rows] == sort (map fst expected) && all ((== 2) . length) rows, Text.pack (show rows))
    : [("source-rewrite." <> name, observed name == [value], Text.pack (show (observed name))) | (name, value) <- expected])

sourceApiChecks :: FilePath -> IO [(Text, Bool, Text)]
sourceApiChecks directory = do
  source <- nativeApiChecks directory unitIds roots
    ["import Amoebius.Validation.Runner.Hygiene", "import Data.Text (Text)"]
    [ ("source-api.constructor", signature, "captureSource", "\\_ -> pure (Right (CapturedSource undefined undefined))", 26,
        ["[GHC-01928]", "Illegal term-level use of the type constructor", "CapturedSource"])
    , ("source-api.read", signature, "captureSource", "\\_ -> pure (Right (read \"forged\"))", 26,
        ["[GHC-39999]", "No instance for", "Read CapturedSource"])
    ]
  binary <- nativeApiChecks directory unitIds (roots <> ["src/doc-check", "src"])
    ["import Amoebius.Validation.Runner", "import Data.Text (Text)"]
    [("source-api.prebuilt-product", "Int -> RunnerConfig", "defaultRunnerConfig \".\"",
      "\\_ -> undefined {runnerProductBinary = undefined}", 24,
      ["[GHC-22385]", "Not in scope: record field", "runnerProductBinary"])]
  predecessor <- predecessorApiChecks directory
  qualification <- nativeApiChecks directory unitIds (roots <> ["src/doc-check", "src"])
    ["import Amoebius.Validation.Runner.Legacy", "import Data.Text (Text)"]
    [ ("source-api.qualification-constructor", "LegacyQualification -> LegacyQualification", "id",
        "\\_ -> LegacyQualified undefined undefined undefined undefined undefined undefined", 13,
        ["[GHC-88464]", "Data constructor not in scope", "LegacyQualified"])
    , ("source-api.qualification-read", "LegacyQualification -> LegacyQualification", "id", "\\_ -> read \"forged\"", 13,
        ["[GHC-39999]", "No instance for", "Read LegacyQualification"])
    , ("source-api.collection-constructor", "LegacyCollection -> LegacyCollection", "id",
        "\\_ -> LegacyCollected undefined undefined undefined undefined undefined", 13,
        ["[GHC-88464]", "Data constructor not in scope", "LegacyCollected"])
    , ("source-api.collection-read", "LegacyCollection -> LegacyCollection", "id", "\\_ -> read \"forged\"", 13,
        ["[GHC-39999]", "No instance for", "Read LegacyCollection"])
    ]
  pure (source <> binary <> qualification <> predecessor)
 where signature = "FilePath -> IO (Either Text CapturedSource)"
       unitIds = ["amoebius-0.1.0.0-inplace-validation-kernel"]
       roots = ["src/validation-kernel", "src/gate-spec", "src/plan-decisions"]

predecessorApiChecks :: FilePath -> IO [(Text, Bool, Text)]
predecessorApiChecks directory = nativeApiChecks directory ["amoebius-0.1.0.0-inplace-validation-kernel"]
  ["src/validation-kernel", "src/gate-spec", "src/plan-decisions", "src/doc-check", "src"]
  ["import Amoebius.Validation.Runner", "import Data.Text (Text)"]
  [("source-api.predecessor-constructor", "PassedGate -> PassedGate", "id", "\\_ -> PassedGate undefined undefined undefined", 13,
    ["[GHC-01928]", "Illegal term-level use of the type constructor", "PassedGate"])
  ,("source-api.predecessor-read", "PassedGate -> PassedGate", "id", "\\_ -> read \"forged\"", 13,
    ["[GHC-39999]", "No instance for", "Read PassedGate"])]

sourceCaptureChecks :: FilePath -> IO [(Text, Bool, Text)]
sourceCaptureChecks directory = do
  input <- TextIO.readFile (directory </> "source.tsv")
  processes <- processChecks directory
  let rows = map (Text.splitOn "\t") (Text.lines input)
      actualKeys = [name | name : _ <- rows]
      observed name = case [value | [key, value] <- rows, key == name] of
        [value] -> value
        _ -> "missing-or-duplicate-row"
  pure (("source.discovery", sort actualKeys == sort (map fst expectations), Text.intercalate "," actualKeys)
    : [("source." <> name, observed name == expected, observed name) | (name, expected) <- expectations] <> processes)

processChecks :: FilePath -> IO [(Text, Bool, Text)]
processChecks directory = do
  input <- TextIO.readFile (directory </> "copy-processes.tsv")
  copied <- makeAbsolute (directory </> "captured-copy")
  compiler <- findExecutable "ghc"
  let rows = map (Text.splitOn "\t") (Text.lines input)
      expected =
        [ ["build", shown (maybe "compiler-unavailable" id compiler)
          , shown (["-v0", "-j1", "-outputdir", ".build/objects", "-o", ".build/program", "Program.hs"] :: [String])
          , shown copied, shown policy, "(ExitSuccess,\"\",\"\",Nothing)"]
        , ["run", shown (copied </> ".build/program"), "[]", shown copied, shown policy, "(ExitSuccess,\"captured\\n\",\"\",Nothing)"]
        ]
      fields = ["executable", "argv", "cwd", "environment", "result"]
      observed name index = case [values | key : values <- rows, key == name] of
        [values] | length values == 5 -> values !! index
        _ -> "missing-or-duplicate-process"
  pure (("source.process-discovery", map (take 1) rows == [["build"], ["run"]] && all ((== 6) . length) rows, shown rows)
    : [("source.process." <> name <> "." <> field, observed name index == value, observed name index)
      | name : values <- expected, (index, (field, value)) <- zip [0 ..] (zip fields values)])
 where
  shown :: Show value => value -> Text
  shown = Text.pack . show
  policy = "inherit:PATH,HOME,CABAL_DIR,GHCUP_INSTALL_BASE_PREFIX,XDG_CACHE_HOME,LANG" :: Text

expectations :: [(Text, Text)]
expectations =
  [ ("inventory.clean", "a.hs,b.hs")
  , ("inventory.empty", "SourceInventoryEmpty")
  , ("inventory.unterminated", "SourceInventoryMalformed")
  , ("inventory.duplicate", "SourceInventoryDuplicate")
  , ("inventory.parent", "SourceInventoryPath")
  , ("inventory.absolute", "SourceInventoryPath")
  , ("inventory.empty-entry", "SourceInventoryPath")
  , ("inventory.windows-drive", "SourceInventoryPath")
  , ("inventory.windows-drive-relative", "SourceInventoryPath")
  , ("inventory.windows-unc", "SourceInventoryPath")
  , ("inventory.backslash", "SourceInventoryPath")
  , ("inventory.windows-device", "SourceInventoryPath")
  , ("capture.broken-git", "SourceGitUnavailable")
  , ("capture.empty", "SourceInventoryEmpty")
  , ("capture.binary", "[0,255,10]")
  , ("capture.global-ignore-visible", "True")
  , ("capture.native-events", "(3,True)")
  , ("capture.native-executable", "True")
  , ("capture.same", "True")
  , ("capture.byte-change", "False")
  , ("capture.path-change", "False")
  , ("capture.mode-change", "False")
  , ("capture.symlink", "SourceInputUnavailable:alias.hs:SourceSymlink")
  , ("capture.nested", "SourceRootMismatch")
  , ("capture.deleted-recorded", "True")
  , ("capture.deleted-digest", "False")
  , ("capture.restored-digest", "True")
  , ("capture.unknown-archive-path", "True")
  , ("capture.canonical-archive-excluded", "True")
  , ("copy.bytes", "[0,255,10]")
  , ("copy.executable", "True")
  , ("copy.initial", "verified")
  , ("copy.reused", "SourceCopyNotFresh")
  , ("copy.byte-change", "SourceCopyInputChanged:binary.hs")
  , ("copy.mode-change", "SourceCopyInputChanged:binary.hs")
  , ("copy.missing", "SourceCopyInventoryChanged")
  , ("copy.symlink", "SourceTreeUnsafe:binary.hs")
  , ("copy.extra", "SourceCopyInventoryChanged")
  , ("copy.directory-symlink", "SourceTreeUnsafe:alias-dir")
  , ("copy.parent-symlink", "SourceCopyParentSymlink")
  , ("copy.parent-symlink-no-write", "True")
  , ("copy.generated-state", "verified")
  , ("copy.native-build", "(ExitSuccess,\"\",\"\")")
  , ("copy.native-run", "(ExitSuccess,\"captured\\n\",\"\")")
  , ("copy.native-origin", "True")
  , ("copy.final", "verified")
  , ("copy.generated-root-symlink", "SourceTreeUnsafe:.build")
  , ("copy.explicit-build-input", "verified")
  , ("copy.explicit-build-changed", "SourceCopyInputChanged:.build/declared.hs")
  , ("copy.deleted-absent", "True")
  , ("copy.deleted-verified", "verified")
  ]

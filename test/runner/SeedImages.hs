{-# LANGUAGE OverloadedStrings #-}
-- | Native observations from the shipped finite-seed API. These controls
-- qualify input/image/refusal guards and add no product mutant to the seed.
module SeedImages (seedImageRows) where
import Amoebius.Validation.BootstrapQualification.Internal
import Amoebius.Validation.Runner
import Control.Monad (forM,forM_,unless)
import Data.ByteString qualified as B
import Data.Text qualified as T
import Data.Text.Encoding qualified as E
import Data.Text.IO qualified as TIO
import System.Directory
import System.Exit (ExitCode(..))
import System.FilePath ((</>),takeDirectory)
seedImageRows :: FilePath -> FilePath -> IO ()
seedImageRows destination ghc = do
 base <- makeAbsolute destination
 present <- doesPathExist base
 unless (not present) (fail "finite seed observation root must be fresh")
 createDirectoryIfMissing True base
 -- The selected inputs are copied from the actual caller tree into a fresh
 -- fixture repository. This also works inside a materialized candidate with
 -- no Git metadata, without changing that candidate's source inventory.
 let inputRoot=base </> "input-repository"
 forM_ ["src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs","test/validation-kernel/BootstrapMutationDriver.hs","src/validation-kernel/Amoebius/Validation/Authority/Core.hs"] $ \path -> do
   bytes <- readSourceBytes path
   createDirectoryIfMissing True (takeDirectory (inputRoot </> path))
   B.writeFile (inputRoot </> path) bytes
 initialized <- observe inputRoot "git" ["init","--quiet"]
 unless (runExit initialized==ExitSuccess && runSpawnFailure initialized==Nothing) (fail "finite seed input repository unavailable")
 source <- captureSource inputRoot >>= either (fail . T.unpack) pure
 let predicate="src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs"
     driver="test/validation-kernel/BootstrapMutationDriver.hs"
     before="bootstrapDigestMatches actual expected = validLowerSha256 actual && actual == expected"
     after="bootstrapDigestMatches actual _expected = validLowerSha256 actual"
     body path=maybe (error "captured input absent") E.decodeUtf8 (capturedSourceBytes source path)
     change path text=either (fail . T.unpack) pure (rewriteCapturedSource source path (E.encodeUtf8 text))
     compile name lines_ = do
       let file=base </> "support" </> name <> ".hs";image=base </> "support" </> name <> ".exe"
       createDirectoryIfMissing True (takeDirectory file)
       TIO.writeFile file (T.unlines lines_)
       actual <- observe "." ghc ["-v0","-j1","-XGHC2024","--make","-package","bytestring","-package","directory","-package","filepath","-package","process","-outputdir",base </> "support" </> name <> "-objects","-o",image,file]
       unless (runExit actual==ExitSuccess && runSpawnFailure actual==Nothing) (fail (show actual))
       pure image
     runtime changeImage =
       ["module Main where","import Control.Monad","import System.Directory","import System.Environment","import System.Exit","import System.FilePath","import System.IO","import Data.ByteString qualified as B","main = do"]
       <> (if changeImage then ["  path <- getExecutablePath","  bytes <- B.readFile path","  B.writeFile (path <> \".next\") (bytes <> B.singleton 0)","  permissions <- getPermissions path","  setPermissions (path <> \".next\") permissions","  renameFile (path <> \".next\") path"] else [])
       <> ["  label <- takeFileName <$> getCurrentDirectory","  unless (label == \"clean\") (hPutStrLn stderr label >> exitFailure)"]
 baseline <- compile "fixed-runtime" (runtime False)
 _ <- compile "changing-runtime" (runtime True)
 let fake mode =
       ["module Main where","import Control.Monad","import System.Directory","import System.Environment","import System.Exit","import System.Process","import System.FilePath","import Data.List","main = do"]
       <> case mode of
         "known-127" -> ["  exitWith (ExitFailure 127)"]
         "absent-image" -> ["  pure ()"]
         "empty-image" -> ["  writeFile \"driver.exe\" \"\""]
         "symlink-image" -> ["  createFileLink "<>T.pack (show baseline)<>" \"driver.exe\""]
         "same-image" -> ["  copyFile "<>T.pack (show baseline)<>" \"driver.exe\""]
         "changed-image" ->
           ["  tag <- takeFileName <$> getCurrentDirectory"
           ,"  body <- readFile "<>T.pack (show (base </> "support/changing-runtime.hs"))
           ,"  let rewrite line | line == \"main = do\" = line <> \"\\n  let expectedLabel = \" <> show tag | line == \"  label <- takeFileName <$> getCurrentDirectory\" = line <> \"\\n  unless (label == expectedLabel) (exitWith (ExitFailure 2))\" | otherwise = line"
           ,"  writeFile \"Changing.hs\" (unlines (map rewrite (lines body)))"
           ,"  rawSystem "<>T.pack (show ghc)<>" [\"-v0\",\"-j1\",\"-o\",\"driver.exe\",\"Changing.hs\"] >>= exitWith"]
         "generated-change" -> ["  args <- getArgs","  result <- rawSystem "<>T.pack (show ghc)<>" args","  appendFile \"Amoebius/Validation/BootstrapPredicate.hs\" \" \\n\"","  exitWith result"]
         "unavailable-run" ->
           ["  source <- readFile \"Amoebius/Validation/BootstrapPredicate.hs\"","  if \"bootstrapDigestMatches actual _expected\" `isInfixOf` source then do","    writeFile \"driver.exe\" "<>T.pack (show ("#!"<>base </> "support/missing-interpreter"<>"\n")),"    permissions <- getPermissions \"driver.exe\"","    setPermissions \"driver.exe\" permissions {executable=True}","  else getArgs >>= rawSystem "<>T.pack (show ghc)<>" >>= exitWith"]
         _ -> error "unknown fake"
 fakes <- forM ["known-127","absent-image","empty-image","symlink-image","same-image","changed-image","generated-change","unavailable-run"] $ \name -> (,) name <$> compile name (fake name)
 let unavailable=base </> "support/unavailable-build.exe"
 writeFile unavailable ("#!"<>base </> "support/missing-interpreter"<>"\n")
 permissions <- getPermissions unavailable
 setPermissions unavailable permissions {executable=True}
 forM_ ["normal","source-mismatch","missing-locus","duplicate-locus","already-bypassed","known-127","absent-image","empty-image","symlink-image","same-image","changed-image","noisy-driver","wrong-label","wrong-exit","unavailable-build","unavailable-run","generated-change"] $ \name -> do
   selectedSource <- case name of
     "missing-locus" -> change predicate (T.replace before (before<>" ") (body predicate))
     "duplicate-locus" -> change predicate (body predicate<>"\n{-\n"<>before<>"\n-}\n")
     "already-bypassed" -> change predicate (T.replace before after (body predicate))
     "noisy-driver" -> change driver (T.replace "main = do\n" "main = do\n  putStrLn \"noise\"\n" (body driver))
     "wrong-label" -> change driver (T.replace "hPutStrLn stderr label" "hPutStrLn stderr (label <> \"-wrong\")" (body driver))
     "wrong-exit" -> change driver (T.replace "import System.Exit (exitFailure)" "import System.Exit (exitFailure,exitWith,ExitCode(..))" (T.replace "hPutStrLn stderr label >> exitFailure" "hPutStrLn stderr label >> exitWith (ExitFailure 2)" (body driver)))
     _ -> pure source
   let work=base </> name
   root <- materializeSource selectedSource (work </> "source") >>= either (fail . T.unpack) pure
   whenName (name=="source-mismatch") (TIO.appendFile (root </> predicate) "\n-- actual uncaptured change\n")
   let selected=if name=="unavailable-build" then unavailable else maybe ghc id (lookup name fakes)
   actual <- runCapturedSeedProtocol ((defaultSeedProtocol root (root </> ".build/finite")) {protocolCompiler=Just selected}) selectedSource (T.replicate 64 "a")
   entries <- forM (seedAttempts actual) $ \attempt -> do
     let save point result=case result of
           Left problem -> pure (Left problem)
           Right buffers -> Right <$> forM (zip [0::Int ..] buffers) (\(index,bytes)->do
             let path=work </> T.unpack (attemptLabel attempt)<>"-"<>point<>"-"<>show index<>".image"
             B.writeFile path bytes
             pure (path,B.length bytes,sha256Bytes bytes))
     beforeImages <- save "before" (attemptImageBefore attempt)
     afterImages <- save "after" (attemptImageAfter attempt)
     present <- doesPathExist (attemptDirectory attempt)
     pure (attemptLabel attempt,attemptDirectory attempt,map B.unpack (attemptInputs attempt),attemptWrite attempt,fmap (map B.unpack) (attemptGeneratedBefore attempt),fmap (map B.unpack) (attemptGeneratedAfter attempt),beforeImages,afterImages,attemptBuild attempt,attemptRun attempt,attemptCleanup attempt,present)
   closing <- verifySourceCopy selectedSource root
   TIO.writeFile (work </> "actual.data") (T.pack (show (name,seedCapturedSource actual,seedCompiler actual,seedProblems actual,seedGreen actual,seedInterrupted actual,seedChain actual,[(path,B.unpack bytes) | (path,bytes)<-seedInputs actual],closing,entries)))
   putStrLn (name<>" observed")
 where whenName True action=action;whenName False _=pure ()

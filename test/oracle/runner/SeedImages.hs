{-# LANGUAGE OverloadedStrings #-}
-- | Independent literal expectations and byte comparisons for finite-seed
-- observations. Imports no product or validation library.
module SeedImages (seedImageChecks,seedImageNames) where
import Control.Monad (forM,unless)
import Crypto.Hash.SHA256 qualified as SHA
import Data.ByteString qualified as B
import Data.List (sort)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Numeric (showHex)
import System.Directory
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import Data.Word (Word8)
import Data.Text (Text)
import Text.Read (readMaybe)
data ObservedRun=ObservedRun
 { runExecutable :: FilePath,runArgv :: [String],runCwd :: FilePath
 ,runEnvironment :: [(String,String)],runEnvironmentPolicy :: Text,runExit :: ExitCode
 ,runStdout :: Text,runStderr :: Text,runSpawnFailure :: Maybe Text } deriving (Eq,Read,Show)
type Image = (FilePath,Int,Text)
type Attempt = (Text,FilePath,[[Word8]],Either Text (),Either Text [[Word8]],Either Text [[Word8]],Either Text [Image],Either Text [Image],Maybe ObservedRun,Maybe ObservedRun,Either Text Bool,Bool)
type SeedRow = (String,Text,Maybe FilePath,[Text],Bool,Bool,Text,[(FilePath,[Word8])],Either Text (),[Attempt])

-- Declared before the collector. Compiler fakes are supplied test boundaries;
-- no result from this diagnostic supplies a native-toolchain or phase receipt.
-- name, attempt count, actual native-return count, interrupted, seed eligible.
expected :: [(String,Int,Int,Bool,Bool)]
expected =
 [("normal",4,8,False,True)
 ,("source-mismatch",0,0,False,False)
 ,("missing-locus",4,6,False,False)
 ,("duplicate-locus",4,6,False,False)
 ,("already-bypassed",4,6,False,False)
 ,("known-127",4,4,False,False)
 ,("absent-image",4,4,False,False)
 ,("empty-image",4,4,False,False)
 ,("symlink-image",4,4,False,False)
 ,("same-image",4,8,False,False)
 ,("changed-image",4,8,False,False)
 ,("noisy-driver",4,8,False,False)
 ,("wrong-label",4,8,False,False)
 ,("wrong-exit",4,8,False,False)
 ,("unavailable-build",1,1,True,False)
 ,("unavailable-run",2,4,True,False)
 ,("generated-change",4,8,False,False)]
labels :: [String]
labels=["clean","digest-equality-bypass","snapshot-freshness-bypass","bootstrap-path-bypass"]

-- Closed oracle-local extension namespace, independent of product registries,
-- inputs and current output. The original five authority cases stay separate.
seedImageNames :: [T.Text]
seedImageNames = "finite.discovery" : concat
 [map (\field -> T.pack ("finite."<>name<>"."<>field))
  (["identity","attempt-inventory","native-count","verdict","copy-closing","retained-leaves","unknown-prefix","image-count","image-window","native-request","generated-readback"]
   <> ["source-inputs" | name/="source-mismatch"]
   <> ["exact-protocol" | name `elem` ["normal","same-image","changed-image","generated-change"]]
   <> ["changed-images" | name `elem` ["normal","changed-image"]]
   <> ["same-image-refused" | name=="same-image"] <> ["known-code-preserved" | name=="known-127"] <> ["source-refusal" | name=="source-mismatch"])
 | (name,_,_,_,_)<-expected]

seedImageChecks :: FilePath -> IO [(T.Text,Bool,T.Text)]
seedImageChecks base = do
 actualNames <- filterMFile base =<< listDirectory base
 results <- forM expected $ \(name,count,native,interrupted,green) -> do
  text <- TIO.readFile (base </> name </> "actual.data")
  (observed,source,compiler,problems,eligible,stopped,chain,inputs,closing,attempts) <- maybe (fail "seed data malformed") pure (readMaybe (T.unpack text)) :: IO SeedRow
  let runs=concat [maybe [] pure build<>maybe [] pure run | (_,_,_,_,_,_,_,_,build,run,_,_)<-attempts]
      terminal run code out err=runExit run==code && runStdout run==out && runStderr run==err && runSpawnFailure run==Nothing
      correctProtocol=and [maybe False (\run->terminal run (if label=="clean" then ExitSuccess else ExitFailure 1) "" (if label=="clean" then "" else label<>"\n")) run | (label,_,_,_,_,_,_,_,_,run,_,_)<-attempts]
      rawImages=[(before,after) | (_,_,_,_,_,_,Right [before],Right [after],_,_,_,_)<-attempts]
      known=not interrupted
      kept=[present | (_,_,_,_,_,_,_,_,_,_,_,present)<-attempts]
      expectedKept=if name=="unavailable-build" then [True] else if name=="unavailable-run" then [False,True] else replicate count False
      untouched=and [after==Left "not attempted" && imageAfter==Left "not attempted" && cleanup==Left "not attempted" | (_,_,_,_,_,after,_,imageAfter,build,run,cleanup,_)<-attempts,any ((/=Nothing).runSpawnFailure) (maybe [] pure build<>maybe [] pure run)]
  images <- forM rawImages $ \(before,after)->do a<-readImage before;b<-readImage after;pure (a,b)
  let expectedImages=if name `elem` ["normal","same-image","changed-image","noisy-driver","wrong-label","wrong-exit","generated-change"] then 4 else if name `elem` ["missing-locus","duplicate-locus","already-bypassed"] then 3 else if name=="unavailable-run" then 1 else 0
      expectedProtocol=name `elem` ["normal","same-image","changed-image","generated-change"]
      checks=
       [("identity",observed==name && length (T.unpack source)==64 && length (T.unpack chain)==64)
       ,("attempt-inventory",map (T.unpack . labelOf) attempts==take count labels)
       ,("native-count",length runs==native)
       ,("verdict",eligible==green && stopped==interrupted)
       ,("copy-closing",if name=="source-mismatch" then closing/=Right () else closing==Right ())
       ,("retained-leaves",kept==expectedKept)
       ,("unknown-prefix",untouched && (known==all ((==Nothing).runSpawnFailure) runs))
       ,("image-count",length images==expectedImages && all (\(a,b)->not (B.null a) && not (B.null b)) images)
       ,("image-window",if name=="changed-image" then all (uncurry (/=)) images else all (uncurry (==)) images)
       ,("native-request",and [runExecutable build==maybe "" id compiler && runCwd build==directory && runArgv build==["-v0","-j1","-i.","-outputdir","objects","-o","driver.exe","Driver.hs"] | (_,directory,_,_,_,_,_,_,Just build,_,_,_)<-attempts])]
       <> [("exact-protocol",correctProtocol) | expectedProtocol]
       <> [("changed-images",case map fst images of clean:mutants->all (/=clean) mutants;_->False) | name `elem` ["normal","changed-image"]]
       <> [("same-image-refused",case map fst images of clean:mutants->length mutants==3 && all (==clean) mutants && not eligible;_->False) | name=="same-image"]
       <> [("known-code-preserved",all (\run->runExit run==ExitFailure 127 && runSpawnFailure run==Nothing) runs) | name=="known-127"]
       <> [("source-refusal",null inputs && not (null problems) && null attempts) | name=="source-mismatch"]
       <> [("source-inputs",map fst inputs==["src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs","test/validation-kernel/BootstrapMutationDriver.hs","src/validation-kernel/Amoebius/Validation/Authority/Core.hs"] && all (not . null . snd) inputs) | name/="source-mismatch"]
       <> [("generated-readback",and [before==Right values && if name=="generated-change" then after/=before else after==before | (_,_,values,Right (),before,after,_,_,Just _,Just run,_,_)<-attempts,runSpawnFailure run==Nothing])]
  pure [("finite."<>name<>"."<>key,okay) | (key,okay)<-checks]
 let names=map (T.pack . fst) (concat results)
     checks=("finite.discovery",sort actualNames==sort [name | (name,_,_,_,_)<-expected] && sort ("finite.discovery":names)==sort seedImageNames):concat results
 pure [(T.pack name,okay,"independent finite native/source/image observation") | (name,okay)<-checks]
 where
  labelOf (label,_,_,_,_,_,_,_,_,_,_,_)=label
  filterMFile base names=fmap concat (forM names (\name->do exists<-doesFileExist (base </> name </> "actual.data");pure [name | exists]))
  readImage (path,count,digest)=do
   bytes<-B.readFile path
   unless (B.length bytes==count && hash bytes==digest) (fail "retained image mismatch")
   pure bytes
  hash=T.pack . concatMap (\word->let hex=showHex word "" in replicate (2-length hex) '0'<>hex) . B.unpack . SHA.hash

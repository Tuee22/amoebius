{-# LANGUAGE OverloadedStrings #-}
-- | Literal comparisons independent of the product, producer and its registry.
module OracleTranscripts (oracleTranscriptChecks,oracleTranscriptNames) where
import OracleTranscriptExpected (transcriptExpected,transcriptLoci)
import Data.List (nub,sort)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import System.FilePath ((</>))
import Text.Read (readMaybe)
type Result=Either (Text,Text) (Text,Text,[(Text,Text,Text)],Text,Integer,Text,Text,Maybe Text)
oracleTranscriptNames :: [Text]
oracleTranscriptNames=["transcript.discovery","transcript.field-loci"]<>map (("transcript."<>).fst) transcriptExpected
oracleTranscriptChecks :: FilePath -> IO [(Text,Bool,Text)]
oracleTranscriptChecks directory = do
 input <- TIO.readFile (directory </> "oracle-transcripts.data")
 let supplied=readMaybe (T.unpack input) :: Maybe [(Text,Result)]
     observed=maybe [] id supplied
     names=map fst observed
     checks=[("transcript.discovery",length observed==length transcriptExpected && sort names==sort (map fst transcriptExpected) && length names==length (nub names))
       ,("transcript.field-loci",sort (nub [locus | (_,Left (_,locus))<-observed,locus/="inventory.declaration"])==sort transcriptLoci)]
       <> [("transcript."<>name,[result | (key,result)<-observed,key==name]==[wanted]) | (name,wanted)<-transcriptExpected]
 pure [(name,green,"independent supplied transcript comparison; no native authority") | (name,green)<-checks]

{-# LANGUAGE OverloadedStrings #-}
-- Independent reader for the public report's lossless row blocks. All semantic
-- expectations still consume the complete expanded rows and native source.
module ReportTransport (expandLayoutReport) where
import Codec.Compression.Zlib.Internal qualified as Zlib
import Control.Monad (foldM,replicateM,unless,when)
import Control.Monad.ST.Lazy (ST,runST)
import Crypto.Hash.SHA256 qualified as SHA
import Data.Binary.Get qualified as Get
import Data.ByteString qualified as Bytes
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Lazy qualified as LazyBytes
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Word (Word64)
import Numeric (showHex)
import Text.Read (readMaybe)

expandLayoutReport :: Text -> Either Text Text
expandLayoutReport input
  | not ("layout-packed-" `Text.isInfixOf` input) = Right input
  | not ("\n" `Text.isSuffixOf` input) = Left "PackedReportMissingFinalLF"
  | otherwise = Text.unlines . concat . reverse . snd <$> foldM expand (0,[]) (Text.lines input)
 where
  expand (used,groups) row
    | not ("layout-packed-" `Text.isPrefixOf` row) = do
        let size=fromIntegral (Bytes.length (Encoding.encodeUtf8 row))+1
        unless (size <= expandedLimit-used) (Left "PackedReportExpandedLimit")
        Right (used+size,[row]:groups)
    | otherwise = case Text.splitOn "\t" row of
        ["layout-packed-rows.v1","fields64be-gzip-base64.v1",rowCount,byteCount,claimed,payload] -> do
          expectedRows <- decimal rowCount
          expectedBytes <- decimal byteCount
          unless (expectedRows>0 && expectedBytes>0 && expectedRows<=expectedBytes
            && expectedBytes<=expandedLimit-used) (Left "PackedReportDeclaredLimit")
          compressed <- either (const (Left "PackedReportBase64")) Right (Base64.decode (Encoding.encodeUtf8 payload))
          unless (Base64.encode compressed==Encoding.encodeUtf8 payload) (Left "PackedReportNoncanonicalBase64")
          inflated <- inflate compressed
          expanded <- case Get.runGetOrFail (getRows (Bytes.length inflated) expectedBytes) (LazyBytes.fromStrict inflated) of
            Left (_,_,problem) | problem=="PackedReportPostimageMismatch" -> Left "PackedReportPostimageMismatch"
            Left _ -> Left "PackedReportFieldTable"
            Right (remaining,_,values) | LazyBytes.null remaining -> Right values
            Right _ -> Left "PackedReportTrailingTable"
          let original=Encoding.encodeUtf8 (Text.unlines expanded)
          unless (fromIntegral (length expanded)==expectedRows
            && fromIntegral (Bytes.length original)==expectedBytes
            && digest original==claimed) (Left "PackedReportPostimageMismatch")
          unless (all (not . Text.isPrefixOf "layout-packed-") expanded) (Left "PackedReportNestedBlock")
          Right (used+expectedBytes,expanded:groups)
        _ -> Left "PackedReportUnknownRecord"
  decimal text=case readMaybe (Text.unpack text) :: Maybe Word64 of
    Just value | Text.pack (show value)==text -> Right value
    _ -> Left "PackedReportNoncanonicalCount"

-- The independent reader bounds both the inflated table and the reconstructed
-- report. It consumes exactly one gzip member and refuses trailing bytes.
expandedLimit :: Word64
expandedLimit=512*1024*1024

inflate :: Bytes.ByteString -> Either Text Bytes.ByteString
inflate input=runST (walk 0 0 [] (Zlib.decompressST Zlib.gzipFormat
  Zlib.defaultDecompressParams {Zlib.decompressAllMembers=False}))
 where
  walk :: Int -> Word64 -> [Bytes.ByteString] -> Zlib.DecompressStream (ST s) -> ST s (Either Text Bytes.ByteString)
  walk stage size chunks stream=case stream of
    Zlib.DecompressInputRequired supply
      | stage==0 -> supply input >>= walk 1 size chunks
      | stage==1 -> supply Bytes.empty >>= walk 2 size chunks
      | otherwise -> pure (Left "PackedReportTruncatedGzip")
    Zlib.DecompressOutputAvailable chunk next ->
      let total=size+fromIntegral (Bytes.length chunk)
      in if total>expandedLimit then pure (Left "PackedReportInflatedLimit")
         else next >>= walk stage total (chunk:chunks)
    Zlib.DecompressStreamEnd remaining -> pure
      (if Bytes.null remaining then Right (Bytes.concat (reverse chunks)) else Left "PackedReportTrailingGzip")
    Zlib.DecompressStreamError _ -> pure (Left "PackedReportMalformedGzip")

getRows :: Int -> Word64 -> Get.Get [Text]
getRows available declaredBytes=do
  count<-boundedCount
  dictionary<-replicateM count $ do
    size<-boundedCount
    bytes<-Get.getByteString size
    text<-either (const (fail "field UTF-8")) pure (Encoding.decodeUtf8' bytes)
    when (Text.any (\character->character=='\n' || character=='\t') text) (fail "field separator")
    pure (text,fromIntegral size :: Word64)
  let names=map fst dictionary
  unless (not (null names) && names==Set.toAscList (Set.fromList names)) (fail "dictionary order or duplicate")
  let entries=Map.fromList (zip [0 :: Word64 ..] dictionary)
  rowCount<-boundedCount
  rows<-readRows entries declaredBytes rowCount []
  unless (Set.fromList (concatMap (Text.splitOn "\t") rows)==Set.fromList names) (fail "unused dictionary field")
  pure rows
 where
  -- A small table can reference one large field many times. Account for the
  -- complete UTF-8 postimage before concatenating any row, sharing the remaining
  -- declared budget across rows. The caller has already bounded this budget by
  -- the report's remaining expanded limit.
  readRows _ _ 0 found=pure (reverse found)
  readRows entries remaining count found=do
    fieldCount<-boundedCount
    when (fieldCount==0) (fail "empty field vector")
    beforeFields<-charge remaining 1
    (afterFields,fields)<-readFields entries beforeFields fieldCount True []
    let row=Text.intercalate "\t" (reverse fields)
    readRows entries afterFields (count-1) (row:found)
  readFields _ remaining 0 _ found=pure (remaining,found)
  readFields entries remaining count first found=do
    index<-Get.getWord64be
    (field,size)<-maybe (fail "field index") pure (Map.lookup index entries)
    beforeField<-if first then pure remaining else charge remaining 1
    afterField<-charge beforeField size
    readFields entries afterField (count-1) False (field:found)
  charge remaining size
    | size>remaining=fail "PackedReportPostimageMismatch"
    | otherwise=pure (remaining-size)
  boundedCount=do
    count<-Get.getWord64be
    unless (count<=fromIntegral available) (fail "count exceeds table")
    pure (fromIntegral count)

digest :: Bytes.ByteString -> Text
digest=Text.pack.concatMap (\byte->let hex=showHex byte "" in replicate (2-length hex) '0'<>hex).Bytes.unpack.SHA.hash

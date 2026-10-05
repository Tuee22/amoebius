{-# LANGUAGE OverloadedStrings #-}

-- | The rows the witnesses earn: the total @fits@ judged over every pair of three-valued
-- vectors against a predicate the oracle states itself, the names and refusals of a volume
-- witness, and the render of a StatefulSet and of a source that claims a volume it has no right
-- to. Every expectation is typed here from the contract; nothing is read from the product.
module DslCapacity
  ( capacityRows
  ) where

import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Maybe (fromMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslParse
import Numeric.Natural (Natural)
import System.FilePath ((</>))

capacityRows :: FilePath -> IO [Row]
capacityRows suite = do
  fits <- readRows (suite </> "fits.tsv")
  volumes <- readRows (suite </> "volumes.tsv")
  claims <- readRows (suite </> "claims.tsv")
  pure (fitsRows fits <> volumeRows volumes <> claimRows claims)

readRows :: FilePath -> IO (Maybe [[Text]])
readRows path = do
  text <- readText path
  pure (fmap (map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines) text)

-- | The three values an axis takes.
values :: [Natural]
values = [0, 1, 2]

natText :: Natural -> Text
natText = Text.pack . show

-- | What @fits@ must answer for a demand and a capacity: the first axis, in the order
-- processor, memory, ephemeral storage, pod slots, on which the demand exceeds the capacity, or
-- the capacity less the demand on every axis.
expectedFit :: [Natural] -> [Natural] -> Text
expectedFit demand capacity = case [(axis, d, c) | (axis, d, c) <- zip3 axes demand capacity, d > c] of
  (axis, d, c) : _ -> "over:" <> axis <> ":" <> natText d <> ":" <> natText c
  [] -> "ok:" <> Text.intercalate "," (zipWith (\d c -> natText (c - d)) demand capacity)
 where
  axes = ["CpuAxis", "MemoryAxis", "EphemeralStorageAxis", "PodSlotsAxis"]

fitsRows :: Maybe [[Text]] -> [Row]
fitsRows actual = case actual of
  Nothing -> [Row "fits.rows" False "the enumeration is absent or unreadable"]
  Just rows ->
    let parsed = [(map readNat (take 4 row), map readNat (take 4 (drop 4 row)), cell 8 row) | row <- rows, length row == 11]
        sums = [(demand, capacity, cell 9 row, cell 10 row) | row <- rows, length row == 11, let demand = map readNat (take 4 row), let capacity = map readNat (take 4 (drop 4 row))]
        grid = [(demand, capacity) | demand <- vectors, capacity <- vectors]
        vectors = [[a, b, c, d] | a <- values, b <- values, c <- values, d <- values]
        admitted = [() | (demand, capacity) <- grid, and (zipWith (<=) demand capacity)]
        exact = [(demand, capacity, result) | (demand, capacity, result) <- parsed, demand == capacity]
        several = [(demand, capacity, result) | (demand, capacity, result) <- parsed, length [() | (d, c) <- zip demand capacity, d > c] > 1]
     in [ check "fits.count" (length parsed == length rows && length rows == length values ^ (8 :: Int)) (Text.pack (show (length rows)))
        , check "fits.grid" (Set.fromList [(demand, capacity) | (demand, capacity, _) <- parsed] == Set.fromList grid && length parsed == length grid) "the enumeration is not every pair of three-valued vectors exactly once"
        , check "fits.verdicts" (and [result == expectedFit demand capacity | (demand, capacity, result) <- parsed]) "a verdict differs from the independent predicate"
        , check "fits.admitted-count" (length [() | (_, _, result) <- parsed, "ok:" `Text.isPrefixOf` result] == length admitted && length admitted == 1296) (Text.pack (show (length admitted)))
        , check "fits.exact-fit" (not (null exact) && and [result == "ok:0,0,0,0" | (_, _, result) <- exact]) "an exact fit is not an admission with nothing left"
        , check "fits.axis-order" (not (null several) && and [result == expectedFit demand capacity | (demand, capacity, result) <- several]) "a demand over several axes does not name the first"
        , check "fits.headroom" (and [result == "ok:" <> Text.intercalate "," (zipWith (\d c -> natText (c - d)) demand capacity) | (demand, capacity, result) <- parsed, and (zipWith (<=) demand capacity)]) "an admitted vector's headroom is not the capacity less the demand"
        , check "fits.sum" (length sums == length rows && and [total == Text.intercalate "," (zipWith (\d c -> natText (d + c)) demand capacity) | (demand, capacity, total, _) <- sums]) "a sum is not the componentwise sum of its two vectors"
        , check "fits.zero" (length sums == length rows && and [fromZero == Text.intercalate "," (map natText demand) | (demand, _, _, fromZero) <- sums]) "the zero vector is not the identity of the sum"
        ]
 where
  readNat text = fromMaybe 0 (readMaybeNat text)

-- | The nth cell of a row, or nothing at all.
cell :: Int -> [Text] -> Text
cell index row = case drop index row of
  text : _ -> text
  [] -> ""

readMaybeNat :: Text -> Maybe Natural
readMaybeNat text
  | not (Text.null text) && Text.all (\c -> c >= '0' && c <= '9') text = Just (fromIntegral (Text.foldl' (\acc c -> acc * 10 + toInteger (fromEnum c - 48)) (0 :: Integer) text))
  | otherwise = Nothing

-- | The names and refusals of a volume witness.
volumeRows :: Maybe [[Text]] -> [Row]
volumeRows actual = case actual of
  Nothing -> [Row "volume.table" False "the table is absent or unreadable"]
  Just rows ->
    let found = [(take 4 row, cell 4 row) | row <- rows, length row == 5]
        wanted =
          [ (["amoebius-minio", "member-0", "0", "10737418240"], "ok:data-member-0-0:amoebius-minio.member-0.pv-0")
          , (["amoebius-postgres", "member-2", "2", "8589934592"], "ok:data-member-2-2:amoebius-postgres.member-2.pv-2")
          , (["a-b", "c", "0", "1"], "ok:data-c-0:a-b.c.pv-0")
          , (["a", "b-c", "0", "1"], "ok:data-b-c-0:a.b-c.pv-0")
          , (["amoebius-minio", "member-0", "0", "0"], "refused:EmptyVolume")
          , (["amoebius.minio", "member-0", "0", "1"], "refused:NotAnIdentityLabel")
          , (["amoebius-minio", "member_0", "0", "1"], "refused:NotAnIdentityLabel")
          , (["", "member-0", "0", "1"], "refused:NotAnIdentityLabel")
          ]
        pvNames = [Text.takeWhileEnd (/= ':') result | (key, result) <- found, key `elem` [["a-b", "c", "0", "1"], ["a", "b-c", "0", "1"]]]
     in [ check "volume.table" (found == wanted) (Text.pack (show found))
        , check "volume.injective" (length pvNames == 2 && Set.size (Set.fromList pvNames) == 2) (Text.pack (show pvNames))
        , check "volume.size-explicit" (lookup ["amoebius-minio", "member-0", "0", "0"] found == Just "refused:EmptyVolume") "a volume of no size is not refused"
        ]

-- | The render of a StatefulSet that owns a volume, one that does not, and a Deployment that
-- claims one.
claimRows :: Maybe [[Text]] -> [Row]
claimRows actual = case actual of
  Nothing -> [Row "claims.table" False "the table is absent or unreadable"]
  Just rows ->
    let scenario name = [row | row <- rows, take 1 row == [name]]
        owned = scenario "statefulset-with-volume"
        bare = scenario "statefulset-without-volume"
        stolen = scenario "deployment-with-volume"
        identity = "objectstore/assets/member-0"
        specOf row = case drop 6 row of
          [text] -> eitherDecodeStrict' (Encoding.encodeUtf8 text) :: Either String Value
          _ -> Left "no spec"
     in [ check "claims.statefulset" (map (take 6) owned == [["statefulset-with-volume", "0", "StatefulSetKind", identity, "member-0", "kind-host-1"], ["statefulset-with-volume", "1", "PersistentVolumeClaimKind", identity <> "/pvc", "data-member-0-0", "none"]]) (Text.pack (show owned))
        , check "claims.claim-body" (case owned of
            [_, claim] -> case specOf claim of
              Right (Object spec) -> case KeyMap.lookup "contents" spec of
                Just (Object contents) -> KeyMap.lookup "claimBytes" contents == Just (Number 4096) && KeyMap.lookup "claimStorageClass" contents == Just (String "amoebius-retained") && KeyMap.lookup "claimVolumeName" contents == Just (String "amoebius-minio.member-0.pv-0") && KeyMap.lookup "claimOwner" contents == Just (String "member-0")
                _ -> False
              _ -> False
            _ -> False) "the claim's size, class, pre-bound volume, or owner is not the witness's"
        , check "claims.bare-statefulset" (map (take 6) bare == [["statefulset-without-volume", "0", "StatefulSetKind", identity, "member-0", "kind-host-1"]]) (Text.pack (show bare))
        , check "claims.pvc-without-statefulset" (stolen == [["deployment-with-volume", "refused", "PvcWithoutStatefulSet", identity]]) (Text.pack (show stolen))
        ]

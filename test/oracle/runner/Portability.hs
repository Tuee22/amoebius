{-# LANGUAGE OverloadedStrings #-}
-- | Product-free transport and bounded-discovery expectations.
module Portability (portabilityChecks, observerChecks) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as B
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)
import System.Directory (exeExtension, makeAbsolute)
import System.FilePath ((</>))
import Text.Read (readMaybe)

observerChecks :: FilePath -> IO [(Text, Bool, Text)]
observerChecks directory = do
  input <- TIO.readFile (directory </> "observer.tsv")
  let rows = map (T.splitOn "\t") (T.lines input)
      base = [("executable", "/subject"), ("argv", "[\"a b\",\"c\"]"), ("cwd", "/work"), ("environment-policy", "policy:a")
        ,("exit", "ExitSuccess"), ("stdout-sha256", digest "λ\n"), ("stderr-sha256", digest ""), ("stdout-bytes", "3")]
      replace key value = map (\(k, v) -> (k, if key == k then value else v)) base
      cases = [("base", base), ("argv", replace "argv" "[\"a\",\"b c\"]"), ("policy", replace "environment-policy" "policy:b")
        ,("spawn", base <> [("spawn-failure", "failed")]), ("executable", replace "executable" "/other")
        ,("cwd", replace "cwd" "/elsewhere"), ("exit", replace "exit" "ExitFailure 23")
        ,("stdout", [(key, if key == "stdout-sha256" then digest "different" else if key == "stdout-bytes" then "9" else value) | (key, value) <- base])
        ,("stderr", replace "stderr-sha256" (digest "error"))]
      observed name = case [(fields, hash) | [key, fields, hash] <- rows, key == name] of
        [(fields, hash)] -> (readMaybe (T.unpack fields) :: Maybe [(Text, Text)], hash)
        _ -> (Nothing, "missing-or-duplicate")
      checks (name, fields) =
        let (actual, hash) = observed name
            wantedHash = digest (T.pack (show fields))
            wantedFields = [("process." <> key, value) | (key, value) <- fields] <> [("process.digest", wantedHash)]
         in [("observer." <> name <> ".fields", actual == Just wantedFields, T.pack (show actual))
            ,("observer." <> name <> ".digest", hash == wantedHash, hash)]
  pure (("observer.discovery", sort [name | name : _ <- rows] == sort (map fst cases) && length rows == length cases, T.pack (show rows))
    : concatMap checks cases)
 where
  digest = T.pack . concatMap (\byte -> let digits = showHex byte "" in if length digits == 1 then '0' : digits else digits) . B.unpack . SHA256.hash . Encoding.encodeUtf8

portabilityChecks :: FilePath -> IO [(Text, Bool, Text)]
portabilityChecks output = do
  absolute <- makeAbsolute output
  contents <- TIO.readFile (output </> "portability.tsv")
  let rows = map (T.splitOn "\t") (T.lines contents)
      value kind name = case [observed | [k, n, observed] <- rows, k == kind, n == name] of
        [observed] -> observed
        _ -> "missing-or-duplicate-row"
      expected =
        [ ("delegate", "sibling", "(ExitFailure 23,\"child stdout\\n\",\"child stderr\\n\")")
        , ("delegate", "path", "(ExitSuccess,\"child stdout\\n\",\"child stderr\\n\")")
        , ("delegate", "missing", "(ExitFailure 2,\"\",\"amoebius validate: the verifier executable amoebius-validate is neither beside amoebius nor on PATH\\n\")")
        , ("child", "sibling", child "sibling" 23 (absolute </> "sibling"))
        , ("child", "path", child "path" 0 (absolute </> "search-path"))
        , ("child", "missing", "absent")
        , ("filename", "posix", "amoebius-validate")
        , ("filename", "windows", "amoebius-validate.exe")
        , ("discovery", "exact", "[]")
        , ("discovery", "over", "[(\"DOC-DISCOVERY-DIRECTORY-ENTRY-LIMIT\",\"documents\")]")
        , ("discovery", "teardown", "True")
        ]
      child name code selected =
        let directory = absolute </> name
            arguments = [directory </> "child.data", show (code :: Int), "space in argument", "λ", "", "$(literal)", "--option=value"]
        in T.pack (show (selected </> ("amoebius-validate" <> exeExtension), arguments, directory, Just ("opaque value λ" :: String), "opaque stdin\n" :: String))
  pure (("portability.discovery", sort [(kind, name) | [kind, name, _] <- rows] == sort [(kind, name) | (kind, name, _) <- expected]
      && length rows == length expected, T.pack (show rows))
    : [("portability." <> kind <> "." <> name, value kind name == wanted, value kind name) | (kind, name, wanted) <- expected])

{-# LANGUAGE OverloadedStrings #-}

-- | The independent judge of the @decoded-lowering@ legacy binding (LTD-DSL-001). It reads the
-- observation table the shipped stages produced and the example bytes they were given, and
-- compares them with literals typed here. It imports no product module and states every
-- expected value itself.
module DslLowering (loweringRows) where

import Control.Exception (SomeException, try)
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslParse (Row (..), check)
import System.FilePath ((</>))

-- | The authored application identity of the baseline example, spelled from the contract.
authoredIdentity :: Text
authoredIdentity = "notes-0b5e17e11a0c0ffee0de1e9a7e5ba5ed"

-- | Every (key, role, expected value) the subject must report.
expected :: [(Text, Text, Text)]
expected =
  [ ("lowering-bypassed", "positive", "True")
  , ("lowering-bypassed", "negative", "UnknownDeployment")
  , ("nonce-discarded", "positive", "True")
  , ("nonce-discarded", "negative", "False")
  , ("control", "baseline", "lowered")
  , ("control", "nonce-run", "lowered")
  , ("control", "sentinel-absent-from-nonce-dump", "True")
  ]

readText :: FilePath -> IO (Maybe Text)
readText path = do
  attempt <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  pure (either (const Nothing) (either (const Nothing) Just . Encoding.decodeUtf8') attempt)

-- | The ledger rows for one suite directory.
loweringRows :: FilePath -> IO [Row]
loweringRows directory = do
  table <- readText (directory </> "decoded-lowering.tsv")
  example <- readText (directory </> "examples" </> "kind-single-objectstore.dhall")
  let rows = maybe [] (map (Text.splitOn "\t") . Text.lines) table
      observed key role = [value | [name, control, value] <- rows, name == key, control == role]
      inventory = sort [(key, role) | (key, role, _) <- expected]
      reported = sort [(key, role) | [key, role, _] <- rows]
      judged key role wanted = check ("decoded-lowering." <> key <> "." <> role) (observed key role == [wanted]) (Text.pack (show (observed key role)))
      authoredBytes = maybe False (Text.isInfixOf authoredIdentity) example
  pure $
    check "decoded-lowering.discovery" (inventory == reported && all ((== 3) . length) rows) "the closed case inventory"
      : [judged key role wanted | (key, role, wanted) <- expected, key /= "control"]
      <> [ check "decoded-lowering.control.complete"
             (observed "control" "baseline" == ["lowered"] && authoredBytes && observed "control" "nonce-run" == ["lowered"] && observed "control" "sentinel-absent-from-nonce-dump" == ["True"])
             "the baseline and the nonce run lowered, the authored bytes carry the identity, and the sentinel does not survive a rewrite"
         ]

{-# LANGUAGE OverloadedStrings #-}

-- | The observations behind the @decoded-lowering@ legacy binding (LTD-DSL-001). Each row is
-- @key, role, value@ and states what the shipped stages did: it decides nothing. The
-- independent oracle owns every expected value.
--
-- * @lowering-bypassed@ — the lowered deployment is a function of the decoded specification:
--   the authored application identity reaches the lowered dump, and a specification whose
--   deployment names an application that does not exist is refused at lowering.
-- * @nonce-discarded@ — a nonce substituted into the authored text after the run starts
--   reaches the lowered dump and the authored sentinel does not survive; a nonce that was
--   never authored is absent.
module SpineLowering (decodedLoweringSection) where

import Amoebius.Dsl.Decode (decodeRefusalTag, decodeRoot)
import Amoebius.Dsl.Examples.Spine (Example (..), exampleNamed, renderExampleFiles, sentinel)
import Amoebius.Dsl.Import (freezeText, importRefusalTag)
import Amoebius.Dsl.Lower (dumpLowered, lowerDeployment, lowerRefusalTag)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

-- | A nonce no example authors.
runNonce :: Text
runNonce = "5eed5eed5eed5eed5eed5eed5eed5eed"

-- | An unauthored nonce, absent from every dump by construction.
absentNonce :: Text
absentNonce = "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4"

-- | Freeze, decode and lower one authored text; the outcome is the dump or the refusal tag.
lowerText :: FilePath -> Text -> IO (Either Text Text)
lowerText directory source = do
  frozen <- freezeText directory source
  pure $ case frozen of
    Left refusal -> Left ("frozen:" <> importRefusalTag refusal)
    Right ready -> case decodeRoot ready of
      Left refusal -> Left ("decoded:" <> decodeRefusalTag refusal)
      Right root -> case lowerDeployment root of
        Left refusal -> Left (lowerRefusalTag refusal)
        Right lowered -> Right (dumpLowered lowered)

-- | Write the observation table @decoded-lowering.tsv@ beneath the given directory.
decodedLoweringSection :: FilePath -> IO ()
decodedLoweringSection suite = do
  mapM_
    (\(path, contents) -> do
        createDirectoryIfMissing True (takeDirectory (suite </> path))
        ByteString.writeFile (suite </> path) (Encoding.encodeUtf8 contents))
    renderExampleFiles
  let examples = suite </> "examples"
      authored name = maybe "" exampleText (exampleNamed name)
      baseline = authored "kind-single-objectstore"
      substituted = Text.replace sentinel runNonce baseline
      boolean = Text.pack . show
  plain <- lowerText examples baseline
  noncey <- lowerText examples substituted
  ghost <- lowerText examples (authored "unknown-deployment")
  let appIdentity = "notes-" <> sentinel
      contains needle = either (const False) (Text.isInfixOf needle)
      outcome = either id (const "lowered")
  writeRows
    (suite </> "decoded-lowering.tsv")
    [ ["lowering-bypassed", "positive", boolean (contains appIdentity plain)]
    , ["lowering-bypassed", "negative", outcome ghost]
    , ["nonce-discarded", "positive", boolean (contains runNonce noncey && not (contains sentinel noncey))]
    , ["nonce-discarded", "negative", boolean (contains absentNonce noncey)]
    , ["control", "baseline", outcome plain]
    , ["control", "nonce-run", outcome noncey]
    , ["control", "sentinel-absent-from-nonce-dump", boolean (not (contains sentinel noncey))]
    ]
 where
  writeRows path rows = do
    createDirectoryIfMissing True (takeDirectory path)
    ByteString.writeFile path (Encoding.encodeUtf8 (Text.unlines (map (Text.intercalate "\t") rows)))

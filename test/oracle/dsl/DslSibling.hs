{-# LANGUAGE OverloadedStrings #-}

-- Independent source, input and refusal observations for a rebuilt catalog.
-- Hashes here describe source/build artifacts, not toolchain admission pins.
module DslSibling (sourceSiblingRows) where

import Control.Monad (guard)
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslBinarySubstrates (normal, field, textAt, listAt, one, unionTag)
import DslExtensionContract (siblingModule, siblingBinding, siblingWitnessFields)
import DslParse
import System.FilePath ((</>))

sourceSiblingRows :: FilePath -> IO [Row]
sourceSiblingRows suite = do
  let root = suite </> "binary"
      subject = "src/extension-link/Amoebius/Extension/Linked.hs"
  input <- readBytes (root </> "input/root.dhall")
  before <- readBytes subject
  after <- readBytes (root </> "sibling/tree" </> subject)
  witness <- readTable (root </> "sibling/witness.tsv")
  refusal <- readText (root </> "sibling/compiled/refusal.tsv")
  let entries = [(key, value) | [key, value] <- maybe [] id witness]
      values = Map.fromList entries
      get key = Map.lookup key values
      nonce = input >>= either (const Nothing) inputNonce . Encoding.decodeUtf8'
      hex value = Text.length value == 64 && Text.all (\c -> c >= '0' && c <= '9' || c >= 'a' && c <= 'f') value
      unequal left right = get left /= Nothing && get right /= Nothing && get left /= get right
      sourceDiff = Text.pack (show ("-linkedExtensions = [jitBuild, coordination, infernix, jitml]\n+linkedExtensions = []" :: Text))
      refused = do
        challenge <- nonce
        record <- refusal
        case Text.splitOn "\t" (Text.stripEnd record) of
          ["UnboundCapability", "lower", detail] -> Just
            (detail == "LowerFailed (LinkRefused (UnboundApplicationNeed "
              <> Text.pack (show ("notes-" <> challenge)) <> " "
              <> Text.pack (show ("engine-" <> challenge))
              <> " (ServiceCapability InferenceEngine)))")
          _ -> Just False
      judgments =
        [check "binary.extensions.source-sibling.complete-witness"
          (length entries == length (maybe [] id witness) && Map.size values == length entries && sort (Map.keys values) == sort siblingWitnessFields)
          "missing, repeated or unexpected witness field",
         check "binary.extensions.source-sibling.source-change"
          (get "module" == Just siblingModule && get "binding" == Just siblingBinding && get "operator" == Just "list-truncation"
           && get "source-before" == (sha256Hex <$> before) && get "source-after" == (sha256Hex <$> after)
           && before /= Nothing && after /= Nothing && unequal "source-before" "source-after" && get "source-diff" == Just sourceDiff
           && maybe False (elem "linkedExtensions = []" . Text.lines . Encoding.decodeUtf8) after)
          "the observed catalog did not undergo the declared source edit",
         check "binary.extensions.source-sibling.binary-change"
          (maybe False hex (get "binary-before") && maybe False hex (get "binary-after") && unequal "binary-before" "binary-after")
          "the build did not supply two distinct observed binary identities",
         check "binary.extensions.source-sibling.same-input"
          (nonce /= Nothing && get "nonce" == nonce && input /= Nothing && get "input-before" == (sha256Hex <$> input) && get "input-after" == get "input-before")
          "the sibling did not consume the same nonce-bearing input",
         check "binary.extensions.source-sibling.refusal" (refused == Just True) "expected UnboundCapability at the exact app and need"]
  pure (judgments <> [check "binary.extensions.source-sibling.unbound-exact-app-need" (all rowGreen judgments) "the source/build/input/refusal boundary is incomplete"])

inputNonce :: Text -> Maybe Text
inputNonce source = do
  root <- normal source
  app <- listAt "rootApps" root >>= one
  name <- textAt "appName" app
  nonce <- Text.stripPrefix "notes-" name
  guard (Text.length nonce == 32 && Text.all (\c -> c >= '0' && c <= '9' || c >= 'a' && c <= 'f') nonce)
  needs <- listAt "needs" app
  inference <- one [need | need <- needs, maybe False (unionTag "InferenceEngine") (field "needCapability" need)]
  guard (textAt "needName" inference == Just ("engine-" <> nonce))
  pure nonce

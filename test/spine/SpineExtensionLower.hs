{-# LANGUAGE OverloadedStrings #-}

-- Observe the shipped lowering path over the product-owned input values.
module SpineExtensionLower (extensionLowerSection) where

import Amoebius.Dsl.Decode (decodeRoot)
import Amoebius.Dsl.Encode (encodeRaw)
import Amoebius.Dsl.Examples.Extensions (loweringInputs)
import Amoebius.Dsl.Import (freezeText)
import Amoebius.Dsl.Lower
import Amoebius.Extension.Linked qualified as Linked
import Amoebius.Extension.Spec (extId)
import Amoebius.Vocabulary (extensionIdText)
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

extensionLowerSection :: FilePath -> IO ()
extensionLowerSection directory = do
  inputs <- either (fail . Text.unpack) pure loweringInputs
  createDirectoryIfMissing True directory
  outcomes <- mapM observe inputs
  Text.writeFile (directory </> "outcomes.tsv") (Text.unlines outcomes)
 where
  observe (name, input) = do
    let output = directory </> Text.unpack name
    createDirectoryIfMissing True output
    frozen <- freezeText output (encodeRaw input)
    value <- either (fail . show) pure frozen
    root <- either (fail . show) pure (decodeRoot value)
    case lowerDeployment root of
      Left problem -> do
        Text.writeFile (output </> "refusal.tsv") (lowerRefusalTag problem <> "\t" <> Text.pack (show problem) <> "\n")
        pure (name <> "\t" <> lowerRefusalTag problem)
      Right lowered -> do
        Text.writeFile (output </> "lowered.dump") (dumpLowered lowered)
        Text.writeFile (output </> "proofs.tsv") (Text.unlines
          [Text.intercalate "\t" [Linked.bindingIssuer proof, Linked.bindingApplication proof, Linked.bindingNeed proof]
           | proof <- Map.elems (loweredProofs lowered)])
        Text.writeFile (output </> "extensions.tsv") (Text.unlines
          [extensionIdText (extId specification) | (specification, _) <- loweredExtensions lowered])
        pure (name <> "\taccepted")

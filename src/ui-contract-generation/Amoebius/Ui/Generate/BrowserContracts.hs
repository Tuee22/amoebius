{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Generate.BrowserContracts
  ( ContractRow (..)
  , browserArtifacts
  , contractInventory
  , writeBrowserArtifacts
  ) where

import Amoebius.Ui.Source qualified as Source
import Control.Monad (forM_)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>), takeDirectory)

data ContractRow = ContractRow
  { contractKind :: Text
  , contractName :: Text
  , contractCodec :: Text
  , contractVisibility :: Text
  }
  deriving stock (Eq, Ord, Show)

contractInventory :: [ContractRow]
contractInventory = valueRows <> clientPlanFields <> transitionFields
  where
    valueRows = map valueRow publicValueTypes

publicValueTypes :: [Source.ValueType]
#ifdef UI_CONTRACT_GENERATION_SERIALIZE_SERVER_HANDLE_MUTANT
publicValueTypes = [minBound .. maxBound]
#else
publicValueTypes = filter (/= Source.ServerHandle) [minBound .. maxBound]
#endif

valueRow :: Source.ValueType -> ContractRow
valueRow value = ContractRow "value" (Text.pack (show value)) (valueCodec value) "public"

valueCodec :: Source.ValueType -> Text
valueCodec value = case value of
  Source.Text -> "string"
  Source.Natural -> "natural"
  Source.Boolean -> "boolean"
  Source.View -> "string"
  Source.TenantChoice -> "string"
  Source.WorkflowStart -> "string"
  Source.WorkflowProgress -> "string"
  Source.ServerHandle -> "opaque-handle"

clientPlanFields :: [ContractRow]
clientPlanFields =
  [ publicField "client-plan" "abi" "string"
  , publicField "client-plan" "events" "array-string"
  , publicField "client-plan" "links" "array-string"
  , publicField "client-plan" "routes" "array-string"
  ]
#ifdef UI_CONTRACT_GENERATION_UNDECLARED_CODEC_MUTANT
  <> [publicField "client-plan" "providerCoordinate" "string"]
#endif

transitionFields :: [ContractRow]
transitionFields =
  [ publicField "transition" "visibleState" "string"
  , publicField "transition" "effect" "string"
  , publicField "transition" "cancelled" "boolean"
  , publicField "transition" "route" "string"
  , publicField "transition" "focus" "string"
  ]
#ifdef UI_CONTRACT_GENERATION_RAW_SINK_MUTANT
  <> [publicField "transition" "rawHtml" "string"]
#endif

publicField :: Text -> Text -> Text -> ContractRow
publicField kind name codec = ContractRow kind name codec "public"

browserArtifacts :: [(FilePath, Text)]
browserArtifacts =
  [ ("Amoebius/Ui/Generated/Contracts.purs", renderContracts)
  , ("Amoebius/Ui/Generated/Codecs.purs", renderCodecs)
  , ("GeneratedBundleMain.purs", renderBundleRecipe)
  ]

writeBrowserArtifacts :: FilePath -> IO ()
writeBrowserArtifacts root = forM_ browserArtifacts $ \(relative, body) -> do
  let target = root </> relative
  createDirectoryIfMissing True (takeDirectory target)
  Text.writeFile target body

renderContracts :: Text
renderContracts = Text.unlines
  [ "module Amoebius.Ui.Generated.Contracts"
  , "  ( PublicValueType(..)"
  , "  , ClientPlan"
  , "  , Transition"
  , "  , contractRuntimeAbi"
  , "  ) where"
  , ""
  , "import Prelude"
  , ""
  , "data PublicValueType"
  , "  = " <> Text.intercalate "\n  | " (map (("Public" <>) . contractName) valueRows)
  , ""
  , "derive instance eqPublicValueType :: Eq PublicValueType"
  , ""
  , "type ClientPlan ="
  , renderRecord (filter ((== "client-plan") . contractKind) contractInventory)
  , ""
  , "type Transition ="
  , renderRecord (filter ((== "transition") . contractKind) contractInventory)
  , ""
  , "contractRuntimeAbi :: String"
  , "contractRuntimeAbi = \"ui-client-v1\""
  ]
  where
    valueRows = filter ((== "value") . contractKind) contractInventory

renderRecord :: [ContractRow] -> Text
renderRecord rows = "  { " <> Text.intercalate "\n  , " (map renderField rows) <> "\n  }"
  where
    renderField row = contractName row <> " :: " <> purescriptType (contractCodec row)

purescriptType :: Text -> Text
purescriptType codec = case codec of
  "boolean" -> "Boolean"
  "natural" -> "Int"
  "array-string" -> "Array String"
  "opaque-handle" -> "String"
  _ -> "String"

renderCodecs :: Text
renderCodecs = Text.unlines
  [ "module Amoebius.Ui.Generated.Codecs (codecForField) where"
  , ""
  , "import Data.Maybe (Maybe(..))"
  , ""
  , "codecForField :: String -> Maybe String"
  , "codecForField field = case field of"
  ] <> Text.concat (map renderCase contractInventory) <> "  _ -> Nothing\n"
  where
    renderCase row = "  \"" <> contractKind row <> "." <> contractName row <> "\" -> Just \""
      <> contractCodec row <> "\"\n"

renderBundleRecipe :: Text
renderBundleRecipe = Text.unlines
  [ "module GeneratedBundleMain where"
  , ""
  , "import Prelude"
  , ""
  , "import Amoebius.Ui.Generated.Contracts (contractRuntimeAbi)"
  , "import Effect (Effect)"
  , "import Effect.Console (log)"
  , "import Main as Runtime"
  , ""
  , "main :: Effect Unit"
  , "main = do"
  , "  log (\"amoebius-generated-contracts:\" <> contractRuntimeAbi)"
  , "  Runtime.main"
  ]

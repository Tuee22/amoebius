{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.Decode
  ( decodeCluster
  ) where

import Amoebius.Dsl.Error (DecodeError (..))
import Amoebius.Vault.SecretRef (SecretRef, promptRef, transitKeyRef, vaultSecretRef)
import Amoebius.Dsl.Decision (distinctHostIds)
import Amoebius.Dsl.SmartConstructors
  ( mkDaemonSetUnit
  , mkComputeHeadroom
  , mkDeploymentUnit
  , mkHostProcessUnit
  , mkJobUnit
  , mkPositiveReplicated
  , mkStatefulSetUnit
  )
import Amoebius.Dsl.Types
  ( ClusterIR (ClusterIR)
  , Cardinality (..)
  , DeploymentProgress (..)
  , ExecutionIdentity (ExecutionIdentity)
  , SomeExecutionUnit (SomeExecutionUnit)
  , StructuralNode (StructuralNode)
  , Surface (..)
  , ResourceArm (..)
  , ResourceEnvelope (..)
  )
import Control.DeepSeq (force)
import Control.Exception (SomeException, bracket, displayException, evaluate, try)
import Control.Monad (foldM)
import Data.Foldable qualified as Foldable
import Data.List (find, isPrefixOf, isSuffixOf)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Data.Void (Void)
import Dhall qualified
import Dhall.Core
  ( Chunks (..)
  , Directory (..)
  , Expr (..)
  , FieldSelection (..)
  , File (..)
  , FilePrefix (..)
  , Import (..)
  , ImportHashed (..)
  , ImportMode (..)
  , ImportType (..)
  , RecordField (..)
  )
import Dhall.Core qualified as Core
import Dhall.Map qualified as DhallMap
import Dhall.Import qualified as DhallImport
import Dhall.Parser qualified as DhallParser
import GHC.Generics (Generic)
import Numeric.Natural (Natural)
import System.Directory (canonicalizePath, doesFileExist, getHomeDirectory, getTemporaryDirectory, makeAbsolute, removeFile)
import System.FilePath ((</>), joinPath, takeDirectory)
import System.IO (hClose, openTempFile)
import Text.Read (readMaybe)

data RawNode = RawNode
  { path :: [Text]
  , kind :: Text
  , value :: Text
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RawDecoded = RawDecoded
  { semanticHash :: Text
  , surface :: Text
  , nodes :: [RawNode]
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

-- | Decode, normalize, refine and deeply force a Gate-1 value.  Every thrown
-- parser/type/import/IO exception is caught at this boundary.
decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)
decodeCluster file = do
  attempted <- try (decodeClusterUnchecked file)
  case attempted of
    Left exception -> pure (Left (DhallFailure (Text.pack (displayException (exception :: SomeException)))))
    Right decoded -> pure decoded

decodeClusterUnchecked :: FilePath -> IO (Either DecodeError ClusterIR)
decodeClusterUnchecked file = do
  absoluteFile <- makeAbsolute file
  source <- Text.readFile absoluteFile
  importVerdict <- validateImportGraph Set.empty absoluteFile source
  case importVerdict of
    Left rejected -> pure (Left rejected)
    Right _ -> do
      -- Importing the file as the expression gives Dhall the correct path root,
      -- resolves all local imports, type-checks, and returns a normalized tree.
      expression <- Dhall.inputExpr (Text.pack absoluteFile)
      let canonical = Core.pretty expression
          digest = DhallImport.hashExpressionToCode (Core.denote expression)
          structural = flattenExpression [] expression
      case classifySurface structural of
        Left problem -> pure (Left problem)
        Right surfaceValue -> do
          raw <- inputStructuralTable digest surfaceValue structural
          let retained = fmap toStructuralNode (nodes raw)
          case refineSecretRefs retained >> refineExecutions retained of
            Left problem -> pure (Left problem)
            Right executions -> do
              let ir = ClusterIR surfaceValue (semanticHash raw) canonical retained executions
              forced <- evaluate (force ir)
              pure (Right forced)

validateImportGraph :: Set.Set FilePath -> FilePath -> Text -> IO (Either DecodeError (Set.Set FilePath))
validateImportGraph visited sourcePath source
  | sourcePath `Set.member` visited = pure (Right visited)
  | otherwise = case DhallParser.exprFromText sourcePath source of
      Left _ -> pure (Right (Set.insert sourcePath visited))
      Right parsed ->
        foldM
          (validateImport sourcePath)
          (Right (Set.insert sourcePath visited))
          (Foldable.toList parsed)

validateImport :: FilePath -> Either DecodeError (Set.Set FilePath) -> Import -> IO (Either DecodeError (Set.Set FilePath))
validateImport _ failure@(Left _) _ = pure failure
validateImport sourcePath (Right visited) Import {importHashed = ImportHashed {importType}, importMode} =
  case importType of
    Remote _ -> pure (Left (ForbiddenImport "http(s):"))
    Env _ -> pure (Left (ForbiddenImport "env:"))
    Missing -> pure (Right visited)
    Local prefix localFile -> case importMode of
      Code -> do
          dependency <- localImportPath sourcePath prefix localFile
          exists <- doesFileExist dependency
          if exists
            then do
              canonical <- canonicalizePath dependency
              contents <- Text.readFile canonical
              validateImportGraph visited canonical contents
            else pure (Right visited)
      _ -> pure (Right visited)

localImportPath :: FilePath -> FilePrefix -> File -> IO FilePath
localImportPath sourcePath prefix File {directory = Directory components, file} = do
  homeDirectory <- getHomeDirectory
  let relative = joinPath (fmap Text.unpack (reverse components <> [file]))
      sourceDirectory = takeDirectory sourcePath
  pure $ case prefix of
    Absolute -> "/" </> relative
    Here -> sourceDirectory </> relative
    Parent -> sourceDirectory </> ".." </> relative
    Home -> homeDirectory </> relative

flattenExpression :: [Text] -> Expr source Void -> [StructuralNode]
flattenExpression current expression = case expression of
  RecordLit fields ->
    StructuralNode current "Record" (Text.pack (show (length entries)))
      : concatMap flattenField entries
   where
    entries = DhallMap.toList fields
    flattenField (label, RecordField {recordFieldValue}) = flattenExpression (current <> [label]) recordFieldValue
  ListLit _ values ->
    StructuralNode current "List" (Text.pack (show (length elements)))
      : concatMap flattenElement (zip [0 :: Int ..] elements)
   where
    elements = Foldable.toList values
    flattenElement (index, element) = flattenExpression (current <> ["[" <> Text.pack (show index) <> "]"]) element
  Some valueExpression -> StructuralNode current "Optional" "Some" : flattenExpression (current <> ["Some"]) valueExpression
  App None _ -> [StructuralNode current "Optional" "None"]
  App constructor payload
    | Just arm <- unionArm constructor ->
        StructuralNode current "Union" arm : flattenExpression (current <> [arm]) payload
  constructor
    | Just arm <- unionArm constructor -> [StructuralNode current "Union" arm]
  TextLit (Chunks [] literal) -> [StructuralNode current "Text" literal]
  BoolLit boolean -> [StructuralNode current "Bool" (if boolean then "True" else "False")]
  NaturalLit natural -> [StructuralNode current "Natural" (Text.pack (show natural))]
  IntegerLit integer -> [StructuralNode current "Integer" (Text.pack (show integer))]
  BytesLit bytes -> [StructuralNode current "Bytes" (Text.pack (show bytes))]
  DoubleLit number -> [StructuralNode current "Double" (Text.pack (show number))]
  _ -> [StructuralNode current "NormalizedExpr" (Core.pretty expression)]

unionArm :: Expr source Void -> Maybe Text
unionArm expression = case expression of
  Field (Union _) FieldSelection {fieldSelectionLabel} -> Just fieldSelectionLabel
  _ -> Nothing

classifySurface :: [StructuralNode] -> Either DecodeError Surface
classifySurface structural
  | requiredDeployment `Set.isSubsetOf` topFields = Right DeploymentSurface
  | requiredCluster `Set.isSubsetOf` topFields = Right ClusterSurface
  | requiredApp `Set.isSubsetOf` topFields = Right AppSurface
  | otherwise = Left (SchemaMismatch "top-level value is not Cluster.Type, App.Type, or Deployment.Type")
 where
  topFields = Set.fromList [field | StructuralNode [field] _ _ <- structural]
  requiredDeployment = Set.fromList ["cluster", "app", "transition", "monitoring"]
  requiredCluster = Set.fromList ["name", "substrate", "servers", "agents", "ingress", "capacity"]
  requiredApp = Set.fromList ["name", "capabilities", "storage", "topic", "workloads", "image", "build"]

inputStructuralTable :: Text -> Surface -> [StructuralNode] -> IO RawDecoded
inputStructuralTable digest surfaceValue structural =
  withTemporaryDhall (renderStructuralTable digest surfaceValue structural) (Dhall.inputFile Dhall.auto)

withTemporaryDhall :: Text -> (FilePath -> IO result) -> IO result
withTemporaryDhall contents action = do
  temporaryDirectory <- getTemporaryDirectory
  bracket (openTempFile temporaryDirectory "amoebius-gate2.dhall") closeAndRemove use
 where
  closeAndRemove (pathName, handle) = do
    _ <- try (hClose handle) :: IO (Either SomeException ())
    removeFile pathName
  use (pathName, handle) = do
    Text.hPutStr handle contents
    hClose handle
    action pathName

renderStructuralTable :: Text -> Surface -> [StructuralNode] -> Text
renderStructuralTable digest surfaceValue structural =
  "{ semanticHash = " <> quote digest
    <> ", surface = " <> quote (surfaceName surfaceValue)
    <> ", nodes = " <> renderList (fmap renderNode structural)
    <> " }"

surfaceName :: Surface -> Text
surfaceName surfaceValue = case surfaceValue of
  ClusterSurface -> "Cluster"
  AppSurface -> "App"
  DeploymentSurface -> "Deployment"

renderNode :: StructuralNode -> Text
renderNode (StructuralNode nodePath nodeKind nodeValue) =
  "{ path = " <> renderPath nodePath
    <> ", kind = " <> quote nodeKind
    <> ", value = " <> quote nodeValue
    <> " }"

renderList :: [Text] -> Text
renderList values = "[ " <> Text.intercalate ", " values <> " ]"

renderPath :: [Text] -> Text
renderPath nodePath = case nodePath of
  [] -> "[] : List Text"
  _ -> renderList (fmap quote nodePath)

quote :: Text -> Text
quote valueText = "\"" <> Core.escapeText valueText <> "\""

toStructuralNode :: RawNode -> StructuralNode
toStructuralNode RawNode {path, kind, value} = StructuralNode path kind value

-- | The label a sensitive field carries.  One name, so the rule is decidable
-- from the structural tree alone and does not need a per-surface schema walk.
sensitiveLabel :: Text
sensitiveLabel = "secretRef"

-- | Refine every sensitive field into the shared 'SecretRef'.
--
-- Gate 1 already gives a @Text@ no inhabitant where the field is *typed*
-- @SecretRef@.  This is the decoder's independent half: it decides the same
-- question from the decoded value, so a config that never reached for the type
-- is rejected too.  It stays pure — whether the named secret exists is a live
-- question answered at admission, not here.
refineSecretRefs :: [StructuralNode] -> Either DecodeError [SecretRef]
refineSecretRefs structural = traverse refine sensitiveNodes
 where
  sensitiveNodes =
    [ (nodePath, nodeKind, nodeValue)
    | StructuralNode nodePath nodeKind nodeValue <- structural
    , Just (_, label) <- [unsnoc nodePath]
    , label == sensitiveLabel
    ]

  refine (nodePath, "Union", arm) = build nodePath arm
  refine (nodePath, nodeKind, _) =
    Left
      ( PlaintextSecret
          ( render nodePath
              <> " holds a "
              <> nodeKind
              <> " value; a sensitive field carries a SecretRef, never a secret"
          )
      )

  build nodePath arm = case arm of
    "Vault" -> do
      mount <- payload nodePath arm "mount"
      path <- payload nodePath arm "path"
      field <- payload nodePath arm "field"
      admit nodePath (vaultSecretRef mount path field)
    "TransitKey" -> do
      name <- payload nodePath arm "name"
      admit nodePath (transitKeyRef name)
    "Prompt" -> do
      name <- payload nodePath arm "name"
      purpose <- payload nodePath arm "purpose"
      admit nodePath (promptRef name purpose)
    _ -> Left (OutOfDomainArm (render nodePath <> " names no SecretRef arm: " <> arm))

  payload nodePath arm name =
    case [value | StructuralNode candidate "Text" value <- structural, candidate == nodePath <> [arm, name]] of
      [value] -> Right value
      _ -> Left (SchemaMismatch (render nodePath <> " SecretRef." <> arm <> " has no " <> name <> " field"))

  admit nodePath = either (Left . SchemaMismatch . (\reason -> render nodePath <> ": " <> reason)) Right

  render nodePath = Text.intercalate "." nodePath

refineExecutions :: [StructuralNode] -> Either DecodeError [SomeExecutionUnit]
refineExecutions structural = do
  rejectZeroDomain structural
  rejectZeroProgress structural
  rejectReusedRke2Host structural
  traverse (refineExecution structural) (executionControllers structural)

executionControllers :: [StructuralNode] -> [([Text], Text)]
executionControllers structural =
  [ (prefix, arm)
  | StructuralNode nodePath "Union" arm <- structural
  , Just (prefix, "controller") <- [unsnoc nodePath]
  ]

refineExecution :: [StructuralNode] -> ([Text], Text) -> Either DecodeError SomeExecutionUnit
refineExecution structural (prefix, controller) = do
  identity <- executionIdentity prefix structural
  resources <- executionResources prefix structural
  validateHeadroom prefix structural
  rejectMetalController controller prefix structural
  case controller of
    "Deployment" -> do
      cardinality <- executionCardinality (prefix <> ["controller", "Deployment", "cardinality"]) structural
      progress <- deploymentProgress prefix structural
      rejectCudaRolling prefix progress structural
      SomeExecutionUnit <$> mkDeploymentUnit identity cardinality progress resources
    "StatefulSet" -> do
      cardinality <- executionCardinality (prefix <> ["controller", "StatefulSet", "cardinality"]) structural
      SomeExecutionUnit <$> mkStatefulSetUnit identity cardinality resources
    "DaemonSet" -> do
      validateDaemonSetRollout prefix structural
      SomeExecutionUnit <$> mkDaemonSetUnit identity resources
    "Job" -> do
      completions <- requiredNaturalAt (prefix <> ["controller", "Job", "completions"]) structural
      parallelism <- requiredNaturalAt (prefix <> ["controller", "Job", "parallelism"]) structural
      retention <- requiredNaturalAt (prefix <> ["controller", "Job", "terminalRetention", "horizon", "seconds"]) structural
      SomeExecutionUnit <$> mkJobUnit identity completions parallelism retention resources
    "HostProcess" -> do
      cardinality <- hostCardinality prefix structural
      SomeExecutionUnit <$> mkHostProcessUnit identity cardinality resources
    unknown -> Left (OutOfDomainArm ("execution.controller." <> unknown))

rejectZeroDomain :: [StructuralNode] -> Either DecodeError ()
rejectZeroDomain structural
  | any isZeroTtl structural = Left (OutOfDomainArm "cluster.ingress.ttlSeconds")
  | otherwise = Right ()
 where
  isZeroTtl (StructuralNode nodePath "Natural" "0") = ["ttlSeconds"] `isSuffixOf` nodePath
  isZeroTtl _ = False

rejectZeroProgress :: [StructuralNode] -> Either DecodeError ()
rejectZeroProgress structural
  | any parentHasZeroPair rolloutParents = Left (UnspellableCombination "execution.controller.rollout.rollingProgress")
  | otherwise = Right ()
 where
  rolloutParents =
    [ parent
    | StructuralNode nodePath "Natural" "0" <- structural
    , Just (parent, "maxSurge") <- [unsnoc nodePath]
    ]
  parentHasZeroPair parent = any (isZeroUnavailable parent) structural
  isZeroUnavailable parent (StructuralNode nodePath "Natural" "0") = nodePath == parent <> ["maxUnavailable"]
  isZeroUnavailable _ _ = False

executionIdentity :: [Text] -> [StructuralNode] -> Either DecodeError ExecutionIdentity
executionIdentity prefix structural = do
  identifier <- requiredTextAt (prefix <> ["id"]) structural
  revision <- requiredNaturalAt (prefix <> ["revision"]) structural
  Right (ExecutionIdentity identifier revision)

executionCardinality :: [Text] -> [StructuralNode] -> Either DecodeError Cardinality
executionCardinality path structural = case unionAt path structural of
  Just "Once" -> Right Once
  Just "Replicated" -> do
    count <- requiredNaturalAt (path <> ["Replicated", "desiredReplicas"]) structural
    mkPositiveReplicated count
  Just arm -> Left (OutOfDomainArm ("execution.controller.cardinality." <> arm))
  Nothing -> Left (SchemaMismatch "execution controller cardinality is absent")

hostCardinality :: [Text] -> [StructuralNode] -> Either DecodeError Cardinality
hostCardinality prefix structural = case unionAt (prefix <> ["controller", "HostProcess", "cardinality"]) structural of
  Just "Once" -> Right Once
  Just "PerNode" -> Right PerNode
  Just arm -> Left (OutOfDomainArm ("execution.controller.HostProcess.cardinality." <> arm))
  Nothing -> Left (SchemaMismatch "host-process cardinality is absent")

deploymentProgress :: [Text] -> [StructuralNode] -> Either DecodeError DeploymentProgress
deploymentProgress prefix structural = case
    ( naturalAt (rollout <> ["RollingUpdate", "maxSurge"]) structural
    , naturalAt (rollout <> ["RollingUpdate", "maxUnavailable"]) structural
    ) of
  (Just surge, Just unavailable) -> Right (RollingProgress surge unavailable)
  (Nothing, Nothing)
    | unionAt rollout structural == Just "Recreate" -> Right Recreate
    | otherwise -> Left (OutOfDomainArm "execution.controller.Deployment.rollout")
  _ -> Left (SchemaMismatch "deployment rollout is structurally incomplete")
 where
  rollout = prefix <> ["controller", "Deployment", "rollout"]

executionResources :: [Text] -> [StructuralNode] -> Either DecodeError ResourceEnvelope
executionResources executionPrefix structural = do
  let resourcePrefix = executionPrefix <> ["resource"]
  arm <- case find (hasExactPath resourcePrefix) structural of
    Just (StructuralNode _ "Union" "Pod") -> Right PodResource
    Just (StructuralNode _ "Union" "Host") -> Right HostResource
    _ -> Left (SchemaMismatch "execution resource envelope is absent or unknown")
  let complete = [node | node@(StructuralNode nodePath _ _) <- structural, resourcePrefix `isPrefixOf` nodePath]
#ifdef PHASE6_NORMALIZATION_MUTANT
      retained = take 1 complete
#else
      retained = complete
#endif
  if null retained
    then Left (SchemaMismatch "execution resource envelope retained no fields")
    else Right (ResourceEnvelope arm retained)

rejectCudaRolling :: [Text] -> DeploymentProgress -> [StructuralNode] -> Either DecodeError ()
rejectCudaRolling prefix progress structural
  | RollingProgress _ _ <- progress
  , unionAt (prefix <> ["resource", "Pod", "accelerator"]) structural == Just "Cuda" =
      Left (UnspellableCombination "execution.controller.Deployment.rollout.Cuda")
  | otherwise = Right ()

rejectMetalController :: Text -> [Text] -> [StructuralNode] -> Either DecodeError ()
rejectMetalController controller prefix structural
  | controller /= "HostProcess"
  , unionAt (prefix <> ["resource", "Host", "accelerator"]) structural == Just "AppleMetal" =
      Left (UnspellableCombination ("execution.controller." <> controller <> ".accelerator.AppleMetal"))
  | otherwise = Right ()

validateDaemonSetRollout :: [Text] -> [StructuralNode] -> Either DecodeError ()
validateDaemonSetRollout prefix structural = case unionAt rollout structural of
  Just "OnDelete" -> Right ()
  Just "RollingUpdate" -> case unionAt (rollout <> ["RollingUpdate"]) structural of
    Just "Surge" -> positive "Surge"
    Just "Unavailable" -> positive "Unavailable"
    _ -> Left (SchemaMismatch "daemon-set rolling policy is incomplete")
  _ -> Left (OutOfDomainArm "execution.controller.DaemonSet.rollout")
 where
  rollout = prefix <> ["controller", "DaemonSet", "rollout"]
  positive arm = do
    value <- requiredNaturalAt (rollout <> ["RollingUpdate", arm]) structural
    if value > 0
      then Right ()
      else Left (OutOfDomainArm ("execution.controller.DaemonSet.rollout." <> arm))

validateHeadroom :: [Text] -> [StructuralNode] -> Either DecodeError ()
validateHeadroom prefix structural
  | unionAt resourcePath structural == Just "Pod" = validatePodHeadroom (resourcePath <> ["Pod"]) structural
  | unionAt resourcePath structural == Just "Host" = validateHostHeadroom (resourcePath <> ["Host"]) structural
  | otherwise = Right ()
 where
  resourcePath = prefix <> ["resource"]

validatePodHeadroom :: [Text] -> [StructuralNode] -> Either DecodeError ()
validatePodHeadroom resourcePrefix structural
  | optionalAt headroom structural /= Just "Some" = Right ()
  | otherwise = () <$ mkComputeHeadroom triples
 where
  headroom = resourcePrefix <> ["headroom"]
  pad = headroom <> ["Some", "pad"]
  triples =
    [ axisTriple ["cpu", "millis"] ["cpu", "Remaining", "millis"]
    , axisTriple ["memory", "bytes"] ["memory", "Remaining", "bytes"]
    , axisTriple ["ephemeralStorage", "bytes"] ["ephemeralStorage", "Remaining", "bytes"]
    ]
  axisTriple vectorSuffix padSuffix =
    ( sumNaturalsUnder resourcePrefix (["resources", "requests"] <> vectorSuffix) structural
    , sumNaturalsUnder resourcePrefix (["resources", "limits"] <> vectorSuffix) structural
    , maybe 0 id (naturalAt (pad <> padSuffix) structural)
    )

validateHostHeadroom :: [Text] -> [StructuralNode] -> Either DecodeError ()
validateHostHeadroom resourcePrefix structural
  | optionalAt headroom structural /= Just "Some" = Right ()
  | otherwise = () <$ mkComputeHeadroom triples
 where
  headroom = resourcePrefix <> ["resources", "headroom"]
  pad = headroom <> ["Some", "pad"]
  triples =
    [ axisTriple ["cpu", "millis"] ["cpu", "Remaining", "millis"]
    , axisTriple ["memory", "bytes"] ["memory", "Remaining", "bytes"]
    ]
  axisTriple vectorSuffix padSuffix =
    ( maybe 0 id (naturalAt (resourcePrefix <> ["resources", "requests"] <> vectorSuffix) structural)
    , maybe 0 id (naturalAt (resourcePrefix <> ["resources", "limits"] <> vectorSuffix) structural)
    , maybe 0 id (naturalAt (pad <> padSuffix) structural)
    )

rejectReusedRke2Host :: [StructuralNode] -> Either DecodeError ()
rejectReusedRke2Host structural
  | Right _ <- distinctHostIds hosts = Right ()
  | otherwise = Left (UnspellableCombination "cluster.rke2.distinctHostIds")
 where
  hosts =
    [ literal
    | StructuralNode nodePath "Text" literal <- structural
    , ["host"] `isSuffixOf` nodePath
    , any (`elem` nodePath) ["servers", "agents"]
    ]

requiredTextAt :: [Text] -> [StructuralNode] -> Either DecodeError Text
requiredTextAt path structural = maybe (Left (SchemaMismatch (Text.intercalate "." path))) Right (textAt path structural)

requiredNaturalAt :: [Text] -> [StructuralNode] -> Either DecodeError Natural
requiredNaturalAt path structural = maybe (Left (SchemaMismatch (Text.intercalate "." path))) Right (naturalAt path structural)

unionAt :: [Text] -> [StructuralNode] -> Maybe Text
unionAt path structural = do
  StructuralNode _ "Union" arm <- find (hasExactPath path) structural
  pure arm

optionalAt :: [Text] -> [StructuralNode] -> Maybe Text
optionalAt path structural = do
  StructuralNode _ "Optional" arm <- find (hasExactPath path) structural
  pure arm

textAt :: [Text] -> [StructuralNode] -> Maybe Text
textAt path structural = do
  StructuralNode _ "Text" literal <- find (hasExactPath path) structural
  pure literal

naturalAt :: [Text] -> [StructuralNode] -> Maybe Natural
naturalAt path structural = do
  StructuralNode _ "Natural" literal <- find (hasExactPath path) structural
  readMaybe (Text.unpack literal)

sumNaturalsUnder :: [Text] -> [Text] -> [StructuralNode] -> Natural
sumNaturalsUnder prefix suffix structural =
  sum
    [ value
    | StructuralNode nodePath "Natural" literal <- structural
    , prefix `isPrefixOf` nodePath
    , suffix `isSuffixOf` nodePath
    , Just value <- [readMaybe (Text.unpack literal)]
    ]

hasExactPath :: [Text] -> StructuralNode -> Bool
hasExactPath expected (StructuralNode nodePath _ _) = expected == nodePath

unsnoc :: [element] -> Maybe ([element], element)
unsnoc values = case reverse values of
  [] -> Nothing
  final : reversedInitial -> Just (reverse reversedInitial, final)

{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Generate.CheckingCorpus
  ( ArtifactClass (..)
  , BuildRoot
  , GeneratedArtifact (..)
  , GenerationProblem (..)
  , OutputPolicy (..)
  , SupportArtifact (..)
  , artifactDigest
  , artifactOutputPath
  , mkBuildRoot
  , outputPolicy
  , supportCorpus
  , supportCorpusProjection
  , writeGeneratedCorpus
  ) where

import Control.Monad (forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)
import System.Directory
  ( createDirectoryIfMissing
  , getPermissions
  , setOwnerExecutable
  , setPermissions
  )
import System.FilePath
  ( isAbsolute
  , normalise
  , splitDirectories
  , takeDirectory
  , (</>)
  )

data ArtifactClass
  = CheckingTool
  | SerializedTestCase
  | MutationBody
  | PulumiProgram
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SupportArtifact = SupportArtifact
  { supportIdentity :: Text
  , supportClass :: ArtifactClass
  , supportLogicalPath :: FilePath
  , supportBytes :: ByteString
  }
  deriving stock (Eq, Show)

data GeneratedArtifact = GeneratedArtifact
  { generatedIdentity :: Text
  , generatedClass :: ArtifactClass
  , generatedDigest :: Text
  , generatedPath :: FilePath
  , generatedBytes :: ByteString
  }
  deriving stock (Eq, Show)

data OutputPolicy = BuildTree | AuthoredTree
  deriving stock (Eq, Show)

data GenerationProblem
  = ProjectRootMustBeAbsolute
  | OutputRootMustBeBuildRoot
  | InvalidRunIdentity
  | ArtifactPathEscapesClassRoot Text FilePath
  | DuplicateArtifactIdentity Text
  | DuplicateArtifactPath FilePath
  deriving stock (Eq, Show)

data BuildRoot = BuildRoot FilePath Text

outputPolicy :: OutputPolicy
#ifdef TOOL_GENERATION_TRACK_OUTPUT_MUTANT
outputPolicy = AuthoredTree
#else
outputPolicy = BuildTree
#endif

supportCorpus :: [SupportArtifact]
supportCorpus = selectTools tools <> cases <> selectMutations mutations <> providerPrograms
 where
  tools =
    [ artifact "tool.validate-phase" CheckingTool "validate-phase"
        "#!/bin/sh\nset -eu\n: \"${AMOEBIUS_SOURCE_BOUND_BINARY:?}\"\nexec \"$AMOEBIUS_SOURCE_BOUND_BINARY\" validate phase \"$@\"\n"
    , artifact "tool.check-documentation" CheckingTool "check-documentation"
        "#!/bin/sh\nset -eu\n: \"${AMOEBIUS_SOURCE_BOUND_BINARY:?}\"\nexec \"$AMOEBIUS_SOURCE_BOUND_BINARY\" validate phase 00\n"
    , artifact "tool.check-source-closure" CheckingTool "check-source-closure"
        "#!/bin/sh\nset -eu\n: \"${AMOEBIUS_SOURCE_BOUND_BINARY:?}\"\nexec \"$AMOEBIUS_SOURCE_BOUND_BINARY\" validate phase 02\n"
    ]
  cases =
    [ artifact "case.source-closure-positive" SerializedTestCase "source-closure/positive.json"
        "{\"case\":\"haskell-source\",\"path\":\"src/Example.hs\",\"expected\":\"accepted\"}\n"
    , artifact "case.source-closure-negative" SerializedTestCase "source-closure/non-haskell-source.json"
        "{\"case\":\"foreign-source\",\"path\":\"tools/example.py\",\"expected\":\"rejected\",\"reason\":\"tracked-behavioral-source-must-be-haskell\"}\n"
    ]
  mutations =
    [ artifact "mutant.missing-rule" MutationBody "checking-corpus/missing-rule.patch"
        "operator=drop-declaration\nlocus=supportCorpus.tools\nexpected=artifact-set-mismatch\n"
    , artifact "mutant.drop-operator" MutationBody "checking-corpus/drop-operator.patch"
        "operator=drop-mutation\nlocus=supportCorpus.mutations\nexpected=mutation-set-mismatch\n"
    , artifact "mutant.tracked-output" MutationBody "checking-corpus/tracked-output.patch"
        "operator=select-authored-tree\nlocus=outputPolicy\nexpected=output-policy-refused\n"
    ]
  providerPrograms =
    [ artifact "pulumi.child-cluster" PulumiProgram "child-cluster/Pulumi.yaml"
        "name: amoebius-child-cluster\nruntime: yaml\ndescription: Generated provider program metadata; Haskell owns the declaration.\n"
    ]

artifact :: Text -> ArtifactClass -> FilePath -> ByteString -> SupportArtifact
artifact = SupportArtifact

selectTools :: [SupportArtifact] -> [SupportArtifact]
#ifdef TOOL_GENERATION_MISSING_RULE_MUTANT
selectTools = selectWithDrop True
#else
selectTools = selectWithDrop False
#endif

selectMutations :: [SupportArtifact] -> [SupportArtifact]
#ifdef TOOL_GENERATION_DROP_OPERATOR_MUTANT
selectMutations = selectWithDrop True
#else
selectMutations = selectWithDrop False
#endif

selectWithDrop :: Bool -> [value] -> [value]
selectWithDrop shouldDrop values = case (shouldDrop, values) of
  (True, _ : rest) -> rest
  _ -> values

mkBuildRoot :: FilePath -> FilePath -> Text -> Either GenerationProblem BuildRoot
mkBuildRoot project output runIdentity
  | not (isAbsolute project) = Left ProjectRootMustBeAbsolute
  | normalise output /= normalise (project </> ".build") = Left OutputRootMustBeBuildRoot
  | not (validRunIdentity runIdentity) = Left InvalidRunIdentity
  | otherwise = Right (BuildRoot (normalise output) runIdentity)

validRunIdentity :: Text -> Bool
validRunIdentity value =
  not (Text.null value)
    && Text.length value <= 96
    && Text.all (\character -> isAsciiAlphaNumeric character || character `elem` ['-', '_']) value
 where
  isAsciiAlphaNumeric character =
    (character >= 'a' && character <= 'z')
      || (character >= 'A' && character <= 'Z')
      || (character >= '0' && character <= '9')

artifactDigest :: SupportArtifact -> Text
artifactDigest = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash . supportBytes
 where
  byteHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

supportCorpusProjection :: Either GenerationProblem [GeneratedArtifact]
supportCorpusProjection = do
  ensureUniqueIdentities supportCorpus
  artifacts <- traverse projectArtifact supportCorpus
  ensureUniquePaths artifacts
  pure artifacts

projectArtifact :: SupportArtifact -> Either GenerationProblem GeneratedArtifact
projectArtifact declaration
  | invalidLogicalPath logical = Left (ArtifactPathEscapesClassRoot (supportIdentity declaration) logical)
  | otherwise =
      Right
        GeneratedArtifact
          { generatedIdentity = supportIdentity declaration
          , generatedClass = supportClass declaration
          , generatedDigest = digest
          , generatedPath = classRoot (supportClass declaration) </> Text.unpack digest </> logical
          , generatedBytes = supportBytes declaration
          }
 where
  logical = supportLogicalPath declaration
  digest = artifactDigest declaration

invalidLogicalPath :: FilePath -> Bool
invalidLogicalPath path =
  null path
    || isAbsolute path
    || normalise path /= path
    || any (== "..") (splitDirectories path)

classRoot :: ArtifactClass -> FilePath
classRoot artifactClass = case artifactClass of
  CheckingTool -> "tools"
  SerializedTestCase -> "test-corpora"
  MutationBody -> "test-corpora" </> "mutants"
  PulumiProgram -> "pulumi"

ensureUniqueIdentities :: [SupportArtifact] -> Either GenerationProblem ()
ensureUniqueIdentities artifacts = uniqueBy supportIdentity DuplicateArtifactIdentity artifacts

ensureUniquePaths :: [GeneratedArtifact] -> Either GenerationProblem ()
ensureUniquePaths artifacts = uniqueBy generatedPath DuplicateArtifactPath artifacts

uniqueBy :: Eq key => (value -> key) -> (key -> GenerationProblem) -> [value] -> Either GenerationProblem ()
uniqueBy project problem = go []
 where
  go _ [] = Right ()
  go seen (value : rest)
    | key `elem` seen = Left (problem key)
    | otherwise = go (key : seen) rest
   where
    key = project value

artifactOutputPath :: BuildRoot -> GeneratedArtifact -> FilePath
artifactOutputPath (BuildRoot root runIdentity) generated =
  root </> addRunIdentity (generatedPath generated)
 where
  addRunIdentity path = case splitDirectories path of
    classDirectory : rest ->
      classDirectory
        </> "tool-and-mutant-generation"
        </> Text.unpack runIdentity
        </> joinDirectoriesSafe rest
    [] -> path

joinDirectoriesSafe :: [FilePath] -> FilePath
joinDirectoriesSafe values = case values of
  [] -> ""
  first : rest -> foldl (</>) first rest

writeGeneratedCorpus :: BuildRoot -> IO (Either GenerationProblem [FilePath])
writeGeneratedCorpus root = case supportCorpusProjection of
  Left problem -> pure (Left problem)
  Right artifacts -> Right <$> forM artifacts writeOne
 where
  writeOne generated = do
    let target = artifactOutputPath root generated
    createDirectoryIfMissing True (takeDirectory target)
    ByteString.writeFile target (generatedBytes generated)
    case generatedClass generated of
      CheckingTool -> do
        permissions <- getPermissions target
        setPermissions target (setOwnerExecutable True permissions)
      _ -> pure ()
    pure target

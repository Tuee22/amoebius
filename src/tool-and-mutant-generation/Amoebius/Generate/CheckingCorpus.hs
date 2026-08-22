{-# LANGUAGE CPP #-}

module Amoebius.Generate.CheckingCorpus
  ( GeneratedArtifact (..)
  , MutationDeclaration (..)
  , OutputPolicy (..)
  , ToolDeclaration (..)
  , generatedCorpus
  , generationDefect
  , outputPolicy
  , writeGeneratedCorpus
  ) where

import Control.Monad (forM_)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>), makeRelative, takeDirectory, takeFileName)

data ToolDeclaration = ToolDeclaration
  { toolSourcePath :: FilePath
  , toolKind :: String
  , toolConcern :: String
  , toolSourceBytes :: ByteString
  }
  deriving stock (Eq, Show)

data MutationDeclaration = MutationDeclaration
  { mutationBodyPath :: FilePath
  , mutationCapability :: String
  , mutationName :: String
  , mutationOperator :: String
  , mutationPositiveSeed :: String
  , mutationBodyBytes :: ByteString
  }
  deriving stock (Eq, Show)

data GeneratedArtifact = GeneratedArtifact
  { generatedPath :: FilePath
  , generatedBytes :: ByteString
  }
  deriving stock (Eq, Show)

data OutputPolicy = BuildTree | AuthoredTree
  deriving stock (Eq, Show)

outputPolicy :: OutputPolicy
#ifdef TOOL_GENERATION_TRACK_OUTPUT_MUTANT
outputPolicy = AuthoredTree
#else
outputPolicy = BuildTree
#endif

generationDefect :: Maybe String
#ifdef TOOL_GENERATION_MISSING_RULE_MUTANT
generationDefect = Just "tool-and-mutant-generation-mutant: RED missing_rule checker-rule-missing"
#elif defined(TOOL_GENERATION_DROP_OPERATOR_MUTANT)
generationDefect = Just "tool-and-mutant-generation-mutant: RED drop_operator mutation-operator-missing"
#else
generationDefect = Nothing
#endif

generatedCorpus :: [ToolDeclaration] -> [MutationDeclaration] -> [GeneratedArtifact]
generatedCorpus tools mutations = map renderTool selectedTools <> map renderMutation selectedMutations
  where
    selectedTools = selectTools tools
    selectedMutations = selectMutations mutations

selectTools :: [ToolDeclaration] -> [ToolDeclaration]
#ifdef TOOL_GENERATION_MISSING_RULE_MUTANT
selectTools values = case values of
  [] -> []
  _first : rest -> rest
#else
selectTools values = values
#endif

selectMutations :: [MutationDeclaration] -> [MutationDeclaration]
#ifdef TOOL_GENERATION_DROP_OPERATOR_MUTANT
selectMutations values = case values of
  [] -> []
  _first : rest -> rest
#else
selectMutations values = values
#endif

renderTool :: ToolDeclaration -> GeneratedArtifact
renderTool declaration = GeneratedArtifact
  { generatedPath = "tools" </> makeRelative "tools" (toolSourcePath declaration)
  , generatedBytes = toolSourceBytes declaration
  }

renderMutation :: MutationDeclaration -> GeneratedArtifact
renderMutation declaration = GeneratedArtifact
  { generatedPath = "mutants" </> mutationCapability declaration </> mutationName declaration
      </> takeFileName (mutationBodyPath declaration)
  , generatedBytes = mutationBodyBytes declaration
  }

writeGeneratedCorpus :: FilePath -> [GeneratedArtifact] -> IO ()
writeGeneratedCorpus root artifacts = forM_ artifacts $ \artifact -> do
  let target = root </> generatedPath artifact
  createDirectoryIfMissing True (takeDirectory target)
  ByteString.writeFile target (generatedBytes artifact)

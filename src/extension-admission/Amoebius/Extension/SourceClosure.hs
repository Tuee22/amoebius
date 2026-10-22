{-# LANGUAGE OverloadedStrings #-}

-- | The file boundary is deliberately separate from the pure checker. Only
-- ordinary .hs files under the fixed contributed-source root enter a closure.
module Amoebius.Extension.SourceClosure
  ( ContributionRefusal (..), contributionRefusalTag, renderContributionRefusal
  , contributionRoot, readContributionClosure
  , ContributionFilesystem (..), readContributionClosureWith
  ) where

import Amoebius.Extension.AstCheck
import Control.Exception (IOException, try)
import Data.ByteString qualified as ByteString
import Data.Char (isAlphaNum, isUpper)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Directory (doesDirectoryExist, listDirectory, pathIsSymbolicLink)
import System.FilePath (dropExtension, joinPath, splitDirectories, takeExtension, (</>))

data ContributionRefusal
  = MissingContributionSource
  | ContributionSymlink FilePath
  | UnexpectedContributionFile FilePath
  | ContributionIoFailure FilePath Text
  | ContributionModuleMismatch FilePath Text Text
  | ContributionRejected (NonEmpty AstViolation)
  deriving (Eq, Show)

contributionRoot :: FilePath
contributionRoot = "src/extension-contributions"

contributionRefusalTag :: ContributionRefusal -> Text
contributionRefusalTag refusal = case refusal of
  MissingContributionSource -> "MissingContributionSource"
  ContributionSymlink _ -> "ContributionSymlink"
  UnexpectedContributionFile _ -> "UnexpectedContributionFile"
  ContributionIoFailure {} -> "ContributionIoFailure"
  ContributionModuleMismatch {} -> "ContributionModuleMismatch"
  ContributionRejected _ -> "ContributionRejected"

renderContributionRefusal :: ContributionRefusal -> Text
renderContributionRefusal refusal = case refusal of
  ContributionRejected problems -> Text.unlines (map renderAstViolation (NonEmpty.toList problems))
  _ -> contributionRefusalTag refusal <> ": " <> Text.pack (show refusal)

-- Supplied observations exercise the same checker without creating host links.
-- They attest no native file identity. Compiler admission always uses the fixed
-- native entry point below; the pure AST checker already accepts supplied bytes.
data ContributionFilesystem = ContributionFilesystem
  { contributionIsDirectory :: FilePath -> IO Bool
  , contributionIsLink :: FilePath -> IO Bool
  , contributionChildren :: FilePath -> IO [FilePath]
  , contributionReadBytes :: FilePath -> IO ByteString.ByteString
  }

readContributionClosure :: FilePath -> IO (Either ContributionRefusal CheckedExtensionSource)
readContributionClosure = readContributionClosureWith
  (ContributionFilesystem doesDirectoryExist pathIsSymbolicLink listDirectory ByteString.readFile)

readContributionClosureWith :: ContributionFilesystem -> FilePath -> IO (Either ContributionRefusal CheckedExtensionSource)
readContributionClosureWith filesystem repository = do
  discovered <- ioAt contributionRoot $ do
    present <- contributionIsDirectory filesystem root
    if present then walk "" else pure (Left MissingContributionSource)
  case discovered >>= id of
    Left refusal -> pure (Left refusal)
    Right [] -> pure (Left MissingContributionSource)
    Right paths -> do
      loaded <- mapM load paths
      pure $ do
        sources <- sequence loaded
        case sources of
          [] -> Left MissingContributionSource
          first : rest -> case checkExtensionSources (first :| rest) of
            Rejected problems -> Left (ContributionRejected problems)
            Accepted seal -> do
              mapM_ checkModule (NonEmpty.toList (checkedSourceModules seal))
              Right seal
 where
  root = repository </> contributionRoot
  walk relative = do
    symbolic <- contributionIsLink filesystem (root </> relative)
    if symbolic then pure (Left (ContributionSymlink relative)) else do
      directory <- contributionIsDirectory filesystem (root </> relative)
      if directory then do
        children <- sort <$> contributionChildren filesystem (root </> relative)
        nested <- mapM (walk . (relative </>)) children
        pure (concat <$> sequence nested)
      else pure $ if takeExtension relative == ".hs"
        then Right [relative]
        else Left (UnexpectedContributionFile relative)
  load relative = do
    bytes <- ioAt relative (contributionReadBytes filesystem (root </> relative))
    pure $ do
      raw <- bytes
      source <- either (Left . ContributionIoFailure relative . Text.pack . show) Right (Encoding.decodeUtf8' raw)
      Right (relative, source)
  checkModule (relative, name) =
    let parts = splitDirectories (dropExtension relative)
        expected = Text.intercalate "." (map Text.pack parts)
        qualified = ["Amoebius", "Extension", "Contributed"]
        validPart part = case part of
          first : rest -> isUpper first && all (\c -> isAlphaNum c || c == '_' || c == '\'') rest
          [] -> False
     in if all validPart parts && take 3 parts == qualified && length parts > 3 && name == expected
          then Right ()
          else Left (ContributionModuleMismatch (joinPath parts) expected name)

ioAt :: FilePath -> IO value -> IO (Either ContributionRefusal value)
ioAt path action = do
  result <- try action
  pure $ case result of
    Left (problem :: IOException) -> Left (ContributionIoFailure path (Text.pack (show problem)))
    Right value -> Right value

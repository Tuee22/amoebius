{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.ExternalLinkCatalog
  ( ExternalLinkId
  , ExternalLinkRequirement (..)
  , ExternalLinkCatalogEntry (..)
  , ResolvedExternalLink (..)
  , BoundExternalLinks
  , UiLinkBindError (..)
  , trustedExternalLinkId
  , externalLinkIdText
  , bindExternalLinks
  , resolvedExternalLinks
  , uiLinkBindErrorTag
  ) where

import Data.Char (isAlphaNum)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text

newtype ExternalLinkId = ExternalLinkId Text
  deriving stock (Eq, Ord, Show)

newtype ExternalLinkRequirement = ExternalLinkRequirement ExternalLinkId
  deriving stock (Eq, Ord, Show)

data ExternalLinkCatalogEntry = ExternalLinkCatalogEntry ExternalLinkId Text
  deriving stock (Eq, Ord, Show)

data ResolvedExternalLink = ResolvedExternalLink
  { resolvedLinkId :: ExternalLinkId
  , resolvedLinkUrl :: Text
  , resolvedLinkTarget :: Text
  , resolvedLinkRel :: Text
  }
  deriving stock (Eq, Ord, Show)

newtype BoundExternalLinks = BoundExternalLinks (Map ExternalLinkId ResolvedExternalLink)

data UiLinkBindError
  = InvalidExternalLinkId Text
  | MissingExternalLink ExternalLinkId
  | UnexpectedExternalLink ExternalLinkId
  | DuplicateExternalLink ExternalLinkId
  | InsecureExternalLink ExternalLinkId
  | UserInfoExternalLink ExternalLinkId
  | WildcardExternalLink ExternalLinkId
  | NoncanonicalExternalLink ExternalLinkId
  | CallerTemplatedExternalLink ExternalLinkId
  deriving stock (Eq, Ord, Show)

trustedExternalLinkId :: Text -> Either UiLinkBindError ExternalLinkId
trustedExternalLinkId value
  | validIdentifier value = Right (ExternalLinkId value)
  | otherwise = Left (InvalidExternalLinkId value)

externalLinkIdText :: ExternalLinkId -> Text
externalLinkIdText (ExternalLinkId value) = value

bindExternalLinks
  :: [ExternalLinkRequirement]
  -> [ExternalLinkCatalogEntry]
  -> Either UiLinkBindError BoundExternalLinks
bindExternalLinks requirements entries = do
  requirementSet <- uniqueRequirements requirements
  entryMap <- uniqueEntries entries
  checkSetParity requirementSet (Map.keysSet entryMap)
  resolved <- traverse resolveEntry (Map.toList entryMap)
  pure (BoundExternalLinks (Map.fromList [(resolvedLinkId link, link) | link <- resolved]))

resolvedExternalLinks :: BoundExternalLinks -> [ResolvedExternalLink]
resolvedExternalLinks (BoundExternalLinks links) = sortOn resolvedLinkId (Map.elems links)

uiLinkBindErrorTag :: UiLinkBindError -> Text
uiLinkBindErrorTag problem = case problem of
  InvalidExternalLinkId _ -> "InvalidExternalLinkId"
  MissingExternalLink _ -> "MissingExternalLink"
  UnexpectedExternalLink _ -> "UnexpectedExternalLink"
  DuplicateExternalLink _ -> "DuplicateExternalLink"
  InsecureExternalLink _ -> "InsecureExternalLink"
  UserInfoExternalLink _ -> "UserInfoExternalLink"
  WildcardExternalLink _ -> "WildcardExternalLink"
  NoncanonicalExternalLink _ -> "NoncanonicalExternalLink"
  CallerTemplatedExternalLink _ -> "CallerTemplatedExternalLink"

uniqueRequirements :: [ExternalLinkRequirement] -> Either UiLinkBindError (Set ExternalLinkId)
uniqueRequirements = go Set.empty
  where
    go result [] = Right result
    go result (ExternalLinkRequirement link : rest)
      | link `Set.member` result = Left (DuplicateExternalLink link)
      | otherwise = go (Set.insert link result) rest

uniqueEntries :: [ExternalLinkCatalogEntry] -> Either UiLinkBindError (Map ExternalLinkId Text)
uniqueEntries = go Map.empty
  where
    go result [] = Right result
    go result (ExternalLinkCatalogEntry link url : rest)
      | Map.member link result = Left (DuplicateExternalLink link)
      | otherwise = go (Map.insert link url result) rest

checkSetParity :: Set ExternalLinkId -> Set ExternalLinkId -> Either UiLinkBindError ()
checkSetParity expected actual = case (Set.lookupMin (expected Set.\\ actual), Set.lookupMin (actual Set.\\ expected)) of
  (Just link, _) -> Left (MissingExternalLink link)
  (Nothing, Just link) -> Left (UnexpectedExternalLink link)
  (Nothing, Nothing) -> Right ()

resolveEntry :: (ExternalLinkId, Text) -> Either UiLinkBindError ResolvedExternalLink
resolveEntry (link, url) = do
  validateUrl link url
  pure (ResolvedExternalLink link url "_blank" "noopener noreferrer")

validateUrl :: ExternalLinkId -> Text -> Either UiLinkBindError ()
validateUrl link url
  | any (`Text.isInfixOf` url) ["{", "}", "${"] = Left (CallerTemplatedExternalLink link)
  | not ("https://" `Text.isPrefixOf` url) = Left (InsecureExternalLink link)
  | Text.null authority = Left (NoncanonicalExternalLink link)
  | "@" `Text.isInfixOf` authority = Left (UserInfoExternalLink link)
  | "*" `Text.isInfixOf` authority = Left (WildcardExternalLink link)
  | Text.toLower authority /= authority = Left (NoncanonicalExternalLink link)
  | "//" `Text.isInfixOf` path = Left (NoncanonicalExternalLink link)
  | otherwise = Right ()
  where
    afterScheme = Text.drop (Text.length "https://") url
    (authority, path) = Text.breakOn "/" afterScheme

validIdentifier :: Text -> Bool
validIdentifier value =
  not (Text.null value)
    && Text.all (\character -> isAlphaNum character || character `elem` ['-', '_', '.', ':']) value

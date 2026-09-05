{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.AstCheck
  ( AstViolationReason (..)
  , SourceSpan (..)
  , AstViolation (..)
  , ExtensionSourceVerdict (..)
#ifdef ASTCHECK_EXPORT_CTOR_MUTANT
  , CheckedExtensionSource (..)
#else
  , CheckedExtensionSource
#endif
  , checkExtensionSource
  , linkCheckedExtension
  , renderAstViolation
  ) where

import Amoebius.Dsl.SanctionedApi
import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data AstViolationReason
  = UnsanctionedImport
  | RawIO
  | ForeignCall
  | UnsafeOperation
  | TemplateHaskell
  | OrphanInstance
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data SourceSpan = SourceSpan
  { sourceLine :: Int
  , sourceColumn :: Int
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data AstViolation = AstViolation
  { violationModulePath :: FilePath
  , violationSpan :: SourceSpan
  , violationReason :: AstViolationReason
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

newtype CheckedExtensionSource = CheckedExtensionSource Text
  deriving stock (Eq, Show)

data ExtensionSourceVerdict
  = Rejected (NonEmpty AstViolation)
  | Accepted CheckedExtensionSource
  deriving stock (Eq, Show)

checkExtensionSource :: FilePath -> Text -> ExtensionSourceVerdict
checkExtensionSource path source = case concatMap checkLine (zip [1 ..] (Text.lines source)) of
  [] -> Accepted (CheckedExtensionSource source)
  violation : violations -> Rejected (violation :| violations)
 where
  checkLine (lineNumber, line) = importViolation lineNumber line <> tokenViolations lineNumber line
  importViolation lineNumber line = case Text.stripPrefix "import " (Text.strip line) of
    Nothing -> []
    Just rest ->
      let moduleName = Text.takeWhile (not . (`elem` [' ', '('])) rest
       in [located lineNumber line "import" UnsanctionedImport | ModuleName moduleName `Set.notMember` sanctionedModules sanctionedApi]
  tokenViolations lineNumber line =
    concat
      [ detect path lineNumber line "foreign import" ForeignCall
#ifndef ASTCHECK_ALLOW_RAWIO_MUTANT
      , detect path lineNumber line ":: IO" RawIO
#endif
      , detect path lineNumber line "unsafe" UnsafeOperation
      , detect path lineNumber line "$(" TemplateHaskell
      , detect path lineNumber line "instance " OrphanInstance
      ]
  located lineNumber line token reason = AstViolation path (SourceSpan lineNumber (columnOf token line)) reason

detect :: FilePath -> Int -> Text -> Text -> AstViolationReason -> [AstViolation]
detect path lineNumber line token reason =
  [AstViolation path (SourceSpan lineNumber (columnOf token line)) reason | token `Text.isInfixOf` line]

columnOf :: Text -> Text -> Int
columnOf token line = Text.length (fst (Text.breakOn token line)) + 1

linkCheckedExtension :: CheckedExtensionSource -> Text
linkCheckedExtension (CheckedExtensionSource source) = source

renderAstViolation :: AstViolation -> Text
renderAstViolation violation =
  Text.pack (violationModulePath violation)
    <> ":"
    <> Text.pack (show (sourceLine (violationSpan violation)))
    <> ":"
    <> Text.pack (show (sourceColumn (violationSpan violation)))
    <> ": "
    <> Text.pack (show (violationReason violation))

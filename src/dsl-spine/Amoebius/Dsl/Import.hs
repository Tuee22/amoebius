{-# LANGUAGE OverloadedStrings #-}

-- | Stage freeze. The operator's text is parsed first, every import it names, directly
-- or through a local file, is judged before any import is resolved, and only then is the
-- text resolved, typechecked, normalised, and hashed. An environment, remote, absolute,
-- home, or non-code import is refused by name; nothing outside the authored tree is read.
module Amoebius.Dsl.Import
  ( Frozen
  , frozenExpression
  , frozenText
  , frozenHash
  , ImportRefusal (..)
  , importRefusalTag
  , freezeText
  , freezeFile
  ) where

import Control.Exception (SomeException, try)
import Data.Foldable qualified as Foldable
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Void (Void)
import Dhall.Core qualified as Core
import Dhall.Import qualified as DhallImport
import Dhall.Parser qualified as Parser
import Dhall.Src (Src)
import Dhall.TypeCheck qualified as TypeCheck
import System.FilePath (normalise, takeDirectory, (</>))

-- | A resolved, normalised specification. The constructor is private: a value of this
-- type exists only because every import it names was judged and resolved.
data Frozen = Frozen
  { frozenExpression :: Core.Expr Src Void
  , frozenText :: Text
  , frozenHash :: Text
  }

data ImportRefusal
  = ParseFailure
  | ForbiddenImport
  | AbsolutePath
  | HomePath
  | NonCodeMode
  | ResolutionFailure
  | IllTyped
  deriving stock (Eq, Ord, Show)

importRefusalTag :: ImportRefusal -> Text
importRefusalTag refusal = case refusal of
  ParseFailure -> "ParseFailure"
  ForbiddenImport -> "ForbiddenImport"
  AbsolutePath -> "AbsolutePath"
  HomePath -> "HomePath"
  NonCodeMode -> "NonCodeMode"
  ResolutionFailure -> "ResolutionFailure"
  IllTyped -> "IllTyped"

-- | Freeze the file at a path; relative imports resolve beside it.
freezeFile :: FilePath -> IO (Either ImportRefusal Frozen)
freezeFile path = do
  contents <- try (TextIO.readFile path) :: IO (Either SomeException Text)
  case contents of
    Left _ -> pure (Left ResolutionFailure)
    Right source -> freezeText (takeDirectory path) source

-- | Freeze authored text; relative imports resolve beneath the given directory.
freezeText :: FilePath -> Text -> IO (Either ImportRefusal Frozen)
freezeText directory source = case Parser.exprFromText "specification" source of
  Left _ -> pure (Left ParseFailure)
  Right parsed -> do
    verdict <- judge Set.empty directory parsed
    case verdict of
      Left refusal -> pure (Left refusal)
      Right () -> do
        resolved <- try (DhallImport.loadRelativeTo directory DhallImport.IgnoreSemanticCache parsed)
          :: IO (Either SomeException (Core.Expr Src Void))
        pure $ case resolved of
          Left _ -> Left ResolutionFailure
          Right expression -> case TypeCheck.typeOf expression of
            Left _ -> Left IllTyped
            Right _ ->
              let normalised = Core.normalize (Core.denote expression) :: Core.Expr Void Void
              in Right Frozen
                   { frozenExpression = Core.denote normalised
                   , frozenText = Core.pretty normalised
                   , frozenHash = DhallImport.hashExpressionToCode normalised
                   }

-- | Judge every import of an expression before following any local file. The alternatives
-- of a fallback import are all judged, so a forbidden alternative is refused even when the
-- alternative before it names a file that is not there.
judge :: Set FilePath -> FilePath -> Core.Expr Src Core.Import -> IO (Either ImportRefusal ())
judge visited directory expression = case traverse (classify directory) (Foldable.toList expression) of
  Left refusal -> pure (Left refusal)
  Right targets -> follow visited [path | Just path <- targets]

follow :: Set FilePath -> [FilePath] -> IO (Either ImportRefusal ())
follow _ [] = pure (Right ())
follow seen (path : rest)
  | Set.member path seen = follow seen rest
  | otherwise = do
      contents <- try (TextIO.readFile path) :: IO (Either SomeException Text)
      case contents of
        Left _ -> pure (Left ResolutionFailure)
        Right inner -> case Parser.exprFromText "import" inner of
          Left _ -> pure (Left ParseFailure)
          Right parsed -> do
            nested <- judge (Set.insert path seen) (takeDirectory path) parsed
            case nested of
              Left refusal -> pure (Left refusal)
              Right () -> follow (Set.insert path seen) rest

-- | The judgement of one import: a refusal, nothing to follow, or a local file to read.
classify :: FilePath -> Core.Import -> Either ImportRefusal (Maybe FilePath)
classify directory imported
  | Core.importMode imported /= Core.Code = Left NonCodeMode
  | otherwise = case Core.importType (Core.importHashed imported) of
      Core.Env _ -> Left ForbiddenImport
      Core.Remote _ -> Left ForbiddenImport
      Core.Missing -> Left ForbiddenImport
      Core.Local Core.Absolute _ -> Left AbsolutePath
      Core.Local Core.Home _ -> Left HomePath
      Core.Local Core.Here file -> Right (Just (normalise (directory </> filePath file)))
      Core.Local Core.Parent file -> Right (Just (normalise (directory </> ".." </> filePath file)))

filePath :: Core.File -> FilePath
filePath (Core.File (Core.Directory components) name) =
  foldr (\component rest -> Text.unpack component </> rest) (Text.unpack name) (reverse components)

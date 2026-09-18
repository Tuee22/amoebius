

module Amoebius.Ui.Projection.Cursor
  ( CursorKey
  , Cursor (..)
  , CursorError (..)
  , cursorKey
  , resumeCursor
  ) where

data CursorKey = CursorKey String String String
  deriving stock (Eq, Ord, Show)
newtype Cursor = Cursor Int deriving stock (Eq, Ord, Show)
data CursorError = CursorScopeMismatch | CursorDiscarded deriving stock (Eq, Show)

cursorKey :: String -> String -> String -> CursorKey
cursorKey tenant owner stream = CursorKey tenant owner stream

resumeCursor :: CursorKey -> CursorKey -> Maybe Cursor -> Either CursorError Cursor
resumeCursor expected actual observed
  | expected /= actual = Left CursorScopeMismatch
  | Just cursor <- observed = Right cursor
  | otherwise = Right (Cursor 0)

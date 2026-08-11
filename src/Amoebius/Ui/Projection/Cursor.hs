{-# LANGUAGE CPP #-}

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
#if defined(PHASE57_DROP_TENANT_CURSOR_KEY_MUTANT) || defined(PHASE58_DROP_TENANT_CURSOR_KEY_MUTANT)
cursorKey _ owner stream = CursorKey "" owner stream
#else
cursorKey tenant owner stream = CursorKey tenant owner stream
#endif

resumeCursor :: CursorKey -> CursorKey -> Maybe Cursor -> Either CursorError Cursor
resumeCursor expected actual observed
  | expected /= actual = Left CursorScopeMismatch
#ifdef PHASE57_DISCARD_CURSOR_MUTANT
  | otherwise = Left CursorDiscarded
#else
  | Just cursor <- observed = Right cursor
  | otherwise = Right (Cursor 0)
#endif

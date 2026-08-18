{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Release.Environment
  ( Environment (..)
  , environmentText
  ) where

import Data.Text (Text)

data Environment = Dev | Staging | Prod
  deriving stock (Bounded, Enum, Eq, Ord, Read, Show)

environmentText :: Environment -> Text
environmentText Dev = "Dev"
environmentText Staging = "Staging"
environmentText Prod = "Prod"

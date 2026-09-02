{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Exception (SomeException, displayException, try)
import Data.Text (Text)
import Dhall qualified
import GHC.Generics (Generic)
import Numeric.Natural (Natural)
import System.Environment (getArgs)
import System.Exit (exitFailure)

data ProbeConfig = ProbeConfig
  { name :: Text
  , count :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

main :: IO ()
main = do
  arguments <- getArgs
  let fixture = case arguments of
        [path] -> path
        _ -> error "usage: decode fixture.dhall"
  decoded <- try (Dhall.inputFile Dhall.auto fixture)
  case decoded of
    Right value -> print (value :: ProbeConfig)
    Left err -> do
      putStrLn ("DHALL_TYPE_ERROR: " <> displayException (err :: SomeException))
      exitFailure

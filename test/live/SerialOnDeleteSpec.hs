{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import System.Exit (die)

newtype Evidence = Evidence Serial
newtype Serial = Serial [Transition]
data Transition = Transition Text Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Phase26Evidence" $ \value -> Evidence <$> value .: "serial"

instance FromJSON Serial where
  parseJSON = withObject "Serial" $ \value -> Serial <$> value .: "transitions"

instance FromJSON Transition where
  parseJSON = withObject "Transition" $ \value ->
    Transition <$> value .: "name" <*> value .: "oldUid" <*> value .: "newUid"
      <*> value .: "absenceObserved" <*> value .: "boundReadyObserved"

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_26/live-reconcile.json"
  case decoded of
    Left problem -> die problem
    Right (Evidence (Serial transitions)) -> verify transitions
  putStrLn "serial-on-delete: PASS (ordered absence and distinct Bound+Ready replacements)"

verify :: [Transition] -> IO ()
verify [Transition "serial-1" oldOne newOne "true" "true", Transition "serial-0" oldZero newZero "true" "true"]
  | oldOne /= newOne && oldZero /= newZero = pure ()
verify _ = die "serial transitions were not exact, ordered, absent, and Bound+Ready"

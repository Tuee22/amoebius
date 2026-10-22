{-# LANGUAGE OverloadedStrings #-}
-- | Portable tool admission: versions only, with no archive, executable digest,
-- signature, operating-system, architecture, or device requirement (DL-0025).
module Amoebius.Toolchain.Versions
  ( Platform (..), renderPlatform, examplePlatform
  , VersionRequirement (..), VersionRefusal (..), ghcupRequirement, ghcRequirement
  , versionNumbers, checkVersion, renderVersionRefusal, versionExamples
  , AdmissionTool (..), AdmissionFault (..), admissionExamples
  ) where
import Data.Char (isDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Text.Read (readMaybe)

data Platform = Platform Text Text deriving (Eq, Ord, Show)
renderPlatform :: Platform -> Text
renderPlatform (Platform os architecture) = os <> "-" <> architecture
-- | A supplied planner fixture, never a requirement on the executing computer.
examplePlatform :: Platform
examplePlatform = Platform "example" "native"
data VersionRequirement = VersionRange Text [Integer] [Integer] | ExactVersion Text [Integer] deriving (Eq, Show)
data VersionRefusal = ToolVersionMalformed Text | ToolVersionMismatch Text deriving (Eq, Show)
ghcupRequirement, ghcRequirement :: VersionRequirement
ghcupRequirement = VersionRange "ghcup" [0, 1, 50, 2] [0, 3]
ghcRequirement = ExactVersion "ghc" [9, 12, 4]
versionNumbers :: Text -> Maybe [Integer]
versionNumbers source = case [value | word <- Text.words source, Just value <- [parse word]] of
  [value] -> Just value
  _ -> Nothing
 where
  parse word = do
    let pieces = Text.splitOn "." (maybe word id (Text.stripPrefix "v" word))
    if length pieces >= 2 && all (\piece -> not (Text.null piece) && Text.all isDigit piece) pieces
      then traverse (readMaybe . Text.unpack) pieces else Nothing
checkVersion :: VersionRequirement -> Text -> Either VersionRefusal [Integer]
checkVersion requirement reported = case versionNumbers reported of
  Nothing -> Left (ToolVersionMalformed tool)
  Just version | accepts version -> Right version
  Just _ -> Left (ToolVersionMismatch tool)
 where
  (tool, accepts) = case requirement of
    VersionRange name lower upper -> (name, \version -> version >= lower && version < upper)
    ExactVersion name expected -> (name, (== expected))

renderVersionRefusal :: VersionRefusal -> Text
renderVersionRefusal refusal = case refusal of
  ToolVersionMalformed tool -> "ToolVersionMalformed: " <> tool
  ToolVersionMismatch tool -> "ToolVersionMismatch: " <> tool

-- | Inputs only. Independent expectations live in the oracle executable.
versionExamples :: [(Text, Text)]
versionExamples = [("ghcup", "0.1.50.1"), ("ghcup", "0.1.50.2"), ("ghcup", "The GHCup Haskell installer, version 0.2.6.2"), ("ghcup", "0.3.0"), ("ghc", "9.12.3"), ("ghc", "9.12.4"), ("ghc", "9.12.5"), ("ghc", "9.13.0"), ("ghc", "9.12.invalid"), ("ghcup", ""), ("ghc", "9.12.4 9.10.1"), ("ghc", "9.12.4.1"), ("ghcup", "0.2"), ("ghcup", "0.3"), ("ghc", "v9.12.4"), ("ghc", "18446744073709551625.12.4")]

-- Inputs for native command-boundary examples; they carry no expected verdict.
data AdmissionTool = InstallerTool | CompilerTool deriving (Eq, Ord, Show)
data AdmissionFault = MissingAdmissionTool | FailedAdmissionCommand | MalformedAdmissionVersion | UnsupportedAdmissionVersion
  deriving (Eq, Ord, Show)
admissionExamples :: [(Text, AdmissionTool, AdmissionFault)]
admissionExamples = [(name, tool, fault)
  | (name, fault) <- [("missing-tool", MissingAdmissionTool), ("failed-command", FailedAdmissionCommand)
                    ,("malformed-version", MalformedAdmissionVersion), ("unsupported-version", UnsupportedAdmissionVersion)]
  , tool <- [InstallerTool, CompilerTool]]

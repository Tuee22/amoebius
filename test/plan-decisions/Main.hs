{-# LANGUAGE OverloadedStrings #-}

-- | The plan-decisions suite: a byte producer, never a verdict.
--
-- It projects the phase-identity table, the roles, the legacy owner map, the decision
-- identifiers, and the frozen baseline into one tab-separated file beneath @.build/**@.
-- The separately authored oracle executable under @test/oracle/doc/Main.hs@ judges those
-- bytes from literals; this program prints no pass or fail token.
module Main (main) where

import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.PhaseIdentity qualified as Identity
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist)
import System.Environment (getArgs)
import System.FilePath (takeDirectory, (</>))

main :: IO ()
main = do
  arguments <- getArgs
  output <- case arguments of
    [path] -> do
      directory <- doesDirectoryExist path
      pure (if directory then path </> "plan-decisions.tsv" else path)
    _ -> pure ".build/runs/phase-00/plan-decisions.tsv"
  createDirectoryIfMissing True (takeDirectory output)
  TextIO.writeFile output (Text.unlines projection)
  putStrLn ("plan-decisions projection written: " <> output)

projection :: [Text]
projection =
  [ Text.intercalate "\t" ["phase", showText (Identity.phaseIdentityOrdinal row), Identity.phaseIdentityCapability row, Text.pack (Identity.phaseIdentityPath row), renderResource (Identity.phaseIdentityResourceProvision row)]
  | row <- Identity.allPhaseIdentities
  ]
    <> [ Text.intercalate "\t" ["predecessor", showText ordinal, maybe "none" showText (Identity.predecessorOrdinal ordinal)]
       | ordinal <- Identity.phaseOrdinals
       ]
    <> [ Text.intercalate "\t" ["successor", showText ordinal, maybe "none" showText (Identity.successorOrdinal ordinal)]
       | ordinal <- Identity.phaseOrdinals
       ]
    <> [ Text.intercalate "\t" ["role", Identity.renderPhaseRole role, maybe "none" showText (Identity.roleOrdinal role)]
       | role <- Identity.allPhaseRoles
       ]
    <> [ Text.intercalate "\t" ["gap", showText (fst Identity.reservedGap), showText (snd Identity.reservedGap)]
       ]
    <> [ Text.intercalate "\t" ["integrity", problem]
       | problem <- Identity.phaseIdentityIntegrityProblems <> Legacy.legacyOwnerProblems
       ]
    <> [ Text.intercalate "\t" ["legacy", Legacy.renderLegacyId identifier, renderOwner (Legacy.legacyOwner identifier), maybe "none" showText (Legacy.legacyOwnerOrdinal identifier)]
       | identifier <- Legacy.allLegacyIds
       ]
    <> [ Text.intercalate "\t" ["decision", Decisions.renderDecisionId identifier]
       | identifier <- Decisions.allDecisionIds
       ]
    <> [ Text.intercalate "\t" ["frozen", Text.pack (Decisions.frozenPath row), Decisions.frozenDigest row, Decisions.renderDecisionId (Decisions.frozenDecision row)]
       | row <- Decisions.frozenBaseline
       ]

renderResource :: Identity.ResourceProvisionRequirement -> Text
renderResource requirement = case requirement of
  Identity.ResourceProvisionAbsent -> "absent"
  Identity.ResourceProvisionRequired -> "required"

renderOwner :: Legacy.LegacyOwner -> Text
renderOwner owner = case owner of
  Legacy.PhaseOwner capability -> capability
  Legacy.LaterPhasesTrack -> "later-phases-track"

showText :: Int -> Text
showText = Text.pack . show

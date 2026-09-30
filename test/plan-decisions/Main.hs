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
import Amoebius.Plan.ValidationRecordPath qualified as ValidationRecordPath
import Data.Maybe (isJust)
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
    <> [ Text.intercalate "\t" ["evidence-path", name, path, if ValidationRecordPath.isValidationRecordPath (Text.unpack path) then "admitted" else "refused"]
       | (name, path) <- evidencePathExamples
       ]
    <> [ Text.intercalate "\t" ["evidence-parser", name, parserFlags path]
       | (name, path) <- [("bundle", goodBundlePath), ("void", goodVoidPath)]
       ]
    <> [ Text.intercalate "\t" ["evidence-parser", "void-fields", voidFields goodVoidPath]
       ]

parserFlags :: Text -> Text
parserFlags path =
  Text.pack (show (isJust (ValidationRecordPath.parseValidationRecordPath textPath)))
    <> ","
    <> Text.pack (show (isJust (ValidationRecordPath.parseValidationVoidPath textPath)))
 where
  textPath = Text.unpack path

voidFields :: Text -> Text
voidFields path = case ValidationRecordPath.parseValidationVoidPath (Text.unpack path) of
  Nothing -> "absent"
  Just parsed -> Text.intercalate ","
    [ ValidationRecordPath.voidGenerationPrefix parsed
    , showText (ValidationRecordPath.voidPhaseOrdinal parsed)
    , ValidationRecordPath.voidTargetBundleDigest parsed
    , ValidationRecordPath.voidDigest parsed
    ]

goodBundlePath :: Text
goodBundlePath = "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> Text.replicate 64 "b" <> "-" <> Text.replicate 64 "c" <> "/receipt.tsv"

goodVoidPath :: Text
goodVoidPath = "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-00-" <> Text.replicate 64 "c" <> "-" <> Text.replicate 64 "d" <> ".tsv"

-- The accepted class is seven exact bundle files and one exact replay-void file
-- shape. Nearby source, fixture, and malformed paths stay outside the exception.
evidencePathExamples :: [(Text, Text)]
evidencePathExamples =
  [ ("receipt", good <> "/receipt.tsv")
  , ("receipt-hash", good <> "/receipt.tsv.sha256")
  , ("candidate", good <> "/candidate.tsv")
  , ("kill-table", good <> "/kill-table.tsv")
  , ("outcome", good <> "/outcome.tsv")
  , ("oracle-ledger", good <> "/oracle-ledger.tsv")
  , ("observer", good <> "/observer.tsv")
  , ("last-phase", lastPhase <> "/receipt.tsv")
  , ("void", goodVoidPath)
  , ("void-last-phase", lastVoid)
  , ("void-missing-suffix", Text.dropEnd 4 goodVoidPath)
  , ("void-sidecar", goodVoidPath <> ".sha256")
  , ("void-markdown", Text.dropEnd 4 goodVoidPath <> ".md")
  , ("void-extra-child", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/child/phase-00-" <> bundleDigest <> "-" <> voidDigest <> ".tsv")
  , ("void-short-generation", "validation-records/generation-abc/voids/phase-00-" <> bundleDigest <> "-" <> voidDigest <> ".tsv")
  , ("void-uppercase-generation", "validation-records/generation-AAAAAAAAAAAAAAAA/voids/phase-00-" <> bundleDigest <> "-" <> voidDigest <> ".tsv")
  , ("void-short-target", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-00-" <> Text.replicate 63 "c" <> "-" <> voidDigest <> ".tsv")
  , ("void-uppercase-target", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-00-" <> Text.replicate 64 "C" <> "-" <> voidDigest <> ".tsv")
  , ("void-short-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-00-" <> bundleDigest <> "-" <> Text.replicate 63 "d" <> ".tsv")
  , ("void-uppercase-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-00-" <> bundleDigest <> "-" <> Text.replicate 64 "D" <> ".tsv")
  , ("void-unregistered-phase", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-10-" <> bundleDigest <> "-" <> voidDigest <> ".tsv")
  , ("void-unpadded-phase", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-0-" <> bundleDigest <> "-" <> voidDigest <> ".tsv")
  , ("void-traversal", "validation-records/generation-aaaaaaaaaaaaaaaa/voids/../phase-00-" <> bundleDigest <> "-" <> voidDigest <> ".tsv")
  , ("void-absolute", "/" <> goodVoidPath)
  , ("void-backslash", Text.replace "/" "\\" goodVoidPath)
  , ("foreign-source", "tools/example.py")
  , ("sibling-tsv", "validation-records/receipt.tsv")
  , ("unknown-file", good <> "/fixture.tsv")
  , ("markdown", good <> "/README.md")
  , ("shell", good <> "/receipt.sh")
  , ("extra-child", good <> "/child/receipt.tsv")
  , ("short-generation", "validation-records/generation-abc/receipts/phase-00-" <> digest <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("uppercase-generation", "validation-records/generation-AAAAAAAAAAAAAAAA/receipts/phase-00-" <> digest <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("short-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> Text.replicate 63 "b" <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("uppercase-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> Text.replicate 64 "B" <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("missing-bundle-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> digest <> "/receipt.tsv")
  , ("short-bundle-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> digest <> "-" <> Text.replicate 63 "c" <> "/receipt.tsv")
  , ("uppercase-bundle-digest", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> digest <> "-" <> Text.replicate 64 "C" <> "/receipt.tsv")
  , ("unregistered-phase", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-10-" <> digest <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("unpadded-phase", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-0-" <> digest <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("traversal", "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/../phase-00-" <> digest <> "-" <> bundleDigest <> "/receipt.tsv")
  , ("absolute", "/" <> good <> "/receipt.tsv")
  , ("backslash", Text.replace "/" "\\" good <> "\\receipt.tsv")
  ]
 where
  digest = Text.replicate 64 "b"
  bundleDigest = Text.replicate 64 "c"
  voidDigest = Text.replicate 64 "d"
  good = "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-00-" <> digest <> "-" <> bundleDigest
  lastPhase = "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-95-" <> digest <> "-" <> bundleDigest
  lastVoid = "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-95-" <> bundleDigest <> "-" <> voidDigest <> ".tsv"

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

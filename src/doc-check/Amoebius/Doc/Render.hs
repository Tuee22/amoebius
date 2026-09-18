{-# LANGUAGE OverloadedStrings #-}

-- | The negative corpus of the documentation checker, rendered from the governed
-- corpus beneath @.build/docs/negatives/<name>/@ (DL-0005). Each negative is one
-- named perturbation of one document and the finding code the checker must report
-- for it. The perturbations are Haskell values here, never conditional-compilation
-- branches inside the checker.
module Amoebius.Doc.Render
  ( Negative (..)
  , firstBlockedPhase
  , negativeCatalogue
  , renderNegative
  , writeCorpus
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

data Negative = Negative
  { negativeName :: Text
  , negativeCode :: Text
  , negativeSubject :: FilePath
  , negativeDetail :: Text
  }
  deriving (Eq, Show)

-- | The closed catalogue: name, expected finding code, perturbed path, and what
-- the perturbation is.
negativeCatalogue :: [Negative]
negativeCatalogue =
  [ Negative "broken-link" "DOC-LINK-TARGET" "documents/README.md" "one link target is retargeted to a Markdown file that does not exist"
  , Negative "stale-backlink" "DOC-BACKLINK-STALE" "documents/glossary.md" "the Referenced-by line declares a source that carries no inbound link"
  , Negative "missing-status-line" "PLAN-PHASE-STATUS" firstBlockedPhase "the first Blocked phase's status line is removed"
  , Negative "non-frontier-status-vector" "PLAN-STATUS-FRONTIER-RECORDED" "DEVELOPMENT_PLAN/README.md" "a second tracker row is set Active while the frontier phase is Active"
  , Negative "unauthorised-frozen-edit" "DOC-FROZEN-BODY-CHANGED" "documents/glossary.md" "a sentence is appended to a frozen body without a decision-log entry"
  , Negative "uncited-module-claim" "DOC-HONESTY-MOOD" "documents/engineering/testing_doctrine.md" "a paragraph names a module in the indicative with no citation, decision link, or owing phase"
  , Negative "gate-spec-block-mismatch" "DOC-GATE-SPEC-MISMATCH" "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" "a line is added inside the fenced gate-spec block of the one phase whose specification is registered"
  , Negative "decision-log-out-of-order" "DOC-DECISION-LOG-ORDER" "documents/decision_log.md" "the last two entry identifiers are swapped"
  , Negative "receipt-line-unexpected" "PLAN-STATUS-RECEIPT-UNEXPECTED" firstBlockedPhase "a receipt line is placed beneath the first Blocked phase's status"
  ]

-- | The subject token that resolves, at render time, to the first phase document
-- (in path order) whose status is Blocked, so the negative follows the frontier.
firstBlockedPhase :: FilePath
firstBlockedPhase = "<first-blocked-phase>"

resolveSubject :: FilePath -> [(FilePath, Text)] -> Maybe FilePath
resolveSubject subject corpus
  | subject == firstBlockedPhase =
      case [path | (path, contents) <- corpus, "DEVELOPMENT_PLAN/phase_" `Text.isPrefixOf` Text.pack path, "\n⏸️ Blocked — NOT VALIDATED.\n" `Text.isInfixOf` contents] of
        [] -> Nothing
        paths -> Just (minimum paths)
  | otherwise = Just subject

-- | Apply one negative to a corpus. The result is Left when the perturbation's
-- anchor text is absent, so a silently unapplied negative cannot pass as a red.
renderNegative :: Negative -> [(FilePath, Text)] -> Either Text [(FilePath, Text)]
renderNegative negative corpus = case resolveSubject (negativeSubject negative) corpus of
  Nothing -> Left ("negative subject cannot be resolved: " <> Text.pack (negativeSubject negative))
  Just subject -> case lookup subject corpus of
    Nothing -> Left ("negative subject absent from the corpus: " <> Text.pack subject)
    Just contents -> do
      perturbed <- perturb (negativeName negative) contents
      pure [(path, if path == subject then perturbed else original) | (path, original) <- corpus]

perturb :: Text -> Text -> Either Text Text
perturb name contents = case name of
  "broken-link" -> replaceOnce "documentation_standards.md)" "documentation_standards_missing.md)" contents
  "stale-backlink" -> replaceOnce "**Referenced by**: " "**Referenced by**: documents/nowhere.md, " contents
  "missing-status-line" -> replaceOnce "\n⏸️ Blocked — NOT VALIDATED.\n" "\n" contents
  "non-frontier-status-vector" -> secondActiveRow contents
  "unauthorised-frozen-edit" -> Right (contents <> "\nThis sentence changes a frozen body without a decision-log entry.\n")
  "uncited-module-claim" -> Right (contents <> "\n`Amoebius.Doc.Check` reports every finding of this corpus today.\n")
  "gate-spec-block-mismatch" -> replaceOnce "```gate-spec\n" "```gate-spec\nperturbed: by-the-negative-renderer\n" contents
  "decision-log-out-of-order" -> swapEntries contents
  "receipt-line-unexpected" -> replaceOnce "\n⏸️ Blocked — NOT VALIDATED.\n" ("\n⏸️ Blocked — NOT VALIDATED.\n**Receipt**: " <> Text.replicate 64 "a" <> "\n") contents
  _ -> Left ("unknown negative: " <> name)

replaceOnce :: Text -> Text -> Text -> Either Text Text
replaceOnce needle replacement haystack = case Text.breakOn needle haystack of
  (before, after)
    | Text.null after -> Left ("perturbation anchor absent: " <> needle)
    | otherwise -> Right (before <> replacement <> Text.drop (Text.length needle) after)

-- | Set the row after the first Active tracker row to Active as well.
secondActiveRow :: Text -> Either Text Text
secondActiveRow contents = case break isActiveRow (Text.lines contents) of
  (before, active : rest) -> case break isBlockedRow rest of
    (between, blocked : after) ->
      Right (Text.unlines (before <> [active] <> between <> [Text.replace "⏸️ Blocked — NOT VALIDATED" "🔄 Active — NOT VALIDATED" blocked] <> after))
    _ -> Left "no Blocked tracker row follows the Active row"
  _ -> Left "no Active tracker row"
 where
  isActiveRow line = "| " `Text.isPrefixOf` line && "🔄 Active — NOT VALIDATED" `Text.isInfixOf` line
  isBlockedRow line = "| " `Text.isPrefixOf` line && "⏸️ Blocked — NOT VALIDATED" `Text.isInfixOf` line

-- | Swap the identifiers of the last two entry headings.
swapEntries :: Text -> Either Text Text
swapEntries contents = case reverse [line | line <- Text.lines contents, "### DL-" `Text.isPrefixOf` line] of
  (lastHeading : previousHeading : _) ->
    let lastId = Text.take 7 (Text.drop 4 lastHeading)
        previousId = Text.take 7 (Text.drop 4 previousHeading)
        swapped line
          | line == lastHeading = "### " <> previousId <> Text.drop 11 lastHeading
          | line == previousHeading = "### " <> lastId <> Text.drop 11 previousHeading
          | otherwise = line
     in Right (Text.unlines (map swapped (Text.lines contents)))
  _ -> Left "fewer than two decision-log entries"

-- | Write a corpus beneath a root, creating directories as needed.
writeCorpus :: FilePath -> [(FilePath, Text)] -> IO ()
writeCorpus root corpus = mapM_ writeOne corpus
 where
  writeOne (path, contents) = do
    createDirectoryIfMissing True (takeDirectory (root </> path))
    TextIO.writeFile (root </> path) contents

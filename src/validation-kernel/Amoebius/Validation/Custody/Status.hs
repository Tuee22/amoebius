{-# LANGUAGE OverloadedStrings #-}
-- | Status acquisition and one-frontier projection (DL-0009).
module Amoebius.Validation.Custody.Status
  ( StatusSurface (..), patchToFrontier, recordedFrontier, statusSurface, surfaceConsistent, surfaceDigest ) where
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.Runner.Observer (sha256Hex, renderTsv)
import Amoebius.Validation.Runner.Hygiene (readSourceText, sourceAttempt)
import Data.Char (isDigit)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesFileExist)
import System.FilePath ((</>))
data StatusSurface = StatusSurface
  { surfaceTracker :: [(Int, Int, Text)] -- phase, line number, status cell
  , surfacePhaseLines :: [(Int, Int, Text)] -- phase, line number, status line
  , surfaceSprints :: [(Int, Int, Int, Text, Text)] -- phase, sprint, heading line, heading, status field line
  , surfaceReceipts :: [(Int, Text)] -- phase, receipt digest recorded beside a Done status
  } deriving (Eq, Show)
trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"
statusSurface :: FilePath -> IO (Either Text StatusSurface)
statusSurface root = either Left id <$> sourceAttempt (do
  trackerExists <- doesFileExist (root </> trackerPath)
  if not trackerExists
    then pure (Left "tracker absent")
    else do
      tracker <- readSourceText (root </> trackerPath)
      phases <- mapM (readPhase root) PhaseIdentity.allPhaseIdentities
      pure (Right StatusSurface
        { surfaceTracker = mapMaybe trackerRow (zip [1 ..] (Text.lines tracker))
        , surfacePhaseLines = concat [lines' | (lines', _, _) <- phases]
        , surfaceSprints = concat [sprints | (_, sprints, _) <- phases]
        , surfaceReceipts = concat [receipts | (_, _, receipts) <- phases] }))
trackerRow :: (Int, Text) -> Maybe (Int, Int, Text)
trackerRow (number, line) = case map Text.strip (Text.splitOn "|" line) of
  ("" : ordinalText : _ : _ : _ : _ : status : _ : _)
    | not (Text.null ordinalText) && Text.all isDigit ordinalText ->
        Just (read (Text.unpack ordinalText), number, status)
  _ -> Nothing
readPhase :: FilePath -> PhaseIdentity.PhaseIdentity -> IO ([(Int, Int, Text)], [(Int, Int, Int, Text, Text)], [(Int, Text)])
readPhase root row = do
  let path = root </> PhaseIdentity.phaseIdentityPath row
      ordinal = PhaseIdentity.phaseIdentityOrdinal row
  exists <- doesFileExist path
  if not exists
    then pure ([], [], [])
    else do
      contents <- readSourceText path
      let numbered = zip [1 ..] (Text.lines contents)
          statusBody = case dropWhile ((/= "## Phase Status") . snd) numbered of
            (_ : rest) -> filter (not . Text.null . Text.strip . snd) (takeWhile (not . ("## " `Text.isPrefixOf`) . snd) rest)
            [] -> []
          statusLine = case statusBody of
            ((number, line) : _) -> [(ordinal, number, line)]
            [] -> []
          receipt = case statusBody of
            (_ : (_, line) : _) | Just digest <- Text.stripPrefix receiptPrefix line -> [(ordinal, Text.strip digest)]
            _ -> []
          sprints =
            [ (ordinal, sprint, number, heading, statusField)
            | (number, heading) <- numbered
            , Just sprint <- [sprintOrdinal ordinal heading]
            , let statusField = case [line | (n, line) <- numbered, n > number, "**Status**:" `Text.isPrefixOf` line] of
                    (line : _) -> line
                    [] -> ""
            ]
      pure (statusLine, sprints, receipt)
receiptPrefix :: Text
receiptPrefix = "**Receipt**: "
sprintOrdinal :: Int -> Text -> Maybe Int
sprintOrdinal ordinal heading = do
  rest <- Text.stripPrefix ("## Sprint " <> Text.pack (show ordinal) <> ".") heading
  let digits = Text.takeWhile isDigit rest
  if Text.null digits then Nothing else Just (read (Text.unpack digits))
recordedFrontier :: StatusSurface -> Maybe Status.StatusFrontier
recordedFrontier surface = do
  statuses <- mapM (\ordinal -> lookup ordinal [(phase, status) | (phase, _, status) <- surfaceTracker surface] >>= Status.parseTrackerStatus) PhaseIdentity.phaseOrdinals
  Status.recognizeStatusFrontier statuses
surfaceDigest :: StatusSurface -> Text
surfaceDigest surface =
  sha256Hex (renderTsv
    ([[Text.pack (show phase), "tracker", status] | (phase, _, status) <- surfaceTracker surface] <>
     [[Text.pack (show phase), "phase", line] | (phase, _, line) <- surfacePhaseLines surface] <>
     [[Text.pack (show phase), "sprint", Text.pack (show sprint), heading, status] | (phase, sprint, _, heading, status) <- surfaceSprints surface] <>
     [[Text.pack (show phase), "receipt", digest] | (phase, digest) <- surfaceReceipts surface]))
-- Structural agreement only; this establishes no gate or receipt authority.
surfaceConsistent :: StatusSurface -> Bool
surfaceConsistent surface = case recordedFrontier surface of
  Nothing -> False
  Just frontier -> map (\(phase, _, _) -> phase) (surfaceTracker surface) == ordinals
    && map (\(phase, _, _) -> phase) (surfacePhaseLines surface) == ordinals
    && all (\(phase, _, line) -> line == Status.renderPhaseStatusLine (Status.phaseStatusAt frontier phase)) (surfacePhaseLines surface)
    && map fst (surfaceReceipts surface) == [phase | phase <- ordinals, Status.phaseStatusAt frontier phase == Status.Done]
    && all (\(_, digest) -> Text.length digest == 64 && Text.all (\c -> c >= '0' && c <= '9' || c >= 'a' && c <= 'f') digest) (surfaceReceipts surface)
    && all (\phase -> let rows = [sprint | (p, sprint, _, _, _) <- surfaceSprints surface, p == phase] in not (null rows) && rows == [1 .. length rows]) ordinals
    && all (\(phase, sprint, _, heading, status) -> let wanted = Status.sprintStatusAt frontier phase sprint in
      status == "**Status**: " <> Status.renderSprintStatus wanted && Status.renderStatusMarker wanted `Text.isSuffixOf` heading) (surfaceSprints surface)
 where ordinals = PhaseIdentity.phaseOrdinals
-- | Return changed frontier/receipt contents without writing files.
patchToFrontier :: FilePath -> Status.StatusFrontier -> Map.Map Int Text -> IO [(FilePath, Text)]
patchToFrontier root frontier receipts = do
  tracker <- readSourceText (root </> trackerPath)
  let tracker' = Text.unlines (map patchTrackerLine (Text.lines tracker))
  phases <- mapM patchPhase PhaseIdentity.allPhaseIdentities
  pure ([(trackerPath, tracker') | tracker' /= tracker] <> concat phases)
 where
  patchTrackerLine line = case trackerRow (0, line) of
    Just (phase, _, status) ->
      let cells = Text.splitOn "|" line
          expected = Status.renderTrackerStatus (Status.phaseStatusAt frontier phase)
       in if Text.strip status == expected then line else Text.intercalate "|" (take 6 cells <> [" " <> expected <> " "] <> drop 7 cells)
    Nothing -> line
  patchPhase row = do
    let path = PhaseIdentity.phaseIdentityPath row
        ordinal = PhaseIdentity.phaseIdentityOrdinal row
    exists <- doesFileExist (root </> path)
    if not exists
      then pure []
      else do
        contents <- readSourceText (root </> path)
        let lines' = Text.lines contents
            statusIndex = case break (== "## Phase Status") lines' of
              (before, _ : rest) -> Just (length before + 1 + length (takeWhile (Text.null . Text.strip) rest))
              _ -> Nothing
            patched = withReceipt ordinal statusIndex (zipWith (patchPhaseLine ordinal statusIndex lines') [0 ..] lines')
            contents' = Text.unlines patched
        pure [(path, contents') | contents' /= contents]
  withReceipt ordinal statusIndex lines' = case statusIndex of
    Nothing -> lines'
    Just index ->
      let (before, rest) = splitAt (index + 1) lines'
          (existing, after) = case rest of
            (line : more) | receiptPrefix `Text.isPrefixOf` line -> ([line], more)
            _ -> ([], rest)
          wanted = case (Status.phaseStatusAt frontier ordinal, Map.lookup ordinal receipts) of
            (Status.Done, Just digest) -> [receiptPrefix <> digest]
            _ -> []
       in existing `seq` before <> wanted <> after
  patchPhaseLine ordinal statusIndex lines' index line
    | Just index == statusIndex = Status.renderPhaseStatusLine (Status.phaseStatusAt frontier ordinal)
    | Just sprint <- sprintOrdinal ordinal line =
        let marker = Status.renderStatusMarker (Status.sprintStatusAt frontier ordinal sprint)
            base = Text.stripEnd (Text.dropWhileEnd (`elem` ("🔄⏸️✅ " :: String)) line)
         in base <> " " <> marker
    | "**Status**:" `Text.isPrefixOf` line =
        case owningSprint ordinal (take index lines') of
          Just sprint -> "**Status**: " <> Status.renderSprintStatus (Status.sprintStatusAt frontier ordinal sprint)
          Nothing -> line
    | otherwise = line
  owningSprint ordinal previous = case mapMaybe (sprintOrdinal ordinal) (reverse previous) of
    (sprint : _) -> Just sprint
    [] -> Nothing

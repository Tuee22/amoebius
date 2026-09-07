-- | One selector command line for every mutation-selector suite.
--
-- Four suites previously hand-copied this dispatcher, and the copies had
-- drifted: three defaulted a bare invocation to @--all@ and one failed, two
-- spelled the exact-case listing @--cases@ and one @--case-list@, and only some
-- offered @--impacted@ or @--control@. A selector harness whose invocation
-- grammar differs per suite cannot be driven uniformly, so the per-gate
-- relevance rule could not be applied across suites at all.
--
-- A suite declares the operations it actually supports. Asking for one it does
-- not support is refused by name rather than silently accepted, so the record
-- stays an honest description of the suite's capability.
module SelectorCli
  ( SelectorSuite (..)
  , selectorSuite
  , runSelectorCli
  ) where

import Control.Exception (SomeException, try)
import Control.Monad (forM, forM_, unless)
import System.Environment (getArgs)
import System.Exit (exitFailure)

data SelectorSuite = SelectorSuite
  { suiteName :: String
  , suiteRunAll :: IO ()
  , suiteSelectorNames :: [String]
  , suiteExactCaseNames :: [String]
  , suiteRunSelector :: String -> IO ()
  , suiteRunExactCase :: Maybe (String -> IO ())
  , suiteRunImpacted :: Maybe (String -> IO ())
  , suiteRunUnaffected :: Maybe (String -> IO ())
  , suiteRunControl :: Maybe (String -> IO ())
  , suiteAssignments :: [(String, [String], String)]
  }

-- | A suite that supports only the two mandatory operations. Each real suite
-- overrides the fields it implements, so an unimplemented operation is a
-- 'Nothing' rather than a copied stub.
selectorSuite :: String -> IO () -> (String -> IO ()) -> SelectorSuite
selectorSuite name runAll runSelector =
  SelectorSuite
    { suiteName = name
    , suiteRunAll = runAll
    , suiteSelectorNames = []
    , suiteExactCaseNames = []
    , suiteRunSelector = runSelector
    , suiteRunExactCase = Nothing
    , suiteRunImpacted = Nothing
    , suiteRunUnaffected = Nothing
    , suiteRunControl = Nothing
    , suiteAssignments = []
    }

runSelectorCli :: SelectorSuite -> IO ()
runSelectorCli suite = do
  arguments <- getArgs
  case arguments of
    [] -> suiteRunAll suite
    ["--all"] -> suiteRunAll suite
    ["--list"] -> mapM_ putStrLn (suiteSelectorNames suite)
    ["--cases"] -> mapM_ putStrLn (suiteExactCaseNames suite)
    ["--case-list"] -> mapM_ putStrLn (suiteExactCaseNames suite)
    ["--assignments"] ->
      forM_ (suiteAssignments suite) $ \(selector, impacts, control) ->
        putStrLn (selector <> "\t" <> commaSeparated impacts <> "\t" <> control)
    ["--qualify", selector] -> qualifySelector suite selector
    ["--case", label] -> withOperation "--case" (suiteRunExactCase suite) label
    ["--case-results"] -> runCaseResults suite
    ["--impacted", selector] -> withOperation "--impacted" (suiteRunImpacted suite) selector
    ["--unaffected", selector] -> withOperation "--unaffected" (suiteRunUnaffected suite) selector
    ["--control", selector] -> withOperation "--control" (suiteRunControl suite) selector
    [selector] -> suiteRunSelector suite selector
    _ -> fail (usage suite)
 where
  withOperation verb operation argument = case operation of
    Just run -> run argument
    Nothing -> fail (suiteName suite <> " does not support " <> verb <> "; " <> usage suite)

-- | Observe one already-compiled changed subject at its independently
-- assigned locus and retain an unrelated same-binary control. The Cabal
-- supervisor owns compilation with exactly one selector enabled.
qualifySelector :: SelectorSuite -> String -> IO ()
qualifySelector suite selector = case assignments of
  [(impacts, control)] -> do
    unless (selector `elem` suiteSelectorNames suite) $
      fail (suiteName suite <> " qualification selector is absent from the closed selector inventory: " <> selector)
    unless (not (null impacts) && not (null control)) $
      fail (suiteName suite <> " qualification assignment is empty: " <> selector)
    case suiteRunImpacted suite of
      Just runImpacted -> runImpacted selector
      Nothing -> do
        attempted <- try (suiteRunSelector suite selector)
        case (attempted :: Either SomeException ()) of
          Right () -> fail (suiteName suite <> " changed subject left its assigned locus green: " <> selector)
          Left _ -> pure ()
    case suiteRunUnaffected suite of
      Just runUnaffected -> runUnaffected selector
      Nothing -> pure ()
    case suiteRunControl suite of
      Just runControl -> runControl selector
      Nothing -> unless (present (suiteRunUnaffected suite)) $
        fail (suiteName suite <> " qualification has no unaffected control runner: " <> selector)
    putStrLn ("selector-qualification: PASS: " <> selector <> " -> " <> commaSeparated impacts <> "; control=" <> control)
  [] -> fail (suiteName suite <> " qualification assignment is missing: " <> selector)
  _ -> fail (suiteName suite <> " qualification assignment is duplicated: " <> selector)
 where
  assignments = [(impacts, control) | (candidate, impacts, control) <- suiteAssignments suite, candidate == selector]
  present value = case value of
    Just _ -> True
    Nothing -> False

runCaseResults :: SelectorSuite -> IO ()
runCaseResults suite = case suiteRunExactCase suite of
  Nothing -> fail (suiteName suite <> " does not support --case-results; " <> usage suite)
  Just runExactCase -> do
    outcomes <-
      forM (suiteExactCaseNames suite) $ \label -> do
        attempted <- try (runExactCase label)
        let succeeded = case (attempted :: Either SomeException ()) of
              Right () -> True
              Left _ -> False
        putStrLn (label <> "\t" <> if succeeded then "PASS" else "FAIL")
        pure succeeded
    unless (and outcomes) exitFailure

usage :: SelectorSuite -> String
usage suite =
  "expected no argument, one SELECTOR, or one of: "
    <> commaSeparated (["--all", "--list", "--cases", "--case-list", "--assignments", "--qualify SELECTOR"] <> optional)
 where
  optional =
    [verb | (verb, supported) <- offered, supported]
  offered =
    [ ("--case LABEL", present (suiteRunExactCase suite))
    , ("--case-results", present (suiteRunExactCase suite))
    , ("--impacted SELECTOR", present (suiteRunImpacted suite))
    , ("--unaffected SELECTOR", present (suiteRunUnaffected suite))
    , ("--control SELECTOR", present (suiteRunControl suite))
    ]
  present value = case value of
    Just _ -> True
    Nothing -> False

commaSeparated :: [String] -> String
commaSeparated values = case values of
  [] -> ""
  first : rest -> first <> concatMap (", " <>) rest

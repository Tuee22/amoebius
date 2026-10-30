-- | Tree-derived kernel shape and vocabulary checks (AGENTS.md "Kernel Budget").
module Amoebius.Validation.Runner.Hygiene
  ( HygieneReport (..), CapturedSource, captureSource, capturedSourceDigest, capturedSourceFiles, capturedSourceBytes
  , capturedSourceRuns, parseSourceInventory, docCheckRoot, hygieneGreen, hygieneProblems, hygieneRow, kernelBudget
  , kernelRoots, isRunModule, phaseLiteral, haskellFilesUnder, materializeSource, verifySourceCopy
  , rewriteCapturedSource, runRootWithinFrame, renderHygiene, vocabularyTypes, TreePurpose (..), TreeNode (..), classifyTreeNode, walkFilesUnder, walkFilesUnderWith, sourceAttempt, readSourceBytes, readSourceText ) where
import Amoebius.Validation.Authority.Core

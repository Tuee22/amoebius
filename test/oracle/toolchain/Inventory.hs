{-# LANGUAGE OverloadedStrings #-}
-- | No-input declaration authored from this oracle's existing judgments.
-- The suite profile excludes the separately owned shipped-binary challenge.
module Inventory (toolchainInventoryNames) where

import Data.Text (Text)
import Data.Text qualified as Text

toolchainInventoryNames :: Bool -> [Text]
toolchainInventoryNames withBinary =
  ["version.case." <> Text.pack (show index) | index <- [1 :: Int .. 16]]
  <> ["version.discovery", "versions.verdict", "second.verdict", "report.versions.verdict"
     ,"report.request.positive", "report.request.negative", "negative.ReportUnknownArgument"
     ,"report.probe.decode.positive", "report.probe.decode.mistyped", "report.probe.sim.clean"
     ,"report.probe.sim.perturbed", "report.probe.codegen.link-token", "report.probe.bridge.files"
     ,"report.provenance.fork-modules", "probe.decode.positive", "probe.decode.mistyped"
     ,"probe.sim.clean", "probe.sim.perturbed", "fork.modules", "fork.problems", "layout.problems"
     ,"upstream.verdict", "probe.codegen.files", "plan.packages", "report.provenance.upstream"]
  <> ["negative." <> name | name <- ["MissingTool", "MalformedVersion", "UnsupportedVersion"
     ,"UnsupportedGhcupVersion", "FailedVersionCommand", "TrackedResolutionOutput", "TrackedProbeInput"
     ,"MutableIdentity", "TopLevelVendor", "AbsentTool", "OutOfRangeVersion", "NoPlatformAsset"
     ,"UpstreamDigestMismatch"]]
  <> ["negative.MissingDependency", "report.probe.source.findings", "report.provenance.layout"
     ,"report.resolution.source.findings", "report.probe.discovery", "report.plan.steps", "plan.steps"
     ,"child.absent.exit", "child.absent.stdout", "child.absent.stderr", "child.failed-cwd.exit"
     ,"child.failed-cwd.stdout", "child.failed-cwd.stderr", "second.mismatch.ghcup", "second.mismatch.compiler"
     ,"second.cabal-version", "versions.cabal-report-unavailable", "report.cli.unknown.exit"
     ,"report.cli.unknown.stderr", "report.cli.emit.exit", "report.cli.run.exit", "report.cli.run.stdout"]
  <> [name | withBinary, name <- ["binary.input-contract", "binary.nonce-recovered"
     ,"binary.version-request-refused", "binary.native-versions-admitted"]]
  <> ["report.cli.request", "report.cli.label", "report.cli.refusal", "report.cli.acquisition", "report.cli.native"
     ,"case:report.cli.plan-a", "case:report.cli.plan-b", "case:report.cli.plans-agree", "case:report.cli.source"
     ,"admission.discovery"]
  <> ["admission." <> name <> "." <> role | name <- ["missing-tool", "failed-command", "malformed-version"
     ,"unsupported-version"], role <- ["positive", "negative"]]
  <> ["admission.control.cleanup", "probe-source.discovery"]
  <> ["probe-source." <> name <> "." <> role | name <- ["foreign-probe-script", "foreign-probe-fixture"
     ,"probe-case-omitted"], role <- ["positive", "negative"]]
  <> ["probe-source.control.inventory", "probe-source.control.cleanup", "vendor-source.discovery"]
  <> ["vendor-source." <> name <> "." <> role | name <- ["top-level-vendor", "mutable-reference"
     ,"tracked-vendor-proto", "tracked-foreign-package", "tracked-patch-program"], role <- ["positive", "negative"]]
  <> ["vendor-source.control.fork", "vendor-source.control.cleanup", "case:simulation.terminal-pair"
     ,"case:planner.paired-remedies", "case:resolution.source-pairs", "case:build.fixed-serial-arguments"]
  <> ["case:resolution." <> name | name <- ["first-plan", "second-plan", "agreement", "disagreement"
     ,"dropped-allowance", "outside-root", "authored-unchanged", "generated-ignored"]]
  <> ["case:upstream." <> name | name <- ["cache-positive", "supplied-cache-positive", "cache-only-query"
     ,"digest-negative", "missing-cache-negative", "absent-identity"]]

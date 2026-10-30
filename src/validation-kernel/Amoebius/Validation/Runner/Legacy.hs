-- | Untrusted analyzer reports and their prequalification audit. No pass authority.
module Amoebius.Validation.Runner.Legacy
( LegacyFinding (..), LegacyObservation (..), LegacyReport (..), legacyRequirementsAt, observeLegacy, observeLegacyMany, auditLegacyReports, renderLegacyReports, LegacyCollection, collectLegacy, inheritLegacyCollection, auditLegacyCollection, legacyCollectionRuns, legacyCollectionEvidence, legacyQualificationSupported, LegacyQualification, qualifyLegacy, qualifiedLegacyReports, auditQualifiedLegacyReports, runLegacyProbe, runAuthorityObservation, runSolverReintroductions, readImages ) where
import Amoebius.Validation.Authority.Core

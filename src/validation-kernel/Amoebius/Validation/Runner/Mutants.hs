-- | Generate mutations in captured source copies from a fixed catalogue and
module Amoebius.Validation.Runner.Mutants
( KillTable (..), Locus (..), MutantOutcome (..), Operator (..), SubjectChangeWitness (..), allOperators, applyLocus, renderMutantOutcome, enumerateLoci, isAttributed, truncateListLocus, killTable, renderKillTable, renderOperator, sampleLoci ) where
import Amoebius.Validation.Authority.Core

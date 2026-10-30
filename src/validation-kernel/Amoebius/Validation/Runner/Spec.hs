-- | Derive source-bound subject, closure and oracle contracts (gate_runner_doctrine.md section 3).
module Amoebius.Validation.Runner.Spec
( PackageGraph (..), SpecProblem (..), VerifiedSpec (..), executableClosure, libraryClosure, internalDependencies, loadPackageGraph, moduleSourcePath, parsePackageGraph, renderSpecProblem, verifySpec, verifySpecAgainst, verifyOracle, sourceTokens, sourceTree, sourceDirectives, compiledBlocks, resolveSpec, bindPhaseSpec, roleFor, requiredSuiteRows ) where
import Amoebius.Validation.Authority.Core

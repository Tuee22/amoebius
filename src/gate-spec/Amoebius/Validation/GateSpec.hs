{-# LANGUAGE OverloadedStrings #-}

-- | The gate-specification vocabulary (gate_runner_doctrine.md section 2).
--
-- A 'GateSpec' is the one typed description of a phase gate that the generic runner
-- consumes. The constructor is not exported: every value passes 'mkGateSpec', which
-- refuses a validator subject, a non-seed specification without a 'BinaryFact', a
-- barrier specification without a 'SpineFact', and a seed that carries facts of its
-- own. The library depends on base, containers, and text only, so a phase document,
-- the runner, and the plan can all name the same value.
module Amoebius.Validation.GateSpec
  ( GateSpec
  , GateSpecInput (..)
  , GateRole (..)
  , GateCategory (..)
  , ProductionModule (..)
  , OracleExecutable (..)
  , CabalTarget (..)
  , ExactCase (..)
  , MutantPolicy (..)
  , BinaryFact (..)
  , Perturbation (..)
  , SpineFact (..)
  , Substrate (..)
  , SeedSpec (..)
  , SpecRefusal (..)
  , allGateCategories
  , defaultMutantPolicy
  , gateBinaryFact
  , gateCapability
  , gateCases
  , gateClaim
  , gateMutants
  , gateOracle
  , gateRole
  , gateSeed
  , gateSpineFact
  , gateSubjects
  , gateSubstrate
  , gateSuite
  , isValidatorModule
  , mkGateSpec
  , renderGateCategory
  , renderGateSpec
  , renderSpecRefusal
  , renderSubstrate
  , substrateCatalogue
  ) where

import Data.List (isPrefixOf, nub)
import Data.Ratio (denominator, numerator)
import Data.Text (Text)
import Data.Text qualified as Text

-- | A module inside the transitive closure of the shipped @amoebius@ executable.
newtype ProductionModule = ProductionModule {productionModuleName :: Text}
  deriving (Eq, Ord, Show)

-- | The separate oracle executable for an area: a test-suite stanza whose entry
-- module is @test/oracle/<area>/Main.hs@ and whose dependencies name no
-- @amoebius@ library.
newtype OracleExecutable = OracleExecutable {oracleExecutableName :: Text}
  deriving (Eq, Ord, Show)

-- | The suite that writes bytes for the oracle to judge.
newtype CabalTarget = CabalTarget {cabalTargetName :: Text}
  deriving (Eq, Ord, Show)

-- | One positive control or paired negative.
data ExactCase
  = PositiveControl
      { caseName :: Text
      , caseInput :: Text
      , caseExpected :: Text
      }
  | PairedNegative
      { caseName :: Text
      , caseInput :: Text
      , caseTag :: Text
      , caseStage :: Text
      }
  deriving (Eq, Ord, Show)

-- | The generated-mutant policy: which stage modules, how many per module, the
-- per-gate cap, and the kill ratio over viable mutants.
data MutantPolicy = MutantPolicy
  { stageModules :: [ProductionModule]
  , perModule :: Int
  , perGateCap :: Int
  , killRatio :: Rational
  }
  deriving (Eq, Ord, Show)

defaultMutantPolicy :: [ProductionModule] -> MutantPolicy
defaultMutantPolicy modules =
  MutantPolicy
    { stageModules = modules
    , perModule = 8
    , perGateCap = 40
    , killRatio = 3 / 5
    }

-- | The runner's rewrite of a binary-fact input after the run starts.
data Perturbation
  = SentinelToNonce {perturbationSentinel :: Text}
  | ReplicaCount {perturbationFrom :: Int, perturbationTo :: Int}
  deriving (Eq, Ord, Show)

-- | A public product command, the perturbation applied to its input, and the
-- output files the runner digests. The token @{input}@ in the command is the
-- perturbed input path; @{run}@ is the run root.
data BinaryFact = BinaryFact
  { factCommand :: [Text]
  , factInput :: FilePath
  , factPerturbation :: Perturbation
  , factOutputs :: [FilePath]
  }
  deriving (Eq, Ord, Show)

-- | The rendered example, the ordered stages, and the applied-digest file that
-- must equal the render digest.
data SpineFact = SpineFact
  { spineRendered :: FilePath
  , spineStages :: [Text]
  , spineAppliedDigestFile :: FilePath
  }
  deriving (Eq, Ord, Show)

-- | @HardwareFree@ or one member of the closed substrate catalogue (DL-0001).
data Substrate
  = HardwareFree
  | LinuxCpu
  | LinuxCuda
  | Apple
  | Windows
  deriving (Bounded, Enum, Eq, Ord, Show)

substrateCatalogue :: [Substrate]
substrateCatalogue = [minBound .. maxBound]

renderSubstrate :: Substrate -> Text
renderSubstrate substrate = case substrate of
  HardwareFree -> "none"
  LinuxCpu -> "linux-cpu"
  LinuxCuda -> "linux-cuda"
  Apple -> "apple"
  Windows -> "windows"

-- | The finite Phase-0 bootstrap seed: the three predicate cases and the custody
-- probes, run by the seed protocol rather than by generated mutants.
data SeedSpec = SeedSpec
  { seedPredicateCases :: [Text]
  , seedCustodyProbes :: [Text]
  }
  deriving (Eq, Ord, Show)

-- | The role the phase table assigns to a gate; the runner resolves it through
-- the identity table and the constructor checks the facts the role requires.
data GateRole
  = SeedGate
  | OrdinaryGate
  | BarrierGate
  | HardwareGate
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | The eighteen candidate rows of gate integrity section M.1, in order.
data GateCategory
  = Claim
  | Subject
  | Command
  | Oracle
  | PositiveControls
  | PairedNegatives
  | Mutants
  | Discovery
  | Challenge
  | Observer
  | AuthorityBypass
  | Freshness
  | Qualification
  | Cleanroom
  | LegacyClosure
  | Predecessor
  | Residue
  | PassCriterion
  deriving (Bounded, Enum, Eq, Ord, Show)

allGateCategories :: [GateCategory]
allGateCategories = [minBound .. maxBound]

renderGateCategory :: GateCategory -> Text
renderGateCategory category = case category of
  Claim -> "Claim"
  Subject -> "Subject"
  Command -> "Command"
  Oracle -> "Oracle"
  PositiveControls -> "Positive controls"
  PairedNegatives -> "Paired negatives"
  Mutants -> "Mutants"
  Discovery -> "Discovery"
  Challenge -> "Challenge"
  Observer -> "Observer"
  AuthorityBypass -> "Authority/bypass"
  Freshness -> "Freshness"
  Qualification -> "Qualification"
  Cleanroom -> "Cleanroom"
  LegacyClosure -> "Legacy closure"
  Predecessor -> "Predecessor"
  Residue -> "Residue"
  PassCriterion -> "Pass criterion"

-- | The caller's proposal; 'mkGateSpec' turns it into a 'GateSpec' or refuses.
data GateSpecInput = GateSpecInput
  { inputCapability :: Text
  , inputClaim :: Text
  , inputSubjects :: [ProductionModule]
  , inputSuite :: CabalTarget
  , inputOracle :: OracleExecutable
  , inputCases :: [ExactCase]
  , inputMutants :: MutantPolicy
  , inputBinaryFact :: Maybe BinaryFact
  , inputSpineFact :: Maybe SpineFact
  , inputSubstrate :: Substrate
  , inputSeed :: Maybe SeedSpec
  }
  deriving (Eq, Show)

-- | A verified specification. The constructor is private.
data GateSpec = GateSpec
  { gateRole :: GateRole
  , gateCapability :: Text
  , gateClaim :: Text
  , gateSubjects :: [ProductionModule]
  , gateSuite :: CabalTarget
  , gateOracle :: OracleExecutable
  , gateCases :: [ExactCase]
  , gateMutants :: MutantPolicy
  , gateBinaryFact :: Maybe BinaryFact
  , gateSpineFact :: Maybe SpineFact
  , gateSubstrate :: Substrate
  , gateSeed :: Maybe SeedSpec
  }
  deriving (Eq, Show)

data SpecRefusal
  = KernelSubject ProductionModule
  | EmptySubjects
  | EmptyClaim
  | EmptyCases
  | MissingBinaryFact
  | MissingSpineFact
  | SeedCarriesBinaryFact
  | SeedCarriesSpineFact
  | SeedAbsent
  | SeedOutsideSeedRole
  | SpineOutsideBarrier
  | HardwareSubstrateOutsideHardwareRole Substrate
  | HardwareRoleWithoutSubstrate
  | StageModuleNotSubject ProductionModule
  | MutantPolicyOutOfBounds
  | DuplicateCaseName Text
  | EmptyBinaryFactOutputs
  deriving (Eq, Ord, Show)

renderSpecRefusal :: SpecRefusal -> Text
renderSpecRefusal refusal = case refusal of
  KernelSubject (ProductionModule name) -> "SUBJECT-NOT-SHIPPED: " <> name
  EmptySubjects -> "SUBJECT-EMPTY"
  EmptyClaim -> "CLAIM-EMPTY"
  EmptyCases -> "CASES-EMPTY"
  MissingBinaryFact -> "BINARY-FACT-MISSING"
  MissingSpineFact -> "SPINE-FACT-MISSING"
  SeedCarriesBinaryFact -> "SEED-CARRIES-BINARY-FACT"
  SeedCarriesSpineFact -> "SEED-CARRIES-SPINE-FACT"
  SeedAbsent -> "SEED-ABSENT"
  SeedOutsideSeedRole -> "SEED-OUTSIDE-SEED-ROLE"
  SpineOutsideBarrier -> "SPINE-OUTSIDE-BARRIER"
  HardwareSubstrateOutsideHardwareRole substrate -> "HARDWARE-BEFORE-BARRIER: " <> renderSubstrate substrate
  HardwareRoleWithoutSubstrate -> "SUBSTRATE-ABSENT"
  StageModuleNotSubject (ProductionModule name) -> "STAGE-MODULE-NOT-SUBJECT: " <> name
  MutantPolicyOutOfBounds -> "MUTANT-POLICY-OUT-OF-BOUNDS"
  DuplicateCaseName name -> "CASE-DUPLICATE: " <> name
  EmptyBinaryFactOutputs -> "BINARY-FACT-NO-OUTPUTS"

-- | A validator module can never be a subject: the runner, the checker, the plan
-- library, and the retained custody core all live under these prefixes.
isValidatorModule :: ProductionModule -> Bool
isValidatorModule (ProductionModule name) =
  any (`isPrefixOf` Text.unpack name) ["Amoebius.Validation.", "Amoebius.Doc.", "Amoebius.Plan."]

-- | The smart constructor. Every refusal is reported, not just the first.
mkGateSpec :: GateRole -> GateSpecInput -> Either [SpecRefusal] GateSpec
mkGateSpec role input = case refusals of
  [] ->
    Right
      GateSpec
        { gateRole = role
        , gateCapability = inputCapability input
        , gateClaim = inputClaim input
        , gateSubjects = inputSubjects input
        , gateSuite = inputSuite input
        , gateOracle = inputOracle input
        , gateCases = inputCases input
        , gateMutants = inputMutants input
        , gateBinaryFact = inputBinaryFact input
        , gateSpineFact = inputSpineFact input
        , gateSubstrate = inputSubstrate input
        , gateSeed = inputSeed input
        }
  problems -> Left problems
 where
  policy = inputMutants input
  names = map caseName (inputCases input)
  refusals =
    concat
      [ [KernelSubject subject | role /= SeedGate, subject <- inputSubjects input, isValidatorModule subject]
      , [EmptySubjects | null (inputSubjects input)]
      , [EmptyClaim | Text.null (Text.strip (inputClaim input))]
      , [EmptyCases | null (inputCases input)]
      , [MissingBinaryFact | role /= SeedGate, inputBinaryFact input == Nothing]
      , [MissingSpineFact | role == BarrierGate, inputSpineFact input == Nothing]
      , [SpineOutsideBarrier | role /= BarrierGate, inputSpineFact input /= Nothing]
      , [SeedCarriesBinaryFact | role == SeedGate, inputBinaryFact input /= Nothing]
      , [SeedCarriesSpineFact | role == SeedGate, inputSpineFact input /= Nothing]
      , [SeedAbsent | role == SeedGate, inputSeed input == Nothing]
      , [SeedOutsideSeedRole | role /= SeedGate, inputSeed input /= Nothing]
      , [HardwareSubstrateOutsideHardwareRole (inputSubstrate input) | role /= HardwareGate, inputSubstrate input /= HardwareFree]
      , [HardwareRoleWithoutSubstrate | role == HardwareGate, inputSubstrate input == HardwareFree]
      , [StageModuleNotSubject stage | stage <- stageModules policy, stage `notElem` inputSubjects input]
      , [MutantPolicyOutOfBounds | perModule policy < 1 || perGateCap policy < perModule policy || killRatio policy <= 0 || killRatio policy > 1]
      , [DuplicateCaseName name | name <- nub names, length (filter (== name) names) > 1]
      , [EmptyBinaryFactOutputs | Just fact <- [inputBinaryFact input], null (factOutputs fact)]
      ]

-- | The deterministic rendering a phase document carries in its fenced
-- @gate-spec@ block. One key per line; lists are comma-separated in order.
renderGateSpec :: GateSpec -> Text
renderGateSpec spec =
  Text.unlines
    ( [ "capability: " <> gateCapability spec
      , "role: " <> renderRole (gateRole spec)
      , "claim: " <> gateClaim spec
      , "subjects: " <> Text.intercalate ", " (map productionModuleName (gateSubjects spec))
      , "suite: " <> cabalTargetName (gateSuite spec)
      , "oracle: " <> oracleExecutableName (gateOracle spec)
      ]
        <> map renderCase (gateCases spec)
        <> [renderPolicy (gateMutants spec)]
        <> maybe [] (pure . renderBinaryFact) (gateBinaryFact spec)
        <> maybe [] (pure . renderSpineFact) (gateSpineFact spec)
        <> ["substrate: " <> renderSubstrate (gateSubstrate spec)]
        <> maybe [] (pure . renderSeed) (gateSeed spec)
    )
 where
  renderRole role = case role of
    SeedGate -> "seed"
    OrdinaryGate -> "ordinary"
    BarrierGate -> "barrier"
    HardwareGate -> "hardware"
  renderCase item = case item of
    PositiveControl name input expected -> "positive: " <> name <> " | input=" <> input <> " | expected=" <> expected
    PairedNegative name input tag stage -> "negative: " <> name <> " | input=" <> input <> " | tag=" <> tag <> " | stage=" <> stage
  renderPolicy policy =
    "mutants: stages="
      <> Text.intercalate "," (map productionModuleName (stageModules policy))
      <> " per-module="
      <> showText (perModule policy)
      <> " cap="
      <> showText (perGateCap policy)
      <> " kill-ratio="
      <> showText (numerator (killRatio policy))
      <> "/"
      <> showText (denominator (killRatio policy))
  renderBinaryFact fact =
    "binary-fact: command="
      <> Text.unwords (factCommand fact)
      <> " | input="
      <> Text.pack (factInput fact)
      <> " | perturbation="
      <> renderPerturbation (factPerturbation fact)
      <> " | outputs="
      <> Text.intercalate "," (map Text.pack (factOutputs fact))
  renderPerturbation perturbation = case perturbation of
    SentinelToNonce sentinel -> "sentinel-to-nonce(" <> sentinel <> ")"
    ReplicaCount from to -> "replica-count(" <> showText from <> "->" <> showText to <> ")"
  renderSpineFact fact =
    "spine-fact: rendered="
      <> Text.pack (spineRendered fact)
      <> " | stages="
      <> Text.intercalate "," (spineStages fact)
      <> " | applied-digest="
      <> Text.pack (spineAppliedDigestFile fact)
  renderSeed seed =
    "seed: predicates="
      <> Text.intercalate "," (seedPredicateCases seed)
      <> " | custody="
      <> Text.intercalate "," (seedCustodyProbes seed)

showText :: Show value => value -> Text
showText = Text.pack . show

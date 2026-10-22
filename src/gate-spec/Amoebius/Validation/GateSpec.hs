{-# LANGUAGE OverloadedStrings #-}
-- | Typed gate specification; 'mkGateSpec' enforces role-specific facts before a runner sees it.
module Amoebius.Validation.GateSpec
  ( GateSpec, GateSpecInput (..), GateRole (..), GateCategory (..), ProductionModule (..), OracleExecutable (..)
  , CabalTarget (..), ExactCase (..), MutantPolicy (..), BinaryFact (..), Perturbation (..), SpineFact (..)
  , GateSubstrate (..), SeedSpec (..), SpecRefusal (..), allGateCategories, defaultMutantPolicy, gateBinaryFact
  , gateCapability, gateCases, gateClaim, gateMutants, gateOracle, gateRole, gateSeed, gateSpineFact, gateSubjects
  , gateSubstrate, gateSuite, isValidatorModule, mkGateSpec, renderGateCategory, renderGateSpec, renderSpecRefusal
  , renderSubstrate, substrateCatalogue, showText ) where
import Data.List (isPrefixOf, nub)
import Data.Ratio (denominator, numerator)
import Data.Text (Text)
import Data.Text qualified as Text
newtype ProductionModule = ProductionModule {productionModuleName :: Text}
  deriving (Eq, Ord, Show)
newtype OracleExecutable = OracleExecutable {oracleExecutableName :: Text}
  deriving (Eq, Ord, Show)
newtype CabalTarget = CabalTarget {cabalTargetName :: Text}
  deriving (Eq, Ord, Show)
data ExactCase
  = PositiveControl {caseName :: Text, caseInput :: Text, caseExpected :: Text}
  | PairedNegative {caseName :: Text, caseInput :: Text, caseTag :: Text, caseStage :: Text} deriving (Eq, Ord, Show)
data MutantPolicy = MutantPolicy
  { stageModules :: [ProductionModule], perModule :: Int, perGateCap :: Int
  , killRatio :: Rational, stageArtefacts :: [(Text, Text)] } deriving (Eq, Ord, Show)
defaultMutantPolicy :: [ProductionModule] -> MutantPolicy
defaultMutantPolicy modules = MutantPolicy modules 8 40 (3 / 5) []
data Perturbation
  = SentinelToNonce {perturbationSentinel :: Text}
  | ReplicaCount {perturbationFrom :: Int, perturbationTo :: Int}
  | Rewrite {perturbationNeedle :: Text, perturbationReplacement :: Text}
  | Staged {stagePrelude :: [[Text]], stagePostlude :: [[Text]], stageInner :: [Perturbation]}
  | PlantForeignPaths [(FilePath, Text)]
  | SourceSibling ProductionModule Text Perturbation
  deriving (Eq, Ord, Show)
data BinaryFact = BinaryFact
  { factCommand :: [Text], factInput :: FilePath
  , factPerturbation :: Perturbation, factOutputs :: [FilePath] } deriving (Eq, Ord, Show)
data SpineFact = SpineFact
  { spineRendered :: FilePath, spineStages :: [Text], spineAppliedDigestFile :: FilePath } deriving (Eq, Ord, Show)
data GateSubstrate
  = HardwareFree | LinuxCpu | LinuxCuda | Apple | Windows
  deriving (Bounded, Enum, Eq, Ord, Show)
substrateCatalogue :: [GateSubstrate]
substrateCatalogue = [minBound .. maxBound]
renderSubstrate :: GateSubstrate -> Text
renderSubstrate substrate = case substrate of
  HardwareFree -> "none"
  LinuxCpu -> "linux-cpu"
  LinuxCuda -> "linux-cuda"
  Apple -> "apple"
  Windows -> "windows"
data SeedSpec = SeedSpec { seedPredicateCases :: [Text], seedCustodyProbes :: [Text] } deriving (Eq, Ord, Show)
data GateRole = SeedGate | OrdinaryGate | BarrierGate | HardwareGate
  deriving (Bounded, Enum, Eq, Ord, Show)
data GateCategory
  = Claim | Subject | Command | Oracle
  | PositiveControls | PairedNegatives | Mutants | Discovery
  | Challenge | Observer | AuthorityBypass | Freshness
  | Qualification | Cleanroom | LegacyClosure | Predecessor | Residue | PassCriterion
  deriving (Bounded, Enum, Eq, Ord, Show)
allGateCategories :: [GateCategory]
allGateCategories = [minBound .. maxBound]
renderGateCategory :: GateCategory -> Text
renderGateCategory category = case category of
  PositiveControls -> "Positive controls"
  PairedNegatives -> "Paired negatives"
  AuthorityBypass -> "Authority/bypass"
  LegacyClosure -> "Legacy closure"
  PassCriterion -> "Pass criterion"
  other -> Text.pack (show other)
data GateSpecInput = GateSpecInput
  { inputCapability :: Text, inputClaim :: Text, inputSubjects :: [ProductionModule]
  , inputSuite :: CabalTarget, inputOracle :: OracleExecutable, inputCases :: [ExactCase]
  , inputMutants :: MutantPolicy, inputBinaryFact :: Maybe BinaryFact, inputSpineFact :: Maybe SpineFact
  , inputSubstrate :: GateSubstrate, inputSeed :: Maybe SeedSpec } deriving (Eq, Show)
data GateSpec = GateSpec
  { gateRole :: GateRole, gateCapability :: Text, gateClaim :: Text, gateSubjects :: [ProductionModule]
  , gateSuite :: CabalTarget, gateOracle :: OracleExecutable, gateCases :: [ExactCase]
  , gateMutants :: MutantPolicy, gateBinaryFact :: Maybe BinaryFact, gateSpineFact :: Maybe SpineFact
  , gateSubstrate :: GateSubstrate, gateSeed :: Maybe SeedSpec } deriving (Eq, Show)
data SpecRefusal
  = KernelSubject ProductionModule
  | EmptySubjects | EmptyClaim | EmptyCases | MissingBinaryFact | MissingSpineFact
  | SeedCarriesBinaryFact | SeedCarriesSpineFact | SeedAbsent | SeedOutsideSeedRole
  | HardwareSubstrateOutsideHardwareRole GateSubstrate
  | HardwareRoleWithoutSubstrate
  | StageModuleNotSubject ProductionModule
  | MutantPolicyOutOfBounds | DuplicateCaseName Text | EmptyBinaryFactOutputs
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
  HardwareSubstrateOutsideHardwareRole substrate -> "HARDWARE-BEFORE-BARRIER: " <> renderSubstrate substrate
  HardwareRoleWithoutSubstrate -> "SUBSTRATE-ABSENT"
  StageModuleNotSubject (ProductionModule name) -> "STAGE-MODULE-NOT-SUBJECT: " <> name
  MutantPolicyOutOfBounds -> "MUTANT-POLICY-OUT-OF-BOUNDS"
  DuplicateCaseName name -> "CASE-DUPLICATE: " <> name
  EmptyBinaryFactOutputs -> "BINARY-FACT-NO-OUTPUTS"
isValidatorModule :: ProductionModule -> Bool
isValidatorModule (ProductionModule name) = any (`isPrefixOf` Text.unpack name) ["Amoebius.Validation.", "Amoebius.Doc.", "Amoebius.Plan."]
mkGateSpec :: GateRole -> GateSpecInput -> Either [SpecRefusal] GateSpec
mkGateSpec role input = case refusals of
  [] -> Right GateSpec
        { gateRole = role, gateCapability = inputCapability input, gateClaim = inputClaim input
        , gateSubjects = inputSubjects input, gateSuite = inputSuite input, gateOracle = inputOracle input
        , gateCases = inputCases input, gateMutants = inputMutants input, gateBinaryFact = inputBinaryFact input
        , gateSpineFact = inputSpineFact input, gateSubstrate = inputSubstrate input, gateSeed = inputSeed input }
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
renderGateSpec :: GateSpec -> Text
renderGateSpec spec = Text.unlines
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
  renderRole = Text.toLower . Text.dropEnd (Text.length "Gate") . Text.pack . show
  renderCase item = case item of
    PositiveControl name input expected -> "positive: " <> name <> " | input=" <> input <> " | expected=" <> expected
    PairedNegative name input tag stage -> "negative: " <> name <> " | input=" <> input <> " | tag=" <> tag <> " | stage=" <> stage
  renderPolicy policy =
    renderFields "mutants: " " "
      [("stages", Text.intercalate "," (map productionModuleName (stageModules policy))),
       ("per-module", showText (perModule policy)), ("cap", showText (perGateCap policy)),
       ("kill-ratio", showText (numerator (killRatio policy)) <> "/" <> showText (denominator (killRatio policy)))]
      <> (if null (stageArtefacts policy) then "" else " artefacts=" <> Text.intercalate "," [module' <> ":" <> prefix | (module', prefix) <- stageArtefacts policy])
  renderBinaryFact fact = renderFields "binary-fact: " " | "
    [("command", Text.unwords (factCommand fact)), ("input", Text.pack (factInput fact)),
     ("perturbation", renderPerturbation (factPerturbation fact)),
     ("outputs", Text.intercalate "," (map Text.pack (factOutputs fact)))]
  renderPerturbation perturbation = case perturbation of
    SentinelToNonce sentinel -> "sentinel-to-nonce(" <> sentinel <> ")"
    ReplicaCount from to -> "replica-count(" <> showText from <> "->" <> showText to <> ")"
    Rewrite needle replacement -> "rewrite(" <> needle <> " => " <> replacement <> ")"
    Staged prelude postlude inner -> "staged(pre=" <> renderCommands prelude <> " post=" <> renderCommands postlude <> " then=" <> Text.intercalate "," (map renderPerturbation inner) <> ")"
    PlantForeignPaths paths -> "plant-foreign-paths(" <> Text.intercalate "," [Text.pack path <> "=" <> tag | (path, tag) <- paths] <> ")"
    SourceSibling subject binding inner -> "source-sibling(" <> productionModuleName subject <> "." <> binding <> " then=" <> renderPerturbation inner <> ")"
  renderCommands = Text.intercalate ";" . map Text.unwords
  renderSpineFact fact = renderFields "spine-fact: " " | "
    [("rendered", Text.pack (spineRendered fact)), ("stages", Text.intercalate "," (spineStages fact)),
     ("applied-digest", Text.pack (spineAppliedDigestFile fact))]
  renderSeed seed = renderFields "seed: " " | "
    [("predicates", Text.intercalate "," (seedPredicateCases seed)), ("custody", Text.intercalate "," (seedCustodyProbes seed))]
  renderFields prefix separator fields = prefix <> Text.intercalate separator [key <> "=" <> value | (key, value) <- fields]
showText :: Show value => value -> Text
showText = Text.pack . show

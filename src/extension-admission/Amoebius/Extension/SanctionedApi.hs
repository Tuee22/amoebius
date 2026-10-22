{-# LANGUAGE OverloadedStrings #-}

-- | The closed source-admission surface. Namespace is part of membership:
-- an abstract type never grants its constructor, selectors or update syntax.
module Amoebius.Extension.SanctionedApi
  ( ModuleName (..), ExportNamespace (..), ExportName (..)
  , SanctionedEffect (..), SanctionedApi (..), sanctionedApi
  , admittedSymbol, reservedName
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

newtype ModuleName = ModuleName {unModuleName :: Text}
  deriving (Eq, Ord, Show)

data ExportNamespace = TypeNamespace | ValueNamespace
  deriving (Eq, Ord, Show)

data ExportName = ExportName ExportNamespace Text
  deriving (Eq, Ord, Show)

data SanctionedEffect = ApplyManifest | BuildImage | PushImage | UpdateInfrastructure
  deriving (Bounded, Enum, Eq, Ord, Show)

data SanctionedApi = SanctionedApi
  { sanctionedModules :: Set ModuleName
  , sanctionedEffects :: Set SanctionedEffect
  , sanctionedSymbols :: Map ModuleName (Set ExportName)
  }
  deriving (Eq, Show)

sanctionedApi :: SanctionedApi
sanctionedApi = SanctionedApi (Map.keysSet symbols) (Set.fromList [minBound .. maxBound]) symbols
 where
  symbols = Map.fromList
    [ entry "Prelude" preludeTypes preludeValues
    , entry "Amoebius.Extension.Spec"
        ["ExtensionSpec", "ExtensionSpecRefusal"]
        [ "mkExtensionSpec", "DuplicateProvidedCapability", "DuplicateRequiredCapability"
        , "extensionSpecRefusalName", "extId", "extConfig", "extProvides", "extRequires"
        , "extRequiresLane", "extChain", "extUiHandlers", "extMonitoring"
        , "extDeclaration", "extSourceSeal" ]
    , entry "Amoebius.Extension.Surface"
        ["ProductSpec", "ProductLinkSet", "SurfaceRefusal", "ConfigSchema", "DeclaredCapability",
         "CapabilityArm", "NonEmpty", "MonitorFactory", "ExtensionInput"]
        [ "mkContribution", "sloMonitoring", "tensorBoardMonitoring", "surfaceRefusalTag", ":|"
        , "BuildCacheConfig", "CoordinationConfig", "InferenceConfig", "TrainingConfig"
        , "ServiceCapability", "JitBuild", "Coordination", "ObjectStore", "SecretStore"
        , "MessageBus", "Sql", "Identity", "Observability", "Registry", "Edge", "InferenceEngine"
        , "extensionSteps", "extensionRuntime" ]
    , entry "Amoebius.Kernel.Step"
        ["Step", "Frame", "StepKind", "StepRefusal", "Plan", "PlanEntry"]
        [ "ImmediateFrame", "BootstrapSchedulerFrame", "AfterBootstrapAddonCutoverFrame"
        , "AfterManagedCapacityReadyFrame", "BoundaryFrame", "ApplyObjects"
        , "DockerBuild", "DockerPush", "PulumiUp", "mkStep", "stepLabel", "stepFrame"
        , "stepKind", "stepObjects", "stepRefusalTag", "chain", "stepsFrom"
        , "nextFrameAfter", "validateChain", "stepPayload", "manifestBytes"
        , "planOf", "renderPlan" ]
    , entry "Amoebius.Manifest.K8sObject" ["K8sObject"] []
    ]
  entry name types values = (ModuleName name, Set.fromList
    (map (ExportName TypeNamespace) types <> map (ExportName ValueNamespace) values))

admittedSymbol :: ModuleName -> ExportNamespace -> Text -> Bool
admittedSymbol name namespace occurrence =
  maybe False (Set.member (ExportName namespace occurrence))
    (Map.lookup name (sanctionedSymbols sanctionedApi))

-- All effectful and reflective Prelude exports are reserved even when a local
-- binder shadows them. The native base bound in the package owns this Prelude.
-- Enum syntax is checked separately because it has no explicit method name.
reservedName :: Text -> Maybe Text
reservedName name
  | name `Set.member` rawNames = Just "RawIO"
  | name `Set.member` unsafeNames = Just "UnsafeOperation"
  | otherwise = Nothing

rawNames, unsafeNames :: Set Text
rawNames = Set.fromList
  [ "IO", "IOError", "IORef", "ST", "STRef", "RealWorld"
  , "putChar", "putStr", "putStrLn", "print", "getChar", "getLine"
  , "getContents", "interact", "readFile", "writeFile", "appendFile"
  , "readIO", "readLn", "ioError", "userError", "getEnv" ]
unsafeNames = Set.fromList
  [ "unsafePerformIO", "unsafeDupablePerformIO", "unsafeInterleaveIO", "unsafeCoerce"
  , "unsafeFixIO", "unsafeIOToST", "unsafeSTToIO", "unsafeThaw", "unsafeFreeze"
  , "coerce", "HostProcess", "Read", "ReadS", "read", "reads", "readParen"
  , "readsPrec", "readList", "readPrec", "readListPrec", "readListDefault"
  , "readListPrecDefault", "Enum", "Bounded", "toEnum", "succ", "pred"
  , "minBound", "maxBound", "enumFrom", "enumFromTo", "enumFromThen"
  , "enumFromThenTo", "Generic", "Generic1", "from", "to", "from1", "to1"
  , "Data", "Typeable", "gfoldl", "gunfold", "fromConstr", "fromConstrB"
  , "fromConstrM", "mkName", "runQ", "runIO", "liftTyped", "unTypeCode" ]

preludeTypes, preludeValues :: [Text]
preludeTypes = Text.words
  "Bool Maybe Either Ordering Char String Eq Ord Int Integer Float Double Rational Word Num Real Integral Fractional Floating RealFrac RealFloat Semigroup Monoid Functor Applicative Monad MonadFail Foldable Traversable ShowS Show FilePath ~"
preludeValues = Text.words
  "False True && || not otherwise Nothing Just maybe Left Right either LT EQ GT fst snd curry uncurry == /= compare < <= >= > max min fromEnum + - * negate abs signum fromInteger toRational quot rem div mod quotRem divMod toInteger / recip fromRational pi exp log sqrt ** logBase sin cos tan asin acos atan sinh cosh tanh asinh acosh atanh properFraction truncate round ceiling floor floatRadix floatDigits floatRange decodeFloat encodeFloat exponent significand scaleFloat isNaN isInfinite isDenormalized isIEEE isNegativeZero atan2 subtract even odd gcd lcm ^ ^^ fromIntegral realToFrac <> mempty mappend mconcat fmap <$ <$> pure <*> *> <* liftA2 >>= >> return fail mapM_ sequence_ =<< elem foldMap foldr foldl foldl' foldr1 foldl1 maximum minimum product sum traverse sequenceA mapM sequence id const . flip $ until asTypeOf error errorWithoutStackTrace undefined seq $! map ++ filter head last tail init !! null length reverse and or any all concat concatMap scanl scanl1 scanr scanr1 iterate repeat replicate cycle take drop takeWhile dropWhile span break splitAt notElem lookup zip zip3 zipWith zipWith3 unzip unzip3 lines words unlines unwords showsPrec showList show shows showChar showString showParen lex"

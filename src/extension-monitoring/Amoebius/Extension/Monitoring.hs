{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Closed monitoring declarations, instantiated at an actual attested scope.
-- These are plans. Metric readback and enforcement belong to the live owners.
module Amoebius.Extension.Monitoring
  ( MetricName, metricName, metricNameText, ErrorBudget, errorBudget
  , Objective, objective, objectiveThreshold, objectiveWindow, objectiveErrorBudget
  , SliKind (..), Sli, sli, Severity (..), AlertBinding (..)
  , AccessScope, accessKind, WorkflowMonitor, ObjectStoreRef
  , MonitoringSurface, monitoringKind, MonitoringBuilder, MonitoringRefusal (..)
  , monitoringRefusalTag, sloBuilder, tensorBoardBuilder, defaultSloBuilder
  , realizeMonitoring, monitoringRows
  ) where

import Amoebius.Extension.AstCheck (CheckedExtensionSource)
import Amoebius.Extension.Capability (DeclaredCapability (ServiceCapability))
import Amoebius.Extension.Graph (BindingProof, bindingApplication, bindingCapability, bindingNeed)
import Amoebius.Scope.Attested
  ( RequestScope, scopeApplication, scopeLabel, scopeTenant, scopeSubject, tenantText, subjectText )
import Amoebius.Vocabulary
  ( CapabilityArm (ObjectStore), Duration, MetricQuantity, durationSeconds
  , isLabel, metricQuantityValue, mkDuration, mkMetricQuantity )
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Ratio (denominator, numerator)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

newtype MetricName = MetricName Text
  deriving (Eq, Ord, Show)

data MonitoringRefusal
  = InvalidMetricName | InvalidMetricQuantity | InvalidDuration | InvalidErrorBudget
  | InvalidMonitoringReference | ObjectStoreBindingRequired | MonitoringScopeMismatch
  deriving (Eq, Ord, Show)

monitoringRefusalTag :: MonitoringRefusal -> Text
monitoringRefusalTag = Text.pack . show

metricName :: Text -> Either MonitoringRefusal MetricName
metricName value = case Text.uncons value of
  Just (first, rest) | initial first && Text.all subsequent rest -> Right (MetricName value)
  _ -> Left InvalidMetricName
 where
  initial character = isAsciiLower character || isAsciiUpper character || character `elem` ['_', ':']
  subsequent character = initial character || isDigit character

metricNameText :: MetricName -> Text
metricNameText (MetricName value) = value

newtype ErrorBudget = ErrorBudget MetricQuantity
  deriving (Eq, Ord, Show)

errorBudget :: Integer -> Integer -> Either MonitoringRefusal ErrorBudget
errorBudget top bottom = case mkMetricQuantity top bottom of
  Just quantity | metricQuantityValue quantity < 1 -> Right (ErrorBudget quantity)
  _ -> Left InvalidErrorBudget

data Objective = Objective !MetricQuantity !Duration !ErrorBudget
  deriving (Eq, Ord, Show)

objective :: Integer -> Integer -> Natural -> Integer -> Integer -> Either MonitoringRefusal Objective
objective top bottom seconds errorTop errorBottom = do
  threshold <- maybe (Left InvalidMetricQuantity) Right (mkMetricQuantity top bottom)
  window <- maybe (Left InvalidDuration) Right (mkDuration seconds)
  budget <- errorBudget errorTop errorBottom
  Right (Objective threshold window budget)

objectiveThreshold :: Objective -> MetricQuantity
objectiveThreshold (Objective threshold _ _) = threshold

objectiveWindow :: Objective -> Duration
objectiveWindow (Objective _ window _) = window

objectiveErrorBudget :: Objective -> ErrorBudget
objectiveErrorBudget (Objective _ _ budget) = budget

data SliKind = Availability | Latency | Saturation | FreshnessSli | BacklogSli
  deriving (Bounded, Enum, Eq, Ord, Show)

data Sli = Sli !MetricName !SliKind !Objective
  deriving (Eq, Ord, Show)

sli :: MetricName -> SliKind -> Objective -> Sli
sli = Sli

data Severity = Page | Warn
  deriving (Bounded, Enum, Eq, Ord, Show)

data AlertBinding = ToObservability Severity
  deriving (Eq, Ord, Show)

-- Constructors stay private. The implemented subject entry consumes an
-- attested scope; admin/role introduction requires their future authority
-- witnesses and is not supplied by an extension or dashboard parameter.
type role AccessScope nominal
data AccessScope scope
  = AdminGlobal
  | SubjectScoped !Text !Text !Text
  | TenantRoleScoped !Text !Text !Text
  deriving (Eq, Ord, Show)

accessKind :: AccessScope scope -> Text
accessKind access = case access of
  AdminGlobal -> "AdminGlobal"
  SubjectScoped {} -> "SubjectScoped"
  TenantRoleScoped {} -> "TenantRoleScoped"

type role WorkflowMonitor nominal
data WorkflowMonitor scope = WorkflowMonitor !(NonEmpty Sli) !Objective !AlertBinding !(AccessScope scope)
  deriving (Eq, Ord, Show)

type role ObjectStoreRef nominal
data ObjectStoreRef scope = ObjectStoreRef !Text !Text
  deriving (Eq, Ord, Show)

type role MonitoringSurface nominal
data MonitoringSurface scope
  = Slo (WorkflowMonitor scope)
  | TensorBoard (ObjectStoreRef scope) (AccessScope scope)
  deriving (Eq, Ord, Show)

monitoringKind :: MonitoringSurface scope -> Text
monitoringKind surface = case surface of Slo _ -> "Slo"; TensorBoard {} -> "TensorBoard"

-- A compiled blueprint contains no scope or authority. Binding supplies those
-- to produce the actual closed surface, preserving the fresh nominal index.
data MonitoringBuilder
  = SloBuilder !(NonEmpty Sli) !Objective !AlertBinding
  | TensorBoardBuilder !Text
  deriving (Eq, Ord, Show)

sloBuilder :: NonEmpty Sli -> Objective -> AlertBinding -> MonitoringBuilder
sloBuilder = SloBuilder

tensorBoardBuilder :: Text -> Either MonitoringRefusal MonitoringBuilder
tensorBoardBuilder reference
  | isLabel reference = Right (TensorBoardBuilder reference)
  | otherwise = Left InvalidMonitoringReference

defaultSloBuilder :: MetricName -> Either MonitoringRefusal MonitoringBuilder
defaultSloBuilder name = do
  target <- objective 999 1000 300 1 100
  Right (SloBuilder (Sli name Availability target :| []) target (ToObservability Warn))

realizeMonitoring
  :: RequestScope scope -> Maybe (BindingProof CheckedExtensionSource)
  -> MonitoringBuilder -> Either MonitoringRefusal (MonitoringSurface scope)
realizeMonitoring scope backing builder = case builder of
  SloBuilder indicators target sink -> Right (Slo (WorkflowMonitor indicators target sink access))
  TensorBoardBuilder wanted -> case backing of
    Nothing -> Left ObjectStoreBindingRequired
    Just proof
      | bindingCapability proof /= ServiceCapability ObjectStore || bindingNeed proof /= wanted -> Left ObjectStoreBindingRequired
      | bindingApplication proof /= scopeApplication scope -> Left MonitoringScopeMismatch
      | otherwise -> Right (TensorBoard (ObjectStoreRef wanted (scopeLabel scope)) access)
 where
  access = SubjectScoped (tenantText (scopeTenant scope)) (subjectText (scopeSubject scope)) (scopeLabel scope)

monitoringRows :: MonitoringSurface scope -> [(Text, Text)]
monitoringRows surface = ("kind", monitoringKind surface) : case surface of
  Slo (WorkflowMonitor indicators target sink access) ->
    [("sli-count", number (NonEmpty.length indicators)), ("sink", Text.pack (show sink))]
      <> concat [indicatorRows index indicator | (index, indicator) <- zip [1 :: Int ..] (NonEmpty.toList indicators)]
      <> objectiveRows "objective" target <> accessRows access
  TensorBoard (ObjectStoreRef backing label) access ->
    [("backing", backing), ("scope-label", label)] <> accessRows access
 where
  indicatorRows index (Sli name kind target) =
    [(base <> ".name", metricNameText name), (base <> ".kind", Text.pack (show kind))]
      <> objectiveRows (base <> ".objective") target
   where base = "sli." <> number index
  objectiveRows prefix (Objective threshold window (ErrorBudget budget)) =
    [(prefix <> ".threshold", ratio threshold), (prefix <> ".window-seconds", number (durationSeconds window)),
     (prefix <> ".error-budget", ratio budget)]
  accessRows access = ("access", accessKind access) : case access of
    SubjectScoped tenant subject policy -> [("tenant", tenant), ("owner", subject), ("policy", policy)]
    TenantRoleScoped tenant role policy -> [("tenant", tenant), ("role", role), ("policy", policy)]
    AdminGlobal -> []
  ratio quantity = let value = metricQuantityValue quantity in number (numerator value) <> "/" <> number (denominator value)
  number :: Show value => value -> Text
  number = Text.pack . show

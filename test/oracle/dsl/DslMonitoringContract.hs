{-# LANGUAGE OverloadedStrings #-}

module DslMonitoringContract
  ( monitorFields, sliKinds, monitoringKinds, accessKinds, monitorControls, defaultObjective
  , runtimeMonitorControls, expectedSloRows, expectedTensorRows ) where

import Data.Text (Text)
import DslParse (attestedScopeLabel)

monitorFields, sliKinds, monitoringKinds, accessKinds :: [Text]
monitorFields = ["sli", "objective", "sink", "access"]
sliKinds = ["Availability", "Latency", "Saturation", "FreshnessSli", "BacklogSli"]
monitoringKinds = ["Slo", "TensorBoard"]
accessKinds = ["AdminGlobal", "SubjectScoped", "TenantRoleScoped"]

monitorControls :: [(Text, Text)]
monitorControls =
  [ ("prometheus-name", "accepted")
  , ("empty-metric-name", "InvalidMetricName")
  , ("digit-leading-metric", "InvalidMetricName")
  , ("zero-threshold", "InvalidMetricQuantity")
  , ("zero-window", "InvalidDuration")
  , ("zero-error-budget", "InvalidErrorBudget")
  , ("unit-error-budget", "InvalidErrorBudget")
  , ("empty-sli-set", "NonEmpty SLI required")
  , ("public-access", "no Public constructor")
  , ("tensorboard-without-backing", "ObjectStoreBindingRequired")
  , ("tensorboard-cross-application", "MonitoringScopeMismatch")
  , ("monitor-retag", "nominal scope index")
  ]

-- Numerator, denominator, seconds, error-budget numerator/denominator.
defaultObjective :: (Integer, Integer, Integer, Integer, Integer)
defaultObjective = (999, 1000, 300, 1, 100)

runtimeMonitorControls :: [(Text, Text)]
runtimeMonitorControls = [("prometheus-name", "accepted"), ("empty-metric-name", "InvalidMetricName"),
  ("digit-leading-metric", "InvalidMetricName"), ("zero-threshold", "InvalidMetricQuantity"),
  ("zero-window", "InvalidDuration"), ("zero-error-budget", "InvalidErrorBudget"),
  ("unit-error-budget", "InvalidErrorBudget"), ("tensorboard-with-backing", "accepted"),
  ("tensorboard-without-backing", "ObjectStoreBindingRequired"), ("tensorboard-cross-application", "MonitoringScopeMismatch")]

expectedSloRows, expectedTensorRows :: Text -> Text -> Text -> [(Text, Text)]
expectedSloRows app need _ =
  [("kind", "Slo"), ("sli-count", "1"), ("sink", "ToObservability Warn"),
   ("sli.1.name", "amoebius_test_success"), ("sli.1.kind", "Availability"),
   ("sli.1.objective.threshold", "999/1000"), ("sli.1.objective.window-seconds", "300"),
   ("sli.1.objective.error-budget", "1/100"), ("objective.threshold", "999/1000"),
   ("objective.window-seconds", "300"), ("objective.error-budget", "1/100")] <> accessRows app need
expectedTensorRows app need store = [("kind", "TensorBoard"), ("backing", store),
  ("scope-label", attestedScopeLabel "extension/infernix" app need)] <> accessRows app need

accessRows :: Text -> Text -> [(Text, Text)]
accessRows app need = [("access", "SubjectScoped"), ("tenant", app), ("owner", need),
  ("policy", attestedScopeLabel "extension/infernix" app need)]

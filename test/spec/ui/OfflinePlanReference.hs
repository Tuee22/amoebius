module OfflinePlanReference (
    referenceContinuityRows,
    referenceNegativeTags,
    referencePlanRows,
) where

-- This module is an independently authored oracle: it imports neither the
-- production offline compiler nor the typed subject-case module.
referenceContinuityRows :: [[String]]
referenceContinuityRows =
    [ ["online-only", "OnlineOnly", "-", "0", "0", "0", "-", "-", "-", "-", "-", "-"]
    , ["infernix", "Offline", "infernix-start", "8", "65536", "86400", "advisory", "command-id", "reject", "preserve", "workflow-root", "current-authority"]
    , ["jitml", "Offline", "jitml-training-start", "4", "131072", "43200", "advisory", "command-id", "reject", "preserve", "dataset-blob", "current-authority"]
    ]

referenceNegativeTags :: [(String, String)]
referenceNegativeTags =
    [ ("zero-count", "MissingCountBound")
    , ("zero-bytes", "MissingByteBound")
    , ("zero-age", "MissingAgeBound")
    , ("missing-local-validation", "MissingLocalValidation")
    , ("missing-idempotency", "MissingIdempotency")
    , ("missing-conflict", "MissingConflictRule")
    , ("missing-order", "MissingOrderRule")
    , ("missing-dependency", "MissingDependencyRule")
    , ("missing-validation", "MissingAuthorityValidation")
    , ("queue-progress", "OnlineOnlyOperation")
    , ("queue-signal", "OnlineOnlyOperation")
    , ("queue-cancel", "OnlineOnlyOperation")
    , ("queue-model-invocation", "OnlineOnlyOperation")
    ]

referencePlanRows :: [[String]]
referencePlanRows =
    [ ["infernix-start", "infernix-start", "infernix-start", "queued"]
    , ["jitml-training-start", "jitml-training-start", "jitml-training-start", "queued"]
    , ["workflow-progress", "workflow-progress", "workflow-progress", "cached-projection"]
    , ["dataset", "dataset", "dataset", "local-blob"]
    , ["offline-view", "offline.dashboard", "-", "client-view"]
    , ["ml-signal", "-", "-", "online-only"]
    , ["workflow-cancel", "-", "-", "online-only"]
    , ["model-invocation", "-", "-", "online-only"]
    ]

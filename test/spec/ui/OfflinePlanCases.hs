{-# LANGUAGE OverloadedStrings #-}

module OfflinePlanCases (
    positiveContinuities,
    offlineSources,
    negativeCases,
    calculusRows,
) where

import Amoebius.Ui.Offline.Types
import Data.Text (Text)

positiveContinuities :: [(Text, Continuity)]
positiveContinuities =
    [ ("online-only", OnlineOnly)
    , ("infernix", Offline infernixSource)
    , ("jitml", Offline jitmlSource)
    ]

offlineSources :: [OfflineSource]
offlineSources = [infernixSource, jitmlSource]

negativeCases :: [(Text, QueuedPort)]
negativeCases =
    [ ("zero-count", QueuedPort InfernixStart (baseContract {maxCount = 0}))
    , ("zero-bytes", QueuedPort InfernixStart (baseContract {maxBytes = 0}))
    , ("zero-age", QueuedPort InfernixStart (baseContract {maxAgeSeconds = 0}))
    , ("missing-local-validation", QueuedPort InfernixStart (baseContract {localValidation = ""}))
    , ("missing-idempotency", QueuedPort InfernixStart (baseContract {idempotency = ""}))
    , ("missing-conflict", QueuedPort InfernixStart (baseContract {conflict = ""}))
    , ("missing-order", QueuedPort InfernixStart (baseContract {ordering = ""}))
    , ("missing-dependency", QueuedPort InfernixStart (baseContract {dependency = ""}))
    , ("missing-validation", QueuedPort InfernixStart (baseContract {authoritativeValidation = ""}))
    , ("queue-progress", QueuedPort WorkflowProgress baseContract)
    , ("queue-signal", QueuedPort MlSignal baseContract)
    , ("queue-cancel", QueuedPort WorkflowCancel baseContract)
    , ("queue-model-invocation", QueuedPort ModelInvocation baseContract)
    ]

calculusRows :: [[String]]
calculusRows =
    [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
    , ["component-names", "offline-plan-artifacts,bounded-queue-contract,language-and-refusal-corpus,paired-plan-workflow,mutant-evidence"]
    , ["projection-counts", "2,9,16,8,5"]
    , ["resource-vector", "5,40,0,0"]
    ]

infernixSource :: OfflineSource
infernixSource =
    OfflineSource
        { projections = [Projection "workflow-progress"]
        , queuedPorts = [QueuedPort InfernixStart (baseContract {dependency = "workflow-root"})]
        , localBlobs = []
        , offlineView = "offline.dashboard"
        }

jitmlSource :: OfflineSource
jitmlSource =
    OfflineSource
        { projections = []
        , queuedPorts =
            [ QueuedPort
                JitmlTrainingStart
                ( baseContract
                    { maxCount = 4
                    , maxBytes = 131072
                    , maxAgeSeconds = 43200
                    , dependency = "dataset-blob"
                    }
                )
            ]
        , localBlobs = [BlobClass "dataset"]
        , offlineView = "offline.dashboard"
        }

baseContract :: QueueContract
baseContract =
    QueueContract
        { maxCount = 8
        , maxBytes = 65536
        , maxAgeSeconds = 86400
        , localValidation = "advisory"
        , idempotency = "command-id"
        , conflict = "reject"
        , ordering = "preserve"
        , dependency = "dependency"
        , authoritativeValidation = "current-authority"
        }

let Cluster = ./Cluster.dhall

let App = ./App.dhall

let Storage = ./Storage.dhall

let ExecutionTransitionIntent =
      < FirstDeployment | UpdateFrom : Storage.PriorProvisionRefSource >

let QueryWorkBudget =
      { maxConcurrentQueries : Natural
      , maxSeriesPerQuery : Natural
      , maxSamplesPerQuery : Natural
      , maxRange : Storage.FiniteDuration
      , timeout : Storage.FiniteDuration
      , costModel : Text
      }

let MonitoringWorkBudget =
      { maxWorkflows : Natural
      , maxRules : Natural
      , maxSeries : Natural
      , maxScrapeSamplesPerSecond : Natural
      , evaluationInterval : Storage.FiniteDuration
      , evaluationCpu : { millis : Natural }
      , evaluationMemory : Storage.ByteQuantity
      , retention : Storage.FiniteDuration
      , query : QueryWorkBudget
      , volume :
          { claim : Storage.StatefulSetClaimSlot
          , backing : Text
          , presentation : Storage.VolumePresentation
          }
      , tsdbCostModel : Text
      }

let Deployment =
      { cluster : Cluster.Type
      , app : App.Type
      , transition : ExecutionTransitionIntent
      , monitoring : MonitoringWorkBudget
      }

in  { Type = Deployment
    , ExecutionTransitionIntent
    , QueryWorkBudget
    , MonitoringWorkBudget
    }

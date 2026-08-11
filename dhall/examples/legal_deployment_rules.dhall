let Deployment = ../amoebius/Deployment.dhall

let V = ./legal_values.dhall

in    { cluster = ./legal_multisubstrate_cluster.dhall
      , app = ./trivial_app.dhall
      , transition = Deployment.ExecutionTransitionIntent.FirstDeployment
      , monitoring =
        { maxWorkflows = 250
        , maxRules = 500
        , maxSeries = 100000
        , maxScrapeSamplesPerSecond = 20000
        , evaluationInterval = V.d 30
        , evaluationCpu.millis = 500
        , evaluationMemory = V.b 1073741824
        , retention = V.d 1209600
        , query =
          { maxConcurrentQueries = 12
          , maxSeriesPerQuery = 20000
          , maxSamplesPerQuery = 2000000
          , maxRange = V.d 86400
          , timeout = V.d 45
          , costModel = "prom-query-v1"
          }
        , volume =
          { claim =
            { statefulSet = "prometheus", template = "data", ordinal = 0 }
          , backing = "observability-retained"
          , presentation = V.volumePresentation
          }
        , tsdbCostModel = "prom-tsdb-v1"
        }
      }
    : Deployment.Type

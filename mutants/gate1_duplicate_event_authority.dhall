let ControlPlaneStorageDemand =
      { staticEngineBytes : { bytes : Natural }
      , etcd :
          { logical :
              { churn :
                  { maxEventsPerWindow : Natural
                  , eventWindow : { seconds : Natural }
                  , maxEventBytes : { bytes : Natural }
                  , eventRetention : { seconds : Natural }
                  }
              }
          }
      , events :
          { maxEventsPerWindow : Natural
          , eventWindow : { seconds : Natural }
          , maxEventBytes : { bytes : Natural }
          , eventRetention : { seconds : Natural }
          }
      }

in  ControlPlaneStorageDemand

let App = ../amoebius/App.dhall

let Resources = ../amoebius/Resources.dhall

let Image = ../amoebius/Image.dhall

let Storage = ../amoebius/Storage.dhall

let legal = ./trivial_app.dhall

let V = ./legal_values.dhall

let IncompleteContainer =
      { id : Text
      , lifecycle : Resources.ContainerLifecycle
      , image : Image.ImageArtifact
      , runtimeMemoryWorkingSet : Storage.ByteQuantity
      , privateEphemeral :
          { rootFilesystem : Resources.RootFilesystem
          , logHeadroom : Storage.ByteQuantity
          }
      , resources : Resources.Resources
      }

let incompleteContainer
    : IncompleteContainer
    = V.container.{ id
                  , lifecycle
                  , image
                  , runtimeMemoryWorkingSet
                  , privateEphemeral
                  , resources
                  }

let badPod =
          V.podEnvelope
      //  { containers =
            { head = incompleteContainer, tail = [] : List IncompleteContainer }
          }

let badWorkload =
      V.workload // { resource = Resources.ResourceEnvelope.Pod badPod }

in        legal
      //  { workloads =
            { head = badWorkload
            , tail = [] : List Resources.ExecutionUnitIntent
            }
          }
    : App.Type

let Resources = ../amoebius/Resources.dhall

let Image = ../amoebius/Image.dhall

let Storage = ../amoebius/Storage.dhall

let V = ./legal_values.dhall

let hostEnvelope
    : Resources.HostResourceEnvelope
    = { process =
          Image.ContainerProcess.BakedService
            { binary = "/app", args = [] : List Text }
      , resources =
        { requests = { cpu.millis = 250, memory = V.b 268435456 }
        , limits = { cpu.millis = 500, memory = V.b 536870912 }
        , headroom = None Resources.HostComputeHeadroomDemand
        }
      , localBacking = "host-local"
      , cache = None Storage.HostCacheDemand
      , accelerator = Resources.HostAcceleratorDemand.None
      }

let metalOwner
    : Resources.MetalOwnerDemand
    = { profile = "apple-unified"
      , sources =
        { head =
          { key = "served-model"
          , value = Resources.AcceleratorWorkloadSource.ServedModel "model-a"
          }
        , tail = [] : List { key : Text, value : Resources.AcceleratorWorkloadSource }
        }
      , workloads =
        { head =
          { key = "served-model"
          , value.residency =
            { head =
              { key = "weights"
              , value =
                { class = Resources.AcceleratorResidencyClass.Weights
                , bytes = V.b 1073741824
                }
              }
            , tail = [] : List { key : Text, value : Resources.MetalResidencyDemand }
            }
          }
        , tail = [] : List { key : Text, value : Resources.MetalWorkloadDemand }
        }
      , coexistence =
        { maxResidentByClass =
          { head = { key = Resources.AcceleratorWorkloadClass.ServedModel, value = 1 }
          , tail = [] : List { key : Resources.AcceleratorWorkloadClass, value : Natural }
          }
        , maxRunningByClass =
          { head = { key = Resources.AcceleratorWorkloadClass.ServedModel, value = 1 }
          , tail = [] : List { key : Resources.AcceleratorWorkloadClass, value : Natural }
          }
        , model = "accelerator-coexistence-v1"
        }
      }

let metalHostEnvelope =
      hostEnvelope with accelerator = Resources.HostAcceleratorDemand.AppleMetal metalOwner

let deploymentPod =
      V.workload
        with controller =
          Resources.Controller.Deployment
            { cardinality =
                Resources.Cardinality.Replicated { desiredReplicas = 2 }
            , rollout = Resources.DeploymentRollout.Recreate
            }
        with resource = Resources.ResourceEnvelope.Pod V.podEnvelope

let statefulSet =
      V.workload
        with controller =
          Resources.Controller.StatefulSet
            { cardinality =
                Resources.Cardinality.Replicated { desiredReplicas = 2 }
            , rollout = Resources.StatefulSetRollout.OnDelete
            }
        with resource = Resources.ResourceEnvelope.Pod V.podEnvelope

let daemonSet =
      V.workload
        with controller =
          Resources.Controller.DaemonSet
            { selector = { allOf = [] : List Resources.NodeEligibilityConstraint }
            , rollout = Resources.DaemonSetRollout.OnDelete
            }
        with resource = Resources.ResourceEnvelope.Pod V.podEnvelope

let job =
      V.workload
        with controller =
          Resources.Controller.Job
            { completions = 1
            , parallelism = 1
            , backoffLimit = 3
            , podRestartPolicy = < Never >.Never
            , podReplacementPolicy = < Failed >.Failed
            , terminalRetention = { horizon = V.d 3600, model = "job-v1" }
            }
        with resource = Resources.ResourceEnvelope.Pod V.podEnvelope

let hostProcess =
      V.workload
        with controller =
          Resources.Controller.HostProcess
            { cardinality = < Once | PerNode >.Once, replacement = "restart" }
        with resource = Resources.ResourceEnvelope.Host hostEnvelope

let metalHostProcess =
      hostProcess with resource = Resources.ResourceEnvelope.Host metalHostEnvelope

in  { deploymentPod
    , statefulSet
    , daemonSet
    , job
    , hostProcess
    , metalHostProcess
    , hostEnvelope
    , metalHostEnvelope
    }

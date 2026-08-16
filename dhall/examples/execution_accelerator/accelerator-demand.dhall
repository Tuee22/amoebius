let Resources = ../../amoebius/Resources.dhall

let ByteQuantity = { bytes = 1 }

let source = Resources.AcceleratorWorkloadSource.ServedModel "model"

let residency =
      { id = "weights"
      , class = Resources.AcceleratorResidencyClass.Weights
      , bytes = ByteQuantity
      , placement = Resources.AcceleratorResidencyPlacement.Unsharded
      }

let workload =
      { residency =
        { head = { key = "weights", value = residency }
        , tail =
            [] : List
                   { key : Text, value : Resources.AcceleratorResidencyDemand }
        }
      }

let class = Resources.AcceleratorWorkloadClass.ServedModel

let bound =
      { head = { key = class, value = 1 }
      , tail =
          [] : List
                 { key : Resources.AcceleratorWorkloadClass, value : Natural }
      }

in  { profile = "a10"
    , devices = 1
    , sources =
      { head = { key = "model", value = source }
      , tail =
          [] : List { key : Text, value : Resources.AcceleratorWorkloadSource }
      }
    , workloads =
      { head = { key = "model", value = workload }
      , tail = [] : List { key : Text, value : Resources.CudaWorkloadDemand }
      }
    , coexistence =
      { maxResidentByClass = bound
      , maxRunningByClass = bound
      , model = "coexist-v1"
      }
    }

let App = ../amoebius/App.dhall

let Storage = ../amoebius/Storage.dhall

let legal = ./trivial_app.dhall

let GrowthWithoutPolicy =
      < Growable :
          { backing : Text
          , floorBytes : Storage.ByteQuantity
          , ceilingBytes : Storage.ByteQuantity
          , presentation : Storage.VolumePresentation
          }
      >

in        legal
      //  { storage =
              GrowthWithoutPolicy.Growable
                { backing = "trivial-data"
                , floorBytes = { bytes = 10737418240 }
                , ceilingBytes = { bytes = 107374182400 }
                , presentation =
                    Storage.VolumePresentation.Filesystem
                      { fsType = "ext4"
                      , overheadModel = "ext4-v1"
                      , allocation =
                          { minimumBytes = { bytes = 4096 }
                          , quantumBytes = { bytes = 4096 }
                          }
                      }
                }
          }
    : App.Type

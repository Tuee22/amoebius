let Resources = ../amoebius/Resources.dhall
in  Resources.StatefulSetRollout.RollingUpdate
      (Resources.StatefulSetRollout.RollingUpdate.Type.NativeSerialPartitionZero 1)

let Resources = ../amoebius/Resources.dhall
in  Resources.StatefulSetRollout.RollingUpdate
      < NativeSerialPartitionZero >.NativeSerialPartitionZero

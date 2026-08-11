let Resources = ../amoebius/Resources.dhall
in  Resources.DaemonSetRollout.RollingUpdate
      (< Surge : Natural | Unavailable : Natural >.Surge 1)

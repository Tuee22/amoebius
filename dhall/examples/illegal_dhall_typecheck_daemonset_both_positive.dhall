let Resources = ../amoebius/Resources.dhall
in  Resources.DaemonSetRollout.RollingUpdate { maxSurge = 1, maxUnavailable = 1 }

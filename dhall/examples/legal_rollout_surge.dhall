let Resources = ../amoebius/Resources.dhall
let app = ./trivial_app.dhall
let V = ./legal_values.dhall
let progressing =
      V.workload
        with controller =
          Resources.Controller.Deployment
            { cardinality = Resources.Cardinality.Replicated { desiredReplicas = 2 }
            , rollout =
                Resources.DeploymentRollout.RollingUpdate
                  { maxSurge = 1, maxUnavailable = 0 }
            }
        with resource = Resources.ResourceEnvelope.Pod V.podEnvelope
in  app with workloads.head = progressing

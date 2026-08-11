-- expected-tag: UnspellableCombination
-- catalog: documents/illegal_state/illegal_state_catalog.md#4-planning-ownership
-- minimal-pair: dhall/examples/legal_deployment_rules.dhall ({1,0})
let Resources = ../amoebius/Resources.dhall

let app = ./trivial_app.dhall

let V = ./legal_values.dhall

let stalled =
      V.workload
        with controller =
          Resources.Controller.Deployment
            { cardinality =
                Resources.Cardinality.Replicated { desiredReplicas = 2 }
            , rollout =
                Resources.DeploymentRollout.RollingUpdate
                  { maxSurge = 0, maxUnavailable = 0 }
            }
        with resource = Resources.ResourceEnvelope.Pod V.podEnvelope

in  app with workloads.head = stalled

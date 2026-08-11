let app = ./legal_controller_statefulset.dhall
let C = ./legal_controller_values.dhall
let Resources = ../amoebius/Resources.dhall
in  app with workloads.head.resource = Resources.ResourceEnvelope.Host C.hostEnvelope

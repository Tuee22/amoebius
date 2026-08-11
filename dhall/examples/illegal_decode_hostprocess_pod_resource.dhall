let app = ./legal_controller_hostprocess.dhall
let V = ./legal_values.dhall
let Resources = ../amoebius/Resources.dhall
in  app with workloads.head.resource = Resources.ResourceEnvelope.Pod V.podEnvelope

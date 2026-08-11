let app = ./trivial_app.dhall
let C = ./legal_controller_values.dhall
in  app with workloads.head = C.deploymentPod

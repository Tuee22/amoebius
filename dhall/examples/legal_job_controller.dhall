let Resources = ../amoebius/Resources.dhall
let V = ./legal_values.dhall
in  Resources.Controller.Job
      { completions = 1
      , parallelism = 1
      , backoffLimit = 3
      , podRestartPolicy = < Never >.Never
      , podReplacementPolicy = < Failed >.Failed
      , terminalRetention = { horizon = V.d 3600, model = "job-v1" }
      }

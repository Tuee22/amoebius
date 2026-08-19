let Resources = ../amoebius/Resources.dhall
in  Resources.Controller.Job
      { completions = 1
      , parallelism = 1
      , backoffLimit = 3
      , podRestartPolicy = < Never >.Never
      , podReplacementPolicy = < Failed >.Failed
      }

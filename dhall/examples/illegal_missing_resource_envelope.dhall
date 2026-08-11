let App = ../amoebius/App.dhall

let Resources = ../amoebius/Resources.dhall

let legal = ./trivial_app.dhall

let IncompleteWorkload =
      { id : Text, revision : Natural, controller : Resources.Controller }

let incompleteWorkload =
      { id = "trivial-api"
      , revision = 1
      , controller = legal.workloads.head.controller
      }

in    legal
    //  { workloads =
            { head = incompleteWorkload
            , tail = [] : List IncompleteWorkload
            }
        }
  : App.Type

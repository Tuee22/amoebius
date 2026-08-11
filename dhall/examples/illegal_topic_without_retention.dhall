let App = ../amoebius/App.dhall

let legal = ./trivial_app.dhall

let incompleteTopic =
      { topic = "persistent://trivial/events"
      , tieredBacking = "trivial-events-tier"
      }

in  legal // { topic = incompleteTopic } : App.Type

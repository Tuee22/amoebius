let App = ../amoebius/App.dhall

let legal = ./trivial_app.dhall

let UnboundedStorage = < Unbounded : { backing : Text } >

in        legal
      //  { storage = UnboundedStorage.Unbounded { backing = "bottomless" } }
    : App.Type

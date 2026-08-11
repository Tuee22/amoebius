let App = ../amoebius/App.dhall

let Capability = ../amoebius/Capability.dhall

let legal = ./trivial_app.dhall

in  legal // { capabilities = [ Capability.Type.Pulsar ] } : App.Type

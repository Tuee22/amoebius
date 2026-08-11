let App = ../amoebius/App.dhall

let legal = ./trivial_app.dhall

let ForeignImage = < Foreign : { digest : Text } >

in    legal // { image = ForeignImage.Foreign { digest = "sha256:foreign" } }
    : App.Type

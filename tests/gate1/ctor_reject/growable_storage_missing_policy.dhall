let Storage = ../../../dhall/amoebius/Storage.dhall

in  Storage.growable "backing" 1 10 : Storage.Type

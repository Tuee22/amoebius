let C = ../amoebius/Capability.dhall

let AppNeed = { need : C.Need }

in  { need = C.objectStoreNeed "assets", shape = C.singleNode } : AppNeed

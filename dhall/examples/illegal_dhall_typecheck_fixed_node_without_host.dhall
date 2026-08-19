let Capacity = ../amoebius/Capacity.dhall
let V = ./legal_values.dhall
in  { capacity = V.rke2Node.capacity, systemReserve = V.rke2Node.systemReserve }
      : Capacity.Rke2NodeDemand

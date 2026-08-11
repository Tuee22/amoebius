let Resources = ../../amoebius/Resources.dhall

let demand = ./accelerator-demand.dhall

in  Resources.PodAcceleratorDemand.Cuda { demand }

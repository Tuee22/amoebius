let Storage = ../../amoebius/Storage.dhall

in  Storage.TrainBudget.Continuous { checkpointCadence.steps = 1000 }

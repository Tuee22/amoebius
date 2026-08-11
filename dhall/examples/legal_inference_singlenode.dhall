let C = ../amoebius/Capability.dhall

in    { app = C.inferenceEngineNeed "inference" "llama-3" (C.cuda "cuda-llama-3")
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed

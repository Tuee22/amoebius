let C = ../amoebius/Capability.dhall

in  C.inferenceEngineNeed
      "inference"
      "llama-3"
      (C.EngineRuntime.Url { url = "https://example.invalid/engine" })

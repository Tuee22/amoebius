{ substrate = "linux-cpu"
, identity = "EngineRuntime.LlamaCppCpu@0.1.0"
, resolveArms = [ "build", "download" ]
, cacheBudgetBytes = 160
, emptyDirSizeLimitBytes = 192
, ephemeralRequestBytes = 224
, writableAndLogHeadroomBytes = 32
, firstMissConcurrency = 2
, ownerCount = 1
, clientCount = 2
, writableHostPath = False
}

{ required =
  { cpuMilli = 500
  , memoryMiB = 256
  , ephemeralMiB = 64
  , cacheMiB = 96
  , threads = 2
  , concurrency = 1
  , maxInputTokens = 64
  , maxOutputTokens = 16
  , retries = 1
  , bufferBytes = 4096
  }
, provided =
  { cpuMilli = 500
  , memoryMiB = 255
  , ephemeralMiB = 64
  , cacheMiB = 96
  , threads = 2
  , concurrency = 1
  , maxInputTokens = 64
  , maxOutputTokens = 16
  , retries = 1
  , bufferBytes = 4096
  }
, expectedTag = "CpuInferenceMemoryUnderReserved"
, effectsBeforeRefusal = 0
}

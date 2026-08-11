{ extensions =
  [ { name = "infernix"
    , provides = [ "InferenceEngine" ]
    , requires = [ "InferenceEngine" ]
    }
  , { name = "jitML", provides = [ "ObjectStore" ], requires = [] : List Text }
  ]
}

{ extensions =
  [ { name = "infernix"
    , provides = [ "InferenceEngine" ]
    , requires = [] : List Text
    }
  , { name = "jitML"
    , provides = [ "ObjectStore" ]
    , requires = [ "InferenceEngine" ]
    }
  ]
}

let RetentionPolicy =
      < SizeBounded :
          { hotBytes : Natural
          , tierAfterBytes : Natural
          , retainBytes : Natural
          }
      | TimeAndSizeBounded :
          { hotSeconds : Natural
          , retainSeconds : Natural
          , hotBytes : Natural
          , retainBytes : Natural
          }
      >

let TopicLifecycle =
      { topic : Text, tieredBacking : Text, retention : RetentionPolicy }

in  { Type = RetentionPolicy
    , TopicLifecycle
    , sizeBounded =
        \(hotBytes : Natural) ->
        \(tierAfterBytes : Natural) ->
        \(retainBytes : Natural) ->
          RetentionPolicy.SizeBounded { hotBytes, tierAfterBytes, retainBytes }
    , timeAndSizeBounded =
        \(hotSeconds : Natural) ->
        \(retainSeconds : Natural) ->
        \(hotBytes : Natural) ->
        \(retainBytes : Natural) ->
          RetentionPolicy.TimeAndSizeBounded
            { hotSeconds, retainSeconds, hotBytes, retainBytes }
    }

let Storage = ../../amoebius/Storage.dhall

in  Storage.TrainData.Feed
      { topic = "training-events", retentionBudget = "training-feed-budget" }

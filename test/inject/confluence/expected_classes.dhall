let ConfluenceClass = < Confluent | NonConfluent >

let Row =
      { invariant : Text
      , class : ConfluenceClass
      , activeActiveAllowed : Bool
      }

in  [ { invariant = "content-addressed-blob"
      , class = ConfluenceClass.Confluent
      , activeActiveAllowed = True
      }
    , { invariant = "work-id-event-fold"
      , class = ConfluenceClass.Confluent
      , activeActiveAllowed = True
      }
    , { invariant = "relational-work-row"
      , class = ConfluenceClass.Confluent
      , activeActiveAllowed = True
      }
    , { invariant = "gateway-authority"
      , class = ConfluenceClass.NonConfluent
      , activeActiveAllowed = False
      }
    , { invariant = "latest-pointer"
      , class = ConfluenceClass.NonConfluent
      , activeActiveAllowed = False
      }
    , { invariant = "cluster-vpn-ip-allocation"
      , class = ConfluenceClass.NonConfluent
      , activeActiveAllowed = False
      }
    ] : List Row

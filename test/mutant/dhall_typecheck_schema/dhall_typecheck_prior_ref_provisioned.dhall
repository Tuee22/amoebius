let PriorProvisionRefSource =
      { deployment : Text
      , generation : Natural
      , resource : < ProvisionedExecution : { receipt : Text } >
      }

in  PriorProvisionRefSource

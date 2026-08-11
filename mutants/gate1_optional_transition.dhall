let PriorProvisionRefSource =
      { deployment : Text, generation : Natural, resource : < Execution > }

let ExecutionTransitionIntent =
      Optional PriorProvisionRefSource

in  ExecutionTransitionIntent

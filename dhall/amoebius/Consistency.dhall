let RecoverySource =
      < WarmReplica
      | ColdSeedFromBackup :
          { backupPolicy : Text, freshnessBoundSeconds : Natural }
      >

let Consistency =
      { pacelcPosture : < ConsistencyFirst | AvailabilityFirst >
      , recoverySource : RecoverySource
      , dataLossBudget : Natural
      , rebindBoundSeconds : Natural
      }

in  { RecoverySource, Type = Consistency }

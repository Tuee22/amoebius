let BackupMedium =
      < ObjectStore : { bucket : Text, objectLockDays : Natural }
      | ManualAirGap : { label : Text }
      >

let BackupPolicy =
      { name : Text
      , cadenceSeconds : Natural
      , retentionGenerations : Natural
      , medium : BackupMedium
      , verification : < Checksum | RestoreProbe >
      }

in  { BackupMedium, Type = BackupPolicy }

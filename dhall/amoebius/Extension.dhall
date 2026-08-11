let MonitoringSurface =
      < Metrics : { path : Text }
      | Logs : { stream : Text }
      | Health : { path : Text }
      >

let ExtensionSpec =
      { name : Text
      , extMonitoring :
          { head : MonitoringSurface, tail : List MonitoringSurface }
      }

in  { MonitoringSurface, ExtensionSpec }

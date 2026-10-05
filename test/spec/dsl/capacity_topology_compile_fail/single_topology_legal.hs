module SingleTopologyLegal where
import Amoebius.Capacity.Types (PlacementError, Workload)
import Amoebius.Placement.Witness (Placed, place)
import Amoebius.Dsl.Topology (Topology)
single :: Topology -> [Workload] -> Either PlacementError Placed
single = place

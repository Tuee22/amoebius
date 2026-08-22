module SingleTopologyLegal where
import Amoebius.Capacity.Fold (place)
import Amoebius.Capacity.Types (Placement, PlacementError, Workload)
import Amoebius.Dsl.Topology (Topology)
single :: Topology -> [Workload] -> Either PlacementError Placement
single = place

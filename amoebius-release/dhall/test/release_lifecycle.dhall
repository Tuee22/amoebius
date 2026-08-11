-- Phase 39 representative topology. The live gate renders these typed values
-- through the existing SSA engine; this oracle names the closed domain.
{ app = "phase39-trivial"
, environments = [ "Dev", "Staging", "Prod" ]
, releases = [ "release_verified", "release_unverified", "release_protocol_unverified" ]
, rollout = [ "base-apply", "schema-migration", "finalize" ]
, migration = [ "create-new", "verified-migrate", "retire-old" ]
}

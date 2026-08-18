create table if not exists phase32_rebind_marker (marker_id text primary key, marker_sha256 text not null);
insert into phase32_rebind_marker(marker_id, marker_sha256)
values ('phase32', 'sha256:308cb887c71d9a100d4d12dd0f7408f41db956a16d16f45144bf20f62240de5c')
on conflict (marker_id) do update set marker_sha256 = excluded.marker_sha256;

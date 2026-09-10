# Migrate (WIP)

**Plan:** `openvoxadm::migrate`  
**Maturity:** WIP — **not safe for typical two-host migrations without manual
file copy**

---

## Intended story

Move from an old primary to a new primary by:

1. Connectivity `hostname` checks on old/new/(optional) related hosts
2. `openvoxadm::backup` on the **old** primary
3. `install_packages` + SSL bootstrap on the **new** primary
4. `openvoxadm::restore` on the **new** primary with `confirm => true`

---

## Parameters

| Name | Required | Effect |
|------|----------|--------|
| `old_primary_host` | yes | Backup source |
| `new_primary_host` | yes | Install + restore target |
| `replica_host` | no | Connectivity check only |
| `primary_postgresql_host` | no | Connectivity check only |
| `version` | no | Package pin for new primary (default `8.11.0`) |

---

## Example (only after you understand the footgun)

```bash
bolt plan run openvoxadm::migrate \
  --params '{
    "old_primary_host":"old.example.com",
    "new_primary_host":"new.example.com",
    "version":"8.11.0"
  }'
```

---

## Critical footgun: no cross-host copy

`backup` writes `path` on the **old** host filesystem.  
`restore` reads `input_file` on the **new** host filesystem.

The migrate plan **does not** `scp` / `file::copy` / download the archive
between hosts.

**Therefore migrate only works if:**

- both hosts share the path (NFS / shared disk), **or**
- you pause and copy the tarball to the same path on the new host yourself
  (today that means not relying on the plan alone), **or**
- you run `backup` and `restore` as separate operator-driven steps with an
  explicit copy between them (recommended).

### Recommended manual sequence

1. `backup` on old; note `path`
2. `scp` the tarball to new host (same or chosen path)
3. Install OpenVox on new (or let packages install)
4. `restore` on new with `confirm => true` and the **new host’s** path
5. Fix hostnames/certs/DNS as required for the new identity
6. Re-point agents

---

## Other limits

- New primary bootstrap then restore of old SSL may conflict — understand
  certname/hostname implications
- Optional replica / PG params are **not** configured by migrate
- Same backup limitations apply (no `pg_dump`)

---

## Related

- [backup_restore.md](backup_restore.md)
- [troubleshooting.md](troubleshooting.md)

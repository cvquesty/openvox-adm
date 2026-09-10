# Expanding an OpenVox cluster

Day-2 plans add capacity or roles after the initial install. **Read maturity
labels.** Several expansion paths are WIP or Experimental and do not deliver
full HA.

Related: [architectures.md](architectures.md),
[plan-reference.md](plan-reference.md), [troubleshooting.md](troubleshooting.md).

---

## Before you expand

1. Take a backup of the primary:
   ```bash
   bolt plan run openvoxadm::backup --params '{"targets":"primary.example.com"}'
   ```
2. Confirm `openvoxadm::status` looks sane on existing hosts.
3. Ensure new hosts are clean, reachable as root, and can reach Vox Pupuli
   repos.
4. Remember: **PostgreSQL** and **r10k** are still not auto-installed by the
   package task.

---

## Add compilers — `openvoxadm::add_compilers` (Beta)

**Prefer this plan.** `openvoxadm::add_compiler` is **deprecated** and only
wraps this one.

### Purpose

- Install OpenVox packages on new compiler hosts
- SSL bootstrap (`waitforcert 60`) — **no automatic CA sign**
- Point compilers at the primary (`server`, `ca_server`, `ca=false`)
- Append compiler certnames to OpenVoxDB
  `/etc/puppetlabs/puppetdb/certificate-allowlist`
- Set `openvoxadm_availability_group` to `A` or `B`
- Enable `openvox-server`

### Allowlist behavior (important)

The plan **stops** openvoxdb on the allowlist host (dedicated PG host if you
pass `primary_postgresql_host`, otherwise primary), appends `file_line`
entries, then **starts** openvoxdb again.

This is the path that adds compilers to the allowlist. Large **install** does
not.

### Parameters (summary)

| Name | Required | Notes |
|------|----------|-------|
| `compiler_hosts` | yes | One or many |
| `primary_host` | yes | CA / server |
| `avail_group_letter` | no | Default `A` |
| `primary_postgresql_host` | no | Where allowlist/openvoxdb live |
| `version` | no | Default `8.11.0` |
| `dns_alt_names` | no | **Dead** (accepted unused) |

### Example

```bash
bolt plan run openvoxadm::add_compilers \
  --params '{
    "compiler_hosts":["compiler3.example.com","compiler4.example.com"],
    "primary_host":"primary.example.com",
    "primary_postgresql_host":"db.example.com",
    "avail_group_letter":"B",
    "version":"8.11.0"
  }'
```

### Manual step after the plan

On the primary, sign each new compiler:

```bash
puppetserver ca list --all
puppetserver ca sign --certname compiler3.example.com
puppetserver ca sign --certname compiler4.example.com
```

Docs that say “the primary signs them automatically” are **wrong** for current
code.

### What success looks like

- Compilers: `systemctl is-active openvox-server` → `active`
- Allowlist file contains the new certnames
- After signing, agent/compiler TLS works

---

## Add a dedicated database — `openvoxadm::add_database` (WIP)

**Param name quirk:** the DB host parameter is `targets` (plural) but typed as
a single host.

### Modes

| `mode` | Behavior |
|--------|----------|
| `undef` or `init` | `configure_postgresql` + `configure_openvoxdb` (wire primary `puppetdb.conf`) |
| `pair` | Prints that HA replication is **not implemented**; only `configure_postgresql` |

### Example — init

```bash
bolt plan run openvoxadm::add_database \
  --params '{
    "targets":"db.example.com",
    "primary_host":"primary.example.com",
    "mode":"init",
    "version":"8.11.0"
  }'
```

### Honest limits

- Does **not** migrate existing co-located OpenVoxDB/Postgres data off the
  primary. Plan for dump/restore yourself if you are moving an established DB.
- `pair` is a **stub**, not streaming replication.
- Still depends on PostgreSQL packages being present/usable on the DB host.
- `configure_openvoxdb` **overwrites** allowlist to primary-only — re-add
  compilers afterward if needed.

---

## Add a replica — `openvoxadm::add_replica` (Experimental)

### What it does

1. Stops `puppet` on primary (errors ignored).
2. Installs packages on `replica_host`; SSL bootstrap.
3. Sets `server`, `ca_server`, `openvoxadm_role=server`,
   `openvoxadm_availability_group=B` (hardcoded B).
4. Enables `openvox-server`.
5. Optional `replica_postgresql_host`: packages + enable postgresql/openvoxdb
   **only** — no OpenVoxDB rewire, no replication.

### Example

```bash
bolt plan run openvoxadm::add_replica \
  --params '{
    "primary_host":"primary.example.com",
    "replica_host":"replica.example.com",
    "version":"8.11.0"
  }'
```

### What it does *not* do

- CA sync / code sync / automatic failover
- Streaming replication
- Zero-downtime HA

Sign the replica CSR manually. Treat this as **bring-up scaffolding**.

---

## Deprecated: `openvoxadm::add_compiler`

Prints a deprecation warning and calls `add_compilers` with a single host.
Update your scripts.

---

## Replace failed PostgreSQL — WIP sibling

`openvoxadm::replace_failed_postgresql` rewires config to a replacement host.
It does **not** copy data; `working_postgresql_host` and
`failed_postgresql_host` are logged only. See
[backup_restore.md](backup_restore.md) and [plan-reference.md](plan-reference.md).

---

## Suggested order for growing from Standard

1. Backup
2. `add_database` (`init`) if you need a dedicated DB — accept WIP risk / manual
   data move
3. `add_compilers` for scale-out compile (sign CSRs; watch allowlist)
4. Defer `add_replica` / `pair` until HA features exist

---

## Related footguns

Allowlist wipe on reconfigure, unsigned CSRs, trust auth: 
[troubleshooting.md](troubleshooting.md), [security-notes.md](security-notes.md).

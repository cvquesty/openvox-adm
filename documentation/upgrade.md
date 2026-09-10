# Upgrading OpenVox with openvox-adm

**Plan:** `openvoxadm::upgrade`  
**Maturity:** Experimental

This plan re-pins OpenVox packages across listed hosts and bounces services. It
is **not** a full configuration migrate or a rolling zero-downtime upgrade.

---

## When to use it

- You already have an OpenVox 8.x cluster managed with this module’s layout
- You want to move to another **8.x** version string (default target pin in
  examples: set explicitly, e.g. `8.12.0`)
- You accept parallel package upgrades and brief service interruption on each
  host in the set

## When not to use it

- Crossing major lines without reading asserts (`permit_unsafe_versions` is an
  escape hatch, not a support promise)
- Expecting automatic PuppetDB schema migration or re-running `configure_*`
- Expecting replica PostgreSQL hosts to be specially started (they are included
  in stop/upgrade sets but not given special start logic)

---

## Prerequisites

1. Bolt `>= 3.17.0 < 6.0.0`
2. Inventory/SSH to every host you list
3. Fresh [backup](backup_restore.md) of the primary (and DB strategy if
   dedicated PostgreSQL holds critical data)
4. Maintenance window — services stop on the upgrade set

---

## Parameters

| Name | Required | Effect |
|------|----------|--------|
| `primary_host` | yes | Always included |
| `replica_host` | no | Included in stop/upgrade/start |
| `compiler_hosts` | no | Same |
| `primary_postgresql_host` | no | Where PG/openvoxdb are started after |
| `replica_postgresql_host` | no | In stop/upgrade set; **not** specially started |
| `version` | no | Target pin (default `8.11.0`) |
| `final_agent_state` | no | If `running`, start `puppet` agent on all |
| `permit_unsafe_versions` | no | Bypass 8.x assert |

Full table: [plan-reference.md](plan-reference.md#openvoxadmupgrade).

---

## What the plan does

1. Assert Bolt + OpenVox version constraints
2. Build the unique target list from all provided role hosts
3. `systemctl stop puppet openvox-server openvoxdb` on all (`_catch_errors`)
4. Parallel `openvoxadm::install_packages` with the target version
5. Start:
   - primary: `enable --now openvox-server`
   - PG host or primary: `enable --now postgresql openvoxdb`
   - optional replica / compilers: `enable --now openvox-server`
6. Optionally start `puppet` if `final_agent_state == running`
7. Return `{ status => upgraded, version => … }`

---

## Example

```bash
bolt plan run openvoxadm::upgrade \
  --params '{
    "primary_host":"primary.example.com",
    "compiler_hosts":["compiler1.example.com","compiler2.example.com"],
    "primary_postgresql_host":"db.example.com",
    "version":"8.12.0",
    "final_agent_state":"running"
  }'
```

Standard-only:

```bash
bolt plan run openvoxadm::upgrade \
  --params '{
    "primary_host":"primary.example.com",
    "version":"8.12.0"
  }'
```

---

## What success looks like

1. Plan returns success
2. `openvoxadm::status` shows the new version string on hosts
3. `openvox-server` (and DB services where expected) are active
4. A test agent can fetch a catalog

---

## What can go wrong

| Issue | Why |
|-------|-----|
| Version assert fails | Not `8.*` and unsafe flag false |
| PostgreSQL won’t start | Still not installed by package task |
| Replica PG left down | No special start path for `replica_postgresql_host` |
| Config drift | No configure_* re-run |
| DB errors after jump | No schema migrate step in this plan |

---

## Recommended operator sequence

1. `backup` (+ DB dump if you have dedicated Postgres data beyond the module’s
   file-level puppetdb tarball)
2. `upgrade`
3. `status` on all roles
4. Spot-check catalogs / OpenVoxDB
5. Keep the previous recovery tarball until you trust the new pin

---

## Related

- [install.md](install.md) — package task behavior (EL vs apt differences)
- [troubleshooting.md](troubleshooting.md)

# Plan reference (public plans)

This page lists every **public** plan under `openvoxadm::`, with purpose,
maturity, parameters (as implemented in code), example Bolt commands, and
honest notes. Subplans under `openvoxadm::subplans::` are building blocks
called by public plans — operators normally do not run them directly.

**Legend for Effect**

- **Effect** — used at runtime
- **Dead** — accepted (and maybe logged) but unused by plan logic

Default OpenVox pin is **`8.11.0`** unless you override `version`.

Module install reminder (pre-Forge):

```ruby
# Puppetfile
mod 'openvox-adm',
  :git => 'https://github.com/cvquesty/openvox-adm.git',
  :branch => 'development'
```

```bash
bolt puppetfile install
```

---

## Maturity quick map

| Plan | Maturity |
|------|----------|
| `install` (standard / large / XL) | Beta / Experimental / WIP |
| `upgrade` | Experimental |
| `status` | Beta |
| `add_compilers` | Beta |
| `add_compiler` | Deprecated |
| `add_database` | WIP |
| `add_replica` | Experimental |
| `backup` / `restore` | Experimental |
| `backup_ca` / `restore_ca` | Experimental |
| `migrate` | WIP |
| `replace_failed_postgresql` | WIP |
| `uninstall` | Beta |

---

## `openvoxadm::install`

**Purpose:** Install OpenVox packages on listed role hosts, bootstrap the
primary, configure primary (and optionally compilers / dedicated DB), then
enable services (and optional r10k if preinstalled).

**Maturity:** Standard **Beta**; Large **Experimental**; XL/HA **WIP**.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `primary_host` | SingleTargetSpec | — | yes | Primary install/configure |
| `replica_host` | Optional Single | undef | no | Packages only; **not configured** |
| `compiler_hosts` | Optional TargetSpec | undef | no | Install + `configure_compiler` |
| `legacy_compilers` | Optional TargetSpec | undef | no | **Dead** |
| `primary_postgresql_host` | Optional Single | undef | no | Dedicated DB path |
| `replica_postgresql_host` | Optional Single | undef | no | Packages only; **not configured** |
| `version` | Openvox_version | `8.11.0` | no | Package pin |
| `dns_alt_names` | Optional Array[String] | undef | no | Primary `dns_alt_names` |
| `compiler_pool_address` | Optional String | undef | no | **Dead** |
| `internal_compiler_a_pool_address` | Optional String | undef | no | **Dead** |
| `internal_compiler_b_pool_address` | Optional String | undef | no | **Dead** |
| `r10k_remote` | Optional String | undef | no | Triggers `configure_r10k` if r10k exists |
| `r10k_private_key_file` | Optional String | undef | no | **Dead** |
| `r10k_private_key_content` | Optional Pem | undef | no | **Dead** |
| `stagingdir` | Optional String | undef | no | **Dead** |
| `uploaddir` | Optional String | undef | no | **Dead** |
| `final_agent_state` | Enum running/stopped | `running` | no | Passed through; **Dead** in configure |
| `permit_unsafe_versions` | Boolean | false | no | Bypass 8.x assert |

### Example — Standard (recommended Quick Start)

```bash
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

### Example — Large (Experimental)

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host":"primary.example.com",
    "compiler_hosts":["compiler1.example.com","compiler2.example.com"],
    "primary_postgresql_host":"db.example.com",
    "version":"8.11.0"
  }'
```

### Notes

- Asserts Bolt version and OpenVox 8.x (unless unsafe flag).
- Does **not** explicitly install PostgreSQL or r10k packages/gems.
- Signs **primary** certname only; compilers need manual `ca sign`.
- Large install allowlist = primary only until `add_compilers`.
- XL replica / pool params do not configure HA.

See [install.md](install.md), [runbook-install-standard.md](runbook-install-standard.md).

---

## `openvoxadm::upgrade`

**Purpose:** Stop key services, reinstall/pin packages on all listed hosts in
parallel, start services again, optionally start the `puppet` agent.

**Maturity:** Experimental.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `primary_host` | Single | — | yes | In upgrade set |
| `replica_host` | Optional Single | undef | no | Included in stop/upgrade/start |
| `compiler_hosts` | Optional TargetSpec | undef | no | Same |
| `primary_postgresql_host` | Optional Single | undef | no | Where to start PG/openvoxdb |
| `replica_postgresql_host` | Optional Single | undef | no | In stop/upgrade set; **not** specially started |
| `version` | Openvox_version | `8.11.0` | no | Target pin |
| `final_agent_state` | Enum | `running` | no | Start `puppet` if `running` |
| `permit_unsafe_versions` | Boolean | false | no | Bypass assert |

### Example

```bash
bolt plan run openvoxadm::upgrade \
  --params '{
    "primary_host":"primary.example.com",
    "version":"8.12.0",
    "final_agent_state":"running"
  }'
```

### Notes

- No `configure_*` re-run, no DB schema migrate, no rolling strategy.
- See [upgrade.md](upgrade.md).

---

## `openvoxadm::status`

**Purpose:** Run the `openvoxadm::status` task on each target and return Bolt
task results (free-form text per host).

**Maturity:** Beta.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `targets` | TargetSpec | — | yes | Hosts to check |

### Example

```bash
bolt plan run openvoxadm::status --targets primary.example.com,compiler1.example.com
```

### Notes

- Always prints checks for `openvox-server`, `openvoxdb`, and `postgresql`.
- Compilers normally show openvoxdb/postgresql as **stopped** — that is expected,
  not an “N/A” string.
- See [status.md](status.md).

---

## `openvoxadm::add_compilers`

**Purpose:** Install packages on new compilers, bootstrap SSL, point them at
the primary (`ca=false`), append certnames to OpenVoxDB allowlist, enable
`openvox-server`, set availability group letter.

**Maturity:** Beta (rough edges: CSR signing, unused `dns_alt_names`).

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `compiler_hosts` | TargetSpec | — | yes | New compilers |
| `primary_host` | Single | — | yes | CA / server pointer |
| `avail_group_letter` | Enum A/B | `A` | no | `openvoxadm_availability_group` |
| `dns_alt_names` | Optional Array[String[1]] | undef | no | **Dead** (computed unused) |
| `primary_postgresql_host` | Optional Single | undef | no | Host that holds openvoxdb/allowlist |
| `version` | Openvox_version | `8.11.0` | no | Package pin |

### Example

```bash
bolt plan run openvoxadm::add_compilers \
  --params '{
    "compiler_hosts":["compiler3.example.com"],
    "primary_host":"primary.example.com",
    "primary_postgresql_host":"db.example.com",
    "avail_group_letter":"B",
    "version":"8.11.0"
  }'
```

### Notes

- Stops openvoxdb on allowlist host, appends lines, starts it again.
- **You** must sign compiler CSRs on the primary.
- Prefer this over deprecated `add_compiler`.

---

## `openvoxadm::add_compiler` (deprecated)

**Purpose:** Thin wrapper that warns and calls `add_compilers`.

**Maturity:** Deprecated.

Uses singular `compiler_host` and optional `dns_alt_names` as a single string
wrapped into an array. Migrate callers to `add_compilers`.

---

## `openvoxadm::add_database`

**Purpose:** Add a dedicated database host. `init` / undef runs
`configure_postgresql` + `configure_openvoxdb`. `pair` prints that HA
replication is not implemented and only runs `configure_postgresql`.

**Maturity:** WIP.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `targets` | Single | — | yes | New DB host (param name is plural `targets`) |
| `primary_host` | Single | — | yes | Agent server + puppetdb.conf |
| `mode` | Optional Enum init/pair | undef | no | init/undef → full OpenVoxDB wire-up; pair → stub |
| `version` | Openvox_version | `8.11.0` | no | Package pin |

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

### Notes

- Does **not** migrate existing co-located PuppetDB data off the primary.
- `pair` is not streaming replication.
- See [expanding.md](expanding.md).

---

## `openvoxadm::add_replica`

**Purpose:** Install packages on a replica, SSL bootstrap, set `server` /
`ca_server` / role / availability group B, enable `openvox-server`. Optional
replica PG host gets packages + enable services only.

**Maturity:** Experimental (bring-up only; not full HA).

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `primary_host` | Single | — | yes | CA/server |
| `replica_host` | Single | — | yes | New replica |
| `replica_postgresql_host` | Optional Single | undef | no | Packages + enable only |
| `version` | Openvox_version | `8.11.0` | no | Package pin |

### Example

```bash
bolt plan run openvoxadm::add_replica \
  --params '{
    "primary_host":"primary.example.com",
    "replica_host":"replica.example.com",
    "version":"8.11.0"
  }'
```

### Notes

- No CA sync, code sync, failover automation, or DB replication.
- CSR signing still manual.

---

## `openvoxadm::backup`

**Purpose:** Create a recovery archive on the **target** under
`/var/backups/openvox` by default.

**Maturity:** Experimental.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `targets` | Single | — | yes | Host to back up (usually primary) |
| `backup_type` | Enum recovery/custom | `recovery` | no | **Dead** (not branched) |
| `output_directory` | String | `/var/backups/openvox` | no | Parent directory |

### Example

```bash
bolt plan run openvoxadm::backup \
  --params '{"targets":"primary.example.com"}'
```

### Notes

- Produces outer `openvox-backup-<ts>.tar.gz` containing component tarballs +
  `MANIFEST.txt`.
- No `pg_dump` of a dedicated PostgreSQL datadir.
- Artifact path is **on the target disk**, not on your laptop.
- See [backup_restore.md](backup_restore.md).

---

## `openvoxadm::restore`

**Purpose:** Extract a recovery tarball **on the target** and restore
component archives into SSL, config, environments, and PuppetDB data paths.

**Maturity:** Experimental.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `targets` | Single | — | yes | Restore target |
| `input_file` | Pattern `.*\.tar\.gz$` | — | yes | Path **on target** |
| `confirm` | Boolean | false | must be **true** | Safety gate |

### Example

```bash
bolt plan run openvoxadm::restore \
  --params '{
    "targets":"primary.example.com",
    "input_file":"/var/backups/openvox/openvox-backup-20260101T000000Z.tar.gz",
    "confirm":true
  }'
```

### Notes

- Stops/restarts `openvox-server` and `openvoxdb`.
- Does not reinstall packages.
- Controller path ≠ target path unless you copied the file.

---

## `openvoxadm::backup_ca`

**Purpose:** Tar the SSL tree to `…/openvox-ca-backup-<ts>/ca_backup.tgz`
under the output directory.

**Maturity:** Experimental.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `target` | Single | — | yes | Note singular **`target`**, not `targets` |
| `output_directory` | Optional String | `/var/backups/openvox` | no | Parent dir |

### Example

```bash
bolt plan run openvoxadm::backup_ca \
  --params '{"target":"primary.example.com"}'
```

---

## `openvoxadm::restore_ca`

**Purpose:** Extract a CA tarball into a recovery directory, then
`cp -a` into `/etc/puppetlabs/puppet/ssl/`.

**Maturity:** Experimental.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `target` | Single | — | yes | Singular `target` |
| `file_path` | String | — | yes | CA tarball on target |
| `recovery_directory` | Optional String | `/var/backups/openvox/openvox_recovery` | no | Extract dir |
| `confirm` | Boolean | false | must be **true** | Gate |

### Example

```bash
bolt plan run openvoxadm::restore_ca \
  --params '{
    "target":"primary.example.com",
    "file_path":"/var/backups/openvox/openvox-ca-backup-…/ca_backup.tgz",
    "confirm":true
  }'
```

### Notes

- Does **not** stop/restart services — restart yourself if needed.

---

## `openvoxadm::migrate`

**Purpose:** Connectivity check → `backup` on old primary → install packages +
SSL bootstrap on new primary → `restore` on new primary with `confirm => true`.

**Maturity:** WIP (typically broken across two hosts).

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `old_primary_host` | Single | — | yes | Backup source |
| `new_primary_host` | Single | — | yes | Install + restore |
| `replica_host` | Optional Single | undef | no | Connectivity check only |
| `primary_postgresql_host` | Optional Single | undef | no | Connectivity check only |
| `version` | Openvox_version | `8.11.0` | no | New primary packages |

### Example

```bash
bolt plan run openvoxadm::migrate \
  --params '{
    "old_primary_host":"old.example.com",
    "new_primary_host":"new.example.com",
    "version":"8.11.0"
  }'
```

### Critical note

Backup path lives on the **old** host. Restore reads the same path on the
**new** host. There is **no** `file::copy` / scp step. Copy the tarball
yourself (or use shared storage), or restore will fail. See
[migrate.md](migrate.md).

---

## `openvoxadm::replace_failed_postgresql`

**Purpose:** Stop services on primary, install packages on replacement,
`configure_postgresql` + `configure_openvoxdb`, restart primary services.

**Maturity:** WIP.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `primary_host` | Single | — | yes | Stop/restart + puppetdb.conf |
| `working_postgresql_host` | Single | — | yes | **Logged only** |
| `failed_postgresql_host` | Single | — | yes | **Logged only** |
| `replacement_postgresql_host` | Single | — | yes | Install + configure |
| `version` | Openvox_version | `8.11.0` | no | Package pin |

### Notes

- Does **not** copy or promote database data. You can “succeed” with an empty DB
  unless you restore data separately.

---

## `openvoxadm::uninstall`

**Purpose:** Stop services; remove OpenVox packages; delete SSL, PuppetDB data,
and environment contents (partial cleanup).

**Maturity:** Beta.

### Parameters

| Name | Type | Default | Required | Effect |
|------|------|---------|----------|--------|
| `targets` | TargetSpec | — | yes | Hosts to wipe |
| `confirm` | Boolean | false | must be **true** | Gate |

### Example

```bash
bolt plan run openvoxadm::uninstall \
  --params '{"targets":"primary.example.com","confirm":true}'
```

### Notes

- Leaves release repos, PostgreSQL packages, openbolt/termini (where present),
  and parts of `/etc/puppetlabs` behind. See [uninstall.md](uninstall.md).

---

## Subplans (not primary operator entry points)

| Subplan | Role |
|---------|------|
| `subplans::install` | Packages + bootstrap + primary/compiler/pg/openvoxdb |
| `subplans::configure` | Optional r10k + service enable |
| `subplans::configure_primary` | dns_alt_names, restart, sign primary |
| `subplans::configure_compiler` | server/ca_server/ca=false |
| `subplans::configure_postgresql` | agent server + enable PG/openvoxdb |
| `subplans::configure_openvoxdb` | DB user, trust hba, ini files, allowlist wipe/write |
| `subplans::configure_r10k` | Write r10k.yaml + deploy |

---

## Related docs

- [concepts.md](concepts.md) — glossary
- [troubleshooting.md](troubleshooting.md) — footguns
- [security-notes.md](security-notes.md) — trust auth / confirm gates

# Backup and restore

**Maturity:** Experimental for `backup` / `restore` / `backup_ca` /
`restore_ca`. Related DR plans (`migrate`, `replace_failed_postgresql`) are
**WIP**.

This page documents the **actual on-disk contract** implemented by the plans.

---

## Mental model

| Plan | Where it runs | What you get |
|------|---------------|--------------|
| `backup` | Target (usually primary) | Outer `openvox-backup-<UTC-ts>.tar.gz` under output dir |
| `restore` | Target | Extracts that archive **on the same host path you provide** |
| `backup_ca` | Target (`target` param) | `…/openvox-ca-backup-<ts>/ca_backup.tgz` |
| `restore_ca` | Target (`target` param) | Copies SSL tree back; **no** service restart |

Default parent directory: **`/var/backups/openvox`** (not `/tmp`).

Bolt’s controller (your laptop/jump host) is **not** the backup disk unless you
copy files there yourself.

---

## Full recovery backup — `openvoxadm::backup`

### Parameters

| Name | Default | Notes |
|------|---------|-------|
| `targets` | required | Single host to back up |
| `output_directory` | `/var/backups/openvox` | Parent directory |
| `backup_type` | `recovery` | **Dead** — not branched in code |

### Example

```bash
bolt plan run openvoxadm::backup \
  --params '{"targets":"primary.example.com"}'
```

Custom directory:

```bash
bolt plan run openvoxadm::backup \
  --params '{
    "targets":"primary.example.com",
    "output_directory":"/var/backups/openvox"
  }'
```

### On-disk contract (single recovery tarball)

1. Create working dir:
   `/var/backups/openvox/openvox-backup-<UTC-timestamp>/` (mode `0700`)
2. Component archives inside that directory:
   - `certs.tar.gz` ← `/etc/puppetlabs/puppet/ssl`
   - `config.tar.gz` ← `/etc/puppetlabs/puppet`
   - `environments.tar.gz` ← code environments (`_catch_errors`)
   - `puppetdb.tar.gz` ← `/opt/puppetlabs/server/data/puppetdb` (`_catch_errors`)
3. `MANIFEST.txt` listing
4. Wrap the directory into:
   **`${output_directory}/openvox-backup-<ts>.tar.gz`**

Return shape includes `{ path => recovery.tar.gz, directory => working_dir }`.

### What is not included

- No `pg_dump` of PostgreSQL
- Dedicated PG datadir beyond PuppetDB’s application data path is not dumped as
  a database dump
- `backup_type => custom` does nothing special

---

## Restore — `openvoxadm::restore`

### Safety gate

Requires **`confirm => true`**. Without it the plan fails immediately.

### Parameters

| Name | Notes |
|------|-------|
| `targets` | Restore host |
| `input_file` | Must match `.*\.tar\.gz$` — path **on the target** |
| `confirm` | Must be `true` |

### Example

```bash
bolt plan run openvoxadm::restore \
  --params '{
    "targets":"primary.example.com",
    "input_file":"/var/backups/openvox/openvox-backup-20260115T120000Z.tar.gz",
    "confirm":true
  }'
```

### Steps the plan takes

1. Extract outer tarball on the target next to the file
2. Stop `openvox-server` and `openvoxdb`
3. For each component archive that **exists on the target**, extract into the
   matching path
4. Restart `openvox-server` and `openvoxdb`

Does **not** reinstall packages. OpenVox must already be installed.

### Footguns

1. **`input_file` is on the target**, not on the Bolt controller.
2. Copy archives between hosts before restore if needed (`scp`, shared storage,
   etc.).
3. Restoring SSL/config onto a host with a different hostname/certname can
   break TLS identity — know what you are restoring.
4. PostgreSQL contents may still be wrong/empty if you only restore app files
   without a DB dump strategy.

---

## CA-only backup — `openvoxadm::backup_ca`

**Parameter name is `target` (singular).**

```bash
bolt plan run openvoxadm::backup_ca \
  --params '{"target":"primary.example.com"}'
```

Creates a timestamped directory under `/var/backups/openvox` and writes
`ca_backup.tgz` from `/etc/puppetlabs/puppet/ssl`.

---

## CA-only restore — `openvoxadm::restore_ca`

Requires **`confirm => true`**. Parameter name is **`target`**.

```bash
bolt plan run openvoxadm::restore_ca \
  --params '{
    "target":"primary.example.com",
    "file_path":"/var/backups/openvox/openvox-ca-backup-…/ca_backup.tgz",
    "confirm":true
  }'
```

Default extract dir: `/var/backups/openvox/openvox_recovery`.

**Important:** this plan does **not** stop or restart `openvox-server` /
`openvoxdb`. Restart services yourself if processes still hold old material:

```bash
systemctl restart openvox-server openvoxdb
```

---

## Migrate interaction

`openvoxadm::migrate` calls `backup` on the old primary and `restore` on the
new primary with `confirm => true`, but **does not copy** the tarball between
hosts. See [migrate.md](migrate.md).

---

## Replace failed PostgreSQL (related WIP)

`openvoxadm::replace_failed_postgresql` rewires OpenVoxDB/Postgres config to a
replacement host. It does **not** restore database data. Operators must restore
DB contents separately. `working_postgresql_host` and `failed_postgresql_host`
are required params but only logged.

---

## Operator checklist

1. Run `backup` on a healthy primary; record the returned `path`
2. Copy that file off-box to safe storage
3. Before restore drills: install OpenVox on the target, place the tarball on
   the target path, pass `confirm => true`
4. After `restore_ca`, restart services manually
5. Do not assume migrate moves files for you

---

## Related

- [migrate.md](migrate.md)
- [uninstall.md](uninstall.md)
- [troubleshooting.md](troubleshooting.md)

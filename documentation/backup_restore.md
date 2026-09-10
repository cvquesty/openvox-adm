# Backup and Restore

Backing up your OpenVox cluster is one of the most important things you can
do. If a server dies, a certificate is accidentally deleted, or you need to
roll back an upgrade, a good backup will save your bacon.

This guide covers:

- Full backups of your primary server
- CA-only backups (certificates)
- Restoring from backups
- Replacing a failed PostgreSQL host

> **Friendly tip:** Run backups *before* making any major changes — upgrades,
> adding replicas, or touching certificates. You will thank yourself later.

---

## Table of Contents

- [What Gets Backed Up](#what-gets-backed-up)
- [Backup / Restore Contract](#backup--restore-contract)
- [Full Backup](#full-backup)
- [CA-Only Backup](#ca-only-backup)
- [Restore from Backup](#restore-from-backup)
- [Restore CA Only](#restore-ca-only)
- [Replace a Failed PostgreSQL Host](#replace-a-failed-postgresql-host)

---

## What Gets Backed Up

The backup plans capture the following data:

| Data | Description |
|------|-------------|
| **CA and SSL certificates** | All certs and keys under `/etc/puppetlabs/puppet/ssl/` |
| **Puppet configuration** | `puppet.conf`, `puppetdb.conf`, and related files |
| **r10k environments** | All deployed environments under `/etc/puppetlabs/code/environments/` |
| **OpenVoxDB data** | Facts, catalogs, and reports (only if stored locally) |

> **Note:** If you use a dedicated PostgreSQL host, the database data is
> *not* included in the backup. You should back up PostgreSQL separately
> (e.g., with `pg_dump` or barman).

---

## Backup / Restore Contract

`openvoxadm::backup` and `openvoxadm::restore` share one contract:

1. **Backup** writes component archives into a timestamped working directory,
   then wraps that directory into a **single** `recovery.tar.gz`.
2. **Restore** takes that outer `*.tar.gz` path (`input_file`), extracts it on
   the **target**, and restores any present component archives
   (`certs.tar.gz`, `config.tar.gz`, `environments.tar.gz`, `puppetdb.tar.gz`).
3. **Migrate** calls backup, then passes `backup['path']` (the recovery
   tarball) into restore.

Default output location is `/var/backups/openvox` (not `/tmp`).

Destructive plans (`restore`, `restore_ca`, `uninstall`) require
`confirm => true`.

---

## Full Backup

A full backup captures everything listed above. Run it regularly — daily
or before any significant change.

```bash
bolt plan run openvoxadm::backup \
  --targets primary.example.com \
  --params '{"output_directory":"/var/backups/openvox"}'
```

**Output:** A single recovery tarball such as:

`/var/backups/openvox/openvox-backup-2026-04-13T120000Z.tar.gz`

That tarball contains a directory with:

- `certs.tar.gz` — all certificates and keys
- `config.tar.gz` — puppet.conf and related files
- `environments.tar.gz` — your deployed code
- `puppetdb.tar.gz` — local OpenVoxDB data (if any)
- `MANIFEST.txt` — listing of backup contents

The plan return value includes:

- `path` — absolute path to the recovery `.tar.gz` (use this with restore)
- `directory` — the working directory that was wrapped

**Recommended:** Automate this with a cron job on your primary:

```cron
0 2 * * * bolt plan run openvoxadm::backup --targets primary.example.com --params '{"output_directory":"/var/backups/openvox"}' >> /var/log/openvox-backup.log 2>&1
```

---

## CA-Only Backup

Sometimes you only need the certificates — for example, if you want to
migrate to new hardware but keep the same CA.

```bash
bolt plan run openvoxadm::backup_ca \
  --targets primary.example.com \
  --params '{"output_directory":"/var/backups/openvox"}'
```

**Output:** A single file `ca_backup.tgz` inside a timestamped directory under
`/var/backups/openvox`.

---

## Restore from Backup

If disaster strikes, you can restore your primary from a full recovery
tarball produced by `openvoxadm::backup`.

```bash
bolt plan run openvoxadm::restore \
  --targets primary.example.com \
  --params '{
    "input_file":"/var/backups/openvox/openvox-backup-2026-04-13T120000Z.tar.gz",
    "confirm": true
  }'
```

**What the plan does:**

1. Extracts the recovery tarball **on the target**.
2. Stops openvox-server and openvoxdb.
3. Restores certificates, config, environments, and local OpenVoxDB data when
   those component archives exist (existence is checked on the target).
4. Restarts services.

> **Warning:** This overwrites existing files. You must pass `confirm => true`.

---

## Restore CA Only

If you only need to restore certificates (for example, after an accidental
deletion), use the CA-only restore:

```bash
bolt plan run openvoxadm::restore_ca \
  --targets primary.example.com \
  --params '{
    "file_path":"/var/backups/openvox/openvox-ca-backup-.../ca_backup.tgz",
    "confirm": true
  }'
```

This extracts the CA backup and copies certificates back into place.

---

## Replace a Failed PostgreSQL Host

If your dedicated PostgreSQL host dies and you have a replacement ready,
this plan reconfigures your cluster to use the new host.

```bash
bolt plan run openvoxadm::replace_failed_postgresql \
  --params '{
    "primary_host": "primary.example.com",
    "working_postgresql_host": "db1.example.com",
    "failed_postgresql_host": "db2.example.com",
    "replacement_postgresql_host": "db3.example.com",
    "version": "8.11.0"
  }'
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| `primary_host` | Your primary OpenVox server |
| `working_postgresql_host` | The still-healthy PostgreSQL host |
| `failed_postgresql_host` | The dead host (for reference) |
| `replacement_postgresql_host` | The new host that will take over |
| `version` | OpenVox package version to install on the replacement |

**What the plan does:**

1. Stops services on the primary.
2. Installs packages on the replacement.
3. Configures PostgreSQL + OpenVoxDB via the shared configure subplans
   (does **not** set `puppet config set server` to the database host).
4. Restarts services.

> **Note:** This assumes you have already restored the database from a
> backup onto the replacement host (for example, with `pg_basebackup` or
> `pg_restore`). The plan does *not* copy data — it only rewires the
> connections.

---

## 💡 Best Practices

- **Test your backups.** Restore to a test server periodically to make sure
  they actually work.
- **Store backups off-site.** A backup on the same server is no backup at
  all if the datacenter burns down.
- **Encrypt backups.** Certificates are sensitive — consider encrypting
  backup files at rest.
- **Document your restore procedures.** When things go wrong, you will be
  stressed. A written runbook helps.

---

## Next Steps

- [Check status](status.md) to verify your cluster is healthy after any
  restore.
- Review [architectures](architectures.md) to understand which components
  need backing up in your setup.

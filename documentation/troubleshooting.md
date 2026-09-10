# Troubleshooting and footguns

This page turns the code-model failure modes into operator guidance. When docs
and code disagree, **trust the plans/tasks on your checkout**.

Related deep dives: [security-notes.md](security-notes.md),
[backup_restore.md](backup_restore.md), [migrate.md](migrate.md),
[plan-reference.md](plan-reference.md).

---

## How to use this page

1. Find the symptom
2. Read the cause (what the code actually does)
3. Apply the mitigation
4. Re-run `openvoxadm::status` on affected hosts

---

## 1. Compiler or replica TLS failures / waiting for certificates

### Symptom

`puppet ssl bootstrap` waited ~60s; `openvox-server` on a compiler/replica
fails TLS; `puppetserver ca list` shows **pending** CSRs.

### Cause

Install / `add_compilers` / `add_replica` bootstrap with
`--waitforcert 60` but **do not** auto-sign non-primary certnames. Only the
primary’s own certname is signed during install.

### Mitigation

On the primary:

```bash
puppetserver ca list --all
puppetserver ca sign --certname compiler1.example.com
```

Prefer targeted `--certname` over `--all`.

---

## 2. Migrate restore cannot find the backup

### Symptom

`openvoxadm::migrate` backs up on the old host, then restore fails on the new
host for missing `input_file`.

### Cause

**No cross-host file copy.** Backup path is local to the old primary; restore
reads the same string on the new primary.

### Mitigation

Do not rely on migrate alone. `scp`/sync the tarball, or run backup → copy →
restore as separate steps. Details: [migrate.md](migrate.md).

---

## 3. `postgresql` service missing or enable fails

### Symptom

`systemctl enable --now postgresql` fails; unit not found.

### Cause

`tasks/install_packages.sh` does **not** install the `postgresql` package
explicitly. The plan assumes it is already present or pulled in some other way
(fragile).

### Mitigation

Install and verify PostgreSQL **before** install/configure (see
[runbook-install-standard.md](runbook-install-standard.md) step 2.4).

---

## 4. r10k deploy fails during configure

### Symptom

`configure_r10k` cannot find `r10k`, or Git auth fails.

### Cause

The module does **not** install the r10k gem/package. Private key install
parameters on `openvoxadm::install` are **dead**.

### Mitigation

Preinstall r10k, create `/etc/puppetlabs/r10k/`, and arrange Git credentials
yourself. Or omit `r10k_remote` and configure code deploy later.

---

## 5. Database auth / remote JDBC confusion

### Symptom

OpenVoxDB cannot connect; or you hoped for password/SCRAM auth.

### Cause

Lab defaults: **trust** on `127.0.0.1/32`, empty password in `database.ini`.
No SCRAM support in these plans. Trust line is localhost-oriented.

### Mitigation

Keep OpenVoxDB co-located with PostgreSQL as the module expects, or harden
manually knowing plan re-runs may rewrite files. See
[security-notes.md](security-notes.md).

---

## 6. Compilers disappear from OpenVoxDB allowlist

### Symptom

Compilers worked after `add_compilers`; later they cannot authenticate to
OpenVoxDB.

### Cause

`configure_openvoxdb` **overwrites**
`/etc/puppetlabs/puppetdb/certificate-allowlist` with **primary only**.
`add_compilers` appends. Re-running OpenVoxDB configure wipes compiler lines.

### Mitigation

Re-run `add_compilers` for those hosts (idempotent-ish append via `file_line`)
or restore allowlist lines carefully. Avoid casual reconfigure of OpenVoxDB.

---

## 7. Large install: compilers not on allowlist

### Symptom

Right after Large `install`, compilers are not listed in the allowlist.

### Cause

Large install path writes allowlist with primary only. Only `add_compilers`
appends compiler certnames.

### Mitigation

Add allowlist entries (via `add_compilers` for new hosts, or carefully edit /
re-add). Still sign CSRs.

---

## 8. XL / HA parameters did nothing useful

### Symptom

You passed `replica_host`, pool addresses, etc., and expected streaming
replication or LB config.

### Cause

Those params are largely **no-ops** during install. Streaming replication and
HAProxy generation are **not implemented**. `add_database` `pair` mode is a
stub message.

### Mitigation

Treat XL as WIP. Use Standard/Large + documented day-2 plans with eyes open.
See [architectures.md](architectures.md).

---

## 9. Dead parameters look configurable

### Examples

`backup_type`, `dns_alt_names` on `add_compilers`, compiler pool addresses,
`r10k_private_key_*`, `stagingdir`, `uploaddir`, `legacy_compilers`,
`final_agent_state` on install/configure.

### Cause

Accepted in signatures (sometimes logged) but unused in logic.

### Mitigation

Check [plan-reference.md](plan-reference.md) Effect column before designing
around a knob.

---

## 10. replace_failed_postgresql “succeeds” with empty data

### Symptom

Primary points at a new DB host; OpenVoxDB is empty / wrong.

### Cause

Plan rewires config only. `working_postgresql_host` and
`failed_postgresql_host` are **logged only**. No data copy or promote.

### Mitigation

Restore PostgreSQL/OpenVoxDB data yourself, then rewire — or rebuild from
[backup_restore.md](backup_restore.md) limitations with a real DB dump tool.

---

## 11. Restore cannot see a file that exists on your laptop

### Symptom

`input_file` not found during `restore`.

### Cause

Path is evaluated **on the target**. Controller paths are irrelevant unless
copied.

### Mitigation

```bash
scp recovery.tar.gz root@target:/var/backups/openvox/
# then pass that target path with confirm => true
```

---

## 12. Uninstall left packages or repos behind

### Symptom

After uninstall, release repos, PostgreSQL, openbolt, or `/etc/puppetlabs`
bits remain.

### Cause

Uninstall is intentionally partial (see [uninstall.md](uninstall.md)).

### Mitigation

Manual package/dir cleanup or rebuild the host image before a clean install
attempt.

---

## 13. EL vs Debian package surprises

### Symptom

Docs or muscle memory expect `openbolt` / `openvoxdb-termini` on RHEL.

### Cause

Yum install path installs `openvox-server`, `openvox-agent`, `openvoxdb` only.
Apt path also pins openbolt and termini.

### Mitigation

Compare against the OS path you actually used; do not fail QA on missing
apt-only packages on EL.

---

## 14. Weird hostnames in puppet.conf / JDBC URLs

### Symptom

`server` or database subname looks like a Ruby object string / unexpected
value.

### Cause

Some commands interpolate `$primary_host` / `$postgresql_host` directly.
Exotic Target shapes may stringify poorly.

### Mitigation

Pass plain hostname strings in params and inventory.

---

## 15. Status looks “red” on compilers

### Symptom

Status shows openvoxdb/postgresql stopped on compilers.

### Cause

Task **always** probes those three units. It never prints “N/A”.

### Mitigation

Interpret by role — see [status.md](status.md).

---

## 16. Destructive plan no-ops / immediate fail

### Symptom

`restore`, `restore_ca`, or `uninstall` fails immediately with a message about
`confirm`.

### Cause

Safety gate: `confirm` defaults to `false`.

### Mitigation

Pass `"confirm": true` only when you mean it.

---

## 17. Security-sensitive environments

### Symptom

Auditors reject trust auth, root SSH, or unsigned waiting compilers.

### Cause

Defaults optimize for bring-up. See [security-notes.md](security-notes.md).

### Mitigation

Segment networks, harden Postgres outside the module, enforce known_hosts,
sign promptly, restrict who can run Bolt plans.

---

## Bolt / module install problems

| Symptom | Mitigation |
|---------|------------|
| `curl …html \| sh` fails | Use [official Bolt install docs](https://help.puppet.com/bolt/current/topics/bolt_installing.htm) |
| Bolt 6+ rejected | Module assert is `>= 3.17.0 < 6.0.0` |
| Forge module missing | Use Git `cvquesty/openvox-adm` Puppetfile entry |
| Plan not found | `bolt puppetfile install`; check plan name `openvoxadm::…` |

---

## Collecting information for a bug report

Include:

1. Module commit / branch (`development` SHA)
2. Bolt version
3. Plan name + params (redact secrets)
4. Target OS family
5. Relevant task/command stderr
6. Whether PostgreSQL/r10k were preinstalled
7. Allowlist and `ca list` snippets if cert-related

Repo issues: https://github.com/cvquesty/openvox-adm/issues

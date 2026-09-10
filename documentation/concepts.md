# Concepts for openvox-adm operators

**Audience:** someone comfortable with Linux and SSH who may be new to OpenVox,
Puppet-style certificate authorities, or Bolt.

**Goal:** give you enough vocabulary and mental models to read the other guides
without getting lost. This page does **not** claim every architecture is
production-ready — see the maturity table in the [README](../README.md#current-status).

---

## 1. OpenVox vs Puppet (names you will see)

OpenVox is the community continuation of open-source Puppet. Many **commands and
paths still look like Puppet**:

| You install / start | You often still type / find |
|---------------------|-----------------------------|
| Package `openvox-agent` | CLI `puppet`, config under `/etc/puppetlabs/puppet/` |
| Package `openvox-server` | Unit `openvox-server`; CLIs `puppetserver`, `puppet` |
| Package `openvoxdb` | Config `/etc/puppetlabs/puppetdb/`; data under `/opt/puppetlabs/server/data/puppetdb` |
| Package `openbolt` (apt path) | Bolt-related tooling on Debian/Ubuntu installs |

**Rule:** talk about **OpenVox packages and systemd units** in ops docs, but do
not be surprised when paths still say `puppetlabs`.

**Do not mix** classic Puppet packages and OpenVox packages on one host.

---

## 2. What this module is (Bolt-first)

**Bolt** is an agentless tool: your **jump host** runs Bolt; Bolt SSHs to
**targets** and runs tasks/commands/plans.

- **Module directory / Forge-style name:** `openvox-adm`
- **Plan namespace in commands:** `openvoxadm::…` (no hyphen)
- **Example:** `bolt plan run openvoxadm::install --params '…'`

A **plan** is a Puppet-language orchestration script inside the module. A
**task** is usually a shell script Bolt copies and runs on a target
(`install_packages`, `status`, `uninstall`).

openvox-adm is **thin orchestration**. It is not a full role/profile catalog
that manages your whole OS. Empty placeholders exist (`plans/util/`,
`manifests/setup/`, `files/`, `templates/`).

---

## 3. Inventory and SSH assumptions

Most examples assume:

```yaml
transport: ssh
ssh:
  user: root
  run-as: root
  host-key-check: false   # lab convenience; tighten for production
```

Plans interpolate hostnames into config files and shell commands. Prefer
**hostname strings** in inventory (not exotic Target object shapes) so
`server`, JDBC URLs, and allowlists look like real DNS names.

---

## 4. Roles in an OpenVox cluster

### Primary

The main server. In Standard architecture it also runs OpenVoxDB + PostgreSQL.
It is usually the **Certificate Authority (CA)** — it issues and signs
certificates for agents and other servers.

### Compiler

An extra `openvox-server` that compiles catalogs but does **not** act as CA
(`ca=false`). Agents may talk to compilers for scale. Compilers still need
certificates signed by the primary CA.

### Dedicated PostgreSQL / OpenVoxDB host

Stores PuppetDB/OpenVoxDB data away from the primary. In this module’s Large
path, OpenVoxDB and PostgreSQL are expected **together** on that host (trust
auth is localhost-oriented — see security notes).

### Replica (HA intent)

A second server role meant for failover in Extra-Large designs. **Today:**
`add_replica` can bring up packages and basic `puppet.conf` settings; it does
**not** implement full CA sync, code sync, or database replication.

---

## 5. Certificates and the CA (plain English)

1. Each OpenVox node has an SSL identity (certname), usually matching its
   hostname.
2. Nodes request certificates with something like
   `puppet ssl bootstrap --waitforcert 60`.
3. The CA (primary) must **sign** those requests before TLS works.
4. **What install does today:** after primary bootstrap, it signs **only** the
   primary’s own certname (`puppetserver ca sign --certname <primary>`).
5. **What it does not do:** automatically sign compiler or replica CSRs during
   `install` / `add_compilers` / `add_replica`. After 60 seconds of waiting,
   the plan may continue while certificates remain unsigned — services can fail
   TLS until you sign manually.

Safer operator habit:

```bash
puppetserver ca list --all
puppetserver ca sign --certname exact.host.name
```

Avoid casually using `sign --all` on a busy CA.

### OpenVoxDB certificate-allowlist

OpenVoxDB can restrict which certificates may talk to it via:

`/etc/puppetlabs/puppetdb/certificate-allowlist`

- `configure_openvoxdb` **overwrites** this file with the **primary** certname
  only.
- `add_compilers` **appends** compiler certnames (and briefly stops/starts
  openvoxdb around that change).

**Footgun:** re-running OpenVoxDB configuration can wipe compiler allowlist
entries. Large **install** does not add compilers to the allowlist; use
`add_compilers` or edit carefully.

---

## 6. OpenVoxDB and PostgreSQL

- Database/user names used by the module: `puppetdb` / `puppetdb`.
- Auth configured today: **trust** for `127.0.0.1/32` in `pg_hba.conf`, and
  `database.ini` with an **empty password** (no SCRAM yet).
- Primary `puppetdb.conf` points at `https://<puppetdb_host>:8081`.

This is acceptable for a lab co-located or dedicated-DB-with-local-OpenVoxDB
layout. It is **not** a hardened multi-tenant database design. See
[security-notes.md](security-notes.md).

**Packaging gap:** `tasks/install_packages.sh` does **not** explicitly install
the `postgresql` package. If PostgreSQL is missing, later `systemctl enable
postgresql` fails.

---

## 7. Architectures in one page

| Name | Hosts (typical) | Maturity | Reality check |
|------|-----------------|----------|---------------|
| Standard | 1 primary | Beta | Main happy path |
| Large | primary + compilers + DB | Experimental | Works partially; CSR + allowlist gaps |
| Extra Large / HA | + replica + second DB + LB ideas | WIP | Params mostly scaffolding; no streaming replication |

Expand later with day-2 plans (`add_compilers`, `add_database`, `add_replica`) —
each has its own maturity. Details:
[architectures.md](architectures.md), [expanding.md](expanding.md).

---

## 8. Backup mental model

`openvoxadm::backup` runs **on the target** (usually primary). Default parent
directory: `/var/backups/openvox`.

It builds a working directory, component tarballs (`certs`, `config`,
`environments`, `puppetdb`), a `MANIFEST.txt`, then wraps everything into a
single outer archive:

`/var/backups/openvox/openvox-backup-<UTC-timestamp>.tar.gz`

`restore` expects that outer `*.tar.gz` **already on the restore target**.
Bolt does not magically use a path from your laptop unless you copied it.

`migrate` calls backup then restore but **does not copy** the tarball between
old and new hosts — a major footgun. See [backup_restore.md](backup_restore.md)
and [migrate.md](migrate.md).

---

## 9. Confirm gates (destructive plans)

These plans refuse to run unless you pass `confirm => true`:

- `openvoxadm::restore`
- `openvoxadm::restore_ca`
- `openvoxadm::uninstall`

Backup itself is not gated that way; be careful where you write archives.

---

## 10. Version pins

- Default OpenVox version string in plans: `8.11.0`
- Assert (on `install` / `upgrade`): version must match `8.*` unless
  `permit_unsafe_versions => true`
- Bolt must be `>= 3.17.0 < 6.0.0`

---

## Next reading

1. [runbook-install-standard.md](runbook-install-standard.md) — do a lab install
2. [plan-reference.md](plan-reference.md) — exact parameters
3. [troubleshooting.md](troubleshooting.md) — when something fails

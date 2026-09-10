<div align="center">

# OpenVox Administration Module

**Bolt plans for deploying and managing OpenVox infrastructure at scale**

[![Version](https://img.shields.io/badge/version-0.1.0-orange?style=for-the-badge)](metadata.json)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue?style=for-the-badge)](LICENSE)
[![OpenVox](https://img.shields.io/badge/OpenVox-8.x-FF7F00?style=for-the-badge)](https://voxpupuli.org/openvox/)
[![Bolt](https://img.shields.io/badge/Bolt-3.17%2B-black?style=for-the-badge)](https://help.puppet.com/bolt/current/topics/bolt_installing.htm)
[![Status](https://img.shields.io/badge/status-WIP-lightgrey?style=for-the-badge)](#current-status)

[![install standard](https://img.shields.io/badge/install%20(standard)-Beta-blue?style=flat-square)](#current-status)
[![install large](https://img.shields.io/badge/install%20(large)-Experimental-orange?style=flat-square)](#current-status)
[![install XL/HA](https://img.shields.io/badge/install%20(XL%2FHA)-WIP-lightgrey?style=flat-square)](#current-status)
[![upgrade](https://img.shields.io/badge/upgrade-Experimental-orange?style=flat-square)](#current-status)
[![status](https://img.shields.io/badge/status-Beta-blue?style=flat-square)](#current-status)
[![add_compilers](https://img.shields.io/badge/add__compilers-Beta-blue?style=flat-square)](#current-status)
[![add_database](https://img.shields.io/badge/add__database-WIP-lightgrey?style=flat-square)](#current-status)
[![add_replica](https://img.shields.io/badge/add__replica-Experimental-orange?style=flat-square)](#current-status)
[![backup/restore](https://img.shields.io/badge/backup%2Frestore-Experimental-orange?style=flat-square)](#current-status)
[![migrate](https://img.shields.io/badge/migrate-WIP-lightgrey?style=flat-square)](#current-status)
[![uninstall](https://img.shields.io/badge/uninstall-Beta-blue?style=flat-square)](#current-status)
[![tests](https://img.shields.io/badge/tests-Experimental-orange?style=flat-square)](#current-status)

[![GitHub Stars](https://img.shields.io/github/stars/cvquesty/openvox-adm?style=flat-square)](https://github.com/cvquesty/openvox-adm/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/cvquesty/openvox-adm?style=flat-square)](https://github.com/cvquesty/openvox-adm/issues)
[![Last Commit](https://img.shields.io/github/last-commit/cvquesty/openvox-adm?style=flat-square)](https://github.com/cvquesty/openvox-adm/commits/development)

[Quick Start](#quick-start) · [**Status**](#current-status) · [Architectures](#supported-architectures) · [Install runbook](documentation/runbook-install-standard.md) · [Documentation](#documentation)

</div>

---

> **Maturity:** v0.1.0 on `development`. Standard install is the most exercised path
> (**Beta**). Large is **Experimental**. Extra-Large / HA is **WIP** — replica and dual
> PostgreSQL parameters install packages but do **not** configure streaming replication
> or failover. Check [Current Status](#current-status) before relying on a plan.

This project is a **PEADM-inspired** lifecycle toolkit for **OpenVox 8.x**, adapted from
the ideas in [puppetlabs-peadm](https://github.com/puppetlabs/puppetlabs-peadm). It is
**not** a full feature-for-feature port: several PEADM capabilities (true HA Postgres,
load-balancer automation, convert) are absent or stubbed. If you have used PEADM, the
plan names will feel familiar, but always trust the maturity table below over memory.

> **Friendly tip:** OpenVox keeps Puppet-compatible commands and many `/etc/puppetlabs/`
> paths. Package and service names change (`openvox-server`, `openvoxdb`, `openvox-agent`).
> See [concepts.md](documentation/concepts.md) for a plain-English glossary.

---

## Table of Contents

- [What Is OpenVox?](#what-is-openvox)
- [What openvox-adm Is (and Is Not)](#what-openvox-adm-is-and-is-not)
- [Supported Architectures](#supported-architectures)
- [Quick Start](#quick-start)
- [Plan Reference](#plan-reference)
- [Current Status](#current-status)
- [Requirements](#requirements)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)
- [Links](#links)

---

## What Is OpenVox?

[OpenVox](https://voxpupuli.org/openvox/) is a community-maintained, drop-in replacement
for open-source Puppet. It is developed by the [Vox Pupuli](https://voxpupuli.org/)
community. OpenVox 8.x is compatible with Puppet 8-era DSL, facts, and Forge modules.

**You can think of OpenVox as "Puppet Community Edition, continued."**

| OpenVox Package | Puppet Equivalent | Purpose |
|-----------------|-------------------|---------|
| `openvox-agent` | `puppet-agent` | Agent that applies catalogs on each node |
| `openvox-server` | `puppetserver` | Server: CA, catalog compilation, related CLIs |
| `openvoxdb` | `puppetdb` | Stores facts, catalogs, reports; enables PQL |
| `openbolt` | `bolt` | Orchestration package (Debian/Ubuntu install path only) |

> **Important:** Do **not** mix classic Puppet packages and OpenVox packages on the same
> host. Back up `/etc/puppetlabs/` before any migration.

---

## What openvox-adm Is (and Is Not)

### Is

- A **Bolt module** (`metadata.json` name `openvox-adm`, plan namespace `openvoxadm::`,
  version `0.1.0`, Apache-2.0).
- Thin orchestration: `run_task` / `run_command` / small `apply()` blocks over SSH.
- Lifecycle plans for **bring-your-own Linux hosts**: install, configure, expand,
  upgrade, backup/restore, migrate (limited), replace failed Postgres (rewire only),
  status, uninstall.
- Packages come from Vox Pupuli repos (`yum.voxpupuli.org` / `apt.voxpupuli.org`).

### Is not

- Not a Forge-published “stable” product yet (v0.1.0 WIP/Beta).
- Not a VM or cloud provisioner (no Terraform / cloud APIs).
- Not a full PEADM port: **no** convert plan, **no** streaming replication, **no**
  HAProxy config generation (even though `puppetlabs/haproxy` appears in the module
  `Puppetfile`).
- Does **not** install PostgreSQL as an explicit package in `install_packages`
  (depends on OS package already present or as a dependency — fragile).
- Does **not** install the `r10k` gem/package; `configure_r10k` assumes `r10k` and
  `/etc/puppetlabs/r10k/` already exist.

---

## Supported Architectures

Pick the architecture that matches your scale — and the maturity you can accept.

### Standard (single server) — Beta

Everything on one host:

- `openvox-server` (CA + compile)
- `openvoxdb` + PostgreSQL co-located

**Best for:** labs, small teams, learning the module.

Step-by-step:
[documentation/runbook-install-standard.md](documentation/runbook-install-standard.md).

### Large (compilers + dedicated DB) — Experimental

- Primary: `openvox-server`
- One or more compilers (`ca=false`)
- Dedicated PostgreSQL + OpenVoxDB host

**Honest gaps today:** compiler CSRs are **not** auto-signed during install; Large
install writes the OpenVoxDB certificate-allowlist with the **primary only** (compilers
are appended later by `add_compilers`); pool / load-balancer addresses are **not**
applied by the install plan.

### Extra Large / HA — WIP

Parameters exist for `replica_host`, `replica_postgresql_host`, and compiler pool
addresses. **What the code actually does:** packages may install on those hosts;
replica and replica-PG are **not** configured during install; pool address params are
**dead** (accepted, unused); **streaming replication is not implemented**.

Treat XL install examples as scaffolding only. Prefer Standard (or carefully validated
Large) until HA work lands.

Details: [documentation/architectures.md](documentation/architectures.md).

---

## Quick Start

This Quick Start covers **Standard install only** (Beta). For Large/XL, read the
architecture and install guides first and expect manual certificate and allowlist work.

### Step 1: Install Bolt on a jump host

You need [Bolt](https://help.puppet.com/bolt/current/topics/bolt_installing.htm)
**>= 3.17.0 and < 6.0.0** on a machine that can SSH to every target as root.

Follow the official install page for your OS. **Do not** pipe an HTML documentation
URL into `sh` (older broken examples did `curl …bolt_installing.html | sh`).

```bash
# After install:
bolt --version
# Must report a version in the supported range (>= 3.17.0 < 6.0.0)
```

> Recent Bolt packages may require Puppet Core / PE credentials for the vendor repos.
> Use the official docs for the current method on your platform.

### Step 2: Get the openvox-adm module (Git / Puppetfile)

While the module is pre-Forge, install from GitHub `cvquesty/openvox-adm`.

```bash
mkdir openvox-deploy && cd openvox-deploy
bolt project init openvox-deploy
```

Add to the project `Puppetfile`:

```ruby
mod 'openvox-adm',
  :git => 'https://github.com/cvquesty/openvox-adm.git',
  :branch => 'development'
```

Then:

```bash
bolt puppetfile install
```

**Forge option** (only when published):

```bash
bolt project init openvox-deploy --modules openvox-adm
```

### Step 3: Inventory (SSH as root)

```yaml
---
groups:
  - name: openvox
    config:
      transport: ssh
      ssh:
        host-key-check: false
        user: root
        run-as: root
    targets:
      - primary.example.com
```

Confirm connectivity:

```bash
bolt command run 'hostname' -t primary.example.com
```

### Step 4: Prerequisites on the primary (Standard)

1. Clean Linux host (supported EL/Ubuntu family) with outbound access to
   `yum.voxpupuli.org` or `apt.voxpupuli.org`.
2. **PostgreSQL** available so `systemctl enable --now postgresql` can succeed
   (the package task does **not** install `postgresql` explicitly).
3. Optional: install `r10k` yourself **before** passing `r10k_remote` (the module
   does not install the gem/package).

### Step 5: Run Standard install

```bash
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

### Step 6: What success looks like

1. Plan completes without failing tasks.
2. On the primary:
   ```bash
   systemctl is-active openvox-server openvoxdb postgresql
   openvox --version || puppet --version
   ```
3. Cluster status from Bolt:
   ```bash
   bolt plan run openvoxadm::status --targets primary.example.com
   ```
4. Sign **agent** CSRs as needed (install signs the **primary certname only**):
   ```bash
   puppetserver ca list --all
   puppetserver ca sign --certname agent.example.com
   ```
   Prefer targeted `--certname` over `--all`.

---

## Plan Reference

| Plan | Maturity | One-line purpose |
|------|----------|------------------|
| `openvoxadm::install` | Beta / Exp / WIP by arch | Install + configure cluster roles |
| `openvoxadm::upgrade` | Experimental | Parallel package pin + service bounce |
| `openvoxadm::status` | Beta | Per-host service/version text |
| `openvoxadm::add_compilers` | Beta | Add compilers + allowlist append |
| `openvoxadm::add_compiler` | **Deprecated** | Wrapper → `add_compilers` |
| `openvoxadm::add_database` | WIP | Dedicated DB (`init`); `pair` stubbed |
| `openvoxadm::add_replica` | Experimental | Basic replica bring-up (no HA sync) |
| `openvoxadm::backup` / `restore` | Experimental | Single `recovery.tar.gz` contract |
| `openvoxadm::backup_ca` / `restore_ca` | Experimental | CA/SSL tree only |
| `openvoxadm::migrate` | WIP | Backup then restore; **no** cross-host copy |
| `openvoxadm::replace_failed_postgresql` | WIP | Rewire only; no data copy |
| `openvoxadm::uninstall` | Beta | Partial package/data removal (`confirm`) |

Full parameters and examples:
[documentation/plan-reference.md](documentation/plan-reference.md).

---

## Current Status

Maturity language used everywhere in this repo:

- **Beta** — usable for common paths; expect rough edges
- **Experimental** — works in limited scenarios; contracts may change
- **WIP** — scaffolding present; not production-ready
- **Deprecated** — still callable; prefer the replacement
- **Skipped** — intentionally not ported

| Feature | Maturity | Notes |
|---------|----------|-------|
| `install` (standard) | Beta | Best-tested; needs PostgreSQL present; r10k optional/manual |
| `install` (large) | Experimental | Compilers + dedicated DB; CSR + allowlist gaps |
| `install` (XL/HA) | WIP | Replica/dual-PG params mostly no-ops; no streaming replication |
| `upgrade` | Experimental | Package pin + restart; no schema migrate / reconfigure |
| `status` | Beta | Always probes openvox-server, openvoxdb, postgresql |
| `add_compilers` | Beta | Allowlist append; CSR signing still manual |
| `add_compiler` | Deprecated | Use `add_compilers` |
| `add_database` | WIP | `init` wires OpenVoxDB; `pair` prints stub message |
| `add_replica` | Experimental | Server role + group B; no CA/code/DB sync |
| `backup` / `restore` | Experimental | Outer `openvox-backup-<ts>.tar.gz`; no `pg_dump` |
| `backup_ca` / `restore_ca` | Experimental | Defaults under `/var/backups/openvox`; restore_ca no service restart |
| `replace_failed_postgresql` | WIP | Rewires config; working/failed hosts logged only |
| `migrate` | WIP | Broken for typical two-host unless shared path |
| `uninstall` | Beta | Requires `confirm => true`; incomplete cleanup |
| `convert` | Skipped | Absent |
| Tests | Experimental | Thin specs only |

**Project shape (approx.):** public plans ≈ 14 (+ deprecated wrapper), 7 subplans,
3 tasks, several functions/types. `plans/util/`, `manifests/setup/`, `files/`, and
`templates/` are empty placeholders.

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **Bolt** | `>= 3.17.0 < 6.0.0` on the jump host |
| **OpenVox** | 8.x (module installs packages; default pin `8.11.0`) |
| **Clean nodes** | No prior Puppet/OpenVox install on targets |
| **SSH** | Root (or equivalent) from jump host to every target |
| **Hostnames** | Prefer resolvable names; inventory strings stringify into configs |
| **Internet** | Targets need Vox Pupuli apt/yum repos |
| **PostgreSQL** | Must exist for service enable; not explicitly packaged by the task |
| **r10k** | Optional; install yourself before `r10k_remote` |

---

## Documentation

| Document | Description |
|----------|-------------|
| [concepts.md](documentation/concepts.md) | Glossary: OpenVox vs Puppet, Bolt, certs, OpenVoxDB, architectures |
| [plan-reference.md](documentation/plan-reference.md) | Every public plan: params, maturity, examples |
| [runbook-install-standard.md](documentation/runbook-install-standard.md) | Painfully detailed Standard install |
| [install.md](documentation/install.md) | Install guide (all architectures + honest gaps) |
| [architectures.md](documentation/architectures.md) | Standard / Large / XL with maturity labels |
| [expanding.md](documentation/expanding.md) | Compilers, database, replica (WIP called out) |
| [upgrade.md](documentation/upgrade.md) | Upgrade plan behavior and limits |
| [backup_restore.md](documentation/backup_restore.md) | recovery.tar.gz contract, CA, DR footguns |
| [migrate.md](documentation/migrate.md) | Migrate plan + cross-host copy gap |
| [uninstall.md](documentation/uninstall.md) | Uninstall + what remains on disk |
| [status.md](documentation/status.md) | Status task output reality |
| [troubleshooting.md](documentation/troubleshooting.md) | Footguns from the code model |
| [security-notes.md](documentation/security-notes.md) | Confirm gates, trust auth, no SCRAM yet |

---

## Contributing

We welcome bug reports, docs fixes, plans/tasks, and tests. Keep documentation honest
about maturity. Prefer small PRs against `development`.

Repo: [https://github.com/cvquesty/openvox-adm](https://github.com/cvquesty/openvox-adm)

---

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

## Links

- [OpenVox Project](https://voxpupuli.org/openvox/)
- [openvox-server](https://github.com/OpenVoxProject/openvox-server)
- [openvox-agent](https://github.com/OpenVoxProject/openvox-agent)
- [openvox-gui](https://github.com/cvquesty/openvox-gui)
- [voxdocs](https://github.com/cvquesty/voxdocs)
- [Vox Pupuli](https://voxpupuli.org/)
- [Bolt install docs](https://help.puppet.com/bolt/current/topics/bolt_installing.htm)

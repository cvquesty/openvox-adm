# OpenVox Administration Module (openvox-adm)

> **Maturity: v0.1.0 — Work in Progress (WIP)**  
> This module is under active development. Plans work for many workflows, but
> several components remain Experimental or WIP. Read the [Current Status](#current-status)
> table before relying on a plan in production.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0-orange.svg)](metadata.json)
[![Maturity](https://img.shields.io/badge/Maturity-WIP-critical.svg)](#current-status)
[![OpenVox](https://img.shields.io/badge/OpenVox-8.x-FF7F00.svg)](https://voxpupuli.org/openvox/)
[![Repo](https://img.shields.io/badge/GitHub-cvquesty%2Fopenvox--adm-informational.svg)](https://github.com/cvquesty/openvox-adm)

### Component maturity

| Component | Badge |
|-----------|-------|
| install (standard) | ![Beta](https://img.shields.io/badge/install%20standard-Beta-blue.svg) |
| install (large) | ![Experimental](https://img.shields.io/badge/install%20large-Experimental-yellow.svg) |
| install (XL/HA) | ![WIP](https://img.shields.io/badge/install%20XL%2FHA-WIP-orange.svg) |
| upgrade | ![Experimental](https://img.shields.io/badge/upgrade-Experimental-yellow.svg) |
| status | ![Beta](https://img.shields.io/badge/status-Beta-blue.svg) |
| add_compilers | ![Beta](https://img.shields.io/badge/add__compilers-Beta-blue.svg) |
| add_database | ![WIP](https://img.shields.io/badge/add__database-WIP-orange.svg) |
| add_replica | ![Experimental](https://img.shields.io/badge/add__replica-Experimental-yellow.svg) |
| backup / restore | ![Experimental](https://img.shields.io/badge/backup%2Frestore-Experimental-yellow.svg) |
| migrate | ![WIP](https://img.shields.io/badge/migrate-WIP-orange.svg) |
| uninstall | ![Beta](https://img.shields.io/badge/uninstall-Beta-blue.svg) |
| tests | ![Experimental](https://img.shields.io/badge/tests-Experimental-yellow.svg) |

Bolt plans for deploying and managing OpenVox infrastructure at scale.

This project is a **feature-for-feature port** of
[puppetlabs-peadm](https://github.com/puppetlabs/puppetlabs-peadm) adapted
for **OpenVox** — the community-maintained, open-source fork of Puppet.
If you have used PEADM to manage Puppet Enterprise clusters, you will feel
right at home with openvox-adm.

> **Friendly tip:** OpenVox uses the same commands, config paths, and Forge
> modules as Puppet. The only difference you will notice is the package names
> (`openvox-server` instead of `puppetserver`, `openvoxdb` instead of
> `puppetdb`, and so on). Everything else works the way you expect.

---

## Table of Contents

- [What Is OpenVox?](#what-is-openvox)
- [What Does openvox-adm Do?](#what-does-openvox-adm-do)
- [Supported Architectures](#supported-architectures)
- [Quick Start](#quick-start)
- [Current Status](#current-status)
- [Requirements](#requirements)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## What Is OpenVox?

[OpenVox](https://voxpupuli.org/openvox/) is a community-maintained,
drop-in replacement for open-source Puppet. It was created by the
[Vox Pupuli](https://voxpupuli.org/) community after Puppet (now owned by
Perforce) scaled back open-source development. OpenVox is fully compatible
with Puppet 8.x — same DSL, same facts, same modules from the Forge.

**You can think of OpenVox as "Puppet Community Edition, continued."**

| OpenVox Package | Puppet Equivalent | Purpose |
|-----------------|-------------------|---------|
| `openvox-agent` | `puppet-agent` | The agent that runs on every node |
| `openvox-server` | `puppetserver` | The server (CA, catalog compilation, r10k) |
| `openvoxdb` | `puppetdb` | Stores facts, catalogs, reports, and enables PQL queries |
| `openbolt` | `bolt` | Orchestration tool (included for convenience) |

> **Note:** You **cannot** install OpenVox and legacy Puppet on the same
> system. Pick one or the other. If you are migrating from Puppet, back up
> `/etc/puppetlabs/` first, then replace the packages.

---

## What Does openvox-adm Do?

openvox-adm automates the **lifecycle of your OpenVox infrastructure**.
It does *not* create virtual machines or cloud instances for you — you bring
your own servers (or VMs). Once you have clean Linux nodes available,
openvox-adm will:

1. **Install** OpenVox components on all nodes (primary, compilers, database,
   replicas)
2. **Configure** everything so it "just works": certificates, OpenVoxDB,
   r10k, services
3. **Scale out** by adding more compilers, a dedicated database host, or a
   replica server for high availability
4. **Upgrade** your entire cluster to a new OpenVox version
5. **Backup and restore** your configuration and CA certificates
6. **Recover** from a failed PostgreSQL host
7. **Migrate** from one set of hosts to another
8. **Check status** of your entire cluster at a glance
9. **Uninstall** cleanly when you want to start over

**In short:** You describe *what* you want (a standard cluster, a large
cluster with dedicated database, an extra-large HA cluster), and openvox-adm
does the heavy lifting.

---

## Supported Architectures

openvox-adm supports three deployment architectures. Pick the one that fits
your scale and availability needs.

### Standard (Single Server) — Beta

The simplest setup. Everything runs on one node:

- **openvox-server** — handles CA duties, catalog compilation, and r10k
- **openvoxdb + PostgreSQL** — co-located on the same server

**Best for:** Labs, small teams, or environments with fewer than 500 nodes.

See the step-by-step guide:
[documentation/runbook-install-standard.md](documentation/runbook-install-standard.md).

### Large (Dedicated Database) — Experimental

Split the database onto its own host for better performance:

- **Primary server** — openvox-server + r10k
- **Compilers** — two or more openvox-server instances with `ca=false`
- **Dedicated PostgreSQL + OpenVoxDB** — offloads storage and queries

**Best for:** 500 to 5,000 nodes, or when you want to tune the database
independently.

### Extra Large (High Availability) — WIP

Full redundancy with availability groups:

- **Primary + Replica** servers (assigned to "A" and "B" groups)
- **Compilers in A/B pools** behind a load balancer (HAProxy recommended)
- **PostgreSQL A + PostgreSQL B** (streaming replication for DR)
- **OpenVoxDB on each PostgreSQL host**
- **Load balancer** in front of the compiler pools

**Best for:** More than 5,000 nodes, or when you need zero-downtime
failover.

> **Availability Groups:** In HA setups, components are tagged with group A
> or B. If group A fails, group B can take over. You assign compilers to
> groups when you add them.

For more details, see [documentation/architectures.md](documentation/architectures.md).

---

## Quick Start

### Step 1: Install Bolt

You need [Bolt](https://www.puppet.com/docs/bolt/latest/bolt_installing) on a
"jump host" — a machine that can SSH to all your OpenVox nodes. Bolt 3.17.0
or later is required.

```bash
# Example: macOS via Homebrew
brew install --cask puppet-bolt

# Example: Linux (follow the official docs — do NOT pipe an HTML page into sh)
# https://www.puppet.com/docs/bolt/latest/bolt_installing.html
```

> **Note:** Older examples that did `curl …bolt_installing.html | sh` were wrong —
> that URL returns HTML documentation, not an installer script.

### Step 2: Install openvox-adm

**Option A — Git (recommended while the module is pre-Forge):**

```bash
mkdir openvox-deploy && cd openvox-deploy
bolt project init openvox-deploy
```

Add to your project's `Puppetfile`:

```ruby
mod 'openvox-adm',
  :git => 'https://github.com/cvquesty/openvox-adm.git',
  :branch => 'development'
```

Then:

```bash
bolt puppetfile install
```

**Option B — Forge** (when published):

```bash
bolt project init openvox-deploy --modules openvox-adm
```

### Step 3: Create an Inventory File

Create an `inventory.yaml` that lists all your target nodes. Here is an
example for a large architecture with a primary, two compilers, and a
dedicated database host:

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
      - compiler1.example.com
      - compiler2.example.com
      - db.example.com
```

> **Tip:** You can use IP addresses instead of hostnames if DNS is not yet
> set up. Just make sure SSH works from your jump host to every target.

### Step 4: Run the Install Plan

For a standard single-server install:

```bash
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

For a large install with dedicated database:

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host":"primary.example.com",
    "compiler_hosts":["compiler1.example.com","compiler2.example.com"],
    "primary_postgresql_host":"db.example.com",
    "version":"8.11.0",
    "r10k_remote":"git@github.com:yourorg/control-repo.git"
  }'
```

### Step 5: Post-Install Checks

1. **Check status:**
   ```bash
   bolt plan run openvoxadm::status --targets all
   ```

2. **Deploy your code:**
   ```bash
   r10k deploy environment --puppetfile
   ```

3. **Sign any pending agent certificates** on the primary (agents only — the
   install plan signs the primary certname itself):
   ```bash
   puppetserver ca list --all
   puppetserver ca sign --certname agent.example.com
   ```

You are now ready to enroll agents!

---

## Current Status

Honest maturity — **no false "Complete"** claims. Maturity levels:

- **Beta** — usable for common paths; expect rough edges
- **Experimental** — works in limited scenarios; contracts may change
- **WIP** — scaffolding present; not production-ready
- **Skipped** — intentionally not ported

| Feature | Maturity | Notes |
|---------|----------|-------|
| `install` (standard) | Beta | Best-tested path; see [runbook](documentation/runbook-install-standard.md) |
| `install` (large) | Experimental | Dedicated DB path needs more validation |
| `install` (XL/HA) | WIP | Replica + dual DB not fully wired |
| `upgrade` | Experimental | Package pin + parallel install improved |
| `status` | Beta | Basic cluster health check |
| `add_compilers` | Beta | Preferred API for scaling compilers |
| `add_compiler` | Deprecated | Thin wrapper — use `add_compilers` |
| `add_database` | WIP | Now uses OpenVoxDB config patterns; HA pair mode stubbed |
| `add_replica` | Experimental | Basic replica bring-up |
| `backup` / `restore` | Experimental | Single `recovery.tar.gz` contract |
| `backup_ca` / `restore_ca` | Experimental | Defaults under `/var/backups/openvox` |
| `replace_failed_postgresql` | WIP | Rewires config; does not copy DB data |
| `migrate` | WIP | Uses backup→restore recovery tarball |
| `uninstall` | Beta | Requires `confirm => true` |
| `convert` | Skipped | Not applicable to OpenVox |
| Documentation | Beta | Runbooks present; keep validating against code |
| Tests | Experimental | status, upgrade, install_packages coverage |

**Project stats:** ~45 files, 21 plans, 3 tasks, 7 functions, growing specs.

---

## Requirements

Before you run any openvox-adm plan, make sure you have:

| Requirement | Details |
|-------------|---------|
| **Bolt** | Version 3.17.0 or later, installed on your jump host |
| **OpenVox** | Version 8.x (the module will install it for you) |
| **Clean nodes** | Target servers must have no prior Puppet or OpenVox install |
| **SSH access** | Your jump host must reach every target via SSH as root |
| **Hostnames** | All nodes need resolvable hostnames (or use IPs in inventory) |
| **Internet access** | Targets need outbound access to apt.voxpupuli.org or yum.voxpupuli.org |

---

## Documentation

The `documentation/` directory contains detailed guides for each major
workflow:

| Document | Description |
|----------|-------------|
| [runbook-install-standard.md](documentation/runbook-install-standard.md) | Painfully step-wise standard install runbook |
| [install.md](documentation/install.md) | Install walkthrough with parameters explained |
| [architectures.md](documentation/architectures.md) | Standard, Large, and Extra Large guidance |
| [expanding.md](documentation/expanding.md) | Adding compilers, database, or replica |
| [backup_restore.md](documentation/backup_restore.md) | Backup, restore, and DR procedures |
| [status.md](documentation/status.md) | Checking cluster health |

If you find anything unclear, please open an issue or submit a pull request.

---

## Contributing

We welcome contributions of all kinds:

- Bug reports and feature requests
- Documentation improvements
- New Bolt plans or tasks
- Tests

Please follow the style of existing code and documentation. When in doubt,
ask a question in an issue before writing a large patch.

Repo: [https://github.com/cvquesty/openvox-adm](https://github.com/cvquesty/openvox-adm)

---

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

---

## Links

- [OpenVox Project](https://voxpupuli.org/openvox/)
- [openvox-server](https://github.com/OpenVoxProject/openvox-server)
- [openvox-agent](https://github.com/OpenVoxProject/openvox-agent)
- [openvox-gui](https://github.com/cvquesty/openvox-gui)
- [voxdocs](https://github.com/cvquesty/voxdocs)
- [Vox Pupuli](https://voxpupuli.org/)

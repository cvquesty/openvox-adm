# OpenVox Administration Module (openvox-adm)

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

### Standard (Single Server)

The simplest setup. Everything runs on one node:

- **openvox-server** — handles CA duties, catalog compilation, and r10k
- **openvoxdb + PostgreSQL** — co-located on the same server

**Best for:** Labs, small teams, or environments with fewer than 500 nodes.

### Large (Dedicated Database)

Split the database onto its own host for better performance:

- **Primary server** — openvox-server + r10k
- **Compilers** — two or more openvox-server instances with `ca=false`
- **Dedicated PostgreSQL + OpenVoxDB** — offloads storage and queries

**Best for:** 500 to 5,000 nodes, or when you want to tune the database
independently.

### Extra Large (High Availability)

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
brew install bolt

# Example: Linux
curl -sSL https://puppet.com/docs/bolt/latest/bolt_installing.html | sh
```

### Step 2: Create a Bolt Project

```bash
mkdir openvox-deploy && cd openvox-deploy
bolt project init openvox-deploy --modules openvox-adm
```

This creates a Bolt project and pulls in openvox-adm and its dependencies.

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

3. **Sign any pending agent certificates** on the primary:
   ```bash
   puppetserver ca sign --all
   ```

You are now ready to enroll agents!

---

## Current Status

| Feature | Status |
|---------|--------|
| `install` plan (standard, large, XL) | ✅ Complete |
| `upgrade` plan | ✅ Complete |
| `status` plan | ✅ Complete |
| `add_compiler` / `add_compilers` | ✅ Complete |
| `add_database` | ✅ Complete |
| `add_replica` | ✅ Complete |
| `backup` / `restore` | ✅ Complete |
| `backup_ca` / `restore_ca` | ✅ Complete |
| `replace_failed_postgresql` | ✅ Complete |
| `migrate` | ✅ Complete |
| `uninstall` | ✅ Complete |
| `convert` | ⏭️ Skipped (not applicable to OpenVox) |
| Documentation | ✅ Complete (you are reading it!) |
| Tests | ✅ Basic (status, upgrade, install_packages) |

**Project stats:** 45 files, 21 plans, 3 tasks, 7 functions, 3 spec tests.

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
| [install.md](documentation/install.md) | Step-by-step install walkthrough with all parameters explained |
| [architectures.md](documentation/architectures.md) | Diagrams and guidance for Standard, Large, and Extra Large setups |
| [expanding.md](documentation/expanding.md) | How to add compilers, a database host, or a replica |
| [backup_restore.md](documentation/backup_restore.md) | Backup, restore, and disaster recovery procedures |
| [status.md](documentation/status.md) | Checking the health of your cluster |

If you find anything unclear, please open an issue or submit a pull request
— we want the docs to be the friendliest in the ecosystem!

---

## Contributing

We welcome contributions of all kinds:

- Bug reports and feature requests
- Documentation improvements
- New Bolt plans or tasks
- Tests

Please follow the style of existing code and documentation. When in doubt,
ask a question in an issue before writing a large patch.

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

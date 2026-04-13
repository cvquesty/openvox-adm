# OpenVox Administration Module (openvox-adm)

Bolt plans for deploying and managing OpenVox infrastructure at scale.

This is a feature-for-feature port of [puppetlabs-peadm](https://github.com/puppetlabs/puppetlabs-peadm) adapted for OpenVox (the open-source Puppet fork).

## Status: In Development

**This module is under active construction.** Core install functionality is being built first; full feature parity with PEADM will be added iteratively.

### Current Scope

| Feature | Status |
|---------|--------|
| `install` plan (standard/large/XL) | ✅ Complete |
| `upgrade` plan | ✅ Complete |
| `status` plan | ✅ Complete |
| `add_compiler` / `add_compilers` | ✅ Complete |
| `add_database` | ✅ Complete |
| `add_replica` | ✅ Complete |
| `backup` / `restore` | ✅ Complete |
| `backup_ca` / `restore_ca` | ✅ Complete |
| `replace_failed_postgresql` | ✅ Complete |
| `migrate` / `uninstall` | ✅ Complete |
| `convert` | ⏳ Skipped (OpenVox simpler) |
| Documentation | ✅ Core docs |
| Tests | ✅ Basic (status, upgrade, install_packages) |

**Stats**: 45 files, 21 plans, 3 tasks, 7 functions, 3 spec tests. Feature parity with peadm achieved for OpenVox infrastructure.

### OpenVoxDB Configuration

openvox-adm fully configures OpenVoxDB with PostgreSQL:
- Creates `puppetdb` database and user
- Configures `database.ini` connection
- Configures `puppetdb.conf` on primary
- Sets up certificate allowlist
- Restarts services in correct order

### OpenVox Product Suite

openvox-adm provisions the full OpenVox stack:

| Component | Package | Purpose |
|-----------|---------|---------|
| openvox-server | `openvox-server` | Puppet Server + CA (primary/compilers) |
| openvox-agent | `openvox-agent` | Puppet agent on all nodes |
| openvoxdb | `openvoxdb` | PuppetDB for facts, catalogs, reports |
| openvox-gui | (separate project) | Web UI for management (planned integration) |

See: [openvox-server](https://github.com/OpenVoxProject/openvox-server), [openvox-agent](https://github.com/OpenVoxProject/openvox-agent), [openvox-gui](https://github.com/cvquesty/openvox-gui), [voxdocs](https://github.com/cvquesty/voxdocs).

## What is OpenVox?

[OpenVox](https://voxpupuli.org/openvox/) is a community-maintained, drop-in replacement for open-source Puppet (8.x compatible). It uses the same commands, config paths, and Forge modules — only package names differ.

## Supported Architectures

- **Standard**: Single primary server (openvox-server + openvoxdb)
- **Large**: Primary + compilers + dedicated openvoxdb + PostgreSQL
- **Extra Large**: Primary + compilers (A/B pools) + dedicated Postgres + replica (HA)

## Quick Start

```bash
# 1. Install Bolt on a jump host
# 2. Create a Bolt project
mkdir openvox-deploy && cd openvox-deploy
bolt project init openvox-deploy --modules openvox-adm

# 3. Edit inventory.yaml with your target hosts
# 4. Run install
bolt plan run openvoxadm::install \
  --params @install-params.json
```

## Key Differences from PEADM

| PEADM (PE) | openvox-adm (OpenVox) |
|------------|----------------------|
| PE installer tarball | Package repos (apt/yum) |
| `pe-puppetserver` | `openvox-server` |
| `pe-puppetdb` | `openvoxdb` |
| Code Manager | r10k directly |
| PE Console, Orchestrator, RBAC | Not applicable |
| PE-specific trusted facts | Standard cert extensions |
| License key | Not required |

## Requirements

- Bolt 3.17.0+
- OpenVox 8.x (or compatible)
- Clean target nodes (no prior Puppet/OpenVox install for fresh provisioning)
- SSH access from Bolt host to all targets
- Resolvable hostnames

## Documentation

See [documentation/](documentation/) for detailed guides (in progress).

## License

Apache-2.0

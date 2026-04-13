# OpenVox Administration Module (openvox-adm)

Bolt plans for deploying and managing OpenVox infrastructure at scale.

This is a feature-for-feature port of [puppetlabs-peadm](https://github.com/puppetlabs/puppetlabs-peadm) adapted for OpenVox (the open-source Puppet fork).

## Status: In Development

**This module is under active construction.** Core install functionality is being built first; full feature parity with PEADM will be added iteratively.

### Current Scope

| Feature | Status |
|---------|--------|
| `install` plan (standard architecture) | 🚧 In progress |
| `install` plan (large/extra-large) | ⏳ Planned |
| `upgrade` plan | ⏳ Planned |
| `status` plan | ⏳ Planned |
| `add_compiler` / `add_compilers` | ⏳ Planned |
| `add_database` | ⏳ Planned |
| `add_replica` | ⏳ Planned |
| `backup` / `restore` | ⏳ Planned |
| `backup_ca` / `restore_ca` | ⏳ Planned |
| `replace_failed_postgresql` | ⏳ Planned |
| `migrate` / `convert` / `uninstall` | ⏳ Planned |
| Documentation | 🚧 In progress |
| Tests | ⏳ Planned |

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

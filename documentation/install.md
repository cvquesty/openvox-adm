# Installing OpenVox with openvox-adm

This guide covers installing a new OpenVox cluster using the `openvoxadm::install` plan.

## Prerequisites

- Bolt 3.17.0+ installed on a jump host
- SSH access to all target nodes as root
- Resolvable hostnames (or use IPs)
- Clean nodes (no prior Puppet/OpenVox install)

## Supported Architectures

- **Standard**: Single primary server
- **Large**: Primary + compilers + dedicated OpenVoxDB/PostgreSQL
- **Extra Large**: Primary + compilers (A/B) + dedicated PG + replica

## Quick Start

```bash
# 1. Create Bolt project
mkdir openvox-deploy && cd openvox-deploy
bolt project init openvox-deploy --modules openvox-adm

# 2. Create inventory.yaml
cat > inventory.yaml << 'EOF'
---
groups:
  - name: openvox
    config:
      transport: ssh
      ssh:
        host-key-check: false
        user: root
    targets:
      - primary.example.com
      - compiler1.example.com
      - compiler2.example.com
EOF

# 3. Run install
bolt plan run openvoxadm::install \
  --targets primary.example.com \
  --params '{"version":"8.11.0","r10k_remote":"git@github.com:org/control-repo.git"}'
```

## Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `primary_host` | Primary server hostname | Yes |
| `version` | OpenVox version (default: 8.11.0) | No |
| `compiler_hosts` | List of compiler hosts | No |
| `primary_postgresql_host` | Dedicated DB host | No |
| `r10k_remote` | Git URL for control repo | No |
| `dns_alt_names` | Additional cert SANs | No |

## Post-Install

1. Verify services running: `bolt plan run openvoxadm::status --targets all`
2. Run r10k: `r10k deploy environment --puppetfile`
3. Sign any pending agent certs on primary

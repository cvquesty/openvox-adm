# Installing OpenVox with openvox-adm

This guide walks you through installing a brand-new OpenVox cluster using the
`openvoxadm::install` Bolt plan. Whether you are setting up a single server
for development or a multi-node production cluster, the steps are the same —
you just pass different parameters.

> **Before you begin:** Make sure you have read the main
> [README](../README.md) and understand the supported architectures. You
> should also have Bolt installed on your "jump host" (the machine you will
> run commands from).

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Supported Architectures](#supported-architectures)
- [Quick Start](#quick-start)
- [Detailed Parameters](#detailed-parameters)
- [Example: Standard Install](#example-standard-install)
- [Example: Large Install](#example-large-install)
- [Example: Extra Large Install](#example-extra-large-install)
- [Post-Install Steps](#post-install-steps)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before running the install plan, make sure the following are true:

| Prerequisite | Why It Matters |
|--------------|----------------|
| **Bolt 3.17.0+** | Installed on your jump host; runs all the plans |
| **SSH access** | You can SSH as `root` to every target node |
| **Clean targets** | No Puppet or OpenVox is already installed on the targets |
| **Hostnames** | All nodes have resolvable hostnames (or you use IPs) |
| **Internet** | Targets can reach apt.voxpupuli.org or yum.voxpupuli.org |

> **Tip:** If you are using a firewall, make sure the following ports are
> open between nodes:
> - **8140** — Puppet Server (agents → compilers/primary)
> - **8081** — OpenVoxDB (compilers/primary → database)
> - **5432** — PostgreSQL (if using a dedicated database host)
> - **22** — SSH (from your jump host to all targets)

---

## Supported Architectures

openvox-adm supports three architectures out of the box. The install plan
automatically figures out what to do based on the parameters you pass.

### Standard

Everything on one node:

- **openvox-server** — CA, catalog compilation, r10k
- **openvoxdb + PostgreSQL** — co-located on the same host

**When to use:** Labs, small teams, or fewer than 500 nodes.

### Large

Database on its own host:

- **Primary server** — openvox-server + r10k
- **Compilers** — two or more (optional)
- **Dedicated PostgreSQL + OpenVoxDB** — separate host

**When to use:** 500–5,000 nodes or when you want to tune the database
independently.

### Extra Large

Full high availability:

- **Primary + Replica** servers (A/B groups)
- **Compilers in A/B pools**
- **PostgreSQL A + PostgreSQL B** (streaming replication)
- **OpenVoxDB on each PostgreSQL host**
- **Load balancer** in front of compilers

**When to use:** More than 5,000 nodes or when you need zero-downtime
failover.

For diagrams and more details, see
[documentation/architectures.md](architectures.md).

---

## Quick Start

If you are in a hurry, here is the shortest path to a working cluster:

```bash
# 1. Create a Bolt project
mkdir openvox-deploy && cd openvox-deploy
bolt project init openvox-deploy --modules openvox-adm

# 2. Create inventory.yaml (adjust hosts for your environment)
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
EOF

# 3. Run the install plan
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

That is it! After the plan finishes, your primary server will have OpenVox
running. Continue with the [Post-Install Steps](#post-install-steps) below.

---

## Detailed Parameters

The `openvoxadm::install` plan accepts the following parameters. You do not
need to specify all of them — only the ones relevant to your architecture.

| Parameter | Type | Required? | Description |
|-----------|------|-----------|-------------|
| `primary_host` | String | **Yes** | Hostname (or IP) of the primary OpenVox server. This node runs the CA and signs certificates. |
| `version` | String | No | OpenVox version to install. Default: `8.11.0`. Examples: `8.11.0`, `8.12.1`. |
| `replica_host` | String | No | Hostname of the replica server (for HA). Omit for Standard/Large. |
| `compiler_hosts` | Array[String] | No | List of compiler hostnames. Omit for Standard. |
| `primary_postgresql_host` | String | No | Hostname of a dedicated PostgreSQL + OpenVoxDB host. Omit for Standard. |
| `replica_postgresql_host` | String | No | Hostname of the replica PostgreSQL host (XL only). |
| `dns_alt_names` | Array[String] | No | Additional Subject Alternative Names (SANs) for the primary's certificate. Useful if agents connect via a load balancer or alternate hostname. |
| `r10k_remote` | String | No | Git URL of your r10k control repository. If omitted, r10k will not be configured automatically. |
| `compiler_pool_address` | String | No | The address agents use to reach compilers (often a load balancer VIP). |
| `internal_compiler_a_pool_address` | String | No | Load balancer VIP for "A" group compilers (XL only). |
| `internal_compiler_b_pool_address` | String | No | Load balancer VIP for "B" group compilers (XL only). |

> **Note:** All hostnames should be fully qualified (FQDNs) whenever
> possible. This avoids certificate hostname mismatches.

---

## Example: Standard Install

A minimal single-node cluster is the easiest way to get started.

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host": "primary.example.com",
    "version": "8.11.0"
  }'
```

**What happens:**

1. openvox-adm installs `openvox-server`, `openvox-agent`, and `openvoxdb` on
   `primary.example.com`.
2. It bootstraps the CA certificate and signs it.
3. It configures OpenVoxDB to use the local PostgreSQL.
4. It starts all services.

You now have a working OpenVox server. Add agents by pointing them at
`primary.example.com`.

---

## Example: Large Install

For better performance at scale, move the database to its own host.

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host": "primary.example.com",
    "compiler_hosts": ["compiler1.example.com", "compiler2.example.com"],
    "primary_postgresql_host": "db.example.com",
    "version": "8.11.0",
    "r10k_remote": "git@github.com:yourorg/control-repo.git",
    "dns_alt_names": ["puppet.example.com", "puppet"]
  }'
```

**What happens:**

1. Packages are installed on all four hosts.
2. The primary and compilers are configured with `ca=false` on compilers.
3. OpenVoxDB and PostgreSQL are installed and configured on `db.example.com`.
4. The primary is told to send reports and queries to the dedicated database.
5. r10k is configured with your control repo.

Agents should now connect to `puppet.example.com` (which resolves to your
load balancer in front of the compilers).

---

## Example: Extra Large Install

For maximum availability, use a replica server and two PostgreSQL hosts.

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host": "primary-a.example.com",
    "replica_host": "primary-b.example.com",
    "compiler_hosts": ["compiler-a1.example.com", "compiler-a2.example.com",
                       "compiler-b1.example.com", "compiler-b2.example.com"],
    "primary_postgresql_host": "db-a.example.com",
    "replica_postgresql_host": "db-b.example.com",
    "version": "8.11.0",
    "r10k_remote": "git@github.com:yourorg/control-repo.git",
    "compiler_pool_address": "puppet.example.com",
    "internal_compiler_a_pool_address": "compilers-a.example.com",
    "internal_compiler_b_pool_address": "compilers-b.example.com"
  }'
```

This is a complex setup. openvox-adm will:

- Assign the primary to availability group "A" and the replica to "B".
- Split compilers between the two groups.
- Configure PostgreSQL streaming replication between A and B.
- Wire everything together so you can survive the loss of group A.

---

## Post-Install Steps

After the install plan finishes successfully, do the following:

### 1. Verify Everything Is Running

```bash
bolt plan run openvoxadm::status --targets all
```

You should see `running` for `openvox-server`, `openvoxdb`, and `postgresql`
on the appropriate hosts.

### 2. Deploy Your Control Repo

If you provided `r10k_remote`, r10k is already configured. Deploy your
environments:

```bash
r10k deploy environment --puppetfile
```

If you did **not** provide `r10k_remote`, install r10k manually and configure
it, or set up your control repo now.

### 3. Sign Any Pending Agent Certificates

On the primary server:

```bash
puppetserver ca sign --all
```

### 4. Enroll Your First Agent (Optional)

On a test node:

```bash
puppet ssl bootstrap
```

Then sign the certificate on the primary and run `puppet agent -t`.

---

## ⚠️ Troubleshooting

### "Permission denied (publickey)" when running Bolt

Make sure your SSH key is loaded and authorized on all targets:

```bash
ssh-copy-id root@primary.example.com
```

### Services fail to start

Check the logs:

```bash
journalctl -u openvox-server -n 100
journalctl -u openvoxdb -n 100
```

Common causes: missing certificate, PostgreSQL not ready, or port conflicts.

### Agents cannot reach the server

- Verify DNS resolution from the agent.
- Check that port 8140 is open.
- If using a load balancer, make sure health checks pass.

### OpenVoxDB connection errors

Run `openvoxadm::status` and look for `openvoxdb` status. If it is down,
check PostgreSQL is running and that `database.ini` has the correct
connection string.

---

## Next Steps

- Learn about [architectures](architectures.md) in more detail.
- [Expand your cluster](expanding.md) by adding compilers or a replica.
- Set up [backups](backup_restore.md) before putting the cluster into
  production.

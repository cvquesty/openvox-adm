# Checking Cluster Status

When something feels off — agents are slow, a service won't start, or you
just want peace of mind — the `openvoxadm::status` plan gives you a quick
health check of your entire cluster.

This guide explains what the status plan checks, how to read the output,
and how to drill down into individual hosts.

---

## Table of Contents

- [Quick Status Check](#quick-status-check)
- [What Gets Checked](#what-gets-checked)
- [Reading the Output](#reading-the-output)
- [Checking Individual Hosts](#checking-individual-hosts)
- [When Things Look Wrong](#when-things-look-wrong)

---

## Quick Status Check

Run this command from your jump host:

```bash
bolt plan run openvoxadm::status --targets all
```

You will see a summary for every host in your inventory. The output includes:

- Whether each service is running or stopped
- The OpenVox version installed
- The node's certname and configured server
- Hostname (useful to verify DNS)

**Example output (abbreviated):**

```
primary.example.com:
  openvox-server: running
  openvoxdb: running
  postgresql: running
  version: 8.11.0
  certname: primary.example.com
  server: primary.example.com
  ca_server: primary.example.com

compiler1.example.com:
  openvox-server: running
  openvoxdb: (not applicable)
  postgresql: (not applicable)
  version: 8.11.0
  certname: compiler1.example.com
  server: primary.example.com
  ca_server: primary.example.com
```

---

## What Gets Checked

The status plan queries the following on each target:

| Check | What It Tells You |
|-------|-------------------|
| `openvox-server` status | Is the Puppet Server running? |
| `openvoxdb` status | Is OpenVoxDB running? (primary and DB hosts only) |
| `postgresql` status | Is PostgreSQL running? (primary and DB hosts only) |
| `openvox --version` | Which OpenVox version is installed |
| `puppet config print certname` | The node's certificate name |
| `puppet config print server` | Which server the node talks to for catalogs |
| `puppet config print ca_server` | Which server signs certificates |
| `hostname` | The system's hostname (sanity check) |

If a service is not applicable (for example, `openvoxdb` on a compiler), the
plan simply skips that check.

---

## Reading the Output

### All Green

If every service shows `running` and versions match, you are in good shape.
Your cluster is healthy.

### Service Stopped

If you see `stopped` for a service, that host has an issue. Common causes:

- The service crashed on startup (check logs with `journalctl`)
- The service was manually stopped
- A dependency (like PostgreSQL) is not running

### Version Mismatch

If one host shows a different version than the others, that host may have
been upgraded separately or missed an upgrade. Run the `upgrade` plan to
bring it in line.

### Wrong Server

If a compiler shows `server: localhost` instead of your primary, its
`puppet.conf` may be misconfigured. Double-check with:

```bash
puppet config print server --section main
```

---

## Checking Individual Hosts

You do not have to check the whole cluster every time. You can target
specific hosts:

### Single Host

```bash
bolt plan run openvoxadm::status --targets primary.example.com
```

### Multiple Hosts

```bash
bolt plan run openvoxadm::status \
  --targets compiler1.example.com,compiler2.example.com
```

### All Compilers

If you have a group in your inventory:

```bash
bolt plan run openvoxadm::status --targets openvox
```

(Assumes you named your group `openvox` in `inventory.yaml`.)

---

## ⚠️ When Things Look Wrong

Here are some quick follow-up commands when status shows problems:

| Symptom | Next Step |
|---------|-----------|
| Service stopped | `journalctl -u openvox-server -n 50` |
| Version mismatch | `bolt plan run openvoxadm::upgrade --params '...' ` |
| Wrong server | `puppet config print server` on the node |
| Certificate errors | `puppetserver ca list` on the primary |

For deeper troubleshooting, see the
[install guide](install.md#troubleshooting) or check the OpenVox
documentation at [voxdocs](https://github.com/cvquesty/voxdocs).

---

## Next Steps

- [Back up your cluster](backup_restore.md) so you can recover from any
  issue.
- [Expand your cluster](expanding.md) if you need more capacity.
- Review [architectures](architectures.md) to understand your setup.

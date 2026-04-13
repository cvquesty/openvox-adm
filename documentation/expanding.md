# Expanding an OpenVox Cluster

So you have a working OpenVox cluster — great! Now you want to grow it.
Maybe you added more nodes and need more compile capacity. Maybe you want a
dedicated database host. Or perhaps you are ready for high availability with
a replica server.

This guide explains how to add each component using openvox-adm's expansion
plans.

> **Friendly tip:** You can expand at any time — your existing agents keep
> running during the process. The plans are designed to be safe to run on a
> live cluster.

---

## Table of Contents

- [Add Compilers](#add-compilers)
- [Add a Database Host](#add-a-database-host)
- [Add a Replica Server](#add-a-replica-server)
- [Availability Groups](#availability-groups)
- [Common Gotchas](#common-gotchas)

---

## Add Compilers

Compilers offload catalog compilation from your primary server. If your
primary is getting slow, or you simply have many agents, adding compilers
is the quickest win.

### When to Add Compilers

- Your primary server CPU is consistently high during puppet runs
- You have more than ~500 nodes
- You want faster agent runs

### How to Add Compilers

```bash
bolt plan run openvoxadm::add_compilers \
  --params '{
    "compiler_hosts": ["compiler3.example.com", "compiler4.example.com"],
    "primary_host": "primary.example.com",
    "avail_group_letter": "A"
  }'
```

**What the plan does:**

1. Installs `openvox-server` and `openvox-agent` on each new compiler.
2. Bootstraps certificates (the primary signs them).
3. Sets `ca=false` so the compiler does not act as a CA.
4. Points the compiler at the primary for certificate operations.
5. Adds the compiler's certname to OpenVoxDB's allowlist.
6. Starts the openvox-server service.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `compiler_hosts` | Array of hostnames for the new compilers |
| `primary_host` | Your primary server (must already be installed) |
| `avail_group_letter` | `"A"` or `"B"` — which availability group to assign |
| `dns_alt_names` | Optional array of SANs for compiler certs |
| `primary_postgresql_host` | Optional; only needed if you have a dedicated DB |

### After Adding Compilers

1. **Update your load balancer** (if any) to include the new compilers.
2. **Run `puppet agent -t`** on a test agent to verify it can reach the
   compilers.
3. **Check status:**
   ```bash
   bolt plan run openvoxadm::status --targets compiler3.example.com,compiler4.example.com
   ```

---

## Add a Database Host

By default, OpenVoxDB and PostgreSQL run on the primary server. Moving them
to a dedicated host improves performance and lets you tune the database
independently.

### When to Add a Database Host

- You have a Large or Extra Large architecture
- The primary server is under memory pressure
- You want to back up the database separately

### How to Add a Database Host

```bash
bolt plan run openvoxadm::add_database \
  --params '{
    "targets": "db.example.com",
    "primary_host": "primary.example.com",
    "mode": "init"
  }'
```

**What the plan does:**

1. Installs PostgreSQL and openvoxdb on the new host.
2. Creates the `puppetdb` database and user.
3. Configures `database.ini` with the connection string.
4. Updates the primary's `puppetdb.conf` to point at the new host.
5. Restarts services.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `targets` | Hostname of the new database host |
| `primary_host` | Your primary server |
| `mode` | `"init"` for the first external DB, `"pair"` for HA (XL) |

> **Note:** After adding a dedicated database, your primary no longer needs
> local PostgreSQL. You can optionally stop it there, but it will not hurt to
> leave it running.

---

## Add a Replica Server

A replica server provides high availability. If your primary goes down, the
replica can take over as the new primary (with some manual steps for full
failover).

### When to Add a Replica

- You have an Extra Large architecture
- You need zero-downtime maintenance
- You want disaster recovery capability

### How to Add a Replica

```bash
bolt plan run openvoxadm::add_replica \
  --params '{
    "primary_host": "primary.example.com",
    "replica_host": "replica.example.com"
  }'
```

**What the plan does:**

1. Installs openvox-server on the replica.
2. Bootstraps certificates pointing to the primary CA.
3. Sets availability group "B" (primary is "A").
4. Starts the replica server.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `primary_host` | Your existing primary server |
| `replica_host` | Hostname for the new replica |
| `replica_postgresql_host` | Optional dedicated PostgreSQL for the replica (XL) |

> **Tip:** After adding a replica, consider setting up PostgreSQL streaming
> replication between primary and replica DB hosts for full data redundancy.

---

## Availability Groups

In HA setups, components are tagged with an **availability group** — either
"A" or "B". This tells openvox-adm which components form a logical pair for
failover.

### Assigning Groups

When you add compilers or a replica, specify the group:

```bash
# Add compilers to group B
bolt plan run openvoxadm::add_compilers \
  --params '{"compiler_hosts":["comp-b1.example.com"],"primary_host":"primary.example.com","avail_group_letter":"B"}'
```

### Group Assignments

| Component | Group |
|-----------|-------|
| Primary server | A |
| Replica server | B |
| Half the compilers | A |
| Half the compilers | B |
| Primary PostgreSQL | A |
| Replica PostgreSQL | B |

If group A fails, group B keeps serving agents. You can promote the replica
to primary manually or via your own automation.

---

## ⚠️ Common Gotchas

### "Certificate not found" after adding a compiler

Make sure the compiler's cert was signed on the primary:

```bash
puppetserver ca sign --certname compiler3.example.com
```

Then restart the compiler:

```bash
systemctl restart openvox-server
```

### PostgreSQL connection refused

Check that PostgreSQL is running on the database host:

```bash
systemctl status postgresql
```

Also verify `pg_hba.conf` allows connections from your primary/compilers.

### Load balancer health checks fail

The health check endpoint is `https://<compiler>:8140/status/v1/simple/master`.
Make sure your LB is configured to check this URL and that port 8140 is open.

---

## Next Steps

- [Check cluster status](status.md) to verify everything is healthy.
- Set up [backups](backup_restore.md) before making more changes.
- Review [architectures](architectures.md) if you want to re-architect.


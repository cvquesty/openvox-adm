# OpenVox Architectures

openvox-adm supports three deployment architectures. Each one balances
simplicity, performance, and availability differently. This document
explains when to choose each architecture and how the components fit
together.

> **Friendly reminder:** You do not need to pick perfectly on day one. You
> can start with a Standard architecture and expand to Large or Extra Large
> later using the `add_database`, `add_compilers`, and `add_replica` plans.

---

## Table of Contents

- [Standard Architecture](#standard-architecture)
- [Large Architecture](#large-architecture)
- [Extra Large (HA) Architecture](#extra-large-ha-architecture)
- [Availability Groups](#availability-groups)
- [Load Balancing Compilers](#load-balancing-compilers)
- [Choosing an Architecture](#choosing-an-architecture)

---

## Standard Architecture

The simplest possible OpenVox deployment. Everything lives on a single
server:

```
┌─────────────────────────────────────┐
│         primary.example.com         │
│  ┌─────────────┐  ┌───────────────┐ │
│  │ openvox-    │  │ openvoxdb     │ │
│  │ server      │  │ + PostgreSQL  │ │
│  │ (CA, r10k)  │  │               │ │
│  └─────────────┘  └───────────────┘ │
└─────────────────────────────────────┘
         ▲
         │ agents connect here
```

**Components:**

| Component | Purpose |
|-----------|---------|
| `openvox-server` | CA, catalog compilation, r10k code deployment |
| `openvoxdb` | Stores facts, catalogs, reports |
| `postgresql` | Backend database for OpenVoxDB |

**Pros:**

- Easiest to set up and maintain
- Lowest infrastructure cost
- Great for learning OpenVox or small teams

**Cons:**

- Single point of failure
- Database and server compete for resources
- Limited to roughly 500 nodes

**Best for:** Labs, small teams, or fewer than 500 nodes.

---

## Large Architecture

Split the database onto its own host. This improves performance because
database queries do not contend with catalog compilation.

```
┌──────────────────────────┐      ┌──────────────────────────┐
│   primary.example.com    │      │     db.example.com       │
│  ┌────────────────────┐  │      │  ┌────────────────────┐  │
│  │ openvox-server     │  │─────▶│  │ PostgreSQL         │  │
│  │ (CA, r10k)         │  │      │  │ + openvoxdb        │  │
│  └────────────────────┘  │      │  └────────────────────┘  │
└──────────────────────────┘      └──────────────────────────┘
           ▲
           │
    ┌──────┴──────┐
    │             │
┌───▼────┐   ┌────▼───┐
│comp1   │   │comp2   │
│(ca=f)  │   │(ca=f)  │
└────────┘   └────────┘
```

**Components:**

| Host | Components |
|------|------------|
| `primary.example.com` | openvox-server, r10k |
| `db.example.com` | PostgreSQL, openvoxdb |
| `compiler*.example.com` | openvox-server with `ca=false` |

**Pros:**

- Better performance at scale
- Database tuning does not affect the primary server
- Compilers offload catalog compilation from the primary

**Cons:**

- More hosts to manage
- Still a single database (no HA)

**Best for:** 500–5,000 nodes, or when you want independent database tuning.

---

## Extra Large (HA) Architecture

Full redundancy with availability groups. If one group fails, the other
continues serving agents.

```
                     ┌──────────────────────────────┐
                     │   Load Balancer (HAProxy)    │
                     │   puppet.example.com         │
                     └──────────────┬───────────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
    ┌───────▼────────┐     ┌────────▼────────┐     ┌────────▼────────┐
    │  primary-a     │     │  primary-b      │     │  compilers      │
    │  (group A)     │     │  (group B)      │     │  (A/B pools)    │
    │  openvox-server│     │  openvox-server │     │                 │
    └───────┬────────┘     └───────┬─────────┘     └────────┬────────┘
            │                      │                        │
    ┌───────▼────────┐     ┌───────▼─────────┐     ┌────────▼────────┐
    │  db-a          │     │  db-b           │     │  (agents)       │
    │  PostgreSQL A  │◀───▶│  PostgreSQL B   │     │                 │
    │  openvoxdb     │     │  openvoxdb      │     │                 │
    └────────────────┘     └─────────────────┘     └─────────────────┘
         (streaming replication)
```

**Components:**

| Role | Group | Purpose |
|------|-------|---------|
| Primary server | A | Main CA, r10k, primary compilation |
| Replica server | B | Hot standby; can take over if A fails |
| Compiler pool A | A | Catalog compilation (behind LB) |
| Compiler pool B | B | Catalog compilation (behind LB) |
| PostgreSQL A | A | Primary database |
| PostgreSQL B | B | Replica database (streaming replication) |

**Pros:**

- Zero-downtime failover
- Horizontal scaling of compilation capacity
- Database redundancy

**Cons:**

- Most complex to set up
- Highest infrastructure cost
- Requires load balancer configuration

**Best for:** More than 5,000 nodes, or any environment that cannot tolerate
downtime.

---

## Availability Groups

In HA (Extra Large) architectures, components are assigned to an
**availability group** — either "A" or "B". This lets openvox-adm (and you)
know which components form a logical pair.

| Component | Group A | Group B |
|-----------|---------|---------|
| Primary server | ✅ | — |
| Replica server | — | ✅ |
| Compiler | ✅ (half) | ✅ (half) |
| PostgreSQL | ✅ | ✅ |

If group A fails (for example, a datacenter outage), group B continues to
serve agents. The replica server becomes the new primary, and the B
compilers keep compiling catalogs.

You assign availability groups when you add compilers or replicas:

```bash
bolt plan run openvoxadm::add_compilers \
  --params '{"compiler_hosts":["comp-b1.example.com"],"primary_host":"primary.example.com","avail_group_letter":"B"}'
```

---

## Load Balancing Compilers

In Large and Extra Large architectures, you will almost certainly want a
load balancer in front of your compilers. This gives you:

- **High availability** — if one compiler dies, agents are sent to others
- **Horizontal scaling** — add more compilers to handle more nodes

**Recommended:** [HAProxy](https://www.haproxy.org/), configured with the
`leastconn` algorithm (agents open long-lived connections).

**Health check endpoint:** `https://<compiler>:8140/status/v1/simple/master`

A sample HAProxy config snippet:

```
backend openvox-compilers
    balance leastconn
    option httpchk GET /status/v1/simple/master
    server compiler1 10.0.1.10:8140 check
    server compiler2 10.0.1.11:8140 check
```

See the [Puppet documentation on compiler load balancing](https://www.puppet.com/docs/pe/latest/installing_compilers.html#load-balancing-compilers)
for more details (the concepts apply directly to OpenVox).

---

## Choosing an Architecture

| If you have... | Choose... |
|----------------|-----------|
| < 500 nodes, single site | Standard |
| 500–5,000 nodes or want DB tuning | Large |
| > 5,000 nodes or need HA/DR | Extra Large |

You can always start simple and expand later. The `add_database`,
`add_compilers`, and `add_replica` plans make it easy to grow.

---

## Next Steps

- [Install your cluster](install.md) using the architecture you chose.
- [Expand later](expanding.md) by adding compilers, a database, or a replica.
- Set up [backups](backup_restore.md) before going to production.

# Architectures

openvox-adm describes three deployment shapes. **Only Standard is Beta.** Large
is Experimental. Extra Large / HA is WIP scaffolding. This page matches the
code on `development`, not an aspirational PEADM brochure.

For Bolt parameters, see [plan-reference.md](plan-reference.md). For Standard
keystrokes, see [runbook-install-standard.md](runbook-install-standard.md).

---

## Choosing an architecture

| If you need… | Choose | Maturity |
|--------------|--------|----------|
| One server to learn / lab / small fleet | **Standard** | Beta |
| Separate DB + compile capacity | **Large** | Experimental |
| True HA with streaming Postgres + LB | **Not ready** — XL is WIP | WIP |

You can start Standard and expand later with day-2 plans. Expansion plans have
their own maturity (compilers Beta-ish; database WIP; replica Experimental
bring-up only).

---

## Standard — single server (Beta)

```
┌─────────────────────────────┐
│ primary.example.com         │
│  openvox-server (CA+compile)│
│  openvoxdb                  │
│  postgresql                 │
└─────────────────────────────┘
```

**Why it exists:** fewest moving parts; best-tested install path.

**Prerequisites:** PostgreSQL present; optional r10k preinstalled if you pass
`r10k_remote`.

**Install sketch:**

```bash
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

**Success looks like:** `openvox-server`, `openvoxdb`, and `postgresql` active;
primary cert signed; agents can be signed day-2.

**What can go wrong:** missing PostgreSQL package; r10k missing; outbound repo
blocked. See [troubleshooting.md](troubleshooting.md).

---

## Large — compilers + dedicated DB (Experimental)

```
┌──────────────────┐     ┌──────────────────┐
│ primary          │     │ compiler N       │
│ openvox-server   │     │ openvox-server   │
│ (CA)             │     │ ca=false         │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         └──────────┬─────────────┘
                    ▼
         ┌──────────────────────┐
         │ db.example.com       │
         │ postgresql + openvoxdb│
         └──────────────────────┘
```

**Why it exists:** scale compile load and isolate DB I/O.

**What install configures**

- Packages on all listed hosts
- Primary CA bootstrap + primary sign
- Compilers pointed at primary (`server`, `ca_server`, `ca false`)
- OpenVoxDB on dedicated host; primary `puppetdb.conf` → DB:8081
- Services enabled on primary, compilers, DB host

**What install does *not* do**

- Auto-sign compiler CSRs
- Add compilers to OpenVoxDB `certificate-allowlist` (primary only until
  `add_compilers`)
- Configure load balancers or `compiler_pool_address` (dead params)
- Install PostgreSQL/r10k for you

**Operator follow-up after Large install**

1. Sign each compiler certname on the primary.
2. Either run `openvoxadm::add_compilers` for *additional* compilers (allowlist
   append is built-in there), or manually ensure allowlist entries exist for
   compilers created during install.
3. Place any LB in front yourself (HAProxy examples online are **manual** —
   this module does not apply `puppetlabs/haproxy` for you).

---

## Extra Large / HA — WIP (scaffolding)

Aspirational shape (not delivered by install today):

```
Group A                          Group B
primary + compilers + PG/DB      replica + compilers + PG/DB
              \                     /
               \                   /
                load balancer ideas
```

**Parameters that look real but are incomplete**

| Param | Reality |
|-------|---------|
| `replica_host` | Packages may install; **not configured** during install |
| `replica_postgresql_host` | Packages may install; **not configured** |
| `compiler_pool_address` / internal A/B pools | **Dead** (unused) |

**Not implemented**

- PostgreSQL streaming replication
- Automatic A/B failover
- HAProxy / LB configuration generation
- CA/code/DB sync for replicas during install

**Day-2 related plans**

- `add_replica` — Experimental bring-up (not zero-downtime HA)
- `add_database` with `mode => pair` — **stub** (message only + basic PG
  configure)

Until those mature, treat XL documentation elsewhere on the internet as
design intent, not openvox-adm capability.

---

## Expanding later

| Goal | Plan | Maturity |
|------|------|----------|
| More compilers | `add_compilers` | Beta |
| Move/add dedicated DB | `add_database` (`init`) | WIP |
| Second PG for HA pair | `add_database` (`pair`) | Stub / WIP |
| Second server | `add_replica` | Experimental |

Details: [expanding.md](expanding.md).

---

## Inventory tips

- Use hostname strings that match certnames you want.
- Root SSH from the jump host to every role host.
- `host-key-check: false` is a lab convenience; tighten for production.

---

## Related

- [install.md](install.md)
- [security-notes.md](security-notes.md) — trust auth implications for DB hosts

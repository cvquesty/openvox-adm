# Installing OpenVox with openvox-adm

This guide explains how `openvoxadm::install` works, what each architecture
actually does in **today’s code**, and how to avoid the common footguns.

**Related**

- Painfully detailed Standard path: [runbook-install-standard.md](runbook-install-standard.md)
- Architecture diagrams/narrative: [architectures.md](architectures.md)
- Full parameter tables: [plan-reference.md](plan-reference.md)
- Concepts glossary: [concepts.md](concepts.md)

---

## What success means

After a **Standard** install you should have:

1. OpenVox 8.x packages on the primary (`openvox-server`, `openvox-agent`,
   `openvoxdb` — plus apt-only extras on Debian/Ubuntu).
2. Primary certificate bootstrapped and **signed for the primary certname**.
3. OpenVoxDB configured against local PostgreSQL with trust auth (lab-style).
4. `openvox-server`, `openvoxdb`, and `postgresql` enabled/started (if
   PostgreSQL is installed).
5. Optional r10k config **only if** you passed `r10k_remote` **and** `r10k`
   already exists on the host.

Large/XL add hosts and complexity; see maturity notes below. Do not treat XL
as production HA.

---

## Prerequisites (all architectures)

1. **Bolt** on a jump host: `>= 3.17.0 < 6.0.0`.
   Install from the official docs:
   [Install and upgrade Bolt](https://help.puppet.com/bolt/current/topics/bolt_installing.htm).
   Do **not** `curl` an HTML doc page into `sh`.
2. **Module** from Git (recommended pre-Forge):

   ```ruby
   # Puppetfile
   mod 'openvox-adm',
     :git => 'https://github.com/cvquesty/openvox-adm.git',
     :branch => 'development'
   ```

   ```bash
   bolt puppetfile install
   ```

   Avoid assuming `bolt project init --modules openvox-adm` works until the
   module is published on the Forge.
3. **SSH as root** (or equivalent) to every target.
4. **Clean hosts** — no prior Puppet/OpenVox install.
5. **Outbound HTTPS** to `yum.voxpupuli.org` or `apt.voxpupuli.org`.
6. **PostgreSQL** available on any host where the plan will
   `systemctl enable --now postgresql`. The install task does **not** install
   the `postgresql` package explicitly.
7. **r10k** (optional): install the gem/package yourself before using
   `r10k_remote`. The module writes config and runs deploy; it does not install
   r10k.

---

## How the install plan runs (high level)

1. Log parameters (secrets redacted) — on install/upgrade also assert Bolt +
   OpenVox version.
2. `subplans::install`:
   - Parallel `openvoxadm::install_packages` on all non-undef role hosts.
   - Primary: `puppet ssl bootstrap --waitforcert 60`.
   - `configure_primary` (optional dns_alt_names, restart, sign **primary**).
   - Each compiler (if any): bootstrap + `configure_compiler` (**no auto-sign**).
   - Optional dedicated PG: `configure_postgresql`.
   - `configure_openvoxdb` (DB user, trust hba, ini files, allowlist =
     primary only).
3. `subplans::configure`:
   - Optional `configure_r10k` if `r10k_remote` set.
   - Enable/start services for the architecture path.

Return value is roughly `[$install_result, $configure_result]`.

---

## Architecture: Standard — Beta

**Params that matter:** `primary_host` (required), `version` (default
`8.11.0`), optional `dns_alt_names`, optional `r10k_remote`.

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host":"primary.example.com",
    "version":"8.11.0",
    "dns_alt_names":["puppet.example.com"]
  }'
```

### What gets installed (packages)

- **EL (yum path):** `openvox-server`, `openvox-agent`, `openvoxdb` at the
  pinned version. Does **not** install `openbolt` or `openvoxdb-termini` on
  this path.
- **Debian/Ubuntu (apt path):** pins `openbolt`, `openvox-agent`,
  `openvox-server`, `openvoxdb`, `openvoxdb-termini`.

### Post-install checks

```bash
bolt plan run openvoxadm::status --targets primary.example.com
# on primary:
systemctl is-active openvox-server openvoxdb postgresql
puppetserver ca list --all
```

Sign **agents** with targeted certnames. Compilers/replicas are not part of
Standard.

---

## Architecture: Large — Experimental

**Extra params:** `compiler_hosts`, `primary_postgresql_host`.

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host":"primary.example.com",
    "compiler_hosts":["compiler1.example.com","compiler2.example.com"],
    "primary_postgresql_host":"db.example.com",
    "version":"8.11.0"
  }'
```

### What actually happens

1. Packages on primary, compilers, and DB host.
2. Primary bootstrap + primary cert sign.
3. Each compiler: bootstrap + point `server`/`ca_server` at primary, `ca false`.
4. Dedicated DB: PostgreSQL + OpenVoxDB enable; primary `puppetdb.conf` points
   at DB host `:8081`.
5. Services started on primary, DB host, and compilers.

### Honest gaps (do these manually)

1. **Sign compiler CSRs** on the primary (`puppetserver ca sign --certname …`).
2. **OpenVoxDB allowlist** after Large install contains **primary only**.
   Compilers are appended when you use `add_compilers` (or edit the file
   carefully). Until then, compilers may be unable to use OpenVoxDB mTLS
   properly.
3. **No load balancer / pool address configuration** — those install params are
   dead even if you pass them.
4. Same PostgreSQL and r10k prerequisites as Standard.

---

## Architecture: Extra Large / HA — WIP

Parameters such as `replica_host`, `replica_postgresql_host`,
`compiler_pool_address`, and internal A/B pool addresses **exist**.

**What the code does today**

- Replica / replica-PG may receive **packages** because they are in the target
  list.
- Install/configure **do not** bootstrap or configure the replica role.
- Replica PG is **not** configured for replication.
- Pool address parameters are **accepted and ignored**.
- **Streaming replication is not implemented.**
- HAProxy is **not** configured by this module.

**Do not** claim zero-downtime HA from `openvoxadm::install` alone. If you need
a second server later, see Experimental `add_replica` (bring-up only) in
[expanding.md](expanding.md).

---

## Parameter reference (install)

See the full table in [plan-reference.md](plan-reference.md#openvoxadminstall).
Dead parameters worth remembering:

- `legacy_compilers`
- `compiler_pool_address`, `internal_compiler_*_pool_address`
- `r10k_private_key_file`, `r10k_private_key_content`
- `stagingdir`, `uploaddir`
- `final_agent_state` (unused in configure)

---

## r10k notes

If you pass `r10k_remote`:

1. Preinstall `r10k` and ensure `/etc/puppetlabs/r10k/` can be written.
2. Private key parameters are **dead** — arrange Git auth yourself.
3. Plan writes `/etc/puppetlabs/r10k/r10k.yaml` and runs
   `r10k deploy environment --puppetfile`.

If r10k is missing, configure fails.

---

## Certificate signing policy

| Identity | Auto-signed by install? |
|----------|-------------------------|
| Primary certname | Yes (targeted sign) |
| Compilers | **No** — sign manually |
| Replicas | **No** (and XL path does not configure them) |
| Agents | **No** — normal day-2 ops |

Prefer:

```bash
puppetserver ca sign --certname host.example.com
```

over `sign --all` unless you intend to trust every pending request.

---

## EL vs Debian package differences

Do not expect `rpm -qa` on RHEL to list `openbolt` or `openvoxdb-termini` after
install — the yum path does not install them. Apt path does pin those names.

---

## What can go wrong

| Symptom | Likely cause |
|---------|--------------|
| `postgresql` unit missing | Package never installed by task |
| r10k deploy fails | Gem/package not installed; Git auth missing |
| Compiler TLS errors | CSR not signed |
| Compilers + OpenVoxDB auth issues after Large install | Allowlist only has primary |
| XL “HA” not actually HA | Replica params are scaffolding |
| Version assert failure | Non-8.x without `permit_unsafe_versions` |

More: [troubleshooting.md](troubleshooting.md).

---

## Next steps after install

1. [status.md](status.md) — verify services
2. [expanding.md](expanding.md) — add compilers/DB/replica carefully
3. [backup_restore.md](backup_restore.md) — take a recovery tarball
4. [upgrade.md](upgrade.md) — when you need a newer 8.x pin

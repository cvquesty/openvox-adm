# Security notes (honest current state)

This module is an early (v0.1.0) operations toolkit. Several defaults favor
**lab bring-up** over hardened multi-tenant production. Read this before you
expose a cluster beyond a trusted network.

---

## Confirm gates

These plans refuse to proceed unless `confirm => true`:

| Plan | Why |
|------|-----|
| `openvoxadm::restore` | Overwrites SSL/config/env/PuppetDB files |
| `openvoxadm::restore_ca` | Overwrites SSL tree |
| `openvoxadm::uninstall` | Removes packages and data |

`migrate` calls `restore` with confirm forced true internally — still dangerous
because of the cross-host path issue.

---

## Parameter logging redaction

`openvoxadm::log_plan_parameters` redacts keys matching roughly
`(key|secret|password|token|pem|credential)` (case-insensitive). Do not put
secrets in parameter names that evade that pattern.

Several r10k private key parameters exist on `install` but are **dead** —
they are not a supported secret-distribution feature yet.

---

## Database authentication: trust, no SCRAM

`configure_openvoxdb` today:

- Creates DB/user `puppetdb` (errors often ignored if they already exist)
- Appends a **trust** line for `127.0.0.1/32` in `pg_hba.conf`
- Writes `database.ini` with **empty password**

**Implications**

- Fine for a single-purpose lab DB host where OpenVoxDB and PostgreSQL are
  local to each other
- Unsafe for shared/multi-tenant PostgreSQL servers
- Splitting OpenVoxDB onto a different host from PostgreSQL while relying on
  localhost trust will break or encourage worse workarounds
- **SCRAM / password auth is not implemented** by these plans

Harden outside the module if your threat model requires it (know that future
plan runs may rewrite lab-oriented files).

---

## Certificate practices

- Install signs **only** the primary certname (safer than historical `--all`
  behavior)
- Compilers/replicas/agents need explicit `puppetserver ca sign --certname`
- Prefer targeted sign over `sign --all`
- OpenVoxDB `certificate-allowlist` starts as primary-only; compilers are
  appended by `add_compilers`. Re-running `configure_openvoxdb` **resets**
  the allowlist to primary-only

---

## SSH and root

Examples use root over SSH with `host-key-check: false` for labs. For real
environments:

- Use key auth, restricted accounts + `run-as`, and known_hosts checking
- Remember Bolt `apply()` and many commands run with high privilege

---

## Shell interpolation

Newer backup/restore/CA/primary paths use `shellquote` in places. Other
`run_command` strings still interpolate hostnames. Prefer boring hostname
inventory strings; treat untrusted inventory input as dangerous.

---

## Transport security for package install

`install_packages` uses `curl --fail` to install release packages from Vox
Pupuli repos. Keep outbound access constrained and verify you trust those
repos/networks.

---

## HAProxy / unused modules

`Puppetfile` may list modules (for example haproxy, r10k, openvoxdb) that
plans do **not** fully apply for cluster roles. Do not assume declaring a
module equals automated hardening.

---

## Related

- [concepts.md](concepts.md)
- [troubleshooting.md](troubleshooting.md)
- [backup_restore.md](backup_restore.md)

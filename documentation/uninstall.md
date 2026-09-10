# Uninstalling OpenVox with openvox-adm

**Plan:** `openvoxadm::uninstall`  
**Maturity:** Beta  
**Safety:** requires **`confirm => true`**

Use this to wipe OpenVox packages and key data from targets so you can retry an
install. It is a **partial** cleanup, not a guarantee of a pristine OS image.

---

## Parameters

| Name | Type | Default | Notes |
|------|------|---------|-------|
| `targets` | TargetSpec | — | One or many hosts |
| `confirm` | Boolean | `false` | Must be `true` or the plan fails |

---

## Example

```bash
bolt plan run openvoxadm::uninstall \
  --params '{"targets":"primary.example.com","confirm":true}'
```

Multiple hosts:

```bash
bolt plan run openvoxadm::uninstall \
  --params '{
    "targets":["primary.example.com","compiler1.example.com"],
    "confirm":true
  }'
```

---

## What the task does

`tasks/uninstall.sh` roughly:

1. Stops related services
2. Removes packages via yum remove / apt purge for
   `openvox-server`, `openvox-agent`, `openvoxdb`
3. Deletes SSL tree, PuppetDB data, and `environments/*`

Exact commands live in the task script — treat this list as the operator
summary.

---

## What typically remains

The uninstall path does **not** reliably remove:

- Vox Pupuli / OpenVox **release repo** packages
- **PostgreSQL** packages or data directories
- **openbolt** / **openvoxdb-termini** (especially relevant on apt installs)
- All of `/etc/puppetlabs` (other leftovers may remain)
- Your recovery tarballs under `/var/backups/openvox` (unless you delete them)

If you need a truly clean slate, finish with OS packaging tools and manual
directory review — or rebuild the VM.

---

## What success looks like

1. Plan completes with `confirm => true`
2. `rpm -qa` / `dpkg -l` no longer show the main OpenVox packages you care
   about
3. `/etc/puppetlabs/puppet/ssl` is gone (or empty as deleted)
4. You still verify PostgreSQL/repos manually before reinstall

---

## Reinstall after uninstall

1. Confirm PostgreSQL still meets [runbook](runbook-install-standard.md)
   prerequisites (uninstall may leave Postgres in place — good or bad
   depending on your intent)
2. Re-run `openvoxadm::install`
3. Do not assume old CSRs/SSL will be reused — they were deleted

---

## Related

- [install.md](install.md)
- [backup_restore.md](backup_restore.md) — take backups **before** uninstall
  if you might need data

# Runbook: Standard install (painfully detailed)

**Architecture:** Standard (single server)  
**Plan:** `openvoxadm::install`  
**Maturity:** Beta (best-tested path — still not a promise of production polish)  
**Module:** [cvquesty/openvox-adm](https://github.com/cvquesty/openvox-adm)  
**Default version pin:** `8.11.0`

This runbook is written so a careful operator can follow it without guessing.
If a step fails, stop and use [troubleshooting.md](troubleshooting.md) before
continuing.

---

## 0. What you will have when finished

On **one** Linux host (the primary):

- Packages: OpenVox agent + server + OpenVoxDB (exact set depends on EL vs
  Debian — see step 9)
- Services: `openvox-server`, `openvoxdb`, `postgresql` active (if PostgreSQL
  was present)
- CA: primary certname signed by the install plan
- Optional: r10k config only if you prepared r10k and passed `r10k_remote`

You will **not** have: compilers, replicas, load balancers, SCRAM Postgres
auth, or Forge-based module install unless you chose that separately.

---

## 1. Gather facts (write them down)

| Item | Example | Your value |
|------|---------|------------|
| Jump host OS | macOS / Ubuntu 22.04 | |
| Primary hostname (FQDN) | `primary.example.com` | |
| Primary IP | `192.0.2.10` | |
| OpenVox version pin | `8.11.0` | |
| DNS alt names (optional) | `puppet.example.com` | |
| Control repo URL (optional) | `git@github.com:org/control-repo.git` | |
| Primary OS family | EL8/9 or Ubuntu | |

Confirm the FQDN is what you want as **certname**. Changing certname later is
painful.

---

## 2. Prepare the primary host

### 2.1 Fresh OS

Use a supported OS from `metadata.json` (EL 8/9 family, Ubuntu 20.04/22.04/24.04,
etc.). Do **not** start from a host that already has Puppet or OpenVox packages.

### 2.2 Hostname and time

```bash
hostnamectl
timedatectl
# fix hostname / chrony/ntp if needed before install
```

### 2.3 Outbound network

The host must reach Vox Pupuli package repos:

- EL: `yum.voxpupuli.org`
- Debian/Ubuntu: `apt.voxpupuli.org`

### 2.4 Install PostgreSQL yourself

The module’s `install_packages` task does **not** explicitly install
`postgresql`. Before Bolt runs, install and enable a PostgreSQL server that
provides the `postgresql` systemd unit and a `postgres` OS user (paths vary by
OS/version).

**What success looks like:**

```bash
systemctl is-active postgresql || systemctl is-active postgresql*.service
sudo -u postgres psql -c 'SELECT 1'
```

If this fails now, install will fail later when enabling PostgreSQL.

### 2.5 Optional: install r10k yourself

Only if you will pass `r10k_remote`. Example (adjust for your Ruby/policy):

```bash
# Example only — follow your org's r10k install standard
gem install r10k
mkdir -p /etc/puppetlabs/r10k
```

Confirm:

```bash
command -v r10k
r10k version
```

Private key parameters on the install plan are **dead**. Arrange Git SSH/HTTPS
auth yourself.

### 2.6 Root SSH from jump host

From the jump host:

```bash
ssh root@primary.example.com 'echo ok && hostname -f'
```

---

## 3. Install Bolt on the jump host

Supported by this module: Bolt **`>= 3.17.0` and `< 6.0.0`**.

1. Open the official guide:
   [Install and upgrade Bolt](https://help.puppet.com/bolt/current/topics/bolt_installing.htm)
2. Follow the section for your jump-host OS.
3. **Do not** pipe documentation HTML into a shell.

Verify:

```bash
bolt --version
```

If the version is 6.x or newer, this module’s assert will fail until the module
raises its upper bound.

---

## 4. Create a Bolt project and install openvox-adm from Git

```bash
mkdir -p ~/openvox-deploy
cd ~/openvox-deploy
bolt project init openvox-deploy
```

Edit `Puppetfile`:

```ruby
mod 'openvox-adm',
  :git => 'https://github.com/cvquesty/openvox-adm.git',
  :branch => 'development'
```

Also ensure any dependencies required by that module’s own `Puppetfile` /
metadata can be resolved (Bolt will fetch Forge deps declared by the module).

Install:

```bash
bolt puppetfile install
```

**Why Git?** The module is pre-Forge. Prefer
`https://github.com/cvquesty/openvox-adm.git` over
`bolt project init --modules openvox-adm` until publication is confirmed.

Verify the plan is visible:

```bash
bolt plan show openvoxadm::install
```

---

## 5. Write inventory.yaml

```yaml
---
groups:
  - name: openvox
    config:
      transport: ssh
      ssh:
        host-key-check: false
        user: root
        run-as: root
    targets:
      - primary.example.com
```

Replace the hostname with yours. For production, prefer known_hosts checking
instead of `host-key-check: false`.

Connectivity check:

```bash
bolt command run 'hostname -f && whoami' -t primary.example.com
```

**Success:** output shows your FQDN and `root` (or your run-as user).

---

## 6. Decide parameters

Minimum:

```json
{
  "primary_host": "primary.example.com",
  "version": "8.11.0"
}
```

Optional useful keys:

```json
{
  "primary_host": "primary.example.com",
  "version": "8.11.0",
  "dns_alt_names": ["puppet.example.com"],
  "r10k_remote": "git@github.com:yourorg/control-repo.git"
}
```

Do **not** pass XL-only hopes (`replica_host`, pool addresses) on a Standard
lab — they will not configure HA.

---

## 7. Pre-flight checklist (tick these)

- [ ] Bolt version in range
- [ ] `bolt plan show openvoxadm::install` works
- [ ] SSH to primary as root works
- [ ] PostgreSQL answers locally on primary
- [ ] Repos reachable (or proxy configured)
- [ ] No existing `/etc/puppetlabs/puppet/ssl` from an old install (or you
      accept wiping via uninstall first)
- [ ] If using r10k: binary present and Git auth works as root

---

## 8. Run the install plan

From the Bolt project directory:

```bash
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

With DNS alt names:

```bash
bolt plan run openvoxadm::install \
  --params '{
    "primary_host":"primary.example.com",
    "version":"8.11.0",
    "dns_alt_names":["puppet.example.com"]
  }'
```

### What you should see (conceptually)

1. Logged parameters / module version
2. Package installation on the primary
3. SSL bootstrap
4. Primary configure + targeted CA sign for the primary certname
5. OpenVoxDB database.ini / puppetdb.conf / allowlist write
6. Services enabled

**Success:** Bolt exits successfully (no failed tasks). Copy the console output
to your change ticket.

**If it fails:** do not re-run blindly. Check PostgreSQL, repo access, and
[troubleshooting.md](troubleshooting.md). You may need
`openvoxadm::uninstall` with `confirm => true` before a clean retry.

---

## 9. Verify packages (OS-specific expectations)

### 9.1 Status plan

```bash
bolt plan run openvoxadm::status --targets primary.example.com
```

Expect text including hostname, version, and active/stopped lines for
`openvox-server`, `openvoxdb`, and `postgresql`.

### 9.2 EL (yum path)

You should see OpenVox packages similar to:

```bash
rpm -qa | grep -E 'openvox|openvoxdb' | sort
```

Expect `openvox-server`, `openvox-agent`, `openvoxdb` at your pin.  
**Do not** expect `openbolt` or `openvoxdb-termini` on the yum install path —
the task does not install them there.

### 9.3 Debian/Ubuntu (apt path)

```bash
dpkg -l | grep -E 'openvox|openbolt' 
```

Apt path pins include `openbolt` and `openvoxdb-termini` in addition to agent,
server, and openvoxdb.

### 9.4 Services

```bash
systemctl is-active openvox-server
systemctl is-active openvoxdb
systemctl is-active postgresql
```

All should be `active` on a healthy Standard primary (given PostgreSQL was
installed in step 2.4).

---

## 10. Verify certificates

On the primary:

```bash
puppetserver ca list --all
ls /etc/puppetlabs/puppet/ssl/certs | head
```

The primary certname should already be signed by the plan. Pending entries are
normal for agents not yet enrolled.

Sign agents individually:

```bash
puppetserver ca sign --certname agent1.example.com
```

Avoid `sign --all` unless you intend to approve every pending request.

---

## 11. Optional r10k verification

If you passed `r10k_remote` and r10k was present:

```bash
cat /etc/puppetlabs/r10k/r10k.yaml
ls /etc/puppetlabs/code/environments
```

If you did **not** pass `r10k_remote`, skip this section — absence of r10k
config is expected.

---

## 12. Smoke-test OpenVoxDB connectivity (basic)

On the primary:

```bash
# local trust-auth style check (lab)
sudo -u postgres psql -c "\\du" | grep -i puppetdb || true
systemctl status openvoxdb --no-pager | head
```

Remember: auth is **trust** on localhost with empty password in
`database.ini`. See [security-notes.md](security-notes.md).

---

## 13. Take a backup before you enroll a fleet

```bash
bolt plan run openvoxadm::backup \
  --params '{"targets":"primary.example.com"}'
```

Confirm an archive under `/var/backups/openvox/` on the **primary**:

```bash
bolt command run 'ls -la /var/backups/openvox' -t primary.example.com
```

Read [backup_restore.md](backup_restore.md) before you need restore.

---

## 14. Enroll a first agent (outline)

1. Install `openvox-agent` on the agent host (out of scope for this runbook’s
   automation).
2. Point `server` at your primary (or dns_alt_name).
3. Run agent once; sign CSR on primary with `--certname`.
4. Re-run agent; confirm catalog apply.

---

## 15. What this runbook does *not* declare

- “Ready for production” — **Beta**, not a stability SLA
- Large/XL install — different docs and lower maturity
- Automatic compiler signing — not applicable on Standard
- Complete uninstall of every related package — see [uninstall.md](uninstall.md)

---

## 16. Abort / retry

Destructive cleanup:

```bash
bolt plan run openvoxadm::uninstall \
  --params '{"targets":"primary.example.com","confirm":true}'
```

Then re-check PostgreSQL still meets step 2.4, and return to step 8.

---

## Checklist summary

1. Prepare host + PostgreSQL (+ optional r10k)
2. Install Bolt (official docs, version in range)
3. Bolt project + Git module `cvquesty/openvox-adm`
4. Inventory + SSH proof
5. `openvoxadm::install` with `primary_host` + `version`
6. Verify status, packages, services, CA
7. Backup
8. Enroll agents carefully

You are done with Standard install when steps 9–10 look healthy and you have a
recovery tarball from step 13.

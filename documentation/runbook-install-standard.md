# Runbook: Standard OpenVox Install (Server + PuppetDB + r10k)

This runbook gives you a **painfully step-by-step** procedure to install a
working OpenVox Standard architecture (single server) from a completely
fresh Linux machine. Every command is spelled out. Copy, paste, press Enter.

> **Target audience:** Someone who has never installed OpenVox before and
> wants a working single-node server with OpenVoxDB and r10k configured.

---

## Prerequisites Checklist

Before you start, verify you have:

- [ ] One Linux server (RHEL 8/9, Rocky, AlmaLinux, Ubuntu 20.04+, Debian 11+)
- [ ] SSH access to that server as `root`
- [ ] A "jump host" (your laptop or another machine) with Bolt 3.17.0+ installed
- [ ] Internet access on both the target server and jump host
- [ ] The server's hostname is resolvable (or you know its IP)

---

## Step 1: Prepare the Jump Host

You run all the Bolt commands from your jump host (laptop, workstation, etc.).

### 1.1 Install Bolt (if not already installed)

**On macOS:**

```bash
brew install bolt
```

**On Linux (RHEL/Rocky/Alma):**

```bash
sudo rpm -Uvh https://yum.puppet.com/puppet7-release-el-$(rpm -E %rhel).noarch.rpm
sudo yum install -y puppet-bolt
```

**On Linux (Ubuntu/Debian):**

```bash
wget https://apt.puppet.com/puppet7-release-$(lsb_release -sc).deb
sudo dpkg -i puppet7-release-$(lsb_release -sc).deb
sudo apt-get update
sudo apt-get install -y puppet-bolt
```

### 1.2 Verify Bolt Version

```bash
bolt --version
```

You should see `3.17.0` or higher. If not, upgrade Bolt.

### 1.3 Create a Bolt Project Directory

```bash
mkdir -p ~/openvox-deploy
cd ~/openvox-deploy
```

### 1.4 Initialize the Bolt Project

```bash
bolt project init openvox-deploy --modules openvox-adm
```

This creates the following files:

- `bolt.yaml` — Bolt configuration
- `inventory.yaml` — target hosts (you will edit this)
- `Puppetfile` — module dependencies
- `.modules/` — where modules are installed

---

## Step 2: Configure the Inventory

### 2.1 Create or Edit inventory.yaml

Open `inventory.yaml` in your editor:

```bash
vim inventory.yaml
# or: nano inventory.yaml
```

Replace its contents with the following, changing `primary.example.com` to
your actual server hostname or IP address:

```yaml
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
```

> **If using an IP address:** Replace `primary.example.com` with the IP, e.g.,
> `10.0.1.50`.

### 2.2 Test SSH Connectivity

From your jump host, verify you can SSH to the target:

```bash
ssh root@primary.example.com hostname
```

You should see the target's hostname printed. If this fails, fix SSH access
before continuing.

---

## Step 3: Run the Install Plan

### 3.1 Execute the Install

Run this single command from your jump host, inside the `~/openvox-deploy`
directory:

```bash
bolt plan run openvoxadm::install \
  --params '{"primary_host":"primary.example.com","version":"8.11.0"}'
```

> **Replace `primary.example.com`** with your actual hostname or IP.

### 3.2 Watch the Output

The plan will print progress messages like:

```
Installing OpenVox 8.11.0 on cluster...
Installing openvox-release repo and packages...
Bootstrapping certificates on primary...
Configuring primary server...
Enabling OpenVoxDB on primary...
Configuring OpenVoxDB...
```

This may take 5–15 minutes depending on your server's speed and network.

### 3.3 Confirm Success

When the plan finishes, you should see something like:

```
{"status":"installed","hosts":["primary.example.com"]}
```

If you see an error, scroll up to find the failure message and check
[Troubleshooting](#troubleshooting) at the end of this runbook.

---

## Step 4: Verify the Installation

### 4.1 Check Status of All Services

Run the status plan:

```bash
bolt plan run openvoxadm::status --targets primary.example.com
```

Expected output (abbreviated):

```
primary.example.com:
  openvox-server: running
  openvoxdb: running
  postgresql: running
  version: 8.11.0
  certname: primary.example.com
  server: primary.example.com
  ca_server: primary.example.com
```

All three services (`openvox-server`, `openvoxdb`, `postgresql`) should show
`running`.

### 4.2 SSH to the Server and Verify Packages

```bash
ssh root@primary.example.com
```

Once connected:

```bash
rpm -qa | grep -E 'openvox|puppetdb'   # RHEL/Rocky/Alma
# or
dpkg -l | grep -E 'openvox|puppetdb'   # Debian/Ubuntu
```

You should see packages like:

```
openvox-server-8.11.0-...
openvox-agent-8.11.0-...
openvoxdb-8.11.0-...
openvoxdb-termini-8.11.0-...
openbolt-3.27.0-...
```

### 4.3 Check That the CA Is Working

```bash
puppetserver ca list --all
```

You should see at least one certificate (the primary's own cert) listed.

---

## Step 5: Install and Configure r10k

### 5.1 Install the r10k Gem

On the primary server:

```bash
ssh root@primary.example.com
gem install r10k
```

### 5.2 Create the r10k Configuration Directory

```bash
mkdir -p /etc/puppetlabs/r10k
```

### 5.3 Create r10k.yaml

Create `/etc/puppetlabs/r10k/r10k.yaml` with your control repo URL:

```bash
cat > /etc/puppetlabs/r10k/r10k.yaml << 'EOF'
---
:cachedir: '/opt/puppetlabs/puppet/cache/r10k'
:sources:
  :main:
    :remote: 'git@github.com:YOURORG/control-repo.git'
    :basedir: '/etc/puppetlabs/code/environments'
EOF
```

> **Replace the `:remote:` URL** with your actual control repository Git URL.
> If you don't have one yet, use a placeholder — you can change it later.

### 5.4 Generate an SSH Key for r10k (if using SSH Git)

```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ''
cat /root/.ssh/id_ed25519.pub
```

Copy the public key output and add it to your Git server's deploy keys or
your GitHub/GitLab SSH keys.

### 5.5 Deploy Environments

```bash
r10k deploy environment --puppetfile
```

This clones your control repo into `/etc/puppetlabs/code/environments/`
and installs any modules listed in the `Puppetfile`.

### 5.6 Verify Environments Exist

```bash
ls /etc/puppetlabs/code/environments/
```

You should see at least `production/` and possibly other branches you have
in your repo.

---

## Step 6: Sign Pending Certificates (If Any)

If any agents have already tried to connect, their certs may be pending:

```bash
puppetserver ca list
```

To sign all pending:

```bash
puppetserver ca sign --all
```

---

## Step 7: Test With an Agent

### 7.1 On a Test Node, Run the Agent

On any Linux machine (not the primary), install the openvox-agent and run:

```bash
# Install agent (example for RHEL)
curl -sL https://yum.voxpupuli.org/openvox8-release-el9.noarch.rpm -o /tmp/openvox-release.rpm
rpm -ivh /tmp/openvox-release.rpm
yum install -y openvox-agent

# Bootstrap (replace with your primary's hostname)
puppet ssl bootstrap --server primary.example.com --waitforcert 60
```

### 7.2 Sign the Agent Cert on the Primary

Back on the primary:

```bash
puppetserver ca list
puppetserver ca sign --certname <agent-hostname>
```

### 7.3 Run Puppet Agent on the Test Node

```bash
puppet agent -t --server primary.example.com
```

If you see "Notice: Applied catalog in X.XX seconds" with no errors, your
OpenVox server is fully working.

---

## Troubleshooting

### Bolt cannot connect via SSH

**Symptom:** `Permission denied (publickey,password)`

**Fix:**

```bash
ssh-copy-id root@primary.example.com
```

Then retry the plan.

### Services fail to start

**Symptom:** `openvox-server: stopped` or `openvoxdb: stopped`

**Fix:**

```bash
ssh root@primary.example.com
journalctl -u openvox-server -n 100 --no-pager
journalctl -u openvoxdb -n 100 --no-pager
```

Look for errors like missing certificates, database connection refused, or
port conflicts.

### r10k deploy fails

**Symptom:** `ERROR -> Unable to clone ...`

**Fix:**

- Verify your Git URL is correct.
- Ensure the SSH key is authorized on your Git server.
- For HTTPS URLs, ensure credentials are set up (or use SSH).

### Agents cannot reach the server

**Symptom:** `Error: Could not request certificate: ...`

**Fix:**

- Check DNS: `nslookup primary.example.com` from the agent.
- Check firewall: port 8140 must be open.
- Check the primary is listening: `ss -tlnp | grep 8140`.

---

## Summary Checklist

After completing this runbook, you should have:

- [ ] openvox-server running on primary
- [ ] openvoxdb (PuppetDB) running and connected to PostgreSQL
- [ ] r10k configured with your control repo
- [ ] Environments deployed under `/etc/puppetlabs/code/environments/`
- [ ] At least one agent able to run `puppet agent -t` successfully

**Congratulations!** Your Standard OpenVox cluster is ready for production use.

---

## Next Steps

- **Add compilers** for scale: see [expanding.md](expanding.md)
- **Set up backups**: see [backup_restore.md](backup_restore.md)
- **Check status regularly**: `bolt plan run openvoxadm::status --targets all`
- **Explore the docs**: [README](../README.md), [install.md](install.md)

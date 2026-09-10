# Checking status

**Plan:** `openvoxadm::status`  
**Task:** `openvoxadm::status`  
**Maturity:** Beta

---

## Purpose

Run a lightweight shell status task on each target and return Bolt task
results. Output is **free-form text**, not a structured per-host hash API.

---

## Parameters

| Name | Required | Notes |
|------|----------|-------|
| `targets` | yes | Any TargetSpec (one host, list, or group) |

---

## Example

```bash
bolt plan run openvoxadm::status --targets primary.example.com
```

```bash
bolt plan run openvoxadm::status --targets primary.example.com,compiler1.example.com,db.example.com
```

Using an inventory group:

```bash
bolt plan run openvoxadm::status --targets openvox
```

---

## What the task prints (reality)

On **every** host it typically echoes:

- Hostname
- `openvox --version` with fallback to `puppet --version`
- Active state checks for **`openvox-server`**, **`openvoxdb`**, and
  **`postgresql`**
- Selected puppet settings such as certname / server / ca_server

### Interpreting compilers and slim roles

Compilers usually **do not** run OpenVoxDB or PostgreSQL. The task still
reports those units as **stopped** (or inactive). That is expected.

Older docs that showed “(not applicable)” were aspirational — the task does
**not** print N/A.

| Role | openvox-server | openvoxdb | postgresql |
|------|----------------|-----------|------------|
| Standard primary | active | active | active |
| Compiler | active | often stopped | often stopped |
| Dedicated DB host | often stopped | active | active |

Use role knowledge when reading the text; do not treat every “stopped” as an
incident.

---

## What success looks like

1. Bolt can SSH to each target
2. Version strings look like your intended 8.x pin
3. Services that **should** run on that role are active
4. Certname/server settings match your architecture

---

## What can go wrong

- Unreachable hosts → Bolt connection errors
- Partial installs → missing version command / inactive units
- Misleading “unhealthy compiler” conclusions from stopped DB units

---

## Related

- [troubleshooting.md](troubleshooting.md)
- [concepts.md](concepts.md)

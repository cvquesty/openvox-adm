# Expanding an OpenVox Cluster

Use these plans to add components to an existing cluster.

## Add Compilers

```bash
bolt plan run openvoxadm::add_compilers \
  --params '{"compiler_hosts":["compiler3.example.com"],"primary_host":"primary.example.com","avail_group_letter":"A"}'
```

## Add Database

```bash
bolt plan run openvoxadm::add_database \
  --params '{"targets":"db2.example.com","primary_host":"primary.example.com","mode":"init"}'
```

## Add Replica

```bash
bolt plan run openvoxadm::add_replica \
  --params '{"primary_host":"primary.example.com","replica_host":"replica.example.com"}'
```

## Availability Groups

When adding compilers to an HA setup, specify `avail_group_letter`:
- `A`: Primary availability group
- `B`: Replica availability group

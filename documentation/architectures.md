# OpenVox Architectures

openvox-adm supports the following deployment architectures.

## Standard

Single primary server running:
- openvox-server (CA, catalog compilation, r10k)
- openvoxdb + PostgreSQL (co-located)

Best for: < 500 nodes

## Large

- Primary server (openvox-server, r10k)
- Compilers (2+, openvox-server with `ca=false`)
- Dedicated PostgreSQL + OpenVoxDB host
- Optional load balancer (HAProxy) in front of compilers

Best for: 500-5000 nodes

## Extra Large (with HA)

- Primary + Replica servers (A/B availability groups)
- Compilers in A/B pools
- Dedicated PostgreSQL (A) + Replica PostgreSQL (B)
- OpenVoxDB on each PostgreSQL host
- Load balancer

Best for: > 5000 nodes, HA requirements

## Availability Groups

For HA setups, components are assigned to group A or B:
- Primary: A
- Replica: B
- Compilers: split between A and B
- PostgreSQL: A (primary DB), B (replica DB)

This allows failover scenarios where group B can serve if A fails.

# Checking Cluster Status

```bash
bolt plan run openvoxadm::status --targets all
```

This checks:
- Service status (openvox-server, openvoxdb, postgresql)
- OpenVox version
- Puppet configuration (certname, server, ca_server)
- Hostname

## Individual Checks

```bash
# Check specific host
bolt plan run openvoxadm::status --targets primary.example.com

# Check all compilers
bolt plan run openvoxadm::status --targets compiler1.example.com,compiler2.example.com
```

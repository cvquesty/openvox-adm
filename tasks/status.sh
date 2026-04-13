#!/bin/bash
set -e

echo "=== OpenVox Status ==="
echo "Hostname: $(hostname)"
echo "OpenVox version: $(openvox --version 2>/dev/null || puppet --version)"
echo ""

echo "Services:"
systemctl is-active --quiet openvox-server && echo "  openvox-server: running" || echo "  openvox-server: stopped"
systemctl is-active --quiet openvoxdb && echo "  openvoxdb: running" || echo "  openvoxdb: stopped"
systemctl is-active --quiet postgresql && echo "  postgresql: running" || echo "  postgresql: stopped"

echo ""
echo "Puppet certname: $(puppet config print certname)"
echo "Puppet server: $(puppet config print server)"
echo "CA server: $(puppet config print ca_server)"
exit 0

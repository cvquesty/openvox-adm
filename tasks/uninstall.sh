#!/bin/bash
set -e

echo "Stopping OpenVox services..."
systemctl stop openvox-server openvoxdb postgresql 2>/dev/null || true

echo "Removing packages..."
if command -v yum &>/dev/null; then
  yum remove -y openvox-server openvox-agent openvoxdb
elif command -v apt-get &>/dev/null; then
  apt-get purge -y openvox-server openvox-agent openvoxdb
fi

echo "Removing data directories..."
rm -rf /etc/puppetlabs/puppet/ssl
rm -rf /opt/puppetlabs/server/data/puppetdb
rm -rf /etc/puppetlabs/code/environments/*

echo "OpenVox uninstalled."
exit 0

#!/bin/bash
# Install OpenVox packages
set -e

VERSION="${PT_version:-8.11.0}"
OS_FAMILY=$(facter os.family)
OS_RELEASE=$(facter os.release.major)

echo "Installing OpenVox ${VERSION} on ${OS_FAMILY} ${OS_RELEASE}..."

# Detect OS and install appropriate repo
if [ "$OS_FAMILY" = "RedHat" ] || [ "$OS_FAMILY" = "CentOS" ] || [ "$OS_FAMILY" = "Rocky" ] || [ "$OS_FAMILY" = "AlmaLinux" ]; then
  # RHEL-family
  if [ ! -f /etc/yum.repos.d/openvox8-release.repo ]; then
    curl -sL "https://yum.voxpupuli.org/openvox8-release-el${OS_RELEASE}.noarch.rpm" -o /tmp/openvox-release.rpm
    rpm -ivh /tmp/openvox-release.rpm
  fi
  yum install -y openvox-server openvox-agent openvoxdb
elif [ "$OS_FAMILY" = "Debian" ] || [ "$OS_FAMILY" = "Ubuntu" ]; then
  # Debian/Ubuntu
  if [ ! -f /etc/apt/sources.list.d/openvox.list ]; then
    curl -sL "https://apt.voxpupuli.org/openvox8-release-${OS_RELEASE}.deb" -o /tmp/openvox-release.deb
    dpkg -i /tmp/openvox-release.deb
    apt-get update
  fi
  apt-get install -y openvox-server openvox-agent openvoxdb
else
  echo "Unsupported OS: ${OS_FAMILY}"
  exit 1
fi

echo "OpenVox packages installed successfully."
exit 0

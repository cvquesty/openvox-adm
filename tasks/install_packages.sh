#!/bin/bash
# Install OpenVox packages
set -euo pipefail

VERSION="${PT_version:-8.11.0}"
OS_FAMILY=$(facter os.family)
OS_RELEASE=$(facter os.release.major)

echo "Installing OpenVox ${VERSION} on ${OS_FAMILY} ${OS_RELEASE}..."

# Detect OS and install appropriate repo
if [ "$OS_FAMILY" = "RedHat" ] || [ "$OS_FAMILY" = "CentOS" ] || [ "$OS_FAMILY" = "Rocky" ] || [ "$OS_FAMILY" = "AlmaLinux" ]; then
  # RHEL-family
  if [ ! -f /etc/yum.repos.d/openvox8-release.repo ]; then
    curl --fail -sL "https://yum.voxpupuli.org/openvox8-release-el${OS_RELEASE}.noarch.rpm" -o /tmp/openvox-release.rpm
    rpm -ivh /tmp/openvox-release.rpm
  fi
  yum install -y \
    "openvox-server-${VERSION}" \
    "openvox-agent-${VERSION}" \
    "openvoxdb-${VERSION}"
elif [ "$OS_FAMILY" = "Debian" ] || [ "$OS_FAMILY" = "Ubuntu" ]; then
  # Debian/Ubuntu — map major release to codename when facter returns a number
  case "${OS_RELEASE}" in
    20.04|20) CODENAME="focal" ;;
    22.04|22) CODENAME="jammy" ;;
    24.04|24) CODENAME="noble" ;;
    *) CODENAME="${OS_RELEASE}" ;;
  esac
  if [ ! -f /etc/apt/sources.list.d/openvox.list ] && [ ! -f /etc/apt/sources.list.d/openvox8-release.list ]; then
    curl --fail -sL "https://apt.voxpupuli.org/openvox8-release-${CODENAME}.deb" -o /tmp/openvox-release.deb
    dpkg -i /tmp/openvox-release.deb
    apt-get update
  fi
  apt-get install -y \
    "openbolt=${VERSION}*" \
    "openvox-agent=${VERSION}*" \
    "openvox-server=${VERSION}*" \
    "openvoxdb=${VERSION}*" \
    "openvoxdb-termini=${VERSION}*"
else
  echo "Unsupported OS: ${OS_FAMILY}"
  exit 1
fi

echo "OpenVox packages installed successfully."
exit 0

#!/usr/bin/env bash
set -euo pipefail

# Wine needs i386 packages
if ! dpkg --print-foreign-architectures | grep -qx i386; then
  sudo dpkg --add-architecture i386
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# install_deb <package> <url>
install_deb() {
  if dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'; then
    return
  fi
  curl -fL --retry 3 -o "$tmp/$1.deb" "$2"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp/$1.deb"
}

# Both packages add their own apt repository, so `apt upgrade` updates them.
install_deb google-chrome-stable \
  'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
install_deb code \
  'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'

# QNAP Qfinder Pro (no apt repository)
if ! dpkg-query -W -f='${Status}' qfinderpro 2>/dev/null | grep -q 'ok installed'; then
  curl -fsSL -o "$tmp/release.xml" 'https://eu1.qnap.com/Liveupdate/SoftwareRelease.xml'
  url="$(grep -oEm1 'https?://[^"<]+/QNAPQfinderProUbuntux64[^"<]+\.deb' "$tmp/release.xml")"
  curl -fL --retry 3 -o "$tmp/qfinder.deb" "$url"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp/qfinder.deb"
fi

#!/usr/bin/env bash

# Bootstrap script for Ubuntu 25.04 (plucky)
# Handles system-level setup that home-manager cannot perform.
#
# Usage:
#   ./bootstrap.sh
#
# After completion, home-manager switch is run automatically.
# A reboot is triggered at the end.

set -eux

IS_DESKTOP="$(apt list --installed 2>/dev/null | grep ubuntu-desktop -q && echo true || :)"

is_desktop() { [[ "$IS_DESKTOP" = true ]]; }

cd ~
mkdir -p .config .gnupg prog Games _setup
pushd _setup

if ! [[ -f ~/.sec.key ]]; then
  echo "need: ~/.sec.key"
  exit 1
fi

is_desktop && gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'

# apt system packages

sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  curl ca-certificates git gnupg2 \
  network-manager-l2tp pass \
  pinentry-tty pkg-config zsh uidmap \
sudo install -m 0755 -d /etc/apt/keyrings

[[ "$SHELL" = "$(which zsh)" ]] || sudo chsh -s "$(which zsh)" "$USER"

is_desktop && sudo apt install -y \
  alsa-utils ibus-mozc \
  network-manager-l2tp-gnome

# mozc / ibus

is_desktop && {
  ibus restart
  gsettings set org.gnome.desktop.input-sources sources \
    "[('xkb', 'jp'), ('ibus', 'mozc-jp')]"
}

# Docker

if command -v wsl.exe &>/dev/null; then
  powershell.exe /c winget.exe install Docker.DockerDesktop || :
fi

# QNAP Qfinder (desktop)

is_desktop && {
  curl -s 'https://www.qnap.com/ja-jp/utilities/essentials' |
    grep -oEm1 'https://[^"]+/QNAPQfinderProUbuntux64[^"]+\.deb' | xargs wget
  sudo apt install ./QNAPQfinderProUbuntux64*.deb -y
}

# GPG key import

gpg --list-keys | grep -qE '^ *EE3A' || {
  export GPG_TTY="$(tty)"
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  touch ~/.gnupg/sshcontrol
  chmod 600 ~/.gnupg/*
  chmod 700 ~/.gnupg
  gpgconf --kill gpg-agent
  sleep 3s
  cat ~/.sec.key | gpg --allow-secret-key --import
  gpg --list-key --with-keygrip | grep -FA1 '[SA]' |
    awk -F 'Keygrip = ' '$0=$2' > ~/.gnupg/sshcontrol
  pass init "$(gpg --with-colons --list-keys | awk -F: '$1=="fpr"{print$10;exit}')"
  gpg-connect-agent updatestartuptty /bye
}

# Nix

if ! command -v nix &>/dev/null; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
  # shellcheck disable=SC1091
  . /etc/profile.d/nix.sh
fi

# Enable flakes
mkdir -p ~/.config/nix
grep -qF 'experimental-features' ~/.config/nix/nix.conf 2>/dev/null ||
  echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# home-manager switch

PROFILE="eggplants$(is_desktop && echo '-desktop' || true)"
nix run home-manager/master -- switch --flake ".#${PROFILE}"

# Run `mise install` to pull language runtimes defined in globalConfig
# (mise itself is installed by home-manager)
export PATH="$HOME/.local/bin:$PATH"
mise install || true

# Cleanup

sudo apt autoremove -y
sudo apt autoclean -y

rm ~/.sec.key
popd
rm -rf _setup

is_desktop && gsettings set org.gnome.desktop.lockdown disable-lock-screen 'false'

echo "Done! Should be reboot."

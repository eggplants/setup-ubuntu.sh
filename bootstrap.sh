#!/usr/bin/env bash

set -eux

if ! [[ -f ~/.sec.key ]]; then
  echo "Not found: ~/.sec.key"
  exit 1
fi

if ! apt list --installed 2>/dev/null | grep ubuntu-desktop -q; then
  echo "This script is only for Ubuntu Desktop."
  exit 1
fi

mkdir -p "$HOME"/{.config/home-manager,.gnupg,prog,Games}

gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'

# mozc / ibus

ibus restart
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'jp'), ('ibus', 'mozc-jp')]"

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

nix run home-manager/master -- switch --flake '.#eggplants-desktop'

# Run `mise install` to pull language runtimes defined in globalConfig
# (mise itself is installed by home-manager)
export PATH="$HOME/.local/bin:$PATH"
mise install || true

rm ~/.sec.key

gsettings set org.gnome.desktop.lockdown disable-lock-screen 'false'

echo "Done! Should be reboot."

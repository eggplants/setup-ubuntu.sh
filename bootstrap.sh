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

# wine / winetricks (installed via apt; nix wine is currently broken)
CODENAME="$(lsb_release -c | cut -f2)"
sudo dpkg --add-architecture i386
sudo apt install -y libfaudio0
wget -qO- https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor > k
sudo install -D -o root -g root -m 644 k /etc/apt/keyrings/winehq-archive.key
rm k
sudo wget -NP /etc/apt/sources.list.d/ \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/${CODENAME}/winehq-${CODENAME}.sources"
sudo apt update
sudo apt install -y --install-recommends winehq-devel winetricks
if ! [[ -d ~/.wine ]]; then
  WINEARCH=wow64 wineboot --init
  for i in allfonts gmdls dmsynth directmusic dsound devenum fakejapanese_ipamona; do
    winetricks -q "$i"
  done
  wine reg add \
    "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\RPG_RT.exe\\X11 Driver" \
    /v ClientSideWithRender /t REG_SZ /d N
  wget https://tkool.jp/products/rtp/2000rtp.zip
  unzip -O sjis -j 2000rtp.zip "*.exe"
  wine RPG2000RTP.exe
  rm RPG2000RTP.exe 2000rtp.zip
fi

# Ubuntu 24.04+ restricts unprivileged user namespaces via AppArmor, which breaks rootless Docker
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system

# Run `mise install` to pull language runtimes defined in globalConfig
# (mise itself is installed by home-manager)
export PATH="$HOME/.local/bin:$PATH"
mise trust -ay
mise install || true

rm ~/.sec.key

echo "Done! Should be reboot."

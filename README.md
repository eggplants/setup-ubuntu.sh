# My setup script for Ubuntu

A setup script for Ubuntu 25.04 (plucky) using **Nix home-manager** for user-level config and a thin bootstrap script for system-level setup.

## Run

Clone this repo to `~/.config/home-manager/`, then run:

```bash
git clone https://github.com/eggplants/setup-ubuntu.sh ~/.config/home-manager
cd ~/.config/home-manager

# Place your GPG secret key at ~/.sec.key, then:
./bootstrap.sh
```

`bootstrap.sh` runs `home-manager switch --flake .` from `~/.config/home-manager/`, so `flake.nix` and `home.nix` must be present there. The directory is kept after bootstrap for ongoing maintenance.

## Update home-manager config

Edit `home.nix` in `~/.config/home-manager/`, then:

```bash
cd ~/.config/home-manager

# headless
home-manager switch --flake .#eggplants

# desktop
home-manager switch --flake .#eggplants-desktop
```

## What goes where

| Concern | File |
|---|---|
| System apt packages, Docker, GPG import, Wine, Ghostty, GNOME extensions | `bootstrap.sh` |
| Packages (nixpkgs), git, zsh, gpg-agent, nano, mise, VSCode | `home.nix` |
| Nix inputs & profile names | `flake.nix` |

The legacy `setup-ubuntu.sh` is kept as reference.

## Family

- [eggplants/setup-macos.sh](https://github.com/eggplants/setup-macos.sh)
- [eggplants/setup-termux.sh](https://github.com/eggplants/setup-termux.sh)
- [eggplants/setup-ubuntu.sh](https://github.com/eggplants/setup-ubuntu.sh) <- here
- [eggplants/SetupWindows.ps1](https://github.com/eggplants/SetupWindows.ps1)

# My setup script for Ubuntu

A setup script for Ubuntu 26.04

## Run

```bash
sudo apt install -y git

git clone https://github.com/eggplants/setup-ubuntu.sh ~/.config/home-manager
cd ~/.config/home-manager

# Place your GPG secret key at ~/.sec.key, then:
./bootstrap.sh
```

## Update home-manager config

Edit `home.nix` in `~/.config/home-manager/`, then:

```bash
cd ~/.config/home-manager

# headless
home-manager switch --flake '.#eggplants'

# desktop
home-manager switch --flake '.#eggplants-desktop'
```

## Family

- [eggplants/setup-macos.sh](https://github.com/eggplants/setup-macos.sh)
- [eggplants/setup-termux.sh](https://github.com/eggplants/setup-termux.sh)
- [eggplants/setup-ubuntu.sh](https://github.com/eggplants/setup-ubuntu.sh) <- here
- [eggplants/SetupWindows.ps1](https://github.com/eggplants/SetupWindows.ps1)

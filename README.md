# My setup for Ubuntu Desktop

## Run

After install Ubuntu Desktop with [`autoinstall.yaml`](./autoinstall.yaml):

```bash
git clone https://github.com/eggplants/setup-ubuntu.sh ~/.config/home-manager
cd ~/.config/home-manager

# Place your GPG secret key at ~/.sec.key, then:
./bootstrap.sh
```

## Update home-manager config

Edit `home.nix` in `~/.config/home-manager/`, then:

```bash
cd ~/.config/home-manager
home-manager switch --flake '.#eggplants-desktop'
```

## Legacy

For Ubuntu 25.04 / 26.04: [`setup.ubuntu.sh`](./setup-ubuntu.sh)

## Family

- [eggplants/setup-macos.sh](https://github.com/eggplants/setup-macos.sh)
- [eggplants/setup-termux.sh](https://github.com/eggplants/setup-termux.sh)
- [eggplants/setup-ubuntu.sh](https://github.com/eggplants/setup-ubuntu.sh) <- here
- [eggplants/SetupWindows.ps1](https://github.com/eggplants/SetupWindows.ps1)

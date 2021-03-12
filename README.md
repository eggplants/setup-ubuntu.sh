# My setup for Ubuntu Desktop

[![Validate autoinstall.yaml](https://github.com/eggplants/setup-ubuntu.sh/actions/workflows/validate-autoinstall.yml/badge.svg)](https://github.com/eggplants/setup-ubuntu.sh/actions/workflows/validate-autoinstall.yml)

## Run

Install [Ubuntu Desktop](https://ubuntu.com/download/desktop) with [`autoinstall.yaml`](./autoinstall.yaml)
- <https://egpl.dev/setup-ubuntu.sh/autoinstall.yaml>

Ref:
- <https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html>
- <https://raw.githubusercontent.com/canonical/subiquity/refs/heads/main/autoinstall-schema.json>

After restarted:

```bash
# Place your GPG secret key at ~/.sec.key, then:
cd ~/.config/home-manager && ./bootstrap.sh
```

## Update home-manager config

Edit `home.nix` in `~/.config/home-manager/`, then:

```bash
hms
```

## Legacy

For Ubuntu 25.04 / 26.04: [`setup.ubuntu.sh`](./setup-ubuntu.sh)

## Family

- [eggplants/setup-macos.sh](https://github.com/eggplants/setup-macos.sh)
- [eggplants/setup-termux.sh](https://github.com/eggplants/setup-termux.sh)
- [eggplants/setup-ubuntu.sh](https://github.com/eggplants/setup-ubuntu.sh) <- here
- [eggplants/SetupWindows.ps1](https://github.com/eggplants/SetupWindows.ps1)

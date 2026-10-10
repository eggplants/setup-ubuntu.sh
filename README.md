# My setup for Ubuntu Desktop

[![Validate autoinstall.yaml](https://github.com/eggplants/setup-ubuntu.sh/actions/workflows/validate-autoinstall.yml/badge.svg)](https://github.com/eggplants/setup-ubuntu.sh/actions/workflows/validate-autoinstall.yml)

## Run

Install [Ubuntu Desktop](https://ubuntu.com/download/desktop) with [`autoinstall.yaml`](./docs/autoinstall.yaml)
- <https://egpl.dev/setup-ubuntu.sh/autoinstall.yaml>

Ref:
- <https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html>
- <https://raw.githubusercontent.com/canonical/subiquity/refs/heads/main/autoinstall-schema.json>

`autoinstall.yaml` only installs `curl`/`git`, [mise](https://mise.jdx.dev), and clones this
repository as `~/.config/mise`. Everything else is declared in the mise config
([`mise bootstrap`](https://mise.jdx.dev/bootstrap.html) / [dotfiles](https://mise.jdx.dev/dotfiles.html)).

After restarted:

```bash
# Place your GPG secret key at ~/.sec.key, then:
~/.config/mise/bootstrap.sh
```

## Update

```bash
mise bootstrap --dry-run
mise bootstrap
mise bootstrap --update
mise bootstrap status
```

## Family

- [eggplants/setup-macos.sh](https://github.com/eggplants/setup-macos.sh)
- [eggplants/setup-termux.sh](https://github.com/eggplants/setup-termux.sh)
- [eggplants/setup-ubuntu.sh](https://github.com/eggplants/setup-ubuntu.sh) <- here
- [eggplants/SetupWindows.ps1](https://github.com/eggplants/SetupWindows.ps1)

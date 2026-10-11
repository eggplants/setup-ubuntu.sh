# AGENTS.md

## What this repo is

The global [mise](https://mise.jdx.dev) config for an Ubuntu Desktop machine. It is cloned as `~/.config/mise`, and `mise bootstrap` sets the machine up from it: apt packages, system files, CLI tools, dotfiles, login shell, and a few imperative steps. `docs/autoinstall.yaml` installs only the minimum needed to get there.

## Apply the config

```bash
mise bootstrap --dry-run   # preview
mise bootstrap             # apply (zsh alias: mb)
```

The desktop module (`config.desktop.toml`) loads only when the `desktop` env is active: `env = ["desktop"]` in `~/.config/mise/miserc.local.toml` (gitignored, written by `bootstrap.sh` on Ubuntu Desktop) or `mise -E desktop ...`. Without it, the config is headless.

## Validate `autoinstall.yaml`

```bash
mise run autoinstall:validate   # run inside a checkout of this repo
```

## Architecture

| File | Purpose |
|------|---------|
| `config.toml` | `[tools]`, `[bootstrap.packages]` (apt), Docker apt repo, `[bootstrap.repos]` (zsh plugins, nano syntax), `[dotfiles]`, shell activation, login shell, `bootstrap` task |
| `config.desktop.toml` | Desktop module: GUI apt packages, WineHQ repo, vendor `.deb` hook, Ghostty/Wine dotfiles, TiMidity user unit |
| `dotfiles/` | `[dotfiles]` sources (symlinked unless the entry says otherwise) |
| `files/apt/` | Vendor apt signing keys (Docker, WineHQ) |
| `files/dconf/desktop.ini` | GNOME settings, loaded by `setup:desktop` |
| `tasks/setup/` | File tasks run by the `bootstrap` task: `gpg`, `git`, `docker`, `claude`, `desktop` |
| `scripts/install-vendor-debs.sh` | Desktop `pre-packages` hook: i386 arch, Chrome / VSCode / Qfinder `.deb` |
| `bootstrap.sh` | Installs mise, clones this repo, writes `miserc.local.toml`, runs `mise bootstrap` |
| `docs/autoinstall.yaml` | Ubuntu unattended-install seed file (served via GitHub Pages) |

### Key design decisions

- **Repo = global config** — relative `source` paths in `[dotfiles]` / `[bootstrap.files]` resolve from `~/.config/mise`. Tools in `[tools]` are global.
- **Declarative first, tasks for the rest** — use `[bootstrap.*]` / `[dotfiles]` when mise can check the state. Hooks and the `bootstrap` task run on every `mise bootstrap`, so they must be idempotent (guard every step).
- **apt vs mise tools** — system libraries, media tools, and GUI apps come from apt; language runtimes and dev CLIs come from `[tools]`. `pipx:` tools need `uv` in `[tools]`.
- **Vendor apt repos** — Docker and WineHQ: key + deb822 `.sources` in `[bootstrap.files]` with `phase = "pre-packages"`; the codename is rendered with `exec()`. Chrome and VSCode: installed from their `.deb` by the hook, because those packages write their own apt repo (declaring it ourselves would conflict on `Signed-By`).
- **Git config** — `dotfiles/gitconfig` is static; `user.email` / `user.signingkey` are derived from the GPG keyring and written to `~/.gitconfig.local` by `setup:git`.
- **Shell** — `~/.zshrc` / `~/.zshenv` are whole-file dotfiles, so `~/.zshrc` activates mise itself; `[bootstrap.mise_shell_activate]` only writes shims into `~/.zprofile` / bash files.
- **Wine/RPG2000 setup** — an XDG autostart `.desktop` entry (not a systemd unit), so the blocking GUI installer runs on the first graphical login, never during `mise bootstrap`.
- **Docker (rootless)** — the rootful `docker`/`docker.socket` system units are declared stopped and disabled; `setup:docker` runs `dockerd-rootless-setuptool.sh install`. `DOCKER_HOST` is set in `dotfiles/zshenv`.
- **GNOME settings** — `setup:desktop` runs `dconf load` only when a D-Bus session exists; re-run `mise run setup:desktop` from a graphical login if it was skipped.

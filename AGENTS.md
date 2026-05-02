# AGENTS.md

## What this repo is

Nix [Home Manager](https://github.com/nix-community/home-manager) configuration for an Ubuntu Desktop machine. Everything lives in `home.nix`; `flake.nix` wires up inputs and exposes two named configurations.

## Apply the config

```bash
hms   # alias for: home-manager switch --flake ~/.config/home-manager#eggplants-desktop
```

Use `#eggplants` (no `-desktop`) for a headless/server target — it skips GUI packages, GNOME settings, Wine, Ghostty, and VSCode.

## Validate `autoinstall.yaml`

```bash
mise run validate-autoinstall
# or directly:
docker run --rm -it -v ./docs/autoinstall.yaml:/autoinstall.yaml \
  ghcr.io/eggplants/validate-ubuntu-autoinstall-docker /autoinstall.yaml -v
```

## Architecture

| File | Purpose |
|------|---------|
| `flake.nix` | Declares inputs (`nixpkgs-unstable`, `home-manager`, `nixGL`) and the two `homeConfigurations` |
| `home.nix` | Single module; receives `isDesktop` and `nixgl` as `extraSpecialArgs` |
| `bootstrap.sh` | One-shot provisioner: imports GPG key, installs Nix + flakes, runs `home-manager switch`, installs Wine via apt, and runs `mise install` |
| `docs/autoinstall.yaml` | Ubuntu unattended-install seed file |
| `mise.toml` | Dev tools (`claude`, `pinact`, `dockerfile-pin`) and task definitions |

### Key design decisions in `home.nix`

- **`isDesktop` guard** — nearly all GUI-only config (packages, GNOME/dconf, Wine, Ghostty, VSCode, fonts) is gated with `lib.mkIf isDesktop`. Headless builds should never enable these.
- **nixGL wrapping** — `config.lib.nixGL.wrap` is required for any GPU-accelerated app installed from Nix on non-NixOS (Ghostty, Chrome, VSCode). The wrapper is set to `mesa`.
- **Git config via activation** — `home.activation.gitConfig` / `gitFromGpg` write to `~/.gitconfig` at activation time (not via `programs.git.extraConfig`) because the signing key and email are derived dynamically from the live GPG keyring.
- **Wine/RPG2000 setup** — uses an XDG autostart `.desktop` entry (not a systemd unit) so the blocking GUI installer never runs during `hms`.
- **Docker (rootless)** — daemon runs as `systemd.user.services.docker`; `DOCKER_HOST` is set via `home.sessionVariables`.
- **GNOME dconf bootstrap** — a one-shot `apply-gnome-defaults` systemd user service applies dconf defaults on first graphical login, working around the fact that `hms` during bootstrap has no D-Bus session.

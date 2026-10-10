#!/usr/bin/env bash
set -euo pipefail

repo='https://github.com/eggplants/setup-ubuntu.sh.git'
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mise"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh
fi

if [[ ! -d "$config_dir/.git" ]]; then
  git clone "$repo" "$config_dir"
fi

if [[ ! -f "$config_dir/miserc.local.toml" ]] &&
  dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q 'ok installed'; then
  echo 'env = ["desktop"]' > "$config_dir/miserc.local.toml"
fi

mise bootstrap "$@"

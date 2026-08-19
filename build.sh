#!/usr/bin/env bash
# Build (or run/clean) the ESPHome firmware using a local uv project - no global
# python/pip involved (see the README's "Python Dependency management" section).
#
# Usage:
#   ./build.sh              # compile only (default)
#   ./build.sh compile
#   ./build.sh run           # compile + flash (first flash must be over USB)
#   ./build.sh clean         # clear the remote package cache, then compile
#   ./build.sh config        # validate the YAML only (as pushed to GitHub)
#   ./build.sh local         # validate the WORKING TREE's base/**.yaml (before pushing)
#
# Any extra arguments are passed through to esphome, e.g.:
#   ./build.sh run --device /dev/ttyACM0

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

CONFIG_FILE="guition-va.yaml"
ACTION="${1:-compile}"
if [[ $# -gt 0 ]]; then
    shift
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "error: uv is not installed. See https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
fi

# Keep the project venv (with esphome) up to date without touching global python.
uv sync --quiet

# uv-managed standalone CPython bundles ensurepip/venv, unlike Debian's system python3
# (which needs the separate python3-venv apt package). ESP-IDF's own internal venv
# creation needs this, and ESPHome's get_system_python_path() honors PYTHONEXEPATH.
uv python install --quiet 3.12
export PYTHONEXEPATH
PYTHONEXEPATH="$(uv python find --python-preference only-managed 3.12)"

# base/**.yaml is pulled from GitHub at compile time, so `config` validates the pushed
# copy. `local` swaps that for !includes of the working tree - use it before pushing.
if [[ "$ACTION" == "local" ]]; then
    uv run python scripts/gen_local_config.py
    exec uv run esphome config validate-local.yaml "$@"
fi

if [[ "$ACTION" == "clean" ]]; then
    uv run esphome clean "$CONFIG_FILE"
    exec uv run esphome compile "$CONFIG_FILE" "$@"
fi

exec uv run esphome "$ACTION" "$CONFIG_FILE" "$@"

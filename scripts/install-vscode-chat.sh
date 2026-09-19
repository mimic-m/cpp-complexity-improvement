#!/usr/bin/env bash
set -euo pipefail

# Entry point for VS Code Chat or a VS Code task.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf '[install-vscode-chat] Installing the C/C++ quality skill\n'
exec bash "$ROOT_DIR/scripts/install-codex.sh" "$@"
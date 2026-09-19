#!/usr/bin/env bash
set -euo pipefail

plugin="${1:?usage: run-tests.sh <plugin> [clang-tidy]}"
clang_tidy="${2:-clang-tidy}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v "$clang_tidy" >/dev/null 2>&1; then
  echo "clang-tidy is required to run custom-check tests" >&2
  exit 2
fi

run_case() {
  local file="$1"
  local expected="$2"
  local output
  set +e
  output="$($clang_tidy -load "$plugin" -checks=-*,company-internal-comments \
    -config='{CheckOptions: [{key: company-internal-comments.BooleanOperatorThreshold, value: "1"}]}' \
    "$root/cases/$file" 2>&1)"
  local status=$?
  set -e
  local count
  count="$(printf '%s\n' "$output" | grep -c 'company-internal-comments' || true)"
  if [[ "$count" != "$expected" || ( "$expected" == "0" && "$status" != "0" ) ]]; then
    printf '%s\n' "$output"
    echo "Expected $expected diagnostics in $file, got $count" >&2
    exit 1
  fi
}

run_case pass.cpp 0
run_case fail.cpp 7
echo "company-internal-comments tests passed"

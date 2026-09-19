#!/usr/bin/env bash
set -euo pipefail

: "${BUILD_COMMAND:?Set BUILD_COMMAND to the repository build command}"
: "${TEST_COMMAND:?Set TEST_COMMAND to the repository unit-test command}"
: "${CLANG_TIDY_COMMAND:?Set CLANG_TIDY_COMMAND to the repository clang-tidy command}"

run_phase() {
  local name="$1"
  local command="$2"
  printf '\n=== %s ===\n' "$name"
  bash -lc "$command"
}

run_phase "Build" "$BUILD_COMMAND"
run_phase "Unit Test" "$TEST_COMMAND"
run_phase "clang-tidy" "$CLANG_TIDY_COMMAND"
printf '\n=== Quality check completed ===\n'

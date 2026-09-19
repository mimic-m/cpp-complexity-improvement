#!/usr/bin/env bash
set -euo pipefail

# Installs the dependencies needed to build and test this quality skill in Codex.
# Set PREFIX to install user-local tools without root privileges.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/custom-check}"
LLVM_VERSION="${LLVM_VERSION:-}"

log() {
  printf '[install-codex] %s\n' "$*"
}

fail() {
  printf '[install-codex] ERROR: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_apt_dependencies() {
  local apt_get="apt-get"
  if [[ "$(id -u)" -ne 0 ]]; then
    command_exists sudo || fail "apt-get requires root or sudo"
    apt_get="sudo apt-get"
  fi

  local llvm_packages=(cmake)
  if ! command_exists c++ || ! command_exists make; then
    llvm_packages+=(build-essential)
  fi
  if [[ -n "$LLVM_VERSION" ]]; then
    llvm_packages+=(
      "llvm-${LLVM_VERSION}-dev"
      "libclang-${LLVM_VERSION}-dev"
      "clang-tidy-${LLVM_VERSION}"
    )
  else
    llvm_packages+=(llvm-dev libclang-dev clang-tidy)
  fi

  log "Installing system dependencies with apt-get"
  $apt_get update
  $apt_get install -y "${llvm_packages[@]}"
}

install_brew_dependencies() {
  command_exists brew || fail "Neither apt-get nor brew is available"
  local packages=()
  command_exists cmake || packages+=(cmake)
  command_exists clang-tidy || packages+=(llvm)
  if ((${#packages[@]} == 0)); then
    log "Using existing Homebrew dependencies"
    return
  fi
  log "Installing missing system dependencies with Homebrew"
  brew install "${packages[@]}"
}

find_cmake_dir() {
  local name="$1"
  local candidate
  for candidate in \
    "${LLVM_DIR:-}" \
    "/usr/lib/llvm-${LLVM_VERSION}/lib/cmake/${name}" \
    "/usr/lib/llvm/lib/cmake/${name}" \
    "/usr/local/opt/llvm/lib/cmake/${name}" \
    "$PREFIX/lib/cmake/${name}"; do
    if [[ -n "$candidate" && -f "$candidate/${name}Config.cmake" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

build_custom_check() {
  command_exists cmake || fail "cmake is required"
  command_exists clang-tidy || fail "clang-tidy is required"

  local llvm_dir clang_dir
  llvm_dir="$(find_cmake_dir LLVM || true)"
  clang_dir="$(find_cmake_dir Clang || true)"
  [[ -n "$llvm_dir" ]] || fail "LLVMConfig.cmake was not found; set LLVM_DIR"
  [[ -n "$clang_dir" ]] || fail "ClangConfig.cmake was not found; set Clang_DIR"

  log "Configuring company-internal-comments"
  cmake -S "$ROOT_DIR/custom-check" -B "$BUILD_DIR" \
    -DLLVM_DIR="$llvm_dir" \
    -DClang_DIR="$clang_dir"
  log "Building company-internal-comments"
  cmake --build "$BUILD_DIR"
}

run_custom_check_tests() {
  local plugin="$BUILD_DIR/company-internal-comments.so"
  if [[ ! -f "$plugin" ]]; then
    plugin="$BUILD_DIR/company-internal-comments.dylib"
  fi
  [[ -f "$plugin" ]] || fail "Custom Check plugin was not produced in $BUILD_DIR"

  log "Running company-internal-comments tests"
  bash "$ROOT_DIR/custom-check/tests/run-tests.sh" "$plugin"
}

main() {
  cd "$ROOT_DIR"
  case "$(uname -s)" in
    Linux)
      if command_exists apt-get; then
        install_apt_dependencies
      elif command_exists brew; then
        install_brew_dependencies
      else
        fail "Unsupported Linux package manager; install LLVM/Clang manually"
      fi
      ;;
    Darwin)
      install_brew_dependencies
      ;;
    *)
      fail "This script supports Linux and macOS Codex environments"
      ;;
  esac

  export PATH="$PREFIX/bin:$PATH"
  build_custom_check
  run_custom_check_tests
  log "Codex quality-skill installation completed"
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

# Installs the dependencies needed to build and test this quality skill in Codex.
# Set SKIP_DEPENDENCY_INSTALL=1 to use an existing LLVM installation.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/custom-check}"
LLVM_VERSION="${LLVM_VERSION:-}"
LLVM_CONFIG="${LLVM_CONFIG:-}"
CLANG_TIDY="${CLANG_TIDY:-}"

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
  local apt_get=(apt-get)
  if [[ "$(id -u)" -ne 0 ]]; then
    command_exists sudo || fail "apt-get requires root or sudo"
    apt_get=(sudo apt-get)
  fi

  local llvm_packages=(cmake)
  if ! command_exists c++ || ! command_exists make; then
    llvm_packages+=(build-essential)
  fi
  if [[ -n "$LLVM_VERSION" ]]; then
    llvm_packages+=(
      "llvm-${LLVM_VERSION}-dev"
      "libclang-${LLVM_VERSION}-dev"
      "libclang-cpp${LLVM_VERSION}-dev"
      "clang-tidy-${LLVM_VERSION}"
    )
  else
    llvm_packages+=(llvm-dev libclang-dev libclang-cpp-dev clang-tidy)
  fi

  log "Installing system dependencies with apt-get"
  "${apt_get[@]}" update
  "${apt_get[@]}" install -y "${llvm_packages[@]}"
}

install_brew_dependencies() {
  command_exists brew || fail "Neither apt-get nor brew is available"
  local formula="llvm${LLVM_VERSION:+@$LLVM_VERSION}"
  local packages=("$formula")
  command_exists cmake || packages+=(cmake)
  log "Installing missing system dependencies with Homebrew"
  brew install "${packages[@]}"
}

select_llvm_tools() {
  if [[ -z "$LLVM_CONFIG" ]]; then
    if [[ -n "${LLVM_DIR:-}" ]]; then
      LLVM_CONFIG="$LLVM_DIR/../../../bin/llvm-config"
    elif [[ -n "$LLVM_VERSION" ]] && command_exists "llvm-config-$LLVM_VERSION"; then
      LLVM_CONFIG="llvm-config-$LLVM_VERSION"
    elif command_exists brew; then
      LLVM_CONFIG="$(brew --prefix "llvm${LLVM_VERSION:+@$LLVM_VERSION}")/bin/llvm-config"
    else
      LLVM_CONFIG="llvm-config${LLVM_VERSION:+-$LLVM_VERSION}"
    fi
  fi
  command_exists "$LLVM_CONFIG" || fail "llvm-config was not found; set LLVM_CONFIG"

  local version major bindir
  version="$("$LLVM_CONFIG" --version)"
  major="${version%%.*}"
  [[ "$major" =~ ^[0-9]+$ && "$major" -ge 18 ]] || fail "LLVM/Clang 18 or newer is required"
  [[ -z "$LLVM_VERSION" || "$LLVM_VERSION" == "$major" ]] || fail "LLVM_VERSION does not match LLVM_CONFIG"
  bindir="$("$LLVM_CONFIG" --bindir)"
  CLANG_TIDY="${CLANG_TIDY:-$bindir/clang-tidy}"
  command_exists "$CLANG_TIDY" || fail "clang-tidy was not found; set CLANG_TIDY"
  CLANG_TIDY="$(command -v "$CLANG_TIDY")"
  "$CLANG_TIDY" --version | grep -Eq "LLVM version ${major}\." || fail "clang-tidy must match LLVM major version $major"

  LLVM_DIR="${LLVM_DIR:-$("$LLVM_CONFIG" --cmakedir)}"
  Clang_DIR="${Clang_DIR:-$(dirname "$LLVM_DIR")/clang}"
  [[ -f "$LLVM_DIR/LLVMConfig.cmake" ]] || fail "LLVMConfig.cmake was not found; set LLVM_DIR"
  [[ -f "$Clang_DIR/ClangConfig.cmake" ]] || fail "ClangConfig.cmake was not found; set Clang_DIR"
  log "Using LLVM $version and $CLANG_TIDY"
}

build_custom_check() {
  command_exists cmake || fail "cmake is required"
  select_llvm_tools

  log "Configuring company-internal-comments"
  cmake -S "$ROOT_DIR/custom-check" -B "$BUILD_DIR" \
    -DLLVM_DIR="$LLVM_DIR" \
    -DClang_DIR="$Clang_DIR" \
    -DCMAKE_CXX_COMPILER="${CXX:-$("$LLVM_CONFIG" --bindir)/clang++}" \
    -DCLANG_TIDY_EXECUTABLE="$CLANG_TIDY"
  log "Building company-internal-comments"
  cmake --build "$BUILD_DIR"
}

run_custom_check_tests() {
  log "Running company-internal-comments tests"
  cmake --build "$BUILD_DIR" --target company_internal_comments_tests
}

main() {
  cd "$ROOT_DIR"
  export PATH="$PREFIX/bin:$PATH"
  if [[ "${SKIP_DEPENDENCY_INSTALL:-0}" != "1" ]]; then
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
  fi
  build_custom_check
  run_custom_check_tests
  log "Codex quality-skill installation completed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

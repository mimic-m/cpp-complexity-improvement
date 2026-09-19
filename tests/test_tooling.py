#!/usr/bin/env python3
"""Run shell regression checks: python3 tests/test_tooling.py /path/to/clang-tidy."""

import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def run(args, **overrides):
    env = os.environ.copy()
    for key in ("LLVM_CONFIG", "LLVM_DIR", "Clang_DIR", "LLVM_VERSION", "CLANG_TIDY"):
        env.pop(key, None)
    env.update(overrides)
    return subprocess.run(args, env=env, text=True, capture_output=True)


def executable(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/usr/bin/env bash\n" + body, encoding="utf-8")
    path.chmod(0o755)


def test_tool_selection(tmp):
    prefix = tmp / "LLVM with spaces"
    llvm_dir = prefix / "lib/cmake/llvm"
    clang_dir = tmp / "separate clang config"
    for directory, name in ((llvm_dir, "LLVM"), (clang_dir, "Clang")):
        directory.mkdir(parents=True)
        (directory / f"{name}Config.cmake").touch()
    executable(prefix / "bin/llvm-config", f"""
case "$1" in
  --version) echo 18.1.3 ;;
  --bindir) echo {shlex.quote(str(prefix / 'bin'))} ;;
  --cmakedir) echo {shlex.quote(str(llvm_dir))} ;;
esac
""")
    executable(prefix / "bin/clang-tidy", "echo 'LLVM version 18.1.3'\n")
    command = ["bash", "-c", 'source "$1"; select_llvm_tools; printf "%s\\n" "$CLANG_TIDY" "$Clang_DIR"',
               "test", str(ROOT / "scripts/install-codex.sh")]
    result = run(command, LLVM_DIR=str(llvm_dir), Clang_DIR=str(clang_dir))
    assert result.returncode == 0, result.stdout + result.stderr
    assert str(prefix / "bin/clang-tidy") in result.stdout
    assert str(clang_dir) in result.stdout

    # A versioned llvm-config must select its own tidy, not the unrelated PATH tidy.
    fake_bin = tmp / "bin"
    executable(fake_bin / "llvm-config-18", (prefix / "bin/llvm-config").read_text())
    executable(fake_bin / "clang-tidy", "echo 'LLVM version 19.1.1'\n")
    path = str(fake_bin) + os.pathsep + os.environ["PATH"]
    result = run(command, PATH=path, LLVM_VERSION="18", Clang_DIR=str(clang_dir))
    assert result.returncode == 0, result.stdout + result.stderr
    assert str(prefix / "bin/clang-tidy") in result.stdout
    result = run(command, PATH=path, LLVM_VERSION="18", Clang_DIR=str(clang_dir),
                 CLANG_TIDY=str(fake_bin / "clang-tidy"))
    assert result.returncode != 0, "Mismatched LLVM and clang-tidy were accepted"

    # Homebrew's LLVM is not necessarily present on PATH.
    executable(fake_bin / "brew", f"echo {shlex.quote(str(prefix))}\n")
    result = run(command, PATH=path, Clang_DIR=str(clang_dir))
    assert result.returncode == 0, result.stdout + result.stderr
    assert str(prefix / "bin/clang-tidy") in result.stdout
    print("tool selection: explicit paths, versioned tools, Homebrew and mismatch checks passed")


def test_runner_failure(tmp):
    tidy = tmp / "fake tidy"
    executable(tidy, """
case "$*" in
  *-list-checks*) echo '    company-internal-comments'; exit 0 ;;
  *pass.cpp*) exit 0 ;;
  *fail.cpp*)
    for n in 1 2 3 4 5 6 7; do
      echo 'case.cpp:1:1: warning: missing comment [company-internal-comments]'
    done
    exit "${FAKE_TIDY_EXIT:-0}" ;;
esac
""")
    command = ["bash", str(ROOT / "custom-check/tests/run-tests.sh"), "unused", str(tidy)]
    result = run(command, FAKE_TIDY_EXIT="0")
    assert result.returncode == 0, result.stdout + result.stderr
    result = run(command, FAKE_TIDY_EXIT="139")
    assert result.returncode != 0, "A crashing analysis was accepted as a passing test"
    assert "exit 139" in result.stderr
    executable(tidy, "echo 'Enabled checks:'\n")
    result = run(command)
    assert result.returncode != 0, "An unloaded plugin was accepted"
    print("test runner: successful diagnostics, crash and missing-plugin checks passed")


def test_quality_gate(tmp, tidy):
    source = tmp / "size.cpp"
    # Use the shipped strict configuration; the custom plugin is tested separately.
    args = [tidy, "--config-file=" + str(ROOT / "custom-check/clang-tidy.example.yaml"),
            "--checks=-*,readability-function-size", str(source), "--", "-std=c++17"]
    command = ["bash", str(ROOT / "tools/check-quality.sh")]
    env = dict(BUILD_COMMAND="true", TEST_COMMAND="true", CLANG_TIDY_COMMAND=shlex.join(args))
    source.write_text("int f(int n) { return n; }\n", encoding="utf-8")
    result = run(command, **env)
    assert result.returncode == 0, result.stdout + result.stderr
    source.write_text("int f(int n) {\n" + "  n += 1;\n" * 85 + "  return n;\n}\n", encoding="utf-8")
    result = run(command, **env)
    assert result.returncode != 0, "A new oversized function passed the quality gate"
    assert "readability-function-size" in result.stdout + result.stderr
    assert "Quality check completed" not in result.stdout
    print("quality gate: clean input passes and a new 87-line function fails")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="cpp-quality-tests-") as directory:
        tmp = Path(directory)
        test_tool_selection(tmp)
        test_runner_failure(tmp)
        test_quality_gate(tmp, sys.argv[1] if len(sys.argv) > 1 else "clang-tidy")

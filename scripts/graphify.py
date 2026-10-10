#!/usr/bin/env python3
"""Run the Graphify CLI version pinned by this repository."""

from __future__ import annotations

import os
import subprocess
import sys
import venv
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ENVIRONMENT_DIR = REPOSITORY_ROOT / ".graphify-venv"
PACKAGE_NAME = "graphifyy"
VERSION_FILES = (
    REPOSITORY_ROOT / ".agents" / "skills" / "graphify" / ".graphify_version",
    REPOSITORY_ROOT / ".codex" / "skills" / "graphify" / ".graphify_version",
)


def pinned_version() -> str:
    versions = {version_file.read_text(encoding="utf-8").strip() for version_file in VERSION_FILES}
    if len(versions) != 1 or not next(iter(versions), ""):
        raise RuntimeError("The .agents and .codex Graphify version files must contain the same version.")
    return next(iter(versions))


def environment_python() -> Path:
    executable = "python.exe" if os.name == "nt" else "python"
    scripts_directory = "Scripts" if os.name == "nt" else "bin"
    return ENVIRONMENT_DIR / scripts_directory / executable


def graphify_executable() -> Path:
    executable = "graphify.exe" if os.name == "nt" else "graphify"
    scripts_directory = "Scripts" if os.name == "nt" else "bin"
    return ENVIRONMENT_DIR / scripts_directory / executable


def installed_package_version(python_executable: Path) -> str | None:
    probe = subprocess.run(
        [
            str(python_executable),
            "-c",
            f"from importlib.metadata import version; print(version('{PACKAGE_NAME}'))",
        ],
        capture_output=True,
        check=False,
        text=True,
    )
    return probe.stdout.strip() if probe.returncode == 0 else None


def ensure_graphify_installed(version: str) -> Path:
    python_executable = environment_python()
    if not python_executable.exists():
        venv.EnvBuilder(with_pip=True, clear=ENVIRONMENT_DIR.exists()).create(ENVIRONMENT_DIR)

    if installed_package_version(python_executable) != version:
        print(f"Installing {PACKAGE_NAME}=={version} into {ENVIRONMENT_DIR.name}…", flush=True)
        subprocess.run(
            [
                str(python_executable),
                "-m",
                "pip",
                "install",
                "--disable-pip-version-check",
                "--no-input",
                f"{PACKAGE_NAME}=={version}",
            ],
            check=True,
        )

    executable = graphify_executable()
    if not executable.exists():
        raise RuntimeError(f"Graphify CLI was not created at {executable}.")
    return executable


def main(arguments: list[str]) -> int:
    if sys.version_info < (3, 10):
        print("Graphify requires Python 3.10 or newer.", file=sys.stderr)
        return 2

    try:
        executable = ensure_graphify_installed(pinned_version())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Graphify bootstrap failed: {error}", file=sys.stderr)
        return 1

    return subprocess.run([str(executable), *(arguments or ["--help"])], cwd=Path.cwd()).returncode


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

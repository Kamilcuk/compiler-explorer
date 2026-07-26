#!/usr/bin/env python3
"""Fetch L_lib from github.com/Kamilcuk/L_lib.

Clones the full git repository into MYSTUFF/libs/L_lib/ and extracts versioned
bin/L_lib.sh files from tagged versions >= v1.0.5 into MYSTUFF/libs/L_lib/bin/.

Usage:
    ./fetch_lib_l.py              # clone/update + extract missing versioned files
    ./fetch_lib_l.py --force      # re-extract everything
    ./fetch_lib_l.py --dry-run    # show what would be done
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

from packaging.version import Version

REPO = "Kamilcuk/L_lib"
REPO_URL = "https://github.com/Kamilcuk/L_lib.git"
MIN_VERSION = Version("1.0.5")

SCRIPT_DIR = Path(__file__).resolve().parent
LIB_DIR = SCRIPT_DIR / "libs" / "L_lib"
BIN_DIR = LIB_DIR / "bin"


def run_git(
    args: list[str],
    cwd: Path | None = None,
    capture_output: bool = True,
) -> subprocess.CompletedProcess:
    """Run a git command and return the result."""
    return subprocess.run(
        ["git"] + args,
        cwd=cwd,
        capture_output=capture_output,
        text=capture_output,
        check=False,
    )


def ensure_clone(dry_run: bool) -> bool:
    """Clone or update the repo into LIB_DIR. Returns True on success."""
    if dry_run:
        if LIB_DIR.exists() and (LIB_DIR / ".git").exists():
            print(f"  WOULD: git pull --ff-only in {LIB_DIR}")
        else:
            print(f"  WOULD: git clone {REPO_URL} {LIB_DIR}")
        return True

    if LIB_DIR.exists() and (LIB_DIR / ".git").exists():
        print(f"Updating existing clone at {LIB_DIR}...")
        result = run_git(["pull", "--ff-only"], cwd=LIB_DIR)
        if result.returncode != 0:
            print(f"  FAILED: {result.stderr.strip()}", file=sys.stderr)
            return False
        print(f"  Updated to HEAD")
        return True

    print(f"Cloning {REPO_URL} into {LIB_DIR}...")
    LIB_DIR.parent.mkdir(parents=True, exist_ok=True)
    result = run_git(["clone", REPO_URL, str(LIB_DIR)], capture_output=False)
    if result.returncode != 0:
        print(f"  FAILED: clone exited with code {result.returncode}", file=sys.stderr)
        return False
    print(f"  Cloned successfully")
    return True


def ensure_tags_fetched(dry_run: bool) -> bool:
    """Fetch tags into the local clone. Returns True on success."""
    if dry_run:
        print(f"  WOULD: git fetch --tags in {LIB_DIR}")
        return True
    result = run_git(["fetch", "--tags", "--force"], cwd=LIB_DIR)
    if result.returncode != 0:
        print(f"  FAILED: git fetch --tags: {result.stderr.strip()}", file=sys.stderr)
        return False
    return True


def get_tags() -> list[tuple[Version, str]]:
    """List all tags from the local clone, return (parsed_version, tag_name) sorted."""
    result = run_git(["tag", "--list"], cwd=LIB_DIR)
    if result.returncode != 0:
        print(f"ERROR: Failed to list tags: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)

    tags = []
    for tag_name in result.stdout.strip().splitlines():
        if not tag_name:
            continue
        ver_str = re.sub(r"^v", "", tag_name)
        try:
            ver = Version(ver_str)
        except Exception:
            continue
        tags.append((ver, tag_name))

    tags.sort(key=lambda x: x[0])
    return tags


def extract_file(tag_name: str, dest: Path, dry_run: bool) -> bool:
    """Extract bin/L_lib.sh from the given git ref into dest. Returns True on success."""
    rel_path = "bin/L_lib.sh"
    if dry_run:
        print(f"  WOULD: git show {tag_name}:{rel_path} -> {dest}")
        return True

    result = run_git(["show", f"{tag_name}:{rel_path}"], cwd=LIB_DIR, capture_output=True)
    if result.returncode != 0:
        print(f"  -> FAILED: '{tag_name}:{rel_path}' not found in repo", file=sys.stderr)
        return False

    dest.parent.mkdir(parents=True, exist_ok=True)
    # Write as bytes — binary-safe for any file content
    dest.write_bytes(result.stdout.encode() if isinstance(result.stdout, str) else result.stdout)
    dest.chmod(0o755)
    print(f"  -> {dest}")
    return True


def extract_master(dest: Path, dry_run: bool) -> bool:
    """Extract bin/L_lib.sh from HEAD into dest."""
    return extract_file("HEAD", dest, dry_run)


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch L_lib from GitHub")
    parser.add_argument("--force", action="store_true", help="Re-extract existing files")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done")
    args = parser.parse_args()

    print(f"Library directory: {LIB_DIR}")
    print(f"Bin directory: {BIN_DIR}")
    print()

    # Step 1: Clone or update the repo
    print("=== Clone / update repository ===")
    if not ensure_clone(args.dry_run):
        sys.exit(1)

    # Step 2: Fetch tags
    print("\n=== Fetch tags ===")
    if not ensure_tags_fetched(args.dry_run):
        sys.exit(1)

    if not args.dry_run:
        print(f"\nListing tags from {REPO}...")
        tags = get_tags()
        print(f"  Found {len(tags)} tags total")

        selected = [(ver, name) for ver, name in tags if ver >= MIN_VERSION]
        print(f"  {len(selected)} tags >= v{MIN_VERSION}:")
        for ver, name in selected:
            print(f"    {name}")
    else:
        tags = []
        selected = []
        print(f"\n  WOULD: list tags (>= v{MIN_VERSION})")

    # Step 3: Extract versioned files
    print(f"\n=== Extract versioned bin/L_lib.sh files ===")
    ok = True
    for ver, tag_name in selected:
        dest = BIN_DIR / f"L_lib.sh.v{ver}"
        if dest.exists() and not args.force:
            print(f"  SKIP: {dest.name} already exists (use --force to re-extract)")
            continue
        if not extract_file(tag_name, dest, args.dry_run):
            ok = False

    # Step 4: Extract master
    master_dest = BIN_DIR / "L_lib.sh"
    print(f"\n=== Extract master (HEAD) bin/L_lib.sh ===")
    if not extract_master(master_dest, args.dry_run):
        ok = False

    if not ok:
        print("\nWARNING: Some extractions failed", file=sys.stderr)
        sys.exit(1)

    print("\nDone.")


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""Generate a throwaway ESPHome config that pulls base/**.yaml from the WORKING TREE.

Why: `guition-va.yaml` pulls the core + screens from GitHub (`packages:` -> url/ref), so
`esphome config guition-va.yaml` validates whatever is pushed, not what you just edited.
This script rewrites that block into local `!include`s so you can validate before pushing.

Run it through build.sh:  ./build.sh local
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "guition-va.yaml"
OUT = ROOT / "validate-local.yaml"


def main() -> int:
    src = SRC.read_text()
    # Everything above the top-level `packages:` key is the user's substitutions block.
    head = re.split(r"^packages:$", src, maxsplit=1, flags=re.M)[0]
    if "substitutions:" not in head:
        print(f"error: no substitutions block found in {SRC.name}", file=sys.stderr)
        return 1

    # Only the files that are actually enabled (commented-out lines are left out).
    files = re.findall(r"^\s+- (base/\S+\.yaml)", src, re.M)
    if not files:
        print(f"error: no base/**.yaml entries found in {SRC.name}", file=sys.stderr)
        return 1

    missing = [f for f in files if not (ROOT / f).is_file()]
    if missing:
        print("error: listed but not on disk: " + ", ".join(missing), file=sys.stderr)
        return 1

    lines = [head, "packages:\n"]
    for f in files:
        key = f[len("base/"):].removesuffix(".yaml").replace("/", "_").replace("-", "_")
        lines.append(f"  {key}: !include {f}\n")
    OUT.write_text("".join(lines))
    print(f"{OUT.name}: {len(files)} local package file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

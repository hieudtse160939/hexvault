"""One-command project check: asset validation, Godot import, unit tests.

Usage:
  python tools/check.py               # everything
  python tools/check.py --tests-only  # skip asset validation/import
  python tools/check.py --select dungeon

Needs GODOT_BIN (defaults to the portable Godot in .tools/ for this OS, see tools/godot_bin.py).
Exit code 0 only if every step passed.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
from godot_bin import godot_bin  # noqa: E402

DEFAULT_GODOT = godot_bin()
SKILL = os.path.join(ROOT, ".claude", "skills", "godot", "scripts")


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tests-only", action="store_true")
    ap.add_argument("--select", default="")
    args = ap.parse_args()
    godot = os.environ.get("GODOT_BIN", DEFAULT_GODOT)
    env = dict(os.environ, GODOT_BIN=godot)
    ok = True
    if not args.tests_only:
        r = run([sys.executable, "tools/validate_assets.py"])
        print("[assets]", r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr[-500:])
        ok &= r.returncode == 0
        r = run([godot, "--headless", "--path", ".", "--import"], timeout=600)
        errs = [l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l or "SCRIPT ERROR" in l]
        print(f"[import] exit={r.returncode} errors={len(errs)}")
        for l in errs[:20]:
            print("   ", l)
        ok &= r.returncode == 0 and not errs
    cmd = [sys.executable, os.path.join(SKILL, "test", "run_tests.py"), ROOT, "--godot-bin", godot, "--test-timeout", "240", "--timeout", "1500"]
    if args.select:
        cmd += ["--select", args.select]
    r = run(cmd, env=env, timeout=1600)
    try:
        d = json.loads(r.stdout)
    except json.JSONDecodeError:
        print("[tests] could not parse runner output:\n", (r.stdout + r.stderr)[-3000:])
        return 1
    print("[tests]", d.get("counts"))
    for t in d.get("results", []):
        if t.get("status") != "passed":
            print(f"   {t.get('status'):8} {t.get('script', '')}::{t.get('name')} | {str(t.get('message'))[:600]}")
    ok &= bool(d.get("ok"))
    print("ALL CHECKS PASSED" if ok else "CHECKS FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

"""Deeper asset QA on top of validate_assets.py: per-frame quality checks.

Errors (fail the build):
  - metadata missing (type, density, version, source)
  - frame clipped: opaque pixels on the frame border of an HD sprite
  - duplicate output paths / ids that differ only by case
Warnings (reported, tracked in the QA report):
  - anchor drift: the feet line (lowest opaque row) or the horizontal centre of
    mass jumps between consecutive frames of a looping animation
  - silhouette jitter: consecutive looping frames overlap less than 55 % (IoU)
  - pixel noise: isolated single-colour specks > 3 % of opaque pixels (HD) or
    > 10 % (16 px art, where single-pixel eyes and glints are intentional)
  - colour budget: > 56 colours in one HD sheet (> 16 for 16 px art)

Usage:
  python tools/asset_qa.py                 # print summary, write docs/qa/asset_qa_report.md
  python tools/asset_qa.py --json out.json # also dump machine-readable results
Exit code 1 if any error.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REPORT = os.path.join(ROOT, "docs", "qa", "asset_qa_report.md")

REQUIRED_META = ("type", "density", "version", "source")


def res_to_path(res: str) -> str:
    return os.path.join(ROOT, res.replace("res://", ""))


def frames_of(img: np.ndarray, s: dict, anim: dict) -> list[np.ndarray]:
    fw, fh = s["frame_w"], s["frame_h"]
    r = anim["row"]
    return [img[r * fh:(r + 1) * fh, i * fw:(i + 1) * fw] for i in range(anim["frames"])]


def noise_ratio(f: np.ndarray) -> float:
    """Share of opaque pixels whose four neighbours are all opaque but of other colours."""
    a = f[..., 3] > 0
    if a.sum() == 0:
        return 0.0
    rgb = f[..., :3].astype(np.int32)
    key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
    k = np.pad(key, 1, constant_values=-1)
    o = np.pad(a, 1, constant_values=False)
    c = k[1:-1, 1:-1]
    iso = a.copy()
    for dy, dx in ((0, 1), (2, 1), (1, 0), (1, 2)):
        nb = k[dy:dy + c.shape[0], dx:dx + c.shape[1]]
        nbo = o[dy:dy + c.shape[0], dx:dx + c.shape[1]]
        iso &= nbo & (nb != c)
    return float(iso.sum()) / float(a.sum())


def check_sprite(key: str, s: dict) -> tuple[list[str], list[str], dict]:
    errs: list[str] = []
    warns: list[str] = []
    stats: dict = {}
    for m in REQUIRED_META:
        if m not in s:
            errs.append(f"{key}: missing metadata '{m}'")
    path = res_to_path(s["path"])
    if not os.path.exists(path):
        return [f"{key}: missing file"], warns, stats
    img = np.array(Image.open(path).convert("RGBA"))
    hd = float(s.get("density", 1)) > 1
    opaque = img[..., 3] > 0
    colours = {tuple(c) for c in img[opaque][:, :3].tolist()}
    stats["colours"] = len(colours)
    budget = 56 if hd else 16
    if len(colours) > budget:
        warns.append(f"{key}: {len(colours)} colours (budget {budget})")
    worst_noise = 0.0
    for name, anim in s["anims"].items():
        fr = frames_of(img, s, anim)
        feet: list[int] = []
        cx: list[float] = []
        masks: list[np.ndarray] = []
        for i, f in enumerate(fr):
            a = f[..., 3] > 0
            masks.append(a)
            if not a.any():
                continue
            if hd and (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()):
                errs.append(f"{key}.{name}[{i}]: clipped (opaque pixels on the frame border)")
            ys, xs = np.nonzero(a)
            feet.append(int(ys.max()))
            cx.append(float(xs.mean()))
            worst_noise = max(worst_noise, noise_ratio(f))
        if anim.get("loop") and len(fr) > 1 and name not in ("death",):
            tol_feet = 3 * float(s.get("density", 1)) if hd else 2
            if feet and max(feet) - min(feet) > tol_feet:
                warns.append(f"{key}.{name}: feet line drifts {max(feet) - min(feet)} px")
            jumps = [abs(cx[i + 1] - cx[i]) for i in range(len(cx) - 1)]
            if jumps and max(jumps) > (3.5 if hd else 2.0) * float(s.get("density", 1)) / (4 if hd else 1):
                warns.append(f"{key}.{name}: centre of mass jumps {max(jumps):.1f} px between frames")
            for i in range(len(masks) - 1):
                inter = (masks[i] & masks[i + 1]).sum()
                union = (masks[i] | masks[i + 1]).sum()
                if union and inter / union < 0.55 and masks[i].sum() > 40:
                    warns.append(f"{key}.{name}[{i}->{i + 1}]: silhouette IoU {inter / union:.2f}")
                    break
    stats["noise"] = round(worst_noise, 4)
    if worst_noise > (0.03 if hd else 0.10):
        warns.append(f"{key}: pixel noise {worst_noise:.1%}")
    return errs, warns, stats


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    with open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8") as f:
        m = json.load(f)
    errors: list[str] = []
    warnings: list[str] = []
    rows: list[tuple] = []
    seen_paths: dict[str, str] = {}
    seen_ids: dict[str, str] = {}
    for section in ("sprites", "images"):
        for key, s in m[section].items():
            low = key.lower()
            if low in seen_ids:
                errors.append(f"{key}: id collides with {seen_ids[low]}")
            seen_ids[low] = key
            p = s["path"].lower()
            if p in seen_paths and section == "sprites":
                errors.append(f"{key}: path shared with {seen_paths[p]}")
            seen_paths[p] = key
    for key, s in sorted(m["sprites"].items()):
        e, w, st = check_sprite(key, s)
        errors += e
        warnings += w
        status = "FAIL" if e else ("WARN" if w else "PASS")
        rows.append((key, s.get("type", "?"), s.get("density", "?"), f"{s['frame_w']}x{s['frame_h']}",
                     sum(a["frames"] for a in s["anims"].values()), st.get("colours", 0), st.get("noise", 0),
                     s.get("version", "?"), status))
    for key, s in m["images"].items():
        for meta in REQUIRED_META:
            if meta not in s:
                errors.append(f"{key}: missing metadata '{meta}'")
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Asset QA report\n\nGenerated by `python tools/asset_qa.py` (also run by `tools/check.py`).\n\n")
        f.write(f"Sprites: {len(m['sprites'])} · images: {len(m['images'])} · "
                f"errors: {len(errors)} · warnings: {len(warnings)}\n\n")
        f.write("| id | type | density | frame | frames | colours | worst noise | version | QA |\n")
        f.write("| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n")
        for r in rows:
            f.write("| " + " | ".join(str(x) for x in r) + " |\n")
        if errors:
            f.write("\n## Errors\n\n" + "\n".join(f"- {e}" for e in errors) + "\n")
        if warnings:
            f.write("\n## Warnings (to fix or accept)\n\n" + "\n".join(f"- {w}" for w in warnings) + "\n")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"errors": errors, "warnings": warnings, "rows": rows}, f, indent=1)
    for e in errors[:40]:
        print("ERROR", e)
    for w in warnings[:40]:
        print("WARN ", w)
    print(f"qa sprites={len(rows)} errors={len(errors)} warnings={len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

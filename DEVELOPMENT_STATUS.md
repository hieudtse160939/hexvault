# Hexvault — Development Status

_Last updated: 2026-10-20 · version 0.9.0 · Godot 4.7.2-stable (ed1daf0bf)_

**Summary:** a complete, playable vertical slice. The full loop (title → hub → 3 procedural floors → boss → results → hub with permanent progression) works and is covered by automated tests. Windows and Android builds are exported and were verified running; iOS is configured but not built (no macOS available).

## Environment (inspected at start)

| Item | Found | Action |
| --- | --- | --- |
| OS | Windows 11 Home, RTX 5050 Laptop GPU | — |
| Godot | not installed | Downloaded the official 4.7.2-stable editor and templates from GitHub releases, SHA-512 verified, installed portable in `.tools/` |
| Git | 2.55 | repo initialised |
| Python | 3.14 + Pillow 12.2 + NumPy 2.4 | used for asset generation and tooling |
| Android | SDK (build-tools 35/36, platforms 36/37), Android Studio JBR (OpenJDK 25), AVD *Medium_Phone_API_37* | debug keystore created in `.tools/` |
| ffmpeg | 8.1 | music → OGG |
| macOS / Xcode | **not available** | iOS left at "configured, not built" |

## Agent skills

The GitHub searches in the brief were treated as starting points. Repositories were cloned into an isolated scratch folder, and the README, LICENSE, SKILL.md and scripts were read before anything was installed.

| Skill | Source / licence | Decision | Why |
| --- | --- | --- | --- |
| `godot` | [haxqer/godot-skill](https://github.com/haxqer/godot-skill), MIT | **Installed** → `.claude/skills/godot` | Verified on 4.7: API lookup, GDScript lint, mini test runner, export presets. Scripts audited: the only network code is a local web-preview server, and subprocess calls only launch Godot |
| `gp-*` (6 skills) | [jame581/GodotPrompter](https://github.com/jame581/GodotPrompter), MIT | **Installed** (procedural-generation, state-machine, save-load, mobile-development, export-pipeline, input-handling) | Markdown-only reference skills for Godot 4.x |
| pixel-art-studio | Gamezxz/pixel-art-studio, MIT | Not installed | Wrote a smaller deterministic Pillow pipeline instead, so every line run is our own |
| Vercel Skills CLI | vercel-labs/skills | Reviewed, not run | It installs to the same `.claude/skills/` for Claude Code. Manual install avoided executing an extra npm package |
| `hexvault-dev` | this repo | **Created** | Project workflow skill for future agents |

API usage was checked against the installed engine with `api_lookup.py`. Example: the Android keystore environment variables were confirmed present in the 4.7.2 binary.

## Phase status

| Phase | Status | Evidence |
| --- | --- | --- |
| 1 Foundation | ✅ Done | Project, Git, pixel settings (480×270 viewport, nearest, integer scale, GL Compatibility), asset pipeline |
| 2 Playable combat | ✅ Done | Player, 11 weapons, pooled projectiles, 5 enemy archetypes, damage/health/armor, restart after death |
| 3 Roguelike loop | ✅ Done | Seeded generator plus 9 room types, loot, shop, chests, boons, boss, run completion |
| 4 Progression | ✅ Done | Hero select/unlocks, armory, forge upgrades, achievements, quests, versioned saves, settings |
| 5 Content & polish | ✅ Vertical-slice level | Boss phases, animations for every actor, 39 SFX + 3 music loops, game-feel effects, reduced-effects mode |
| 6 Platforms | ◑ Partial | Windows exported and verified. Android debug APK exported and verified on emulator. iOS preset only |
| 7 Release candidate | ◑ Partial | Regression suite, performance numbers, save-migration tests and packaging done. Physical device, clean PC and gamepad hardware tests still open |

## Automated verification (`python tools/check.py`)

Last run: **ALL CHECKS PASSED.** 95 assets validated, headless import with 0 errors, **42/42 tests passing** in about 1 m 44 s.

| Suite | Tests | Covers |
| --- | --- | --- |
| `test_scripts_compile` | 1 | Every script in `scripts/` loads and compiles with autoloads present |
| `test_data` | 8 | Data cross-references; every weapon valid; all 9 weapon categories present; every room template navigable (flood fill, door approaches); every room type has a template; required animations exist for every enemy and hero |
| `test_dungeon` | 7 | Determinism (same seed gives an identical layout); variety; **900 generated floors** (300 seeds × 3 floors) all valid and fully connected; boss reachable as a dead end; specials present; fallback valid; impossible config falls back |
| `test_damage` | 5 | Damage formula, crits, armor absorption, scaling, Health invulnerability/death/revive |
| `test_save` | 9 | Round trip; missing file; backup created and used on corruption; truncated file with no backup resets safely; corrupt main never overwrites a good backup; v1→v2 migration; schema repair of wrong types; **death keeps permanent unlocks**; dev-menu self-test |
| `test_gameplay` | 9 | Wall collision; projectile kills enemy and drops loot; bullets stop at walls; **every weapon pattern damages a target**; dash i-frames; enemy projectiles hurt player; death and revive; every enemy archetype threatens the player; boss phase 2/3 transitions, invulnerable transition, defeat |
| `test_full_run` | 1 | **End-to-end:** start run → clear every combat/elite room on 3 floors (doors lock/unlock) → portals → boss spawn and defeat → victory portal → results; shards, stats and achievement banked; Prism Lance unlocked |
| `test_lifecycle` | 2 | Focus loss pauses the run (no stacked menus), resume; abandon banks shards |

Other checks run:
- `tools/validate_assets.py`: palette, binary alpha, frame grid and non-empty frames for all 95 assets.
- Skill linter: 0 parse errors. Its 20 "undefined input action" findings are false positives, because actions are registered at runtime in `controls.gd`.

## Manual / visual verification performed

- **Screenshot tour** (`--tour=<dir>`), run windowed at 960×540, 1280×720, 2560×1080 and 1024×768. Title, hub, dungeon, combat, debug map, shop, boss and stress screens were all inspected. Issues found this way and fixed:
  - Title layout collapsed (anchor bug).
  - World labels rendered at 16 px.
  - Minimap would not collapse.
  - FPS label overlapped the HUD.
  - Hub camera started off-centre when a modal paused the tree.
- **Performance** (RTX 5050 laptop, vsync on a 144 Hz display):

  | Scene | Avg | p95 | Worst frame |
  | --- | --- | --- | --- |
  | Combat | 6.8 ms | 7.5–8.8 ms | — |
  | Boss | 6.9 ms | 7.5 ms | — |
  | Stress: 40 enemies + 300 projectiles | 6.9 ms | 9.5 ms | 22 ms (single spike) |

  The game stays at the 144 FPS vsync cap, so real headroom is larger. Mobile performance on real hardware has **not** been measured.
- **Windows export:**
  - `build/windows/Hexvault.exe` + `.pck`, packaged as `build/Hexvault-0.9.0-windows-x64.zip` (38.5 MB).
  - The exported exe, and a copy extracted from the ZIP into an empty folder, both boot into a dungeon run and exit cleanly (code 0, no errors in the log).
- **Android export:**
  - `build/android/hexvault-debug.apk` (58 MB, arm64-v8a + x86_64, signed with the debug key).
  - Installed on the emulator (API 37, x86_64, 2400×1080).
  - Verified there: launch, landscape, title, hub, tutorial with touch text, **touch joystick movement**, context USE button, run start, HUD/minimap/touch layout, **touch firing** (6 shots in 1.5 s), Home → resume auto-paused the run and **saved** (`profile.save` + `.bak` on device), 0 errors in logcat.
- Clean shutdown verified free of leaks via `--smoke-quit`.

## Not verified (honest gaps)

- iOS build, signing and device run (needs macOS + Xcode + Apple team ID).
- Android on a physical phone; real-device frame rate and battery use.
- A separate clean Windows machine. The extracted-ZIP test was on the development PC.
- Physical gamepads. Bindings and device switching are implemented, and stick aim was exercised only via simulated input.
- Long manual playtesting by a human. Balance is first-pass.
- Resolution changes while running (startup at 4 resolutions was tested).

## Known issues / limitations

- No key-rebinding UI; English only.
- Mid-run save/resume not implemented (by design for v1).
- One biome and one boss. Wall faces are one tile tall (simpler collision and navigation).
- The development machine's own profile (`%APPDATA%\Hexvault\profile.save`) contains stats from smoke runs. Delete it, or use *Dev menu → Reset profile*, for a fresh start.
- Android JDK is OpenJDK 25 (Android Studio JBR). The export works but apksigner prints Java "restricted method" warnings; JDK 17 is Godot's documented baseline.

## Next steps (suggested order)

1. Playtest sessions; tune enemy HP/damage, shop prices and shard economy.
2. Test the APK on 2–3 physical Android phones (performance, notch safe area, touch sizes).
3. On a Mac: set the Team ID, export the iOS Xcode project, run on device, TestFlight.
4. Gamepad hardware pass (Xbox/PlayStation) plus a key-rebinding screen.
5. Content: second biome, two more bosses, more room templates and weapons (all data-driven).
6. CI (GitHub Actions) running `tools/check.py` and a Windows/Android export on each push.
7. Release signing for Android (AAB via the Gradle build template) using environment-variable credentials.

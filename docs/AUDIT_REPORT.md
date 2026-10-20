# Hexvault — Báo cáo audit & kế hoạch nâng cấp HD Pixel Art

_Ngày audit: 2026-10-20 · nhánh `claude/hd-pixel-art-roguelike-6d4lcx` · phiên bản game 0.9.0_

Báo cáo này ghi lại những gì **đã kiểm tra thực tế** trong container Linux của phiên làm việc
(không phải máy Windows mà các phiên trước đã dùng). Mọi con số bên dưới đều có lệnh tái hiện.

## 1. Trạng thái hiện tại

| Hạng mục | Kết quả kiểm tra |
| --- | --- |
| Engine | Godot **4.7.2-stable** (`ed1daf0bf`), GDScript, renderer GL Compatibility. Không có scene editor phức tạp: hầu hết node được dựng trong code, `scenes/main.tscn` là điểm vào. |
| Nền tảng phát triển trước đây | Windows 11 — toàn bộ tooling (`tools/check.py`, `tools/package.py`, skill `hexvault-dev`) mặc định gọi `Godot_v4.7.2-stable_win64_console.exe`. |
| Môi trường phiên này | Linux x86_64, Python 3 + Pillow 12.3 + NumPy 2.5, Xvfb (render offscreen bằng llvmpipe). Đã tải Godot 4.7.2 Linux từ GitHub release, **SHA-512 khớp** `SHA512-SUMS.txt`. |
| Baseline test | `python tools/check.py` → 95 asset hợp lệ, import 0 lỗi, **42/42 test pass**. |
| Tour ảnh chụp | Chạy được dưới Xvfb; 10 ảnh + `tour_report.json`. (Thời gian khung hình dưới llvmpipe không đại diện cho GPU thật.) |
| Cấu trúc | `scripts/{autoload,core,combat,dungeon,world,entities,ui,fx,data}`, dữ liệu JSON trong `data/`, art sinh bằng script trong `tools/artgen/`, audio trong `tools/audiogen/`. |

### Hệ thống đã hoạt động (đã xác minh bằng test hoặc ảnh chụp)

- Combat: 11 vũ khí data-driven (single/spread/melee/hitscan/chain), projectile pool, crit, giáp, hiệu ứng nguyên tố (burn/frost/shock/hex), dash có i-frame.
- Kẻ địch: 5 archetype FSM (chaser, ranged kiter, flanker, tank charge, summoner) + elite; 1 boss 3 phase, 7 đòn có telegraph.
- Dungeon: sinh tầng có seed, kiểm tra kết nối (900 tầng trong test), 9 loại phòng, cửa khoá/mở, minimap.
- Roguelike loop: hub → 3 tầng → boss → kết quả → hub; boon trong run, shard, nâng cấp vĩnh viễn, mở khoá anh hùng/vũ khí, 10 thành tựu, quest.
- Save: có version, checksum, ghi atomic, backup, phục hồi khi hỏng, migration v1→v2.
- UI: title, hub, hero select, armory, forge, quest, settings, pause, death, results, HUD, touch controls, dev menu.
- Export preset Windows/Android/iOS (Windows + Android đã được build và chạy ở phiên trước; iOS chưa build).

### Hệ thống còn thiếu / yếu so với mục tiêu

| Mục tiêu trong brief | Hiện trạng |
| --- | --- |
| HD pixel art (nhân vật 64–128 px) | Toàn bộ art là **16×16** (boss 48×48), viewport nội bộ **480×270**, stretch mode `viewport`. Không thể hiển thị chi tiết HD vì độ phân giải render bị khoá ở 480×270. |
| Kiến trúc nhân vật quy mô lớn | 4 nhân vật trong `characters.json`, **không có khái niệm class**, không có passive. Kỹ năng được hard-code bằng `match character.skill` rải trong `player.gd` (try_skill, _skill_tick, _skill_end, weapon_mod, try_dash). Thêm nhân vật có kỹ năng mới = sửa `player.gd`. |
| Chỉ số nhân vật | Chỉ có HP, armor, speed. Không có crit cơ bản, cooldown reduction, damage mult… theo nhân vật. |
| Màn chọn nhân vật cho hàng chục/hàng trăm nhân vật | Một hàng nút ngang, không lọc/tìm/sắp xếp. |
| Biome / boss | 1 biome, 1 boss. |
| Art Style Guide, asset metadata (version/nguồn/QA) | Có manifest + validator palette/alpha/grid, nhưng chưa có style guide, chưa có version/nguồn/trạng thái QA, chưa kiểm tra lệch anchor hay nhiễu pixel giữa các frame. |
| Tooling đa nền tảng | Script chỉ tìm binary Windows. |

### Lỗi / rủi ro kiến trúc phát hiện

1. **Kỹ năng hard-code trong Player** (nêu trên) — rào cản lớn nhất cho việc mở rộng lên hàng chục nhân vật.
2. **Độ phân giải render cố định 480×270** — rào cản lớn nhất cho HD art.
3. Khi thoát sau tour ảnh, Godot báo rò rỉ 4 CanvasItem RID / 4 body vật lý (chỉ ở đường thoát của tour debug, `--smoke-quit` sạch theo báo cáo cũ). Mức độ thấp, ghi nhận để theo dõi.
4. Ghi chú dưới Xvfb: thời gian khung hình (combat ~9 ms, stress 40 quái + 300 đạn ~17 ms trung bình) đo trên **CPU rasterizer**, không dùng để kết luận FPS thực tế.

### Hiệu suất

Đã có object pool cho projectile, AI dùng AStarGrid2D, FX có chế độ giảm hiệu ứng. Không thấy điểm nghẽn rõ ràng ở mức code. Chuyển sang render độ phân giải cao hơn sẽ tăng fill-rate; cần đo lại trên GPU thật (không làm được trong container).

### Khả năng đóng gói

| Nền tảng | Đánh giá |
| --- | --- |
| Windows | Preset có sẵn; đã build ở phiên trước. Từ Linux có thể export Windows nếu tải export templates (~1 GB) — chưa làm trong phiên này. |
| Android | Preset có sẵn; cần Android SDK + JDK + keystore. Container không có Android SDK → **bị chặn bởi môi trường**. |
| iOS | Preset có sẵn; cần macOS + Xcode + Apple Team ID → **bị chặn bởi môi trường**. |

## 2. Đánh giá ba skill đồ hoạ

Cả ba repo được clone vào thư mục scratch cách ly, đọc README/SKILL.md/LICENSE/mã nguồn trước khi cài.

| Skill | Giấy phép / dependency | Khả năng thực tế trong dự án | Quyết định |
| --- | --- | --- | --- |
| **A — ianlintner/ai-pixel-art-image-generation** | MIT. Cần `openai`, `azure-identity`, `google-genai`, `fal-client`, `rembg`, `onnxruntime` và **API key trả phí** (OpenAI/Azure/Gemini/fal). | Môi trường **không có API key nào** (đã kiểm tra biến môi trường). Mọi chức năng tạo ảnh đều phát sinh chi phí. Đầu ra là ảnh AI được downscale + quantize — đúng là thứ brief cảnh báo "không coi là pixel art hoàn chỉnh" nếu không làm sạch. | **Không cài.** Bị chặn bởi API key/chi phí. Ý tưởng QA (palette, kích thước, số frame) đã được đưa vào QA riêng của dự án. Nếu sau này bạn cung cấp key, pipeline nhập ảnh ngoài (`tools/artgen/import_external.py`) đã sẵn sàng làm sạch đầu ra của skill này. |
| **B — Gamezxz/pixel-art-studio** | MIT. Chỉ cần Pillow. Đã grep: không có network, subprocess, eval/exec. | Vẽ từng pixel bằng Python, ramp màu hue-shift, outline/selout, dọn ảnh AI (harden_alpha, despeckle, dedupe, dehalo), preview/silhouette/stats, tài liệu kỹ thuật animation tốt. Phù hợp nhất với pipeline art-bằng-code hiện có. | **Đã cài** vào `.claude/skills/pixel-art-studio` (commit `f8c2466`, kèm LICENSE và `VENDORED.txt`). Đã chạy thử import + vẽ + outline thành công. |
| **C — gididaf/sprite-forge** | README ghi MIT nhưng **repo không có file LICENSE**. Cần `rsvg-convert` (không có trong container; installer dùng `sudo apt-get`). | Pipeline SVG động → raster. SVG render ra cạnh khử răng cưa (anti-aliased), không phải pixel art có kiểm soát từng pixel; frame 64×64 mặc định. | **Không cài.** Rủi ro giấy phép chưa rõ ràng, phụ thuộc hệ thống, và chất lượng pixel không đạt tiêu chí "crisp pixel clusters". |

**Tổ hợp nhỏ nhất đáp ứng yêu cầu:** skill `godot` (đã có) + `pixel-art-studio` (mới) + pipeline Pillow nội bộ `tools/artgen`.

## 3. Pipeline phù hợp với engine

1. Art được **vẽ bằng script Python có tham số** (`tools/artgen/hd/`), deterministic, có thể tái tạo, mỗi asset có metadata (id, loại, kích thước, palette, version, nguồn, trạng thái QA).
2. Ảnh từ nguồn ngoài (AI hoặc vẽ tay) đi qua `import_external.py` dùng `pixelstudio` để harden alpha, khử nhiễu, khoá palette → `assets/` ; bản gốc giữ nguyên trong `art_src/raw/`.
3. `tools/validate_assets.py` + `tools/asset_qa.py` kiểm tra kích thước, alpha nhị phân, palette, frame rỗng, cắt mép, lệch anchor, rung giữa các frame, nhiễu pixel, trùng ID; xuất báo cáo QA.
4. Godot nạp qua `assets/manifest.json` → `SpriteLib`, nay hỗ trợ trường `density` (mật độ pixel) để asset HD và asset cũ cùng tồn tại trong quá trình chuyển đổi.

## 4. Kế hoạch theo thứ tự ưu tiên

| # | Giai đoạn | Nội dung | Điều kiện nghiệm thu |
| --- | --- | --- | --- |
| 1 | Audit (xong) | Báo cáo này, tooling đa nền tảng, cài skill | `check.py` xanh trên Linux |
| 2 | Nền tảng render HD | Stretch `canvas_items` + integer scale, `density` trong manifest, shader lọc pixel-art cho tỉ lệ không nguyên | Game cũ trông như trước, test xanh |
| 3 | Pipeline HD + Style Guide + QA | Palette HD, thư viện vẽ rig, metadata, QA tự động | QA chạy trong `check.py` |
| 4 | Vertical slice | 1 anh hùng HD đầy đủ animation, vũ khí HD, tileset HD, 1 quái HD, tích hợp và chụp ảnh | Ảnh tour cho thấy HD sắc nét, test xanh |
| 5 | Character framework | Class, module kỹ năng, passive, chỉ số mở rộng, registry + validator, màn chọn có lọc/sắp xếp | Thêm nhân vật mới chỉ bằng dữ liệu + art; test bao phủ mọi nhân vật |
| 6 | Mở rộng nội dung | Thêm nhân vật (mục tiêu 12), chuyển dần quái/boss/props sang HD | Mỗi đợt có QA + test |
| 7–8 | Polish, build | Theo lộ trình; build mobile cần môi trường ngoài | — |

Tiến độ thực tế từng giai đoạn được cập nhật trong `DEVELOPMENT_STATUS.md`.

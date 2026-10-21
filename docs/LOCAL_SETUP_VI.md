# Chạy Hexvault trên máy của bạn

## 1. Lấy source
- **Cách A (khuyên dùng):** `git clone https://github.com/hieudtse160939/hexvault.git`, rồi
  `git checkout claude/hd-pixel-art-roguelike-6d4lcx`. Mọi thay đổi đều nằm trên nhánh này.
- **Cách B:** giải nén `hexvault-source-<commit>.zip` (file tôi gửi, tạo bằng `git archive`
  từ đúng commit ghi trong tên file; không có `.git`).

## 2. Cài Godot 4.7.2 (bắt buộc đúng phiên bản)
1. Tải **Godot 4.7.2-stable** (bản thường, không phải .NET/mono) cho hệ điều hành của bạn:
   https://github.com/godotengine/godot/releases/tag/4.7.2-stable
2. Mở Godot → **Import** → chọn file `project.godot` trong thư mục source → **Import & Edit**.
3. Lần mở đầu tiên Godot sẽ import asset (vài phút). Xong thì bấm **F5 (Run)**.
   - Không cần chạy tool Python: mọi sprite và âm thanh đã được tạo sẵn và có trong repo.

Chạy không cần mở editor:
```bash
godot --path <thư-mục-source>                      # chạy game
godot --headless --path <thư-mục-source> --import  # chỉ import asset
```

## 3. Phím
WASD di chuyển · chuột ngắm · chuột trái tấn công · Q / chuột phải dùng skill · Space lướt ·
Tab đổi vũ khí · E tương tác / nói chuyện · I túi đồ · R nạp đạn · M bản đồ · Esc tạm dừng.
Hỗ trợ tay cầm. Bản Android có nút cảm ứng.

## 4. Kiểm tra (tùy chọn, cần Python 3.10+ có Pillow + numpy)
```bash
pip install pillow numpy
set GODOT_BIN=C:\path\Godot_v4.7.2-stable_win64_console.exe   (Windows)
export GODOT_BIN=/path/Godot_v4.7.2-stable_linux.x86_64          (Linux/macOS)
python tools/check.py        # asset + import + 97 test -> phải in "ALL CHECKS PASSED"
```
Nếu không đặt `GODOT_BIN`, `tools/godot_bin.py` sẽ tìm Godot trong `.tools/`; cách cài ở đó xem `BUILD_GUIDE.md`.

## 5. Xuất bản build
Cần export templates 4.7.2. Trong editor: **Editor → Manage Export Templates → Download**.
Sau đó: **Project → Export**, chọn preset Windows / Linux / Android, rồi bấm Export.
Hoặc chạy `python tools/package.py windows|linux|android`.
- Android cần Android SDK và JDK 17+ (xem `BUILD_GUIDE.md`; có cả cách ký APK khi không có SDK).

## 6. Save game
Windows: `%APPDATA%\Hexvault\profile.save` (kèm file `.bak` dự phòng).
Linux: `~/.local/share/Hexvault/`. macOS: `~/Library/Application Support/Hexvault/`.

## 7. Tài liệu
- `docs/SESSION_CONTEXT.md`: toàn bộ context (đưa file này vào session mới để làm tiếp).
- `docs/GUILD_OVERVIEW_VI.md`: Guild và giao diện hiện có.
- `docs/GUILD_RPG.md`: thiết kế hệ thống.
- `docs/ART_STYLE_GUIDE.md`: phong cách đồ họa.
- `docs/ADDING_CHARACTERS.md`: cách thêm nhân vật.
- `docs/qa/animation_coverage.md`: animation hiện có và còn thiếu.

# Hexvault – Tổng quan Guild và Giao diện (GUI)

_Cập nhật 2026-10-21 · nhánh `claude/hd-pixel-art-roguelike-6d4lcx` · 96/96 test qua_

Ảnh chụp thật trong game: `docs/qa/guild_map.png`, `docs/qa/guild_hall.png`.

---

## 1. Map Guild (Hội Mạo Hiểm Giả)

Map được mô tả bằng dữ liệu trong `data/maps/guild.json` (kích thước 32 × 22 ô, đã thu gọn từ 40 × 29 cho bớt trống). Bộ nạp map dùng chung là `scripts/world/map_loader.gd`. Tường được tự vẽ quanh sàn: mặt tường là gỗ + vữa, đỉnh tường là gỗ.

### Các phòng và trạm

| Phòng | Trạm / NPC (bấm **E** để tương tác) | Trang trí |
| --- | --- | --- |
| **Tiền sảnh** (lối vào, chỗ xuất hiện) | **Cổng Xuất phát**: mở Bảng nhiệm vụ | 2 cờ hội, 2 chậu cây, thảm đỏ dẫn vào Đại sảnh |
| **Đại sảnh** | **Lễ tân** (NPC Rime): chào, báo hạng / level / nhiệm vụ kế tiếp, có nút tắt sang các dịch vụ<br>**Bảng nhiệm vụ**: chọn nhiệm vụ để vào dungeon | Lò sưởi đá có lửa động, quầy bar, 4 bàn kèm ghế dài, thảm tròn lớn, 2 cột trụ |
| **Sảnh Anh hùng** | **Hero Shrine**: đổi nhân vật trong 5 hero<br>**Rune Forge**: nâng cấp vĩnh viễn bằng shard<br>**Bảng Quest**: quest và thành tựu | Cờ, chậu cây |
| **Sân tập** | 2 **hình nhân tập**: nhận đòn thật, hiện số sát thương và DPS | Nền đá, sàn đấu gỗ ở giữa, giá vũ khí, thùng, rương |
| **Kho vũ khí & Thư viện** | **Giá trang bị**: mở túi đồ và trang bị<br>**Thư viện kỹ năng**: cây kỹ năng, chọn skill | Giá vũ khí, kệ sách, thùng gỗ |
| **Cửa hàng** | **Bàn bán hàng** (NPC Cog): mua và bán đồ | Kệ hàng, thùng, rương, chậu cây |

- **Ánh sáng:** toàn sảnh hơi tối và ấm. Có quầng sáng ở đèn lồng trên tường, lò sưởi, nến trên bàn, quầy bar và cổng (màu tím).
- **Nhãn tên phòng** hiện trên sàn: HALL OF HEROES, GREAT HALL, ARMORY & LIBRARY, TRAINING YARD, GUILD SHOP, ENTRANCE.
- **Đã kiểm tra bằng test:** tường chặn được nhân vật, đi bộ qua cửa tới được mọi trạm, chỗ xuất hiện không bị kẹt trong đồ đạc.

### Dịch vụ sau từng trạm

- **Nhiệm vụ:** 3 nhiệm vụ, nhiệm vụ sau mở khi hoàn thành nhiệm vụ trước.

  | Nhiệm vụ | Độ khó | Level đề nghị | Số tầng |
  | --- | --- | --- | --- |
  | Forgotten Catacombs | Normal | 1 | 2 |
  | Ember Vault | Hard | 5 | 3 |
  | Clockwork Abyss | Nightmare | 10 | 3 |

  Mỗi nhiệm vụ hiện mô tả, mục tiêu, phần thưởng, điều kiện mở và số lần đã hoàn thành.
- **Trang bị:**
  - 6 ô trang bị: Vũ khí, Mũ, Giáp, Găng, Giày, Phụ kiện.
  - 5 độ hiếm, có cả chữ lẫn màu: Common, Uncommon, Rare, Epic, Legendary.
  - Đồ có affix ngẫu nhiên.
  - Có so sánh chỉ số trước khi mặc (+ xanh / − đỏ).
  - Mỗi class chỉ dùng được một số loại vũ khí; mặc sai sẽ báo lý do.
- **Cửa hàng:** 6 món trang bị + 2 sách kỹ năng. Hàng đổi sau mỗi chuyến đi. Mỗi món chỉ mua được 1 lần. Bán đồ trong túi để lấy vàng.
- **Kỹ năng:**
  - Mỗi hero có 10 talent chia 4 nhánh; nhánh "Weapon Mastery" chỉ có tác dụng khi cầm đúng loại vũ khí.
  - Đặt lại talent tốn vàng.
  - 12 sách dạy skill + 1 sách cộng điểm kỹ năng.
  - Chọn skill đang dùng (phím Q / chuột phải).

---

## 2. Giao diện (GUI)

### Menu và màn hình

| Màn hình | Nội dung |
| --- | --- |
| **Menu chính** | Continue (khóa khi chưa có save; hiện tên và level hero), New Game, Settings, Quit |
| **Chọn nhân vật** | 5 thẻ nhân vật có sprite chạy thật, mô tả lối chơi, skill / passive, chỉ số; nút "Begin the adventure". Có hỏi xác nhận khi ghi đè save cũ (save cũ được sao lưu ra `profile.previous.save`) |
| **HUD trong Guild** | Bảng nhân vật: chân dung, tên + level, hạng, thanh EXP, vàng, shard, điểm kỹ năng chưa dùng<br>Nút nhanh: Missions / Bag / Skills / Menu<br>Gợi ý phím đọc từ phím đang gán thật<br>Lời nhắc "Press E: …" khi đứng gần trạm |
| **HUD trong dungeon** | Thanh HP, giáp, xu, shard, vũ khí đang cầm, đạn, skill + thời gian hồi, thanh lướt, level + EXP, mục tiêu hiện tại, thanh máu boss, bản đồ nhỏ |
| **Bảng Lễ tân** | Lời chào, hạng, level, số nhiệm vụ đã xong, nhắc điểm kỹ năng; nút sang Bảng nhiệm vụ / Trang bị / Kỹ năng |
| **Bảng nhiệm vụ** | Danh sách (đã xong / bị khóa) và chi tiết nhiệm vụ; nút Embark |
| **Túi đồ / Trang bị** | 6 ô trang bị, chỉ số cuối cùng, túi 40 ô, chi tiết món đồ (chỉ số ngẫu nhiên, affix), so sánh; nút Equip / Unequip / Sell / Read (sách)<br>Mở trong Guild hoặc bằng phím **I** trong dungeon |
| **Cửa hàng** | Danh sách hàng có giá, chi tiết + so sánh, nút mua, nút "Sell items" |
| **Cây kỹ năng** | Các nhánh có thanh cuộn, rank của từng talent, điều kiện vũ khí, danh sách skill đã học để chọn skill đang dùng |
| **Tạm dừng (dungeon)** | Resume, Inventory, Settings, Retreat to the Guild |
| **Chết** | Hồi sinh bằng shard, hoặc về Guild; nói rõ mất / giữ gì |
| **Kết quả chuyến đi** | Thắng / thua, nhiệm vụ, EXP, vàng, shard, danh sách đồ nhặt được; nút "Return to the Guild" / "Retry mission" |
| **Settings** | Âm lượng, rung màn hình, số sát thương, toàn màn hình, vsync, FPS, hỗ trợ ngắm, nút cảm ứng, cỡ UI |

### Phong cách

- Chữ pixel. Các menu trong Guild dùng khung gỗ sẫm viền đồng.
- Độ hiếm luôn hiện bằng chữ ([C] / [U] / [R] / [E] / [L]) chứ không chỉ bằng màu.
- Khi mở menu, game tạm dừng và nhân vật không di chuyển hay bắn. Cú bấm dùng để đóng menu cũng không làm nhân vật bắn.

### Phím

WASD di chuyển · chuột ngắm · chuột trái tấn công · Q / chuột phải dùng skill · Space lướt · Tab đổi vũ khí · E tương tác · I túi đồ · R nạp đạn · M bản đồ · Esc tạm dừng. Hỗ trợ tay cầm và cảm ứng.

---

## 3. Còn thiếu / sẽ làm

- Chưa có map bên ngoài Guild (thị trấn Kingdom of Dawn, rừng…). Cổng Xuất phát hiện mở Bảng nhiệm vụ để vào dungeon.
- NPC chưa có hội thoại riêng (trừ Lễ tân), chưa đi lại.
- Hero chưa có khung hình niệm phép / vung đòn riêng; chuyển động tấn công nằm ở vũ khí.
- Chưa có chế tạo / nâng cấp đồ và endgame.

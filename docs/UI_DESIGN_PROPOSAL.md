# 🎨 IADA-GIS UI/UX Design Proposal

## Referensi
- Behance: Smart Farming App — Agriculture Mobile App UI
- Target: Petani yang ingin cek kesesuaian tanaman di lokasinya
- Platform: Web + Android
- Style: Modern Clean

---

## 1. Color Palette — "Earth Green + Harvest Gold"

Terinspirasi dari alam pertanian Kalimantan Timur.

| Role | Hex | Kegunaan |
|------|-----|----------|
| **Primary** | `#15803D` | AppBar, tombol utama, ikon aktif |
| **On Primary** | `#FFFFFF` | Teks di atas primary |
| **Secondary** | `#22C55E` | Chip, badge, status aktif |
| **On Secondary** | `#0F172A` | Teks di atas secondary |
| **Accent/CTA** | `#A16207` | Tombol aksi, highlight, HWSD scoring |
| **On Accent** | `#FFFFFF` | Teks di atas accent |
| **Background** | `#F0FDF4` | Latar belakang utama |
| **Foreground** | `#14532D` | Teks utama |
| **Card** | `#FFFFFF` | Card, sheet, dialog |
| **Card Foreground** | `#14532D` | Teks di card |
| **Muted** | `#E8F0F1` | Placeholder, disabled |
| **Muted Foreground** | `#475569` | Teks sekunder |
| **Border** | `#BBF7D0` | Garis pembatas |
| **Destructive** | `#DC2626` | Error, hapus |
| **Ring** | `#15803D` | Focus indicator |

---

## 2. Typography — Poppins + Open Sans

| Element | Font | Weight | Size |
|---------|------|--------|------|
| H1 (AppBar Title) | Poppins | Bold (700) | 24px |
| H2 (Section Title) | Poppins | SemiBold (600) | 20px |
| H3 (Card Title) | Poppins | Medium (500) | 16px |
| Body | Open Sans | Regular (400) | 14px |
| Caption | Open Sans | Regular (400) | 12px |
| Button | Poppins | Medium (500) | 14px |
| Label | Open Sans | SemiBold (600) | 12px |

---

## 3. Layout Structure — Bottom Navigation

```
┌─────────────────────────────┐
│  🌾 IADA-GIS     [📍 Lokasi] │  ← AppBar
├─────────────────────────────┤
│                             │
│     [Konten Halaman]        │  ← Body
│                             │
├─────────────────────────────┤
│  💬 Chat  🗺️ Peta  📊 Data  │  ← Bottom Nav
└─────────────────────────────┘
```

### 3 Halaman Utama:

**💬 Chat (Home)**
- Chat screen dengan input bar + GPS button
- Quick action chips saat pertama buka:
  - "Cek kesesuaian tanah"
  - "Cari lahan terdekat"
  - "Info pertanian"
- Chat bubble bot → card dengan sections

**🗺️ Peta**
- Full screen FlutterMap
- Floating search bar di atas
- Layer toggle (kawasan pertanian, lahan padi)
- Marker lokasi user (biru pulsing)
- Bottom sheet info saat tap marker/polygon

**📊 Data (HWSD)**
- Input lokasi (GPS atau manual)
- Card hasil scoring per komoditas
- Visual gauge meter (S1→N)
- Detail parameter tanah

---

## 4. Component Design

### 4.1 Chat Bubble (Bot Response)
```
┌─────────────────────────────────┐
│ 🌾 Rekomendasi Tanaman          │  ← Header (green)
├─────────────────────────────────┤
│ Lokasi: Samarinda (-0.50, 117.15)│
│                                 │
│ ✅ Padi Sawah: Sangat Sesuai    │  ← HWSD Score
│    ████████████████████ 100%    │  ← Progress bar
│                                 │
│ 🟡 Jagung: Cukup Sesuai         │
│    ██████████████░░░░░░  70%    │
│                                 │
│ 📄 Sumber: Data BPS Kaltim 2024 │  ← Citations
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │🗺️ Lihat  │ │📊 Detail │      │  ← Action buttons
│ │   Peta   │ │  Tanah   │      │
│ └──────────┘ └──────────┘      │
└─────────────────────────────────┘
```

### 4.2 HWSD Score Card
```
┌─────────────────────────────────┐
│ 🟠 Sesuai Bersyarat (S3)        │  ← Status badge
│ Padi Sawah                      │
├─────────────────────────────────┤
│                                 │
│ pH Tanah     ████████░░  4.9   │  ← Parameter bars
│ Tekstur      ██████████  9.0   │
│ Drainase     ████████░░  MW    │
│ Karbon Org.  ████████░░  1.27% │
│                                 │
│ ⚠️ Faktor pembatas: pH Tanah   │
│ 💡 Perlu pengapuran untuk       │
│    meningkatkan pH              │
└─────────────────────────────────┘
```

### 4.3 Quick Action Chips (Home)
```
┌─────────────────────────────────┐
│                                 │
│    🌾 Selamat Datang!           │
│    Tanya apa saja tentang       │
│    pertanian Kaltim             │
│                                 │
│  ┌─────────────┐ ┌───────────┐ │
│  │📍 Cek Tanah │ │🔍 Cari    │ │
│  │   di Saya   │ │  Lahan    │ │
│  └─────────────┘ └───────────┘ │
│  ┌─────────────┐ ┌───────────┐ │
│  │📊 Kesesuaian│ │📚 Info    │ │
│  │   Lahan     │ │ Dokumen   │ │
│  └─────────────┘ └───────────┘ │
│                                 │
└─────────────────────────────────┘
```

### 4.4 Input Bar dengan GPS
```
┌─────────────────────────────────┐
│ 📍 Samarinda (-0.50, 117.15) ✕  │  ← Location indicator
├─────────────────────────────────┤
│ [📍] [ Ketik pesan...     ] [➤] │  ← Input bar
└─────────────────────────────────┘
```

### 4.5 Peta Screen
```
┌─────────────────────────────────┐
│ [🔍 Cari lokasi...        ] [⚙] │  ← Floating search
├─────────────────────────────────┤
│                                 │
│         🗺️ MAP                  │
│                                 │
│    📍 User                      │
│    ┌───┐                        │
│    │   │ ← Polygon kawasan     │
│    └───┘                        │
│                                 │
├─────────────────────────────────┤
│ 📊 3 lahan ditemukan    [List]  │  ← Bottom info
└─────────────────────────────────┘
```

---

## 5. Spacing & Radius

| Element | Border Radius | Padding |
|---------|--------------|---------|
| Card | 16px | 16px |
| Button | 24px (pill) | 12px 24px |
| Chip | 20px | 8px 16px |
| Input | 24px | 12px 16px |
| Dialog | 20px | 24px |
| Bottom Sheet | 24px (top) | 16px |
| Badge | 12px | 4px 12px |

---

## 6. Shadows & Elevation

```dart
// Card shadow
BoxShadow(
  color: Colors.black.withOpacity(0.05),
  blurRadius: 10,
  offset: Offset(0, 2),
)

// Floating element (FAB, search bar)
BoxShadow(
  color: Colors.black.withOpacity(0.1),
  blurRadius: 20,
  offset: Offset(0, 4),
)
```

---

## 7. Iconography

Gunakan **Material Icons** (sudah built-in di Flutter):
- 💬 → `Icons.chat_bubble_outline`
- 🗺️ → `Icons.map_outlined`
- 📊 → `Icons.analytics_outlined`
- 📍 → `Icons.location_on`
- 🌾 → `Icons.grass` / `Icons.eco`
- 🔍 → `Icons.search`
- ⚙️ → `Icons.settings_outlined`
- ✅ → `Icons.check_circle`
- ❌ → `Icons.cancel`
- 🟠 → `Icons.warning_amber`

---

## 8. Animasi

- **Page transition:** Slide dari kanan (300ms ease)
- **Chat bubble:** Fade in + slide up (200ms)
- **Card appear:** Scale dari 0.95 → 1.0 (200ms)
- **Loading:** Skeleton shimmer (hijau muda)
- **Location pulse:** Pulsing circle di marker (loop)

---

## 9. Responsive Breakpoints

| Breakpoint | Width | Layout |
|------------|-------|--------|
| Mobile | < 600px | Single column, bottom nav |
| Tablet | 600-1024px | Sidebar + content |
| Desktop | > 1024px | Sidebar + content + detail panel |

---

## 10. File Changes Needed

### New Files:
1. `frontend/lib/app/theme.dart` — Custom theme dengan palette di atas
2. `frontend/lib/app/app.dart` — MaterialApp dengan theme + bottom nav
3. `frontend/lib/features/home/screens/home_screen.dart` — Home dengan quick actions
4. `frontend/lib/features/map/screens/map_screen.dart` — Full map screen
5. `frontend/lib/features/data/screens/data_screen.dart` — HWSD data screen

### Modified Files:
1. `frontend/lib/main.dart` — Tambah bottom navigation
2. `frontend/lib/features/chat/screens/chat_screens.dart` — Update UI
3. `frontend/lib/features/chat/screens/widgets/chat_bubble.dart` — Redesign bubble
4. `frontend/lib/features/chat/screens/widgets/chat_input_bar.dart` — Sudah diupdate
5. `frontend/lib/features/map/screens/widgets/map_view.dart` — Full map

---

## Estimasi Implementasi

| Task | Estimasi |
|------|----------|
| Theme & color system | 1 jam |
| Bottom navigation + routing | 2 jam |
| Home screen redesign | 2 jam |
| Chat bubble redesign | 2 jam |
| Map screen redesign | 3 jam |
| HWSD data screen | 2 jam |
| Animasi & polish | 2 jam |
| **Total** | **~14 jam** |

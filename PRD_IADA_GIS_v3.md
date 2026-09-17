# Product Requirements Document (PRD)
## IADA-GIS — Intelligent Agriculture Data Assistant dengan Integrasi Geospasial
### Roadmap Menuju Kompetisi AITeC

**Versi:** 3.0
**Tanggal:** 25 Agustus 2026
**Deadline Target:** ~1 bulan dari sekarang (~22-25 September 2026)
**Tim:** 1 orang (solo developer) — Muhammad Ridho

---

## 1. Ringkasan Perubahan dari PRD v2

PRD v2 (21 Juli 2026) fokus menstabilkan backend dan menyambungkan chat + peta — **selesai dan tervalidasi**. PRD v3 ini fokus pada scope tambahan yang sebelumnya belum masuk rencana resmi:

1. **HWSD land suitability scoring** — fitur baru, **wajib** untuk submission, **status data belum diverifikasi**
2. Fitur pending dari PRD v2 yang belum sempat dikerjakan (GPS, halaman peta terpisah, fix kecil)
3. **Deployment penuh** — belum dimulai sama sekali, wajib ada sebelum demo

**Peringatan jujur:** dengan 4 minggu dan HWSD yang statusnya masih "belum tahu datanya bisa dipakai atau tidak", ini timeline agresif. PRD ini disusun dengan **checkpoint GO/NO-GO di akhir Minggu 1** khusus untuk HWSD — supaya kalau ada masalah data, masih ada waktu untuk pivot scope, bukan ketahuan gagal mendekati deadline.

---

## 2. Status Saat Ini (25 Agustus 2026)

| Komponen | Status |
|---|---|
| Backend RAG pipeline (chat, PostGIS, ChromaDB) | ✅ Selesai, tervalidasi end-to-end |
| Chat screen Flutter | ✅ Selesai, termasuk guard anti-kirim-ganda |
| Bottom sheet peta (Polygon + MultiPolygon) | ✅ Selesai, tervalidasi dengan data asli |
| Tombol GPS di chat input | 🔲 Belum, `geolocator` terpasang tapi tidak dipakai |
| Input lokasi manual (teks/tap peta) | 🔲 Belum, parameter sudah ada tapi selalu `null` |
| Halaman peta terpisah (dedicated screen) | 🔲 Belum, baru tahap prompt desain UI/UX |
| `/health` — status LLM hardcoded salah | 🔲 Bug kecil belum diperbaiki |
| Rendering markdown di jawaban chat | 🔲 Belum, teks `**bold**` masih mentah |
| **HWSD land suitability scoring** | 🔲 **Belum mulai. Data belum diverifikasi cakupan/atributnya untuk Kaltim** |
| Deployment (backend + web + APK) | 🔲 Belum mulai sama sekali |
| Migrasi Docker lokal → Supabase cloud | 🔲 Belum, wajib sebelum deploy |

---

## 3. Keputusan yang Harus Diambil di Minggu 1 — Tidak Bisa Ditunda

### 3.1 GO/NO-GO untuk HWSD (Paling Kritis)

Sebelum menulis satu baris kode untuk fitur ini, verifikasi dulu:

- [ ] Cakupan spasial HWSD v2.0 benar-benar meng-cover wilayah Kalimantan Timur (bukan cuma "Indonesia" secara umum — cek resolusi ~1km apakah cukup detail untuk level kecamatan/kabupaten)
- [ ] Atribut yang dibutuhkan (tekstur, pH, drainase, karbon organik) benar-benar lengkap untuk grid yang relevan, bukan banyak sel kosong/`NULL`
- [ ] Lisensi HWSD memperbolehkan penggunaan untuk kompetisi/riset (FAO biasanya open, tapi cek eksplisit)
- [ ] Format file bisa dibaca dengan tool yang kamu kuasai (`rasterio`/GDAL di Python)

**Keputusan di akhir Minggu 1:**
- **GO** → lanjut ke implementasi sesuai jadwal Minggu 2
- **NO-GO (data tidak layak)** → karena ini fitur wajib, opsi realistisnya: (a) cari sumber data alternatif untuk parameter tanah Kaltim yang lebih granular (misal data BBSDLP/Balittanah kalau tersedia publik), atau (b) turunkan cakupan fitur (misal cuma untuk 1-2 komoditas utama, bukan semua tanaman) supaya tetap bisa diklaim sebagai fitur jalan meski lebih sempit dari rencana awal

**Jangan mulai kerjakan fitur lain sebelum checkpoint ini selesai** — kalau NO-GO, seluruh roadmap Minggu 2-4 perlu disusun ulang, jadi lebih baik tahu di awal.

### 3.2 Docker Lokal vs Supabase Cloud

Sudah dibahas di PRD v2, belum diputuskan. **Wajib final di Minggu 1** karena migrasi database butuh waktu dan harus selesai sebelum deployment Minggu 3.

---

## 4. Prioritas Fitur — P0/P1/P2

Supaya jelas mana yang dikorbankan duluan kalau waktu mepet:

**P0 — Wajib ada untuk demo, tidak bisa dikompromikan:**
- HWSD scoring berfungsi (walau scope-nya mungkin menyempit setelah GO/NO-GO)
- Aplikasi bisa diakses online (backend + Flutter web live)
- Input lokasi (GPS **atau** manual — minimal salah satu, karena HWSD scoring butuh titik lokasi user)
- Fix `/health` (effort kecil, tidak ada alasan untuk skip)

**P1 — Harusnya ada, tapi bisa dikorbankan kalau P0 belum kelar:**
- Halaman peta terpisah
- Rendering markdown
- Build APK Android
- Input lokasi via tap peta (kalau GPS sudah cukup, ini nice-to-have)

**P2 — Ditunda tanpa penyesalan kalau waktu habis:**
- UI/UX polish menyeluruh dari hasil review desain
- Layer GIS tambahan di luar yang sudah ada
- Testing sistematis lebih dari 15 query
- Optimasi latensi LLM

---

## 5. Roadmap 4 Minggu

### Minggu 1 (25-31 Agustus): Verifikasi & Keputusan Fondasi

| Task | Detail | Prioritas |
|---|---|---|
| Verifikasi data HWSD | Download, inspeksi cakupan Kaltim, cek kelengkapan atribut (Section 3.1) | P0 |
| **Checkpoint GO/NO-GO HWSD** | Akhir minggu — keputusan final | P0 |
| Putuskan Docker vs Supabase | Final, mulai migrasi kalau pindah ke Supabase | P0 |
| Fix `/health` LLM status | Quick fix, `main.py` | P0 |
| Implementasi GPS button di chat input | `geolocator`, permission handling | P0 |
| Rendering markdown | Package `flutter_markdown`, ganti `Text()` biasa di bubble | P1 |

**Checkpoint akhir Minggu 1:** Keputusan HWSD dan database sudah final dan tidak berubah lagi. GPS button berfungsi (user bisa kirim lokasi tanpa ketik manual).

---

### Minggu 2 (1-7 September): HWSD Core (kalau GO) + Migrasi Database

| Task | Detail | Prioritas |
|---|---|---|
| Clip & convert HWSD raster → PostGIS | Ekstrak nilai atribut jadi queryable per titik/area | P0 |
| Desain algoritma scoring | Logika overlay: bandingkan kebutuhan tanaman vs atribut tanah → skor/kategori (Sesuai/Cukup Sesuai/Tidak Sesuai — bukan ML, murni rule-based sesuai rencana) | P0 |
| Endpoint scoring baru | `POST /land-suitability` atau terintegrasi ke pipeline chat | P0 |
| Migrasi data ke Supabase (kalau pindah) | Jalankan ulang semua SQL setup + re-import shapefile & data HWSD | P0 |
| **Kalau NO-GO di Minggu 1:** alokasikan minggu ini untuk scope alternatif HWSD | Sesuai keputusan Section 3.1 | P0 |

**Checkpoint akhir Minggu 2:** Query skor kesesuaian lahan untuk minimal 1 titik koordinat & 1 komoditas berhasil dan masuk akal secara manual (verifikasi dengan pengetahuan domain — apakah hasilnya secara kasar "make sense").

---

### Minggu 3 (8-14 September): Integrasi UI + Deployment

| Task | Detail | Prioritas |
|---|---|---|
| Tampilkan hasil scoring di chat/UI | Bisa berupa badge baru, card khusus, atau extend bottom sheet peta | P0 |
| Input lokasi manual via tap peta | Kalau GPS sudah cukup di Minggu 1, ini opsional | P1 |
| Halaman peta terpisah | Implementasi sesuai hasil desain (kalau sudah ada), atau versi sederhana kalau desain belum final | P1 |
| Deploy backend | Railway/Render, environment variables, test dari URL publik | P0 |
| Deploy Flutter web | Firebase Hosting/Vercel | P0 |
| Test end-to-end dari deployment | Bukan localhost lagi | P0 |

**Checkpoint akhir Minggu 3:** Aplikasi bisa diakses dari internet oleh orang lain (bukan cuma localhost kamu), fitur HWSD scoring bisa dicoba dari situ.

---

### Minggu 4 (15-21 September): Testing, Polish, Persiapan Demo

| Task | Detail | Prioritas |
|---|---|---|
| Build APK Android | Test di device fisik | P1 |
| Testing sistematis | Minimal 15 query (campuran: chat biasa, spasial, HWSD scoring) | P0 |
| Fix bug kritis dari testing | Prioritas yang mengganggu demo | P0 |
| Quick-win UI polish | Ambil dari hasil review Claude Design, cuma yang low-effort | P2 |
| Rekam video demo | 5-8 menit, skenario paling representatif (termasuk HWSD sebagai nilai jual utama) | P0 |
| Dokumentasi teknis ringkas | Arsitektur, cara jalankan ulang | P1 |
| Buffer | Sisa waktu untuk hal tak terduga | — |

**Checkpoint akhir Minggu 4 / Deadline:** Submission siap — aplikasi live, video demo selesai, dokumentasi ada.

---

## 6. Manajemen Risiko

| Risiko | Kemungkinan | Dampak | Mitigasi |
|---|---|---|---|
| **Data HWSD tidak layak pakai untuk Kaltim** | Sedang-Tinggi (belum diverifikasi) | Sangat Tinggi (fitur wajib) | Checkpoint GO/NO-GO di Minggu 1, siapkan rencana B (data alternatif atau scope sempit) sebelum mulai coding |
| Migrasi database molor/bermasalah | Sedang | Tinggi (blok deployment) | Putuskan dan mulai migrasi di Minggu 1, jangan tunda ke Minggu 3 |
| Algoritma scoring HWSD ternyata butuh domain expertise pertanian yang lebih dalam dari perkiraan | Sedang | Sedang | Kalau buntu, sederhanakan jadi kategori kasar (3 level) daripada skor numerik presisi — tetap valid sebagai "bukan ML prediktif, murni overlay data" |
| Waktu habis sebelum deployment selesai | Sedang | Sangat Tinggi (tidak ada yang bisa didemo) | Deployment adalah P0 mutlak — kalau di Minggu 3 checkpoint tidak tercapai, korbankan P1/P2 (halaman peta terpisah, polish UI) tanpa ragu |
| Solo dev kelelahan dengan scope sebesar ini dalam 4 minggu | Tinggi | Tinggi | Checkpoint mingguan wajib dicek jujur — kalau satu minggu meleset, jangan coba "kejar" di minggu berikutnya dengan menambah 2x kerja, potong scope P2 dulu |

---

## 7. Yang Sengaja TIDAK Masuk Roadmap Ini (Defer)

- Optimasi latensi LLM (short-circuit, ganti provider) — technical debt yang sudah disepakati ditunda sejak PRD v2
- Layer GIS tambahan di luar kawasan pertanian + HWSD
- OCR untuk PDF hasil scan
- UAT formal dengan responden
- Load testing
- CI/CD

---

## 8. Catatan Konsistensi dengan PRD v2

Semua yang sudah **selesai** di PRD v2 (backend inti, chat, bottom sheet peta) **tidak diulang** di roadmap ini — itu fondasi yang sudah solid dan tidak perlu disentuh lagi kecuali kalau testing di Minggu 4 menemukan regresi.

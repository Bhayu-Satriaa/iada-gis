# Baseline Latensi — SEBELUM Tahap 1

Diukur pada 2026-10-01, backend lokal, model `gemini-3-flash-preview`.

| # | Query | Wall | LLM (`generate_answer`) | Pipeline non-LLM | Panjang jawaban |
|---|-------|------|--------------------------|------------------|-----------------|
| 1 | cek kesesuaian lahan di samarinda untuk padi | 8,3 s | — | — | 1557 char |
| 2 | tampilkan kawasan pertanian kutai timur | 10,6 s | — | — | 1669 char |
| 3 | lahan di kutai barat cocok untuk jagung? | 6,5 s | 5.178 ms | ≈ 1,3 s | 1221 char |
| 4 | cek kesesuaian lahan di samarinda untuk padi | 8,3 s | 7.827 ms | ≈ 0,5 s | 1626 char |

## Kesimpulan

- **LLM = ~80% dari total waktu.** Pipeline non-LLM hanya ~0,5–1,3 s.
- Throughput model ≈ **60 token/detik** (1626 char ≈ 450 token dalam 7,8 s).
- Rincian pipeline (dari log backend):
  - GIS layers query: **17–60 ms**
  - Vector search (ChromaDB + sentence-transformers): termasuk dalam sisa
  - Geocoding (Nominatim): ~0,5 s
  - HWSD scoring: cepat (skoring 513 polygon = 0,3 s)
- **Tidak ada timeout**: pada sesi sebelumnya pernah tercatat 51.087 ms untuk
  jawaban sepanjang 1758 char — panjang serupa tapi 3x lebih lama. Jadi variasi
  beban server Google adalah risiko nyata, dan tanpa timeout variasi itu jadi hang.

## Target setelah Tahap 1

- Token pertama terlihat: **~1–2 s** (sekarang 6,5–10,6 s tanpa umpan balik)
- Total selesai: **~3–6 s**
- Batas keras **20 s** lalu jatuh ke `_fallback_answer`, bukan menggantung

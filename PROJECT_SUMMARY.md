# 📋 IADA-GIS — Project Summary (AI Reference)

> **Dokumen ini adalah acuan untuk AI** agar dapat memahami progress, arsitektur, dan status implementasi project IADA-GIS secara akurat.
> Diperbarui terakhir: 2026-09-15

---

## 🧭 Gambaran Umum

**IADA-GIS** (Intelligent Agriculture Data Assistant — Geographic Information System) adalah aplikasi asisten pertanian berbasis AI untuk wilayah **Kalimantan Timur**. Pengguna bisa bertanya dalam Bahasa Indonesia tentang pertanian, dan sistem akan menjawab dengan data spasial (peta), data dokumen, dan analisis kesesuaian lahan (HWSD), beserta jawaban natural language dari LLM.

**Target pengguna:** Petani, penyuluh pertanian, dan instansi dinas pertanian di Kaltim.

---

## 🏗️ Arsitektur Sistem

```text
Flutter App (Android/Web)
        │  HTTP (Dio)
        ▼
FastAPI Backend (Python)
        │
    ┌───┼────────────────┬──────────────┐
    ▼   ▼                ▼              ▼
PostGIS ChromaDB        HWSD           LLM
(Map)   (Vector/RAG)    (SQLite cache) (Gemini)
```

### Alur Query Utama:
1. User ketik pertanyaan di chat Flutter
2. Frontend kirim ke `POST /api/v1/chat`
3. Backend: **Query Parser** (regex NLP) → ekstrak intent (tanya peta, kesesuaian lahan, info dokumen), lokasi, jenis tanaman, radius
4. **Geocoding** via Nominatim (OSM) + fallback hardcoded Kaltim
5. **Spatial Search** di PostGIS (radius-based, filter kategori) → geojson polygon
6. **Vector Search** di ChromaDB (semantic search dokumen)
7. **HWSD Scoring** (Jika intent kesesuaian lahan): Cek koordinat ke HWSD raster → ambil data tanah dari SQLite cache → Rule-based scoring untuk komoditas (S1/S2/S3/N)
8. **LLM** (Gemini) generate jawaban dari context gabungan (GIS + Documents + HWSD)
9. Response JSON dikirim balik ke Flutter
10. Flutter tampilkan chat bubble + peta (jika ada geojson) + HWSD card (jika ada hasil kesesuaian lahan)

---

## 🛠️ Tech Stack

### Backend
| Komponen | Teknologi | Status |
|---|---|---|
| Web Framework | FastAPI + Uvicorn | ✅ Running |
| Database Spatial | PostgreSQL 15 + PostGIS 3.3 | ✅ Connected |
| Vector DB | ChromaDB (persistent) | ✅ Running |
| Land Suitability (HWSD) | Rasterio + SQLite (cache) / MDB fallback | ✅ Active |
| Embedding Model | paraphrase-multilingual-MiniLM-L12-v2 | ✅ Active |
| LLM | Google Gemini (via google-genai) | ✅ Active |
| Geocoding | Nominatim OSM + fallback hardcoded | ✅ Active |
| GIS Processing | GeoPandas, Shapely | ✅ Active |
| Document Loader | LangChain + PyPDF + OpenPyXL | ✅ Active |
| OCR | Pytesseract + pdf2image | ⚠️ Terinstall, belum diintegrasikan |
| Containerization | Docker Compose (hanya PostgreSQL) | ⚠️ Parsial |

### Frontend
| Komponen | Teknologi | Status |
|---|---|---|
| Framework | Flutter (Dart, SDK ^3.10.7) | ✅ Running |
| State Management | Riverpod v2 (flutter_riverpod) | ✅ Active |
| HTTP Client | Dio v5 | ✅ Active |
| Routing | go_router v13 | ✅ Installed, belum dipakai |
| Map | flutter_map v8 + latlong2 | ✅ Active |
| Tile Layer | OpenStreetMap | ✅ Active |
| Location | geolocator v11 | ✅ Installed, belum dipakai di UI |
| Env Config | flutter_dotenv | ✅ Active |
| Target Platform | Android + Web (web folder ada) | ✅ Android running |

---

## 📁 Struktur File Project

```
iada_gis/
├── backend/
│   ├── app/
│   │   ├── main.py                    # FastAPI entry, CORS, register 7 routers
│   │   ├── core/config.py
│   │   ├── models/schemas.py
│   │   ├── routers/
│   │   │   ├── pipeline.py            # /ask, /ask-simple, /pipeline-debug
│   │   │   ├── chat.py                # /chat (endpoint utama frontend)
│   │   │   ├── vector.py
│   │   │   ├── spatial.py
│   │   │   ├── geocode.py
│   │   │   ├── query.py
│   │   │   └── ingestion.py           # batch-ingest, list-files
│   │   └── services/
│   │       ├── pipeline_service.py    # ✅ Orchestrator RAG pipeline lengkap
│   │       ├── query_parser.py        # ✅ NLP regex parser
│   │       ├── geocode_service.py     # ✅ Nominatim + fallback Kaltim
│   │       ├── database.py            # ✅ PostgreSQL + PostGIS (connection pool)
│   │       ├── chroma_service.py      # ✅ ChromaDB vector service
│   │       ├── document_loader.py     # ✅ PDF, SHP, CSV, XLSX loader
│   │       ├── llm_service.py         # ✅ Google Gemini generate answer
│   │       └── batch_ingest.py        # ✅ Batch ingest semua file di /data
│   ├── data/documents/ + data/jigd/
│   ├── chroma_db/
│   └── test_all.py, test_integration.py, test_shapefile.py
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart                  # Entry → ChatScreens
│   │   ├── core/
│   │   │   ├── network/api_service.dart       # ✅ Dio ApiService
│   │   │   └── constants/api_constants.dart   # ✅ baseUrl, endpoint
│   │   ├── features/
│   │   │   ├── chat/
│   │   │   │   ├── models/chat_message.dart   # ✅ ChatMessage, ChatResponse, UIMessage
│   │   │   │   ├── providers/chat_providers.dart # ✅ ChatNotifier, isLoadingProvider
│   │   │   │   └── screens/
│   │   │   │       ├── chat_screens.dart       # ✅ Chat screen utama
│   │   │   │       └── widgets/
│   │   │   │           ├── chat_bubble.dart    # ✅ Bubble + spatial badge
│   │   │   │           ├── chat_input_bar.dart # ✅ Input bar
│   │   │   │           └── citations_chip.dart # ✅ Chip sumber dokumen
│   │   │   └── map/
│   │   │       ├── providers/map_provider.dart # ✅ MapNotifier
│   │   │       ├── screens/
│   │   │       │   ├── map_screen.dart         # ❌ File kosong
│   │   │       │   └── widgets/
│   │   │       │       ├── map_view.dart       # ✅ FlutterMap + polygon render
│   │   │       │       └── map_bottom_sheet.dart # ✅ Modal bottom sheet
│   │   │       └── utils/
│   │   │           └── geojson_parser.dart     # ❌ Hanya komentar
│   │   └── shared/widgets/loading_indicator.dart # ✅
│   └── test/features/map/                        # ⚠️ Minimal
│
├── docker-compose.yml                 # ⚠️ Hanya PostgreSQL
├── init.sql                           # SQL init schema
└── docs/                              # ❌ Kosong
```

---

## ✅ Fitur yang Sudah Selesai (Backend)

| Fitur | File | Keterangan |
|---|---|---|
| FastAPI setup + CORS | main.py | 8 router terdaftar, /health check valid |
| Query Parser NLP | query_parser.py | Regex: intent, lokasi, tanaman, radius, kategori |
| Geocoding | geocode_service.py | Nominatim + 20+ kota Kaltim hardcoded |
| Spatial Search (PostGIS) | database.py | search_places_radius() |
| GIS Layer Query → GeoJSON | database.py + pipeline_service.py | query_intersecting_layers() + _build_geojson() |
| Vector DB (ChromaDB) | chroma_service.py | Embedding + semantic search |
| Multi-format Document Loader | document_loader.py | PDF, SHP, CSV, XLSX, XLS |
| Batch Ingest | batch_ingest.py + ingestion.py | Ingest semua file di /data |
| RAG Pipeline Orchestrator | pipeline_service.py | Parse → Geocode → Spatial → GIS → Vector → LLM + HWSD |
| LLM Integration | llm_service.py | Google Gemini, fallback jika gagal |
| Chat Endpoint | routers/chat.py | POST /api/v1/chat |
| HWSD Service & Scoring | hwsd_service.py, hwsd_scoring.py | Raster lookup + SQLite caching + FAO-LECS scoring |
| Citations Extraction | pipeline_service.py | _extract_citations() dari vector results |

## ✅ Fitur yang Sudah Selesai (Frontend)

| Fitur | File | Keterangan |
|---|---|---|
| Chat Screen | chat_screens.dart | ListView + auto-scroll ke bawah |
| Chat Bubble | chat_bubble.dart | Bubble user/bot, spatial badge tap-to-map, HWSD badge |
| Chat Input Bar | chat_input_bar.dart | Send message ke provider |
| HWSD Card | hwsd_card.dart | Tampilkan hasil analisis kesesuaian lahan (S1/S2/S3/N) |
| Citations Chip | citations_chip.dart | Tampilkan sumber dokumen |
| Chat Provider (Riverpod) | chat_providers.dart | State management chat + API call |
| API Service (Dio) | api_service.dart | HTTP client ke backend, 30s/60s timeout |
| Map View (FlutterMap) | map_view.dart | Render Polygon + MultiPolygon GeoJSON |
| Auto-center peta | map_view.dart | _mapController.move() ke centroid polygon |
| Map Bottom Sheet | map_bottom_sheet.dart | Modal 85% screen tinggi dengan peta |
| Map State Provider | map_provider.dart | MapNotifier simpan GeoJSON terkini |
| Loading Indicator | loading_indicator.dart | Tampil saat fetch API |
| Empty State | chat_screens.dart | Tampilan awal sebelum ada pesan |

---

## ⚠️ Yang Belum Selesai / In-Progress

| Item | Status | Prioritas |
|---|---|---|
| geojson_parser.dart | ❌ File ada tapi hanya komentar kosong | Medium |
| map_screen.dart | ❌ File kosong (0 bytes) | Medium |
| Routing dengan go_router | ❌ Package terinstall tapi belum dipakai | Low |
| GPS/Geolocator di UI | ❌ Package terinstall, belum ada tombol lokasi user | Medium |
| Home Screen | ❌ Direktori features/home ada, tidak ada file | Low |
| OCR untuk PDF gambar | ⚠️ Library terinstall, belum di-integrate | Low |
| Autentikasi & API Key | ❌ Belum ada | Low |
| Rate Limiting | ❌ Belum ada | Low |
| Docker full stack | ⚠️ Hanya PostgreSQL ter-containerize | Low |
| Dokumentasi /docs | ❌ Folder kosong | Low |
| Widget/Unit Tests | ⚠️ Direktori test ada, test sangat minimal | Low |

---

## 🐛 Known Issues & Catatan Teknis

1. **database.py raise error saat startup** — Jika env var DB tidak ada, langsung throw ValueError. Tidak ada lazy initialization.
2. **geojson_parser.dart kosong** — Parsing GeoJSON dilakukan langsung di map_view.dart (_processGeoJson()), bukan di utility class terpisah.
3. **CORS terlalu terbuka** — allow_origins=["*"] harus direstriksi sebelum production.
4. **go_router belum dipakai** — Navigasi via Navigator langsung, routing belum terstruktur.
5. **map_screen.dart kosong** — Peta hanya tampil via bottom sheet, belum ada halaman peta dedicated.
6. **API version inkonsisten** — main.py pakai env default "0.6.0" tapi health check versioning (skrg 0.9.0).

---

## 🔄 Alur Data Lengkap (Chat → Peta)

```
User ketik query
  → ChatInputBar.send()
  → ChatNotifier.sendMessage()
  → ApiService.sendMessages() → POST /api/v1/chat
  → RAGPipeline.process()
      → RegexQueryParser.parse()             ← intent (spatial/hwsd/doc), lokasi, tanaman
      → geocode_service.geocode()            ← lat/lon dari Nominatim/fallback
      → db_service.search_places_radius()   ← PostGIS point search
      → hwsd_service.get_soil_at_point()     ← Get Raster SMU → SQLite attributes
      → hwsd_scoring.score_all_crops()       ← Score land suitability
      → _build_geojson()                     ← FeatureCollection JSON untuk map
      → chroma_service.search()              ← vector semantic search
      → llm_service.generate_answer()       ← Gemini generate text
  ← ChatResponse { answer, geo_json, citations, hwsd_result }
  → MapProvider.updateGeoJson(geoJson)
  → ChatBubble tampil dengan badge HWSD/Map
  → Render HWSD Card / Map Bottom Sheet
```

---

## 📊 Estimasi Progress Keseluruhan

| Area | Progress | Catatan |
|---|---|---|
| Backend Core (API + Pipeline) | ~95% | Hampir lengkap, HWSD & RAG integrated |
| Backend Data Layer (DB + Vector) | ~85% | OCR belum terintegrasi |
| Frontend Chat Feature | ~95% | Fungsional end-to-end, HWSD UI lengkap |
| Frontend Map Feature | ~65% | MapView ada, screen dedicated kosong |
| Frontend Routing & Navigation | ~20% | go_router belum dipakai |
| Testing | ~15% | Test files sangat minimal |
| DevOps / Deployment | ~20% | Docker parsial, belum full stack |
| Dokumentasi | ~30% | README backend bagus, docs/ kosong |

**Overall: ~75% selesai** — Fitur inti (chat + peta + kesesuaian lahan HWSD + RAG pipeline) sudah berjalan menyeluruh end-to-end. Yang tersisa: refinement, fitur tambahan (GPS, routing), testing, dan deployment.

---

## 🎯 Prioritas Next Steps (Saran)

### Jangka Pendek
1. Implementasi geojson_parser.dart sebagai utility class terpisah
2. Tambah tombol "Gunakan Lokasi Saya" di chat input (pakai geolocator)
3. Implementasi map_screen.dart sebagai halaman peta full

### Jangka Menengah
4. Setup go_router untuk navigasi antar halaman (Chat ↔ Map ↔ Home)
5. Integrasi OCR ke document_loader.py
7. Tambah widget test untuk ChatBubble dan MapView
8. Docker Compose full stack (backend + frontend web)

### Jangka Panjang
9. Autentikasi pengguna (JWT atau API Key)
10. Rate limiting di backend
11. Deploy ke cloud (GCP/AWS/VPS)
12. Isi folder docs/ dengan dokumentasi API dan arsitektur

"""
enrich_layers_with_soil.py
Mengisi kolom `properties` pada tabel gis_layers dengan hasil analisis tanah HWSD
per polygon, supaya peta bisa mewarnai zona sesuai kelas kesesuaian lahan.

Untuk setiap polygon:
  1. Ambil satu titik yang dijamin berada DI DALAM polygon (ST_PointOnSurface)
  2. Baca SMU dari raster HWSD  -> atribut tanah
  3. Hitung skor 4 komoditas   -> kelas S1/S2/S3/N
  4. Simpan ringkasan ke kolom properties (jsonb) yang sudah ada

Jalankan sekali:  python enrich_layers_with_soil.py
Aman diulang — hasilnya menimpa nilai sebelumnya (idempotent).
"""

import os
import sys
import json
import time

import psycopg2
from psycopg2.extras import RealDictCursor, execute_batch
from dotenv import load_dotenv

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.hwsd_service import hwsd_service          # noqa: E402
from app.services.hwsd_scoring import scoring_engine        # noqa: E402

load_dotenv()

DB = dict(
    host=os.getenv("DB_HOST", "localhost"),
    dbname=os.getenv("DB_NAME", "iada_gis"),
    user=os.getenv("DB_USER", "postgres"),
    password=os.getenv("DB_PASSWORD"),
    port=os.getenv("DB_PORT", "5432"),
)

# Komoditas yang diwarnai di peta
CROPS = ["padi", "jagung", "kelapa_sawit", "kedelai"]


def main():
    print("Menghubungkan ke database...")
    conn = psycopg2.connect(**DB)
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # Ambil satu titik representatif di dalam tiap polygon.
    # ST_PointOnSurface dijamin berada di dalam geometri (ST_Centroid tidak,
    # terutama untuk MultiPolygon / bentuk cekung).
    cur.execute("""
        SELECT id, name, layer_type,
               ST_Y(ST_PointOnSurface(geom)) AS lat,
               ST_X(ST_PointOnSurface(geom)) AS lon
        FROM public.gis_layers
        ORDER BY id
    """)
    rows = cur.fetchall()
    total = len(rows)
    print(f"{total} polygon akan diperkaya dengan data tanah HWSD.\n")

    if not hwsd_service.is_available():
        print("GAGAL: service HWSD tidak tersedia.")
        sys.exit(1)

    updates = []
    stats = {"full": 0, "partial": 0, "missing": 0, "outside": 0}
    t0 = time.time()

    for i, row in enumerate(rows, 1):
        lat, lon = row["lat"], row["lon"]
        props = {}

        if lat is None or lon is None:
            stats["outside"] += 1
        else:
            soil = hwsd_service.get_soil_at_point(float(lat), float(lon))
            if soil is None:
                stats["outside"] += 1
            else:
                scores = scoring_engine.score_all_crops(
                    soil.texture, soil.ph_h2o, soil.drainage, soil.organic_carbon
                )
                by_crop = {s.crop_key: s.overall.value for s in scores}

                completeness = soil.data_completeness
                if completeness == "full":
                    stats["full"] += 1
                else:
                    stats["partial"] += 1

                # Komoditas dengan kelas terbaik (tie-break: urutan CROPS)
                order = {"S1": 0, "S2": 1, "S3": 2, "N": 3}
                best = min(
                    CROPS,
                    key=lambda c: (order.get(by_crop.get(c, "N"), 9), CROPS.index(c)),
                )

                props = {
                    "smu_id": soil.smu_id,
                    "texture_label": soil.texture_label,
                    "ph_h2o": soil.ph_h2o,
                    "drainage_label": soil.drainage_label,
                    "organic_carbon_pct": soil.organic_carbon,
                    "data_completeness": completeness,
                    "scores": by_crop,
                    "best_crop": best,
                    "soil_class": by_crop.get(best),
                }

        updates.append((json.dumps(props), row["id"]))

        if i % 200 == 0 or i == total:
            done = time.time() - t0
            rate = i / done if done else 0
            print(f"  {i}/{total}  ({rate:.0f} polygon/detik)")

    print(f"\nMenyimpan ke database ({len(updates)} baris)...")
    # MERGE, bukan replace: atribut asli dari sumber tetap dipertahankan.
    execute_batch(
        cur,
        "UPDATE public.gis_layers SET properties = properties || %s::jsonb WHERE id = %s",
        updates,
        page_size=200,
    )
    conn.commit()

    print("\n=== Ringkasan ===")
    print(f"  data tanah lengkap  : {stats['full']}")
    print(f"  data tanah parsial  : {stats['partial']}")
    print(f"  tanpa data tanah    : {stats['outside']}")
    print(f"  durasi              : {time.time() - t0:.1f} detik")

    # Verifikasi: berapa polygon yang punya kelas skor
    cur.execute("""
        SELECT properties->>'soil_class' AS cls, COUNT(*) AS n
        FROM public.gis_layers
        WHERE properties ? 'soil_class'
        GROUP BY 1 ORDER BY 1
    """)
    print("\nSebaran kelas (pada komoditas terbaik):")
    for r in cur.fetchall():
        print(f"  {r['cls']}: {r['n']} polygon")

    cur.execute("""
        SELECT COUNT(*) AS n FROM public.gis_layers WHERE NOT (properties ? 'soil_class')
    """)
    print(f"  (tanpa kelas: {cur.fetchone()['n']} polygon)")

    cur.close()
    conn.close()
    print("\nSelesai.")


if __name__ == "__main__":
    main()

"""
hwsd_service.py
Mengakses data HWSD v2.0 (raster + MDB) untuk mendapatkan atribut tanah
pada titik koordinat tertentu.

Alur:
  1. Buka raster HWSD2.bil → ambil SMU_ID pada piksel (lat, lon)
  2. Lookup tabel HWSD2_LAYERS dari SQLite cache (atau MDB via pyodbc sebagai fallback)
  3. Agregasi komponen tanah (ambil dominant share) → return SoilAttributes

Setup awal (jalankan SATU KALI):
    python setup_hwsd_db.py   ← konversi MDB → SQLite cache (butuh ACE driver sekali)
"""

import os
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass, field

import numpy as np
import rasterio
from rasterio.transform import rowcol

logger = logging.getLogger(__name__)

# ── Path konfigurasi ──────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
RASTER_PATH = os.path.join(BASE_DIR, "HWSD2_RASTER", "HWSD2.bil")
MDB_PATH    = os.path.join(BASE_DIR, "HWSD2_DB",     "HWSD2.mdb")
CACHE_PATH  = os.path.join(BASE_DIR, "HWSD2_DB",     "HWSD2_cache.db")  # SQLite cache

# Kode drainase HWSD v2 → label
DRAINAGE_LABELS = {
    "E":  "Sangat cepat",
    "SE": "Agak cepat",
    "W":  "Baik",
    "MW": "Sedang",
    "I":  "Agak terhambat",
    "P":  "Terhambat",
    "VP": "Sangat terhambat",
}

# Kode tekstur HWSD v2 (TEXTURE_USDA) → label (mengelompokkan USDA ke kasar/sedang/halus)
TEXTURE_LABELS = {
    1: "Liat sangat halus",       # Clay (heavy)
    2: "Liat berdebu",            # Silty clay
    3: "Liat halus",              # Clay (light)
    4: "Lempung liat berdebu",    # Silty clay loam
    5: "Lempung berliat",         # Clay loam
    6: "Debu",                    # Silt
    7: "Lempung berdebu",         # Silt loam
    8: "Liat berpasir",           # Sandy clay
    9: "Lempung",                 # Loam
    10: "Lempung liat berpasir",  # Sandy clay loam
    11: "Lempung berpasir",       # Sandy loam
    12: "Pasir berlempung",       # Loamy sand
    13: "Pasir",                  # Sand
}


@dataclass
class SoilAttributes:
    """Atribut tanah hasil query HWSD untuk satu titik koordinat"""
    smu_id: int
    share: float
    texture: Optional[int] = None
    texture_label: str = "Tidak ada data"
    ph_h2o: Optional[float] = None
    drainage: Optional[str] = None
    drainage_label: str = "Tidak ada data"
    organic_carbon: Optional[float] = None
    data_completeness: str = "unknown"
    raw: Dict[str, Any] = field(default_factory=dict)


class HWSDService:
    """
    Service singleton untuk mengakses data HWSD v2.0.
    Data dimuat ke memory saat first use (lazy load).

    Urutan pembacaan database:
      1. HWSD2_cache.db (SQLite) — tidak perlu ODBC driver
      2. HWSD2.mdb via pyodbc   — butuh Microsoft Access ODBC driver

    Jalankan setup_hwsd_db.py SATU KALI untuk generate SQLite cache.
    """

    def __init__(self):
        self._raster_src: Optional[rasterio.DatasetReader] = None
        self._layers_cache: Optional[Dict[int, list]] = None
        self._id_col_layers: Optional[str] = None
        self._initialized = False
        self._init_error: Optional[str] = None

    # ── Public API ────────────────────────────────────────────────────────────

    def get_soil_at_point(self, lat: float, lon: float) -> Optional[SoilAttributes]:
        """Return atribut tanah dominan pada titik (lat, lon). None jika tidak ada data."""
        self._ensure_initialized()
        if self._init_error:
            logger.warning(f"HWSD tidak terinisialisasi: {self._init_error}")
            return None

        smu_id = self._get_smu_id_from_raster(lat, lon)
        if smu_id is None:
            logger.info(f"Titik ({lat}, {lon}) di luar coverage HWSD atau nodata")
            return None

        return self._lookup_soil_attrs(smu_id)

    def is_available(self) -> bool:
        """Cek apakah HWSD service siap digunakan"""
        self._ensure_initialized()
        return self._init_error is None

    def get_status(self) -> Dict[str, Any]:
        """Status service untuk health check dan debug"""
        self._ensure_initialized()
        return {
            "available": self._init_error is None,
            "raster_path": RASTER_PATH,
            "mdb_path": MDB_PATH,
            "cache_path": CACHE_PATH,
            "raster_exists": os.path.exists(RASTER_PATH),
            "mdb_exists": os.path.exists(MDB_PATH),
            "cache_exists": os.path.exists(CACHE_PATH),
            "layers_loaded": self._layers_cache is not None,
            "smu_count": len(self._layers_cache) if self._layers_cache else 0,
            "error": self._init_error,
            "hint": (
                "Jalankan: python setup_hwsd_db.py "
                "(perlu Microsoft Access ODBC driver untuk konversi sekali jalan)"
                if self._init_error and not os.path.exists(CACHE_PATH) else None
            ),
        }

    # ── Inisialisasi ──────────────────────────────────────────────────────────

    def _ensure_initialized(self):
        if self._initialized:
            return
        self._initialized = True
        try:
            self._init_raster()
            self._load_db_cache()
            logger.info(f"HWSD Service siap: {len(self._layers_cache)} SMU dimuat")
        except Exception as e:
            self._init_error = str(e)
            logger.error(f"HWSD Service gagal inisialisasi: {e}")

    def _init_raster(self):
        if not os.path.exists(RASTER_PATH):
            raise FileNotFoundError(f"File raster tidak ditemukan: {RASTER_PATH}")
        self._raster_src = rasterio.open(RASTER_PATH)
        logger.info(f"Raster HWSD terbuka: bounds={self._raster_src.bounds}")

    def _load_db_cache(self):
        """Load data: SQLite cache (prioritas) → pyodbc MDB (fallback)"""
        if os.path.exists(CACHE_PATH):
            logger.info(f"Membaca dari SQLite cache: {CACHE_PATH}")
            self._load_from_sqlite()
        elif os.path.exists(MDB_PATH):
            logger.info(f"Cache belum ada, coba dari MDB: {MDB_PATH}")
            self._load_from_mdb()
        else:
            raise FileNotFoundError(
                f"Tidak ada data HWSD yang bisa dibaca.\n"
                f"  MDB  : {MDB_PATH}\n"
                f"  Cache: {CACHE_PATH}\n"
                f"Pastikan HWSD2.mdb ada di HWSD2_DB/, lalu jalankan setup_hwsd_db.py"
            )

    def _load_from_sqlite(self):
        """Baca HWSD2_LAYERS dari SQLite cache — tidak perlu ODBC driver"""
        import sqlite3
        import pandas as pd

        with sqlite3.connect(CACHE_PATH) as conn:
            tables = [r[0] for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()]
            logger.info(f"Tabel di cache: {tables}")

            tbl_layers = next((t for t in tables if "LAYER" in t.upper()), None)
            if not tbl_layers:
                raise ValueError(f"Tabel LAYERS tidak ada di cache. Tersedia: {tables}")

            df_layers = pd.read_sql_query(f"SELECT * FROM [{tbl_layers}]", conn)
            logger.info(f"LAYERS dimuat: {len(df_layers)} baris")

        self._build_layers_cache(df_layers)

    def _load_from_mdb(self):
        """Baca dari HWSD2.mdb via pyodbc (butuh Microsoft Access ODBC driver)"""
        try:
            import pyodbc
        except ImportError:
            raise ImportError("pyodbc tidak terinstall. Jalankan: pip install pyodbc")

        drivers = pyodbc.drivers()
        access_driver = next(
            (d for d in drivers if "access" in d.lower() or "mdb" in d.lower()), None
        )

        if not access_driver:
            raise RuntimeError(
                "Microsoft Access ODBC driver tidak ditemukan.\n"
                "SOLUSI: Jalankan setup_hwsd_db.py setelah install ACE driver:\n"
                "  https://www.microsoft.com/en-us/download/details.aspx?id=54920\n"
                f"Driver tersedia saat ini: {drivers}"
            )

        import pandas as pd

        conn_str = f"Driver={{{access_driver}}};Dbq={MDB_PATH};"
        conn = pyodbc.connect(conn_str, autocommit=True)
        try:
            cursor = conn.cursor()
            tables = [r.table_name for r in cursor.tables(tableType="TABLE")]
            tbl_layers = next((t for t in tables if "LAYER" in t.upper()), None)
            if not tbl_layers:
                raise ValueError(f"Tabel LAYERS tidak ditemukan. Tersedia: {tables}")

            df_layers = pd.read_sql(f"SELECT * FROM [{tbl_layers}]", conn)
            logger.info(f"LAYERS dari MDB: {len(df_layers)} baris")
        finally:
            conn.close()

        self._build_layers_cache(df_layers)

    def _build_layers_cache(self, df_layers):
        """Build dict cache SMU_ID → list of component rows dari DataFrame"""
        import pandas as pd

        self._id_col_layers = self._find_col(
            df_layers, ["HWSD2_SMU_ID", "SMU_ID", "MU_GLOBAL"]
        )
        if not self._id_col_layers:
            raise ValueError(
                f"Kolom SMU ID tidak ditemukan. Kolom: {list(df_layers.columns)}"
            )

        share_col = self._find_col(df_layers, ["SHARE", "COMP_SHARE", "PERCENTAGE"])

        # Deteksi nama kolom aktual (HWSD v2 pakai nama berbeda dengan v1)
        texture_col  = self._find_col(df_layers, ["T_TEXTURE", "TEXTURE_USDA", "TEXTURE_SOTER"])
        ph_col       = self._find_col(df_layers, ["T_PH_H2O", "PH_WATER", "PH_H2O"])
        drainage_col = self._find_col(df_layers, ["DRAINAGE"])
        oc_col       = self._find_col(df_layers, ["T_OC", "ORG_CARBON", "ORGANIC_CARBON"])
        logger.info(f"Kolom mapping: texture={texture_col}, ph={ph_col}, drainage={drainage_col}, oc={oc_col}")

        # Filter topsoil saja (LAYER D1 atau TOPDEP=0) jika kolom LAYER ada
        layer_col = self._find_col(df_layers, ["LAYER"])
        if layer_col:
            topsoil_mask = df_layers[layer_col].isin(["D1", "T", "S"]) | (df_layers[layer_col].isna())
            df_layers = df_layers[topsoil_mask].copy()
            logger.info(f"Filter topsoil: {len(df_layers)} baris")

        self._layers_cache = {}
        for _, row in df_layers.iterrows():
            sid = int(row[self._id_col_layers])
            if sid not in self._layers_cache:
                self._layers_cache[sid] = []

            self._layers_cache[sid].append({
                "share":    float(row[share_col]) if (share_col and pd.notna(row.get(share_col))) else 100.0,
                "TEXTURE":  self._safe_int_nodata(row.get(texture_col) if texture_col else None),
                "PH":       self._safe_float_nodata(row.get(ph_col) if ph_col else None),
                "DRAINAGE": str(row.get(drainage_col)).strip().upper() if pd.notna(row.get(drainage_col)) else None,
                "OC":       self._safe_float_nodata(row.get(oc_col) if oc_col else None),
            })

        logger.info(f"Cache selesai: {len(self._layers_cache)} SMU unik")

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _get_smu_id_from_raster(self, lat: float, lon: float) -> Optional[int]:
        """Baca nilai piksel raster pada koordinat (lat, lon) → SMU_ID"""
        try:
            src = self._raster_src
            bounds = src.bounds
            if not (bounds.left <= lon <= bounds.right and bounds.bottom <= lat <= bounds.top):
                return None

            row, col = rowcol(src.transform, lon, lat)
            data = src.read(1, window=rasterio.windows.Window(col, row, 1, 1))
            val = data[0, 0]

            if src.nodata is not None and val == src.nodata:
                return None
            if val <= 0:
                return None

            return int(val)
        except Exception as e:
            logger.warning(f"Gagal baca raster di ({lat}, {lon}): {e}")
            return None

    def _lookup_soil_attrs(self, smu_id: int) -> Optional[SoilAttributes]:
        """Ambil atribut tanah dari cache, pilih komponen dominan (share terbesar)"""
        if not self._layers_cache:
            return None

        components = self._layers_cache.get(smu_id)
        if not components:
            logger.warning(f"SMU_ID {smu_id} tidak ditemukan di cache")
            return SoilAttributes(smu_id=smu_id, share=100.0, data_completeness="missing")

        dominant = max(components, key=lambda x: x["share"])

        texture_code  = dominant["TEXTURE"]
        drainage_code = dominant["DRAINAGE"]
        ph            = dominant["PH"]
        oc            = dominant["OC"]

        filled = sum(1 for v in [texture_code, ph, drainage_code, oc] if v is not None)
        completeness = "full" if filled == 4 else ("partial" if filled >= 2 else "minimal")

        return SoilAttributes(
            smu_id=smu_id,
            share=dominant["share"],
            texture=texture_code,
            texture_label=TEXTURE_LABELS.get(texture_code or 0, "Tidak ada data"),
            ph_h2o=ph,
            drainage=drainage_code,
            drainage_label=DRAINAGE_LABELS.get(drainage_code, "Tidak ada data"),
            organic_carbon=oc,
            data_completeness=completeness,
        )

    @staticmethod
    def _find_col(df, candidates):
        for c in candidates:
            match = [col for col in df.columns if col.upper() == c.upper()]
            if match:
                return match[0]
        return None

    @staticmethod
    def _safe_int(val) -> Optional[int]:
        try:
            if val is None:
                return None
            import pandas as pd
            if pd.isna(val):
                return None
            return int(val)
        except Exception:
            return None

    @staticmethod
    def _safe_float(val) -> Optional[float]:
        try:
            if val is None:
                return None
            import pandas as pd
            if pd.isna(val):
                return None
            return float(val)
        except Exception:
            return None

    @staticmethod
    def _safe_int_nodata(val) -> Optional[int]:
        """Seperti _safe_int tapi juga handle nilai -9 (nodata HWSD)"""
        try:
            if val is None:
                return None
            import pandas as pd
            if pd.isna(val):
                return None
            v = int(float(val))
            return None if v <= -9 else v
        except Exception:
            return None

    @staticmethod
    def _safe_float_nodata(val) -> Optional[float]:
        """Seperti _safe_float tapi juga handle nilai -9 (nodata HWSD)"""
        try:
            if val is None:
                return None
            import pandas as pd
            if pd.isna(val):
                return None
            v = float(val)
            return None if v <= -9 else v
        except Exception:
            return None

    def __del__(self):
        """Tutup raster saat service dihancurkan"""
        if self._raster_src and not self._raster_src.closed:
            self._raster_src.close()


# Singleton instance
hwsd_service = HWSDService()

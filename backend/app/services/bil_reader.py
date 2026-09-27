"""
bil_reader.py
Pembaca raster ESRI BIL (Band Interleaved by Line) tanpa GDAL/rasterio.

Dipakai sebagai pengganti rasterio untuk HWSD2.bil — karena DLL native
rasterio diblokir oleh Windows Application Control (Smart App Control),
sementara numpy tidak. Format BIL adalah data mentah + header teks (.hdr),
jadi cukup dibaca dengan memory-map numpy.

Konvensi koordinat mengikuti GDAL/rasterio:
  ULXMAP/ULYMAP pada .hdr adalah koordinat CENTER piksel kiri-atas,
  sedangkan geotransform GDAL memakai CORNER, sehingga origin bergeser
  setengah piksel (XDIM/2, YDIM/2).

  row = floor((ULYMAP + YDIM/2 - lat) / YDIM)
  col = floor(( lon  - (ULXMAP - XDIM/2)) / XDIM)

Rumus ini sudah diverifikasi cocok dengan hasil rasterio.rowcol()
(titik Samarinda -0.5018, 117.1393 → SMU 3749).
"""

import os
import logging
from typing import Optional, Tuple

import numpy as np

logger = logging.getLogger(__name__)


class BilRaster:
    """Raster BIL 1-band dengan akses piksel acak lewat numpy.memmap."""

    def __init__(self, bil_path: str):
        self.bil_path = bil_path
        self.hdr_path = os.path.splitext(bil_path)[0] + ".hdr"
        self._memmap: Optional[np.memmap] = None
        self._header: dict = {}
        self._load_header()

    # ── Header ───────────────────────────────────────────────────────────────

    def _load_header(self) -> None:
        if not os.path.exists(self.hdr_path):
            raise FileNotFoundError(f"Header BIL tidak ditemukan: {self.hdr_path}")

        header = {}
        with open(self.hdr_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                parts = line.split(None, 1)
                if len(parts) == 2:
                    header[parts[0].strip().upper()] = parts[1].strip()

        def num(key, default=None):
            """Ambil nilai numerik dari header; toleran terhadap suffix 'd' (Fortran)."""
            raw = header.get(key)
            if raw is None:
                if default is None:
                    raise ValueError(f"Header {key} tidak ada di {self.hdr_path}")
                return default
            return float(str(raw).rstrip("dD"))

        self._header = header
        self.nrows = int(num("NROWS"))
        self.ncols = int(num("NCOLS"))
        self.nbands = int(num("NBANDS", 1))
        self.nbits = int(num("NBITS", 16))
        self.byteorder = header.get("BYTEORDER", "I").upper()  # I=little, M=big
        self.pixeltype = header.get("PIXELTYPE", "UNSIGNEDINT").upper()
        self.nodata = int(num("NODATA", 0))

        # Koordinat center piksel kiri-atas + ukuran piksel (derajat)
        self.ulx = num("ULXMAP")
        self.uly = num("ULYMAP")
        self.xdim = num("XDIM")
        self.ydim = num("YDIM")

        if self.nbands != 1:
            raise ValueError(f"Pembaca BIL ini hanya mendukung 1 band (dapat {self.nbands})")

        # dtype numpy sesuai NBITS + PIXELTYPE + byte order
        if self.pixeltype == "UNSIGNEDINT":
            base = {8: "u1", 16: "u2", 32: "u4"}.get(self.nbits)
        else:
            base = {8: "i1", 16: "i2", 32: "i4"}.get(self.nbits)

        if base is None:
            raise ValueError(f"Kombinasi NBITS={self.nbits} PIXELTYPE={self.pixeltype} tidak didukung")

        self.dtype = np.dtype(("<" if self.byteorder == "I" else ">") + base)

        # Bounds geografis (sudut luar raster)
        self.left = self.ulx - self.xdim / 2
        self.top = self.uly + self.ydim / 2
        self.right = self.left + self.ncols * self.xdim
        self.bottom = self.top - self.nrows * self.ydim

    # ── Buka file ────────────────────────────────────────────────────────────

    def open(self) -> None:
        if self._memmap is not None:
            return
        if not os.path.exists(self.bil_path):
            raise FileNotFoundError(f"File raster tidak ditemukan: {self.bil_path}")

        expected = self.nrows * self.ncols * self.dtype.itemsize * self.nbands
        actual = os.path.getsize(self.bil_path)
        if actual < expected:
            raise ValueError(
                f"Ukuran file raster tidak sesuai: {actual} < {expected} bytes"
            )

        # memmap: pembacaan lazy, hanya halaman yang diakses yang masuk RAM
        self._memmap = np.memmap(
            self.bil_path, dtype=self.dtype, mode="r", shape=(self.nrows, self.ncols)
        )
        logger.info(
            f"Raster BIL terbuka: {self.nrows}x{self.ncols} dtype={self.dtype} "
            f"bounds=({self.left:.4f}, {self.bottom:.4f}, {self.right:.4f}, {self.top:.4f})"
        )

    def close(self) -> None:
        if self._memmap is not None:
            try:
                del self._memmap
            finally:
                self._memmap = None

    # ── Akses piksel ─────────────────────────────────────────────────────────

    def contains(self, lat: float, lon: float) -> bool:
        return (
            self.left <= lon <= self.right and self.bottom <= lat <= self.top
        )

    def latlon_to_rowcol(self, lat: float, lon: float) -> Tuple[int, int]:
        """Konversi (lat, lon) → (row, col) mengikuti konvensi GDAL/rasterio."""
        row = int(np.floor((self.top - lat) / self.ydim))
        col = int(np.floor((lon - self.left) / self.xdim))
        return row, col

    def value_at(self, lat: float, lon: float) -> Optional[int]:
        """
        Nilai piksel pada (lat, lon).
        Return None jika di luar bounds, kena NODATA, atau nilai <= 0.
        """
        self.open()
        if not self.contains(lat, lon):
            return None

        row, col = self.latlon_to_rowcol(lat, lon)
        if not (0 <= row < self.nrows and 0 <= col < self.ncols):
            return None

        val = int(self._memmap[row, col])

        if val == self.nodata or val <= 0:
            return None
        return val

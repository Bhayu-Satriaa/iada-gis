"""
hwsd_scoring.py
Rule-based land suitability scoring engine berbasis kriteria FAO-LECS.

Sistem penilaian:
  S1 — Sangat Sesuai      (skor 4): tidak ada faktor pembatas signifikan
  S2 — Cukup Sesuai       (skor 3): ada faktor pembatas ringan
  S3 — Sesuai Bersyarat   (skor 2): faktor pembatas sedang, butuh ameliorasi
  N  — Tidak Sesuai       (skor 1): faktor pembatas berat, tidak ekonomis

Skor akhir = skor terendah dari semua parameter (limiting factor principle).

Referensi kriteria:
  - FAO Agro-ecological Zones methodology
  - Balai Penelitian Tanah (BBSDLP) kriteria kesesuaian lahan Indonesia
"""

from dataclasses import dataclass, field
from typing import Optional, Dict, List
from enum import Enum


class Suitability(str, Enum):
    S1 = "S1"  # Sangat Sesuai
    S2 = "S2"  # Cukup Sesuai
    S3 = "S3"  # Sesuai Bersyarat
    N  = "N"   # Tidak Sesuai


SUITABILITY_SCORE = {
    Suitability.S1: 4,
    Suitability.S2: 3,
    Suitability.S3: 2,
    Suitability.N:  1,
}

SUITABILITY_LABEL = {
    Suitability.S1: "Sangat Sesuai",
    Suitability.S2: "Cukup Sesuai",
    Suitability.S3: "Sesuai Bersyarat",
    Suitability.N:  "Tidak Sesuai",
}

SUITABILITY_EMOJI = {
    Suitability.S1: "✅",
    Suitability.S2: "🟡",
    Suitability.S3: "🟠",
    Suitability.N:  "❌",
}

# Daftar komoditas yang didukung (alias → normalized key)
CROP_ALIASES = {
    "padi":          "padi",
    "padi sawah":    "padi",
    "rice":          "padi",
    "jagung":        "jagung",
    "corn":          "jagung",
    "maize":         "jagung",
    "kelapa sawit":  "kelapa_sawit",
    "sawit":         "kelapa_sawit",
    "palm":          "kelapa_sawit",
    "palm oil":      "kelapa_sawit",
    "kelapa_sawit":  "kelapa_sawit",
    "kedelai":       "kedelai",
    "soybean":       "kedelai",
    "kacang kedelai": "kedelai",
}

SUPPORTED_CROPS = {
    "padi": "Padi Sawah",
    "jagung": "Jagung",
    "kelapa_sawit": "Kelapa Sawit",
    "kedelai": "Kedelai",
}


@dataclass
class ParameterScore:
    """Skor satu parameter tanah untuk satu komoditas"""
    parameter: str
    value: Optional[float]
    suitability: Suitability
    reason: str


@dataclass
class SuitabilityResult:
    """Hasil scoring kesesuaian lahan untuk satu komoditas"""
    crop_key: str
    crop_name: str
    overall: Suitability
    label: str
    emoji: str
    limiting_factors: List[str]
    parameters: List[ParameterScore]
    note: str = ""
    data_sufficient: bool = True


# ─────────────────────────────────────────────────────────────────────────────
# Tabel kriteria kesesuaian lahan
# Format per parameter: {kelas: (min, max), ...} atau fungsi evaluator
# ─────────────────────────────────────────────────────────────────────────────

class HWSDScoringEngine:
    """Rule-based scoring engine kesesuaian lahan berbasis HWSD attributes"""

    def score(
        self,
        crop_type: str,
        texture: Optional[int],
        ph_h2o: Optional[float],
        drainage: Optional[str],
        organic_carbon: Optional[float],
    ) -> SuitabilityResult:
        """
        Hitung skor kesesuaian lahan.

        Args:
            crop_type: nama komoditas (akan di-normalize via CROP_ALIASES)
            texture: kode tekstur HWSD (1-13)
            ph_h2o: pH dalam air
            drainage: kode drainase HWSD (string: W, MW, I, P, VP, E, SE)
            organic_carbon: % organic carbon topsoil

        Returns:
            SuitabilityResult
        """
        crop_key = CROP_ALIASES.get(crop_type.lower().strip(), crop_type.lower().strip())
        crop_name = SUPPORTED_CROPS.get(crop_key, crop_key.replace("_", " ").title())

        if crop_key == "padi":
            params = self._score_padi(texture, ph_h2o, drainage, organic_carbon)
        elif crop_key == "jagung":
            params = self._score_jagung(texture, ph_h2o, drainage, organic_carbon)
        elif crop_key == "kelapa_sawit":
            params = self._score_kelapa_sawit(texture, ph_h2o, drainage, organic_carbon)
        elif crop_key == "kedelai":
            params = self._score_kedelai(texture, ph_h2o, drainage, organic_carbon)
        else:
            # Fallback: scoring generic
            params = self._score_generic(texture, ph_h2o, drainage, organic_carbon)

        # Hitung overall = minimum skor (limiting factor)
        overall = min(params, key=lambda p: SUITABILITY_SCORE[p.suitability]).suitability

        # Identifikasi faktor pembatas
        min_score = SUITABILITY_SCORE[overall]
        limiting = [p.parameter for p in params if SUITABILITY_SCORE[p.suitability] == min_score and overall != Suitability.S1]

        # Cek kelengkapan data
        none_count = sum(1 for p in params if p.value is None and p.parameter != "Drainase")
        data_sufficient = none_count == 0

        note = ""
        if none_count > 0:
            note = f"⚠️ {none_count} parameter tidak tersedia di data HWSD — scoring dilakukan dengan data parsial."
        if overall == Suitability.N:
            note += " Lahan tidak sesuai secara alami namun bisa diperbaiki dengan ameliorasi intensif."

        return SuitabilityResult(
            crop_key=crop_key,
            crop_name=crop_name,
            overall=overall,
            label=SUITABILITY_LABEL[overall],
            emoji=SUITABILITY_EMOJI[overall],
            limiting_factors=limiting,
            parameters=params,
            note=note.strip(),
            data_sufficient=data_sufficient,
        )

    def score_all_crops(
        self,
        texture: Optional[int],
        ph_h2o: Optional[float],
        drainage: Optional[str],
        organic_carbon: Optional[float],
    ) -> List[SuitabilityResult]:
        """Score semua 4 komoditas utama"""
        return [
            self.score("padi",         texture, ph_h2o, drainage, organic_carbon),
            self.score("jagung",       texture, ph_h2o, drainage, organic_carbon),
            self.score("kelapa_sawit", texture, ph_h2o, drainage, organic_carbon),
            self.score("kedelai",      texture, ph_h2o, drainage, organic_carbon),
        ]

    # ── Padi Sawah ────────────────────────────────────────────────────────────
    def _score_padi(self, texture, ph, drainage, oc) -> List[ParameterScore]:
        """
        Padi sawah membutuhkan:
        - Tekstur: medium-halus (3, 4, 5, 8, 9, 10, 11) untuk menahan air
        - pH: 5.0–7.5 optimal, sedikit masam masih toleran
        - Drainase: terhambat hingga agak terhambat (P, VP, I) OK untuk sawah
        - OC: > 1% ideal
        """
        return [
            self._eval_texture(texture, s1=[3,4,5,8,9,10,11], s2=[1,2,6,7], s3=[12], n=[13]),
            self._eval_ph(ph,
                s1=(5.5, 7.0), s2=[(5.0, 5.5), (7.0, 7.5)],
                s3=[(4.5, 5.0), (7.5, 8.0)], n_below=4.5, n_above=8.0
            ),
            self._eval_drainage(drainage, s1=["P", "VP", "I"], s2=["MW", "W"], s3=["SE"], n=["E"]),
            self._eval_oc(oc, s1=1.5, s2=1.0, s3=0.5),
        ]

    # ── Jagung ────────────────────────────────────────────────────────────────
    def _score_jagung(self, texture, ph, drainage, oc) -> List[ParameterScore]:
        """
        Jagung membutuhkan:
        - Tekstur: medium (6, 7, 9, 10, 11) optimal
        - pH: 5.5–7.5
        - Drainase: baik hingga sedang (W, MW)
        - OC: > 1%
        """
        return [
            self._eval_texture(texture, s1=[6,7,9,10,11], s2=[2,3,4,5,8], s3=[1,12], n=[13]),
            self._eval_ph(ph,
                s1=(5.8, 7.2), s2=[(5.5, 5.8), (7.2, 7.8)],
                s3=[(5.0, 5.5), (7.8, 8.0)], n_below=5.0, n_above=8.0
            ),
            self._eval_drainage(drainage, s1=["W", "MW"], s2=["SE", "I"], s3=["E", "P"], n=["VP"]),
            self._eval_oc(oc, s1=1.5, s2=1.0, s3=0.5),
        ]

    # ── Kelapa Sawit ──────────────────────────────────────────────────────────
    def _score_kelapa_sawit(self, texture, ph, drainage, oc) -> List[ParameterScore]:
        """
        Kelapa sawit membutuhkan:
        - Tekstur: medium-halus (3, 4, 5, 6, 7, 8, 9, 10)
        - pH: 4.5–7.5 (lebih toleran masam)
        - Drainase: baik hingga agak baik/sedang (W, MW, I) — tidak toleran genangan sangat buruk
        - OC: > 1.5% (butuh lebih banyak bahan organik)
        """
        params = [
            self._eval_texture(texture, s1=[3,4,5,6,7,8,9,10], s2=[2,11], s3=[1,12], n=[13]),
            self._eval_ph(ph,
                s1=(5.0, 6.5), s2=[(4.5, 5.0), (6.5, 7.5)],
                s3=[(4.0, 4.5), (7.5, 8.0)], n_below=4.0, n_above=8.0
            ),
            self._eval_drainage(drainage, s1=["W", "MW", "I"], s2=["SE", "P"], s3=["E"], n=["VP"]),
            self._eval_oc(oc, s1=2.0, s2=1.5, s3=1.0),
        ]
        return params

    # ── Kedelai ───────────────────────────────────────────────────────────────
    def _score_kedelai(self, texture, ph, drainage, oc) -> List[ParameterScore]:
        """
        Kedelai membutuhkan:
        - Tekstur: medium (6, 7, 9, 10, 11) optimal
        - pH: 5.8–7.0 (sensitif terhadap keasaman)
        - Drainase: baik hingga sedang (W, MW) — tidak toleran genangan
        - OC: > 1%
        """
        return [
            self._eval_texture(texture, s1=[6,7,9,10,11], s2=[2,3,4,5,8], s3=[1,12], n=[13]),
            self._eval_ph(ph,
                s1=(6.0, 7.0), s2=[(5.8, 6.0), (7.0, 7.5)],
                s3=[(5.5, 5.8), (7.5, 8.0)], n_below=5.5, n_above=8.0
            ),
            self._eval_drainage(drainage, s1=["W", "MW"], s2=["SE", "I"], s3=["E", "P"], n=["VP"]),
            self._eval_oc(oc, s1=1.5, s2=1.0, s3=0.5),
        ]

    # ── Generic fallback ──────────────────────────────────────────────────────
    def _score_generic(self, texture, ph, drainage, oc) -> List[ParameterScore]:
        return [
            self._eval_texture(texture, s1=[3,4,5,6,7,8,9,10], s2=[2,11], s3=[1,12], n=[13]),
            self._eval_ph(ph,
                s1=(5.5, 7.0), s2=[(5.0, 5.5), (7.0, 7.5)],
                s3=[(4.5, 5.0), (7.5, 8.0)], n_below=4.5, n_above=8.0
            ),
            self._eval_drainage(drainage, s1=["W", "MW", "I"], s2=["SE", "P"], s3=["E"], n=["VP"]),
            self._eval_oc(oc, s1=1.5, s2=1.0, s3=0.5),
        ]

    # ── Evaluator tiap parameter ──────────────────────────────────────────────

    def _eval_texture(
        self,
        texture: Optional[int],
        s1: List[int], s2: List[int], s3: List[int], n: List[int],
    ) -> ParameterScore:
        """Evaluasi tekstur (kode integer HWSD 1-13)"""
        from app.services.hwsd_service import TEXTURE_LABELS

        if texture is None:
            return ParameterScore(
                parameter="Tekstur Tanah",
                value=None,
                suitability=Suitability.S2,  # assume medium jika tidak ada
                reason="Data tekstur tidak tersedia (diasumsikan S2)"
            )

        label = TEXTURE_LABELS.get(texture, str(texture))

        if texture in s1:
            suit, reason = Suitability.S1, f"Tekstur {label} — sangat sesuai"
        elif texture in s2:
            suit, reason = Suitability.S2, f"Tekstur {label} — cukup sesuai, perlu perhatian"
        elif texture in s3:
            suit, reason = Suitability.S3, f"Tekstur {label} — sesuai bersyarat, butuh ameliorasi"
        elif texture in n:
            suit, reason = Suitability.N, f"Tekstur {label} — tidak sesuai"
        else:
            suit, reason = Suitability.S2, f"Tekstur {label} — tidak dalam kategori standar"

        return ParameterScore("Tekstur Tanah", float(texture), suit, reason)

    def _eval_ph(
        self,
        ph: Optional[float],
        s1: tuple,
        s2: list,
        s3: list,
        n_below: float,
        n_above: float,
    ) -> ParameterScore:
        """Evaluasi pH tanah"""
        if ph is None:
            return ParameterScore(
                parameter="pH Tanah",
                value=None,
                suitability=Suitability.S2,
                reason="Data pH tidak tersedia"
            )

        if s1[0] <= ph <= s1[1]:
            return ParameterScore("pH Tanah", ph, Suitability.S1,
                                  f"pH {ph:.1f} — sangat sesuai (optimal {s1[0]}-{s1[1]})")

        for rng in s2:
            if rng[0] <= ph < rng[1] or rng[0] < ph <= rng[1]:
                return ParameterScore("pH Tanah", ph, Suitability.S2,
                                      f"pH {ph:.1f} — cukup sesuai")

        for rng in s3:
            if rng[0] <= ph < rng[1] or rng[0] < ph <= rng[1]:
                return ParameterScore("pH Tanah", ph, Suitability.S3,
                                      f"pH {ph:.1f} — sesuai bersyarat, perlu pengapuran/acidifikasi")

        return ParameterScore("pH Tanah", ph, Suitability.N,
                              f"pH {ph:.1f} — tidak sesuai (di luar batas {n_below}-{n_above})")

    def _eval_drainage(
        self,
        drainage: Optional[str],
        s1: List[str], s2: List[str], s3: List[str], n: List[str],
    ) -> ParameterScore:
        """Evaluasi drainase (string code HWSD)"""
        from app.services.hwsd_service import DRAINAGE_LABELS

        if drainage is None:
            return ParameterScore(
                parameter="Drainase",
                value=None,
                suitability=Suitability.S2,
                reason="Data drainase tidak tersedia"
            )

        label = DRAINAGE_LABELS.get(drainage, str(drainage))
        dr_code = drainage.upper()

        if dr_code in [x.upper() for x in s1]:
            suit, reason = Suitability.S1, f"Drainase {label} — sangat sesuai"
        elif dr_code in [x.upper() for x in s2]:
            suit, reason = Suitability.S2, f"Drainase {label} — cukup sesuai"
        elif dr_code in [x.upper() for x in s3]:
            suit, reason = Suitability.S3, f"Drainase {label} — sesuai bersyarat"
        elif dr_code in [x.upper() for x in n]:
            suit, reason = Suitability.N, f"Drainase {label} — tidak sesuai"
        else:
            suit, reason = Suitability.S2, f"Drainase {label} — tidak dalam kategori standar"

        return ParameterScore("Drainase", None, suit, reason)

    def _eval_oc(
        self,
        oc: Optional[float],
        s1: float,
        s2: float,
        s3: float,
    ) -> ParameterScore:
        """Evaluasi Organic Carbon (% topsoil)"""
        if oc is None:
            return ParameterScore(
                parameter="Karbon Organik",
                value=None,
                suitability=Suitability.S2,
                reason="Data karbon organik tidak tersedia"
            )

        if oc >= s1:
            return ParameterScore("Karbon Organik", oc, Suitability.S1,
                                  f"OC {oc:.2f}% — sangat sesuai (≥ {s1}%)")
        elif oc >= s2:
            return ParameterScore("Karbon Organik", oc, Suitability.S2,
                                  f"OC {oc:.2f}% — cukup sesuai ({s2}–{s1}%)")
        elif oc >= s3:
            return ParameterScore("Karbon Organik", oc, Suitability.S3,
                                  f"OC {oc:.2f}% — sesuai bersyarat ({s3}–{s2}%), perlu penambahan bahan organik")
        else:
            return ParameterScore("Karbon Organik", oc, Suitability.N,
                                  f"OC {oc:.2f}% — tidak sesuai (< {s3}%), tanah terdegradasi")


def normalize_crop_type(crop_input: str) -> Optional[str]:
    """Normalize input komoditas ke key standar. Return None jika tidak dikenali."""
    if not crop_input:
        return None
    normalized = CROP_ALIASES.get(crop_input.lower().strip())
    return normalized


# Singleton scoring engine
scoring_engine = HWSDScoringEngine()

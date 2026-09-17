"""
hwsd.py
Router FastAPI untuk fitur HWSD Land Suitability Scoring.

Endpoints:
  POST /api/v1/land-suitability           — scoring satu titik koordinat
  GET  /api/v1/land-suitability/crops     — daftar komoditas yang didukung
  GET  /api/v1/land-suitability/soil-info — info tanah di titik (tanpa scoring)
  GET  /api/v1/land-suitability/status    — status service HWSD
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any

from app.services.hwsd_service import hwsd_service, SoilAttributes
from app.services.hwsd_scoring import scoring_engine, normalize_crop_type, SUPPORTED_CROPS, CROP_ALIASES

router = APIRouter()


# ── Pydantic Schemas ─────────────────────────────────────────────────────────

class LandSuitabilityRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90, description="Latitude titik lokasi")
    longitude: float = Field(..., ge=-180, le=180, description="Longitude titik lokasi")
    crop_type: Optional[str] = Field(
        None,
        description="Jenis tanaman (padi, jagung, kelapa_sawit, kedelai). Kosongkan untuk score semua komoditas."
    )

class ParameterScoreOut(BaseModel):
    parameter: str
    value: Optional[float]
    suitability: str
    reason: str

class CropScoreOut(BaseModel):
    crop_key: str
    crop_name: str
    overall: str
    label: str
    emoji: str
    limiting_factors: List[str]
    parameters: List[ParameterScoreOut]
    note: str
    data_sufficient: bool

class SoilInfoOut(BaseModel):
    smu_id: int
    share_pct: float
    texture_code: Optional[int]
    texture_label: str
    ph_h2o: Optional[float]
    drainage_code: Optional[str]
    drainage_label: str
    organic_carbon_pct: Optional[float]
    data_completeness: str

class LandSuitabilityResponse(BaseModel):
    location: Dict[str, float]
    soil_info: Optional[SoilInfoOut]
    scores: List[CropScoreOut]
    summary: str


# ── Helper ───────────────────────────────────────────────────────────────────

def _soil_to_out(soil: SoilAttributes) -> SoilInfoOut:
    return SoilInfoOut(
        smu_id=soil.smu_id,
        share_pct=soil.share,
        texture_code=soil.texture,
        texture_label=soil.texture_label,
        ph_h2o=soil.ph_h2o,
        drainage_code=soil.drainage,
        drainage_label=soil.drainage_label,
        organic_carbon_pct=soil.organic_carbon,
        data_completeness=soil.data_completeness,
    )


def _build_summary(scores: List[CropScoreOut]) -> str:
    """Buat ringkasan teks dari hasil scoring semua komoditas"""
    lines = []
    for s in scores:
        lines.append(f"{s.emoji} {s.crop_name}: {s.label}")
        if s.limiting_factors:
            lines.append(f"   Faktor pembatas: {', '.join(s.limiting_factors)}")
    return "\n".join(lines)


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/land-suitability", response_model=LandSuitabilityResponse)
async def get_land_suitability(request: LandSuitabilityRequest):
    """
    Hitung skor kesesuaian lahan pada titik koordinat berdasarkan data HWSD v2.0.

    - Jika `crop_type` diisi, return skor untuk komoditas tersebut saja.
    - Jika `crop_type` kosong, return skor untuk semua 4 komoditas (padi, jagung, kelapa sawit, kedelai).
    """
    if not hwsd_service.is_available():
        status = hwsd_service.get_status()
        raise HTTPException(
            status_code=503,
            detail={
                "error": "HWSD service tidak tersedia",
                "reason": status.get("error", "Unknown"),
                "raster_exists": status.get("raster_exists"),
                "mdb_exists": status.get("mdb_exists"),
            }
        )

    lat, lon = request.latitude, request.longitude

    # Ambil data tanah
    soil = hwsd_service.get_soil_at_point(lat, lon)

    if soil is None:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "Tidak ada data tanah HWSD untuk koordinat ini",
                "location": {"lat": lat, "lon": lon},
                "hint": "Pastikan koordinat berada dalam batas wilayah Indonesia/Kalimantan Timur",
            }
        )

    # Normalisasi crop_type
    crop_key = None
    if request.crop_type:
        crop_key = normalize_crop_type(request.crop_type)
        if not crop_key:
            supported = list(SUPPORTED_CROPS.keys())
            raise HTTPException(
                status_code=422,
                detail={
                    "error": f"Komoditas '{request.crop_type}' tidak dikenali",
                    "supported": supported,
                    "aliases": list(CROP_ALIASES.keys()),
                }
            )

    # Scoring
    if crop_key:
        results = [scoring_engine.score(
            crop_key,
            soil.texture,
            soil.ph_h2o,
            soil.drainage,
            soil.organic_carbon,
        )]
    else:
        results = scoring_engine.score_all_crops(
            soil.texture,
            soil.ph_h2o,
            soil.drainage,
            soil.organic_carbon,
        )

    scores_out = [
        CropScoreOut(
            crop_key=r.crop_key,
            crop_name=r.crop_name,
            overall=r.overall.value,
            label=r.label,
            emoji=r.emoji,
            limiting_factors=r.limiting_factors,
            parameters=[
                ParameterScoreOut(
                    parameter=p.parameter,
                    value=p.value,
                    suitability=p.suitability.value,
                    reason=p.reason,
                )
                for p in r.parameters
            ],
            note=r.note,
            data_sufficient=r.data_sufficient,
        )
        for r in results
    ]

    return LandSuitabilityResponse(
        location={"lat": lat, "lon": lon},
        soil_info=_soil_to_out(soil),
        scores=scores_out,
        summary=_build_summary(scores_out),
    )


@router.get("/land-suitability/crops")
async def list_supported_crops():
    """Daftar komoditas yang didukung oleh sistem scoring HWSD"""
    return {
        "supported_crops": [
            {"key": k, "name": v}
            for k, v in SUPPORTED_CROPS.items()
        ],
        "aliases": CROP_ALIASES,
        "total": len(SUPPORTED_CROPS),
    }


@router.get("/land-suitability/soil-info")
async def get_soil_info(
    lat: float = Query(..., description="Latitude titik lokasi"),
    lon: float = Query(..., description="Longitude titik lokasi"),
):
    """
    Ambil informasi atribut tanah dari HWSD pada titik koordinat tertentu (tanpa scoring).
    Berguna untuk debugging dan inspeksi data.
    """
    if not hwsd_service.is_available():
        raise HTTPException(status_code=503, detail="HWSD service tidak tersedia")

    soil = hwsd_service.get_soil_at_point(lat, lon)
    if soil is None:
        raise HTTPException(
            status_code=404,
            detail=f"Tidak ada data tanah HWSD pada titik ({lat}, {lon})"
        )

    return {
        "location": {"lat": lat, "lon": lon},
        "soil": _soil_to_out(soil).dict(),
    }


@router.get("/land-suitability/status")
async def hwsd_status():
    """Cek status HWSD service — apakah data tersedia dan ter-load dengan benar"""
    return hwsd_service.get_status()

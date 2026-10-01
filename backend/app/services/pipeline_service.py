import json
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from app.services.database import db_service
from app.services.chroma_service import chroma_service
from app.services.geocode_service import geocode_service
from app.services.query_parser import RegexQueryParser, QueryIntent, IntentType
from app.services.llm_service import llm_service

@dataclass
class Pipelineresult:
    query_original: str
    intent: QueryIntent
    location: Optional[Dict]
    spatial_results: List[Dict]
    vector_results: List[Dict]
    context: str
    answer: str
    answer_ready: bool
    model_used: str = "unknown"
    processing_time_ms: int = 0
    citations: List[Dict] = field(default_factory=list)
    geo_json: Optional[Dict] = None
    hwsd_result: Optional[Dict] = None
    data_sources: List[Dict] = field(default_factory=list)

class RAGPipeline:
    """Pipeline: Query -> parse -> geocode -> search(spatial + vector) -> context"""

    def __init__(self):
        self.parser = RegexQueryParser()
        self.geocoder = geocode_service
        self.spatial_db = db_service
        self.vector_db = chroma_service
    
    async def process(
        self,
        query: str,
        user_location: Optional[Dict] = None,
        on_event=None,
    ) -> Pipelineresult:
        """on_event: callback opsional untuk streaming.

        Kalau diberikan, metadata (peta/skor) dikirim lebih dulu, lalu jawaban
        dikirim potongan demi potongan. Tanpa callback, perilakunya persis
        seperti sebelumnya (tunggu jawaban utuh).
        """
        start_time = time.time()
        print(f"\n{'='*60}")
        print(f"Pipeline: '{query}'")
        print(f"{'='*60}")

        # 1) Parse Query
        print("\n 1: Parsing Query...")
        intent = self.parser.parse(query)
        print(f"\n Parsed: {intent.type} | loc={intent.location} | crop={intent.crop_type}")

        # 2) Geocode (kalau ada lokasi)
        center_lat, center_lon = None, None

        if intent.location:
            print(f"\n Geocoding '{intent.location}'...")
            geo_result = await self.geocoder.geocode(intent.location)
            
            if geo_result.get("lat") is not None and geo_result.get("lon") is not None:
                center_lat, center_lon = geo_result["lat"], geo_result["lon"]
                src = "Nominatim" if geo_result.get("found") else geo_result.get("source", "fallback")
                print(f" Coords ({src}): ({center_lat}, {center_lon})")
            elif user_location:
                center_lat, center_lon = user_location["lat"], user_location["lon"]
                print(f" Fallback to user location")

        # 3) Spatial Search
        spatial_results = []
        if intent.has_spatial and center_lat and center_lon:
            print(f"\nSpatial search...")
            spatial_results = self.spatial_db.search_places_radius(
                lat=center_lat,
                lon=center_lon,
                radius_km=intent.radius_km,
                category=intent.category
            )
            print(f"Found: {len(spatial_results)} places")

        # 4) Query Polygon layer GIS — filter sesuai lokasi yang ditanyakan
        geo_json = None
        # layer_results harus selalu terdefinisi: dipakai untuk geo_json (peta)
        # DAN untuk ringkasan kawasan di konteks LLM.
        layer_results: List[Dict] = []
        layer_centroid_lat, layer_centroid_lon = None, None
        preferred_layer_type = self._match_layer_type(intent.location) if intent.location else None
        
        if preferred_layer_type:
            # Ambil SEMUA polygon untuk area ini (tanpa filter radius)
            print(f"\nQuerying GIS layers for type '{preferred_layer_type}'...")
            geo_query_start = time.time()
            layer_results = self.spatial_db.get_layers_by_type(
                preferred_layer_type, limit=200
            )
            geo_query_ms = int((time.time() - geo_query_start) * 1000)
            print(f"Found: {len(layer_results)} polygons ({geo_query_ms}ms)")
            
            if layer_results:
                geo_json = self._build_geojson(layer_results)
                # Ambil centroid dari polygon pertama untuk HWSD scoring
                first = layer_results[0]
                layer_centroid_lat = first.get('centroid_lat')
                layer_centroid_lon = first.get('centroid_lon')
        elif center_lat and center_lon:
            # Fallback: cari dalam radius
            print(f"\nQuerying GIS layers (radius search)...")
            geo_query_start = time.time()
            layer_results = self.spatial_db.query_intersecting_layers(
                center_lat, center_lon, 
                radius_km=intent.radius_km,
                max_results=10
            )
            geo_query_ms = int((time.time() - geo_query_start) * 1000)
            print(f"Found: {len(layer_results)} intersecting layers ({geo_query_ms}ms)")
            if layer_results:
                geo_json = self._build_geojson(layer_results)


        # 5) Vector search
        print(f"\nVector search...")
        vector_query = self._build_vector_query(intent)
        vector_results = self.vector_db.search(vector_query, top_k=5)
        print(f"Found: {len(vector_results)} docs")

        # 5b) HWSD scoring — otomatis untuk spatial_search & land_suitability
        hwsd_result = None
        # Tentukan koordinat untuk scoring: centroid polygon > geocode center
        scoring_lat = layer_centroid_lat or center_lat
        scoring_lon = layer_centroid_lon or center_lon
        
        if scoring_lat and scoring_lon:
            try:
                from app.services.hwsd_service import hwsd_service
                from app.services.hwsd_scoring import scoring_engine, normalize_crop_type

                print(f"\nHWSD scoring di ({scoring_lat}, {scoring_lon})...")
                soil = hwsd_service.get_soil_at_point(scoring_lat, scoring_lon)

                if soil:
                    crop_key = normalize_crop_type(intent.crop_type) if intent.crop_type else None
                    if crop_key:
                        scores = [scoring_engine.score(
                            crop_key, soil.texture, soil.ph_h2o,
                            soil.drainage, soil.organic_carbon
                        )]
                    else:
                        scores = scoring_engine.score_all_crops(
                            soil.texture, soil.ph_h2o,
                            soil.drainage, soil.organic_carbon
                        )

                    # Bentuk data HARUS sama dengan response POST /land-suitability
                    # (SoilInfoOut + CropScoreOut) supaya semua widget frontend
                    # bisa membaca key yang sama. Key pendek seperti `texture`,
                    # `ph`, `oc`, dan `crop` sudah tidak dipakai lagi.
                    hwsd_result = {
                        "lat": scoring_lat,
                        "lon": scoring_lon,
                        "soil_info": {
                            "smu_id": soil.smu_id,
                            "share_pct": soil.share,
                            "texture_code": soil.texture,
                            "texture_label": soil.texture_label,
                            "ph_h2o": soil.ph_h2o,
                            "drainage_code": soil.drainage,
                            "drainage_label": soil.drainage_label,
                            "organic_carbon_pct": soil.organic_carbon,
                            "data_completeness": soil.data_completeness,
                        },
                        "scores": [
                            {
                                "crop_key": s.crop_key,
                                "crop_name": s.crop_name,
                                "overall": s.overall.value,
                                "label": s.label,
                                "emoji": s.emoji,
                                "limiting_factors": s.limiting_factors,
                                "parameters": [
                                    {
                                        "parameter": p.parameter,
                                        "value": p.value,
                                        "suitability": p.suitability.value,
                                        "reason": p.reason,
                                    }
                                    for p in s.parameters
                                ],
                                "note": s.note,
                                "data_sufficient": s.data_sufficient,
                            }
                            for s in scores
                        ],
                    }
                    hwsd_result["summary"] = "\n".join(
                        f"{s['emoji']} {s['crop_name']}: {s['label']}"
                        + (
                            f"\n   Faktor pembatas: {', '.join(s['limiting_factors'])}"
                            if s["limiting_factors"]
                            else ""
                        )
                        for s in hwsd_result["scores"]
                    )
                    print(f"HWSD scoring selesai: {len(scores)} komoditas")
                else:
                    print("HWSD: tidak ada data tanah untuk koordinat ini")
            except Exception as e:
                print(f"HWSD scoring error (non-critical): {e}")

        # 6) Context
        context = self._build_context(
            intent, spatial_results, vector_results, hwsd_result, layer_results
        )

        citations = self._extract_citations(vector_results)
        data_sources = self._data_sources(hwsd_result, layer_results, citations)

        # 6b) Mode streaming: metadata (peta + skor) dikirim lebih dulu supaya
        # UI bisa langsung menampilkannya tanpa menunggu jawaban selesai.
        if on_event is not None:
            await on_event({
                "type": "meta",
                "intent_type": intent.type,
                "places_found": len(spatial_results),
                "documents_found": len(vector_results),
                "citations": citations,
                "geo_json": geo_json,
                "hwsd_result": hwsd_result,
                "data_sources": data_sources,
            })

        # 7) LLM generate
        print(f"\n Generating Answer....")
        llm_start = time.time()
        if on_event is not None:
            potongan = []
            async for chunk in llm_service.generate_answer_stream(context, query):
                potongan.append(chunk)
                await on_event({"type": "token", "text": chunk})
            answer = "".join(potongan)
            llm_result = {
                "answer": answer,
                "model": llm_service.model_name,
                "status": "success",
            }
        else:
            llm_result = await llm_service.generate_answer(context, query)
            answer = llm_result["answer"]
        llm_ms = int((time.time() - llm_start) * 1000)
        print(f" Answer generate ({len(answer)} chars, {llm_ms}ms)")
        elapsed_ms = int((time.time() - start_time) * 1000)
        
        return Pipelineresult(
            query_original=intent.raw_query,
            intent=intent,
            location={"lat": center_lat, "lon": center_lon, "name": intent.location} if center_lat else None,
            spatial_results=spatial_results,
            vector_results=vector_results,
            context=context,
            answer=answer,
            answer_ready=True,
            model_used=llm_result.get("model", "unknown"),
            processing_time_ms=elapsed_ms,
            citations=citations,
            geo_json=geo_json,
            hwsd_result=hwsd_result,
            data_sources=data_sources
        )

    def _match_layer_type(self, location: str) -> Optional[str]:
        """Cocokkan nama lokasi dengan layer_type yang ada (berdasarkan konvensi nama file shapefile)"""
        if not location:
            return None
        
        location_lower = location.lower().replace(' ', '_')
        
        # Mapping manual — sesuaikan dengan layer_type yang benar-benar ada di database
        location_to_layer = {
            'samarinda': 'kawasan_pertanian_kota_samarinda',
            'kutai_barat': 'kawasan_pertanian_kutai_barat',
            'kutai_kartanegara': 'kawasan_pertanian_kutai_kartanegara',
            'kutai_timur': 'kawasan_pertanian_kutai_timur',
        }
        
        for key, layer_type in location_to_layer.items():
            if key in location_lower:
                return layer_type
        
        return None

    def _build_geojson(self, layer_results: List[Dict]) -> Dict:
        """Gabungkan hasil query_intersecting_layers jadi FeatureCollection standar"""
        import json

        features = []
        for row in layer_results:
            try:
                geojson_str = row.get("geojson")
                if not geojson_str:
                    continue
                geometry = json.loads(geojson_str)
            except (KeyError, json.JSONDecodeError, TypeError):
                continue
            
            features.append({
                "type" : "Feature",
                "geometry" : geometry,
                "properties" : {
                    "id": row.get("id"),
                    "name": row.get("name"),
                    "layer_type": row.get("layer_type"),
                    **(row.get("properties") or {})
                }
            })
        return {
            "type": "FeatureCollection",
            "features": features
        }

    def _build_vector_query(self, intent: QueryIntent) -> str:
        """Build query untuk vector search dari intent"""
        parts = []

        if intent.crop_type:
            parts.append(str(intent.crop_type.replace('_', ' ')))
        if intent.category:
            parts.append(str(intent.category))
        if intent.keywords:
            for kw in intent.keywords:
                if isinstance(kw, str):
                    parts.append(kw)
                elif isinstance(kw, list):
                    parts.extend([str(k) for k in kw])
                else:
                    parts.append(str(kw))
        if intent.action:
            parts.append(str(intent.action))

        if not parts:
            return str(intent.raw_query)

        return " ".join(parts)

    def _extract_citations(self, vector_results: List[Dict]) -> List[Dict]:
        """ Ekstrak sumber unik dari hasil vector search """
        citations = []
        seen = set()

        for d in vector_results:
            meta = d.get('metadata', {}) if isinstance(d, dict) else {}
            source = meta.get('source') or meta.get('file') or "Sumber tidak diketahui"
            if source not in seen:
                citations.append({
                    "source": source,
                    "type": meta.get("source_type", "unknown")
                })
                seen.add(source)

        return citations

    def _data_sources(
        self,
        hwsd_result: Optional[Dict],
        layer_results: List[Dict],
        citations: List[Dict],
    ) -> List[Dict]:
        """Ringkasan asal-usul data supaya pengguna tahu sumbernya.

        Ditampilkan di UI (chat dan peta) untuk transparansi. Hanya sumber yang
        benar-benar dipakai pada permintaan ini yang dicantumkan — kalau tidak
        ada data tanah, baris tanah tidak muncul. Sengaja tidak menampilkan
        apa pun yang tidak bisa dipastikan dari data yang ada.
        """
        sumber: List[Dict] = []

        if hwsd_result:
            soil = hwsd_result.get("soil_info") or {}
            sumber.append({
                "jenis": "tanah",
                "label": "HWSD v2.0 (FAO & IIASA)",
                "detail": f"resolusi ~1 km · SMU {soil.get('smu_id', '-')}",
            })

        if layer_results:
            jenis_layer = layer_results[0].get("layer_type") or "-"
            sumber.append({
                "jenis": "kawasan",
                "label": "Shapefile kawasan pertanian",
                "detail": f"{len(layer_results)} polygon · {jenis_layer}",
            })

        if citations:
            nama = ", ".join(str(c.get("source", "?")) for c in citations[:3])
            sisa = len(citations) - 3
            sumber.append({
                "jenis": "dokumen",
                "label": "Dokumen pendukung",
                "detail": f"{len(citations)} berkas: {nama}"
                          + (f" (+{sisa} lagi)" if sisa > 0 else ""),
            })

        return sumber

    # Label komoditas untuk ringkasan konteks (kunci sama dengan yang dipakai
    # enrich_layers_with_soil.py di kolom properties->scores).
    NAMA_KOMODITAS = {
        "padi": "Padi Sawah",
        "jagung": "Jagung",
        "kedelai": "Kedelai",
        "kelapa_sawit": "Kelapa Sawit",
    }

    @staticmethod
    def _properti(layer: Dict) -> Dict:
        """Ambil kolom properties dengan aman (jsonb bisa datang sebagai str)."""
        p = layer.get("properties")
        if isinstance(p, dict):
            return p
        if isinstance(p, str):
            try:
                hasil = json.loads(p)
                return hasil if isinstance(hasil, dict) else {}
            except (ValueError, TypeError):
                return {}
        return {}

    def _sebaran_kelas(self, layers: List[Dict]) -> List[str]:
        """Jumlah kawasan per kelas kesesuaian, untuk tiap komoditas.

        Tujuannya menyelaraskan jawaban teks dengan warna polygon di peta:
        sebelumnya LLM menjawab "data spasial belum tersedia" sementara di
        layar ada ratusan polygon berwarna.
        """
        from collections import Counter

        hitung = {k: Counter() for k in self.NAMA_KOMODITAS}
        for layer in layers:
            skor = self._properti(layer).get("scores") or {}
            if not isinstance(skor, dict):
                continue
            for kunci in self.NAMA_KOMODITAS:
                kelas = skor.get(kunci)
                if kelas:
                    hitung[kunci][kelas] += 1

        hasil = ["Sebaran kelas kesesuaian (jumlah kawasan):"]
        for kunci, label in self.NAMA_KOMODITAS.items():
            c = hitung[kunci]
            if not c:
                continue
            rincian = "  ".join(
                f"{c[k]} {k}" for k in ("S1", "S2", "S3", "N") if c.get(k)
            )
            hasil.append(f"  {label}: {rincian}")
        return hasil

    def _build_context(
        self,
        intent: QueryIntent,
        spatial: List[Dict],
        vector: List[Dict],
        hwsd_result: Optional[Dict] = None,
        layer_results: Optional[List[Dict]] = None,
    ) -> str:
        layers = layer_results or []
        lines = []
        lines.append("=" * 50)
        lines.append(f"Query: {intent.raw_query}")
        lines.append(f"Intent: {intent.type}")

        if intent.location:
            lines.append(f"Location: {intent.location}")
            # Radius hanya bermakna untuk pencarian titik. Untuk query tingkat
            # kabupaten/kota, menyebut "radius 15 km" menyesatkan LLM sehingga
            # jawabannya bilang data tidak tersedia padahal kawasan ada.
            if not layers:
                lines.append(f"Radius: {intent.radius_km} km")

        keywords_str = ", ".join([str(k) for k in intent.keywords]) if intent.keywords else "None"
        lines.append(f"Keywords: {keywords_str}")

        lines.append(f"\n-- Spatial ({len(spatial)} result) --")
        for p in spatial:
            name = p.get('name', 'Unknown')
            dist = p.get('distance_meters', 0)
            lines.append(f"- {name} ({dist:.0f}m)")

        # Ringkasan kawasan dari layer GIS. Tanpa ini LLM tidak tahu ada
        # kawasan di peta, sehingga jawabannya berbunyi "data spasial belum
        # tersedia" padahal di layar terlihat ratusan polygon berwarna.
        if layers:
            lines.append("")
            lines.append(f"-- Kawasan Pertanian terdeteksi: {len(layers)} kawasan --")
            # Nama kawasan di database berupa penanda mesin
            # ("kawasan_pertanian_kutai_timur_125"), bukan nama tempat asli.
            # Sengaja tidak dikirim: LLM bisa salah menganggapnya nama lokasi.
            for baris in self._sebaran_kelas(layers):
                lines.append(baris)

        lines.append(f"\n--- Documents ({len(vector)} results) ---")
        for d in vector:
            meta = d.get('metadata', {}) if isinstance(d, dict) else {}
            source = meta.get('source_type', '?') if isinstance(meta, dict) else '?'
            content = d.get('content', '') if isinstance(d, dict) else str(d)
            lines.append(f"- [{source}] {str(content)[:500]}...")

        # Inject HWSD result ke context
        if hwsd_result:
            lines.append(f"\n--- Analisis Kesesuaian Lahan HWSD ---")
            soil = hwsd_result.get("soil_info", {})
            lines.append(f"Data Tanah (SMU ID: {soil.get('smu_id', 'N/A')})")
            lines.append(f"  Tekstur  : {soil.get('texture_label', 'N/A')}")
            lines.append(f"  pH       : {soil.get('ph_h2o', 'N/A')}")
            lines.append(f"  Drainase : {soil.get('drainage_label', 'N/A')}")
            lines.append(f"  Org. Carbon: {soil.get('organic_carbon_pct', 'N/A')}%")
            lines.append(f"  Kelengkapan data: {soil.get('data_completeness', 'unknown')}")
            lines.append("")
            lines.append("Hasil Scoring Kesesuaian Lahan:")
            for s in hwsd_result.get("scores", []):
                lines.append(f"  {s['emoji']} {s['crop_name']}: {s['label']} ({s['overall']})")
                if s.get('limiting_factors'):
                    lines.append(f"     Faktor pembatas: {', '.join(s['limiting_factors'])}")
                if s.get('note'):
                    lines.append(f"     Catatan: {s['note']}")

            # Beri tahu LLM bila skor berbasis data parsial, supaya jawabannya
            # tidak menyiratkan kepastian yang tidak dimiliki datanya.
            partial = [
                s['crop_name'] for s in hwsd_result.get("scores", [])
                if s.get("data_sufficient") is False
            ]
            if partial:
                lines.append("")
                lines.append(
                    "PENTING: skor untuk "
                    + ", ".join(partial)
                    + " dihitung dengan data tanah yang TIDAK lengkap "
                    "(parameter kosong diasumsikan S2). Sampaikan bahwa hasil ini "
                    "bersifat perkiraan dan sebutkan parameter yang tidak tersedia."
                )

        return "\n".join(lines)
    

pipeline = RAGPipeline()

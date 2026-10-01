import asyncio
import json
from typing import Dict, List, Optional

from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from app.services.pipeline_service import pipeline

router = APIRouter()

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    user_lat: Optional[float] = None
    user_lon: Optional[float] = None

class ChatResponse(BaseModel):
    answer: str
    intent_type: str
    places_found: int
    documents_found: int
    citations: List[dict] = []
    geo_json: Optional[Dict] = None
    hwsd_result: Optional[Dict] = None  # null jika tidak ada data HWSD

@router.post("/chat")
async def chat(request: ChatRequest):
    """
    Endpoint chat conversational
    Ambil pesan terakhir dari user, proses, return jawaban
    """
    last_message = request.messages[-1].content if request.messages else ""

    user_location = None
    if request.user_lat and request.user_lon:
        user_location = {"lat": request.user_lat, "lon": request.user_lon}

    result = await pipeline.process(
        query=last_message,
        user_location=user_location
    )

    return ChatResponse(
        answer=result.answer,
        intent_type=result.intent.type,
        places_found=len(result.spatial_results),
        documents_found=len(result.vector_results),
        citations=result.citations,
        geo_json=result.geo_json,
        hwsd_result=result.hwsd_result,
    )


@router.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    """Versi streaming dari /chat (Server-Sent Events).

    Urutan kejadian:
      {"type":"meta", ...}   peta + skor, dikirim sebelum LLM mulai
      {"type":"token", ...}  potongan jawaban, seiring dihasilkan
      {"type":"done", ...}   jawaban utuh + waktu proses
      {"type":"error", ...}  bila terjadi kegagalan

    Endpoint /chat yang lama tidak diubah, sehingga klien lama tetap jalan.
    """
    last_message = request.messages[-1].content if request.messages else ""

    user_location = None
    if request.user_lat and request.user_lon:
        user_location = {"lat": request.user_lat, "lon": request.user_lon}

    # Pipeline menulis ke queue; generator di bawah membacanya sambil jalan
    # sehingga tiap potongan terkirim segera, tanpa menunggu selesai.
    antrean: asyncio.Queue = asyncio.Queue()

    async def kirim(kejadian: Dict):
        await antrean.put(kejadian)

    async def jalankan():
        try:
            hasil = await pipeline.process(
                query=last_message,
                user_location=user_location,
                on_event=kirim,
            )
            await antrean.put({
                "type": "done",
                "answer": hasil.answer,
                "model_used": hasil.model_used,
                "processing_time_ms": hasil.processing_time_ms,
            })
        except Exception as e:  # noqa: BLE001
            await antrean.put({"type": "error", "message": str(e)})
        finally:
            await antrean.put(None)  # penanda aliran selesai

    async def aliran():
        tugas = asyncio.create_task(jalankan())
        try:
            while True:
                kejadian = await antrean.get()
                if kejadian is None:
                    break
                yield f"data: {json.dumps(kejadian, ensure_ascii=False)}\n\n"
        finally:
            await tugas

    return StreamingResponse(
        aliran(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
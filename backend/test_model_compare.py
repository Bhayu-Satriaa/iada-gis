"""Bandingkan TTFT antar model. Yang menang jadi kandidat Tahap 2."""
import asyncio
import time

from dotenv import load_dotenv

load_dotenv()

from google import genai  # noqa: E402
from google.genai import types  # noqa: E402

KANDIDAT = [
    "gemini-3-flash-preview",
    "gemini-flash-lite-latest",
    "gemini-2.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
]

CTX = (
    "Lokasi: Samarinda (-0.5018, 117.1393)\n"
    "SMU 3749, tekstur Lempung, pH 4.9, drainase Sedang, OC 1.269%\n"
    "Skor: Padi S3 (faktor: pH, drainase), Jagung S3, Sawit S3\n"
)
Q = "cek kesesuaian lahan di samarinda untuk padi"

import os

client = genai.Client(api_key=os.getenv("LLM_API_KEY"))


async def ukur(model):
    cfg = types.GenerateContentConfig(
        temperature=0.2, max_output_tokens=800
    )
    isi = f"KONTEKS DATA:\n{CTX}\n\nPERTANYAAN USER:\n{Q}"
    t0 = time.time()
    ttft = None
    n = 0
    total = 0
    try:
        stream = await client.aio.models.generate_content_stream(
            model=model, contents=isi, config=cfg
        )
        async for chunk in stream:
            if chunk.text:
                if ttft is None:
                    ttft = round(time.time() - t0, 2)
                n += 1
                total += len(chunk.text)
    except Exception as e:  # noqa: BLE001
        print(f"{model:26} GAGAL: {str(e)[:90]}")
        return
    print(
        f"{model:26} TTFT {ttft:>5} s | selesai {round(time.time() - t0, 2):>5} s "
        f"| {n:>3} chunk | {total} char"
    )


async def main():
    for m in KANDIDAT:
        await ukur(m)


asyncio.run(main())

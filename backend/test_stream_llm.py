"""Tes langsung: apakah streaming benar-benar mengalir bertahap?"""
import asyncio
import time

from dotenv import load_dotenv

load_dotenv()

import os  # noqa: E402

os.environ.setdefault("LLM_MODEL", "gemini-3.5-flash-lite")
os.environ["LLM_MODEL"] = os.getenv("UJI_MODEL", "gemini-3.5-flash-lite")

from app.services.llm_service import llm_service  # noqa: E402


async def main():
    ctx = (
        "Lokasi: Samarinda (-0.5018, 117.1393)\n"
        "SMU 3749, tekstur Lempung, pH 4.9, drainase Sedang, OC 1.269%\n"
        "Skor: Padi S3 (faktor: pH, drainase), Jagung S3, Sawit S3\n"
    )
    q = "cek kesesuaian lahan di samarinda untuk padi"

    t0 = time.time()
    potongan = 0
    total = 0
    t_pertama = None
    teks = []

    async for chunk in llm_service.generate_answer_stream(ctx, q):
        if t_pertama is None:
            t_pertama = time.time() - t0
            t_pertama = round(t_pertama, 2)
            print(f"  >> token PERTAMA pada {t_pertama} s")
        potongan += 1
        total += len(chunk)
        teks.append(chunk)

    selesai = round(time.time() - t0, 2)
    print(f"  >> potongan diterima : {potongan}")
    print(f"  >> total karakter    : {total}")
    print(f"  >> selesai pada      : {selesai} s")
    print("  >> kutipan:", "".join(teks)[:150].replace("\n", " "))


asyncio.run(main())

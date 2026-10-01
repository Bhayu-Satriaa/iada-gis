import os
from typing import AsyncIterator, Dict
from google import genai
from google.genai import types

class LLMService:
    def __init__(self):
        api_key = os.getenv("LLM_API_KEY")

        if not api_key:
            print(f"API_KEY tidak ditemukan")

        # Tanpa timeout, request yang lambat menggantung tanpa batas (pernah
        # tercatat 51 detik). Satuan milidetik.
        self.timeout_ms = int(os.getenv("LLM_TIMEOUT_MS", "20000"))
        self.client = genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(timeout=self.timeout_ms),
        )

        self.model_name = os.getenv("LLM_MODEL")

        # Batasi panjang jawaban: tiap token keluaran memakan waktu. Tanpa
        # batas, model bisa menulis sepanjang yang ia mau.
        self.max_output_tokens = int(os.getenv("LLM_MAX_OUTPUT_TOKENS", "800"))
        self.temperature = float(os.getenv("LLM_TEMPERATURE", "0.2"))

        self.system_prompt = """
        Anda adalah IADA (Intelligent Agriculture Data Assistant), asisten AI khusus untuk pertanian di Kalimantan Timur.
        ATURAN:
        1. Jawab berdasarkan DATA yang diberikan di konteks.
        2. Kalau ada data lokasi/spatial, sebutkan jarak dan koordinatnya.
        3. Kalau ada dokumen relevan, rangkum informasinya.
        4. Gunakan bahasa Indonesia yang santai dan mudah dipahami petani.
        5. Kalau data tidak cukup, bilang jujur: "Data belum tersedia untuk [X]".
        6. Jangan membuat informasi yang tidak ada di konteks!
        7. Jika ada data kesesuaian lahan HWSD, jelaskan hasilnya dengan bahasa sederhana.

        FORMAT JAWABAN:
        - Lokasi: [nama tempat]
        - Jarak: [X km dari pusat]
        - Informasi: [rangkuman dari dokumen]
        - Rekomendasi: [saran praktis]
        """

    def is_available(self) -> bool:
        """Cek apakah LLM service terkonfigurasi (punya API key + model)"""
        api_key = os.getenv("LLM_API_KEY")
        return bool(api_key and self.model_name)

    def _config(self) -> types.GenerateContentConfig:
        """Konfigurasi bersama untuk generate biasa maupun streaming."""
        return types.GenerateContentConfig(
            system_instruction=self.system_prompt,
            temperature=self.temperature,
            max_output_tokens=self.max_output_tokens,
        )

    @staticmethod
    def _build_contents(context: str, user_query: str) -> str:
        # System prompt kini dikirim lewat system_instruction, bukan ditempel
        # di dalam isi prompt, supaya bisa di-cache penyedia.
        return (
            "KONTEKS DATA:\n"
            f"{context}\n\n"
            "PERTANYAAN USER:\n"
            f"{user_query}\n\n"
            "Berikan jawaban berdasarkan konteks di atas"
        )

    async def generate_answer(self, context: str, user_query: str) -> Dict:
        """
        Generate jawaban dari context + query menggunakan Gemini

        Returns:
            {
                "answer": str,
                "model": str,
                "status": "success" | "fallback" | "error"
            }
        """
        try:
            contents = self._build_contents(context, user_query)

            response = await self.client.aio.models.generate_content(
                model=self.model_name,
                contents=contents,
                config=self._config(),
            )

            answer = response.text if response.text else "Maaf, tidak bisa generate jawaban"

            return {
                "answer": answer,
                "model": self.model_name,
                "status": "success"
            }

        except Exception as e:
            print(f"Gemini Error: {e}")
            return {
                "answer": self._fallback_answer(context, user_query),
                "model": f"{self.model_name} (fallback)",
                "status": "fallback",
                "error": str(e)
            }
        
    async def generate_answer_stream(
        self, context: str, user_query: str
    ) -> AsyncIterator[str]:
        """Stream potongan jawaban begitu tersedia.

        Ini yang membuat perbedaan terasa: token pertama muncul ~1 detik,
        bukan menunggu 6-10 detik tanpa umpan balik apa pun.
        """
        contents = self._build_contents(context, user_query)
        stream = await self.client.aio.models.generate_content_stream(
            model=self.model_name,
            contents=contents,
            config=self._config(),
        )
        async for chunk in stream:
            if chunk.text:
                yield chunk.text

    def _fallback_answer(self, context: str, query: str) -> str:
        lines = [
            "Berikut informasi yang ditemukan dari database: ",
            "",
            context[:1500],
            "",
            "Jawaban berasal dari database kami"
        ]
        return "\n".join(lines)
    

llm_service = LLMService()
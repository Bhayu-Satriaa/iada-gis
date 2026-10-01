@echo off
cd /d "D:\Politani\IT Comp - IoT\iada_gis\backend"
call venv\Scripts\activate

echo ===== MODEL: gemini-3.5-flash-lite =====
set UJI_MODEL=gemini-3.5-flash-lite
python test_stream_llm.py

echo.
echo ===== MODEL: gemini-3-flash-preview (lama) =====
set UJI_MODEL=gemini-3-flash-preview
python test_stream_llm.py

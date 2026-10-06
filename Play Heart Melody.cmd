@echo off
cd /d "%~dp0"
echo Heart Melody opens at http://127.0.0.1:8772/heart.html
echo Keep this window open while playing. Press Ctrl+C to stop the server.
python tools\serve_heart_web.py --port 8772
pause

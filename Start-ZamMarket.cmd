@echo off
cd /d "%~dp0"
echo Starting the ZamNexus application at http://127.0.0.1:5173/
echo Keep this window open while using the local website.
call npm run dev
pause

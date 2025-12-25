# Quick Start - Backend Server

## The Problem
You got `ModuleNotFoundError: No module named 'app'` because uvicorn needs to run from the `backend` directory.

## The Fix

You're already in the `backend` directory! Just run:

```powershell
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or use the script:
```powershell
.\start_server.ps1
```

## Why This Works

- The `app` module is in `backend/app/`
- Uvicorn needs to be run from `backend/` directory
- The command `app.main:app` means: "import `app` package, get `main` module, use `app` variable"

## Alternative: Use Python Module

```powershell
.\venv\Scripts\Activate.ps1
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## What You Should See

```
INFO:     Will watch for changes in these directories: ['D:\\p\\TazeinDecor-Main\\backend\\app']
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process [XXXX] using WatchFiles
INFO:     Started server process [XXXX]
INFO:     Waiting for application startup.
✅ Database initialized successfully
INFO:     Application startup complete.
```

Then test: http://localhost:8000/docs


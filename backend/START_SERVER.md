# How to Start the Backend Server

## Problem
If you get `ModuleNotFoundError: No module named 'app'`, you're running uvicorn from the wrong directory.

## Solution

### Option 1: Use the Script (Easiest)

**Windows (PowerShell):**
```powershell
cd backend
.\start_server.ps1
```

**Windows (CMD):**
```cmd
cd backend
start_server.bat
```

### Option 2: Manual Start

**Step 1: Navigate to backend directory**
```powershell
cd backend
```

**Step 2: Activate virtual environment**
```powershell
.\venv\Scripts\Activate.ps1
```

**Step 3: Run uvicorn**
```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Option 3: Using Python Module

From the `backend` directory:
```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Important Notes

1. **Always run from `backend` directory** - The `app` module is inside `backend/app/`
2. **Activate virtual environment first** - Ensures all dependencies are available
3. **Use `app.main:app`** - This tells uvicorn to import `app` from the `app` package

## Quick Command (One Line)

From project root:
```powershell
cd backend; .\venv\Scripts\Activate.ps1; uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Verify It's Working

After starting, you should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
✅ Database initialized successfully
```

Then test: http://localhost:8000/docs


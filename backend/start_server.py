#!/usr/bin/env python3
"""
Startup script for Liara deployment
Ensures PORT is always set before running uvicorn
"""
import os
import sys

# CRITICAL: Set PORT in environment FIRST, before any imports
# This ensures uvicorn and all subprocesses can access PORT
if not os.getenv("PORT"):
    os.environ["PORT"] = "80"

# Get port and ensure it's valid
port_str = os.getenv("PORT", "80")
try:
    port = int(port_str)
except (ValueError, TypeError):
    port = 80
    os.environ["PORT"] = "80"

# Ensure port is positive
if port <= 0:
    port = 80
    os.environ["PORT"] = "80"

print(f"🚀 Starting server on port {port} (PORT env: {os.getenv('PORT')})")
print(f"🔍 Environment check - PORT exists: {bool(os.getenv('PORT'))}, value: {os.getenv('PORT')}")

# CRITICAL: Ensure PORT is definitely set before importing uvicorn
# This is especially important for worker subprocesses
os.environ["PORT"] = str(port)
print(f"✅ PORT confirmed set to: {os.getenv('PORT')}")

# Temporary monkey patch for passlib+bcrypt compatibility.
# Newer bcrypt releases (>=4.1) removed the __about__ attribute that
# passlib 1.x expects. Add it back before anything imports passlib.
import bcrypt  # type: ignore

if not hasattr(bcrypt, "__about__"):
    class _About:
        __version__ = getattr(bcrypt, "__version__", "unknown")

    bcrypt.__about__ = _About()

# Import uvicorn after setting PORT
import uvicorn

# Run uvicorn - PORT is already set in environment and passed explicitly
if __name__ == "__main__":
    # Use uvicorn.run() with explicit port parameter
    # PORT is also set in environment for worker subprocesses
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=port,
        workers=4,
        log_level="info",
        access_log=True,
    )


#!/usr/bin/env python3
"""
Startup script for Liara deployment
Ensures PORT is always set before running uvicorn
"""
import os
import sys

# Set PORT to 80 if not already set
if not os.getenv("PORT"):
    os.environ["PORT"] = "80"

port = os.getenv("PORT", "80")
print(f"🚀 Starting server on port {port}")

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

# Run uvicorn
if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(port),
        workers=4,
        log_level="info",
        access_log=True,
    )


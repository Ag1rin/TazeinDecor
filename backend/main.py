"""
Production entry point for FastAPI application
"""
import os

# Temporary monkey patch for passlib+bcrypt compatibility.
# Newer bcrypt releases (>=4.1) removed the __about__ attribute that
# passlib 1.x expects. Add it back before anything imports passlib.
import bcrypt  # type: ignore

if not hasattr(bcrypt, "__about__"):
    class _About:
        __version__ = getattr(bcrypt, "__version__", "unknown")

    bcrypt.__about__ = _About()

import uvicorn
from app.main import app as fastapi_app

# Expose the FastAPI instance so `uvicorn main:app` works
app = fastapi_app

# Determine if we're in development or production
# Set ENVIRONMENT=production in production, or leave unset for development
is_production = os.getenv("ENVIRONMENT", "development").lower() == "production"

if __name__ == "__main__":
    # Get port from environment variable (required by Heroku/Liara, optional for VPS)
    # Default to 8000 for local/VPS development, or use PORT env var
    # Also check settings.PORT as fallback
    from app.config import settings
    port_env = os.getenv("PORT")
    if port_env:
        port = int(port_env)
    else:
        port = settings.PORT
    
    # Production configuration
    if is_production:
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",  # Listen on all interfaces
            port=port,
            log_level="info",
            reload=False,  # Never reload in production
            workers=4,  # Use multiple workers for better performance
            access_log=True,
        )
    else:
        # Development configuration
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=port,
            log_level="info",  # Use info instead of debug to reduce noise
            reload=True,  # Auto-reload on code changes
            reload_dirs=["app"],  # Only watch app directory
            reload_excludes=["*.pyc", "__pycache__", "*.db", "*.db-journal"],  # Exclude unnecessary files
        )

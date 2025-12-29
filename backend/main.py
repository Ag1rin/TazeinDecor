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
    # Liara uses port 80 by default if PORT is not set
    # Default to 80 for Liara/production, 8000 for local development
    from app.config import settings
    
    # Get PORT from environment, with proper fallback
    port_env = os.getenv("PORT")
    if port_env and port_env.strip():
        try:
            port = int(port_env.strip())
        except (ValueError, TypeError):
            # If PORT env var is invalid, use default from settings
            port = settings.PORT
    else:
        # No PORT env var set, use default from settings (80 for Liara)
        port = settings.PORT
    
    # Ensure port is always a valid integer (final safety check)
    if not isinstance(port, int) or port <= 0:
        port = 80  # Final fallback to port 80 for Liara
    
    # Print port for debugging (helps in deployment logs)
    print(f"🚀 Starting server on port {port} (ENVIRONMENT={os.getenv('ENVIRONMENT', 'development')})")
    
    # Production configuration
    if is_production:
        uvicorn.run(
            app="app.main:app",
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
            app="app.main:app",
            host="0.0.0.0",
            port=port,
            log_level="info",  # Use info instead of debug to reduce noise
            reload=True,  # Auto-reload on code changes
            reload_dirs=["app"],  # Only watch app directory
            reload_excludes=["*.pyc", "__pycache__", "*.db", "*.db-journal"],  # Exclude unnecessary files
        )

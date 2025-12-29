"""
Database configuration and session management
"""
import os
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings

# Ensure database directory exists for SQLite
if "sqlite" in settings.DATABASE_URL.lower():
    # Extract path from SQLite URL
    db_path = settings.DATABASE_URL.replace("sqlite:///", "")
    # Handle relative paths (remove ./ if present)
    if db_path.startswith("./"):
        db_path = db_path[2:]
    # Get absolute path
    if not os.path.isabs(db_path):
        db_path = os.path.abspath(db_path)
    # Create directory if it doesn't exist
    db_dir = os.path.dirname(db_path)
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)

# Create database engine
# For PostgreSQL, set timezone to Asia/Tehran
connect_args = {}
if "sqlite" in settings.DATABASE_URL.lower():
    connect_args = {"check_same_thread": False}
elif "postgresql" in settings.DATABASE_URL.lower():
    # Set timezone to Asia/Tehran for PostgreSQL connections
    connect_args = {"options": "-c timezone=Asia/Tehran"}

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True  # Verify connections before using
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


def get_db():
    """Dependency for getting database session"""
    db = SessionLocal()
    try:
        # Set timezone to Asia/Tehran for PostgreSQL connections
        if "postgresql" in settings.DATABASE_URL.lower():
            db.execute(text("SET timezone = 'Asia/Tehran'"))
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables"""
    try:
        # Ensure directory exists for SQLite (only for SQLite databases)
        if "sqlite" in settings.DATABASE_URL.lower():
            db_path = settings.DATABASE_URL.replace("sqlite:///", "")
            # Handle relative paths (remove ./ if present)
            if db_path.startswith("./"):
                db_path = db_path[2:]
            # Convert to absolute path
            if not os.path.isabs(db_path):
                db_path = os.path.abspath(db_path)
            # Create directory if it doesn't exist
            db_dir = os.path.dirname(db_path)
            if db_dir:
                try:
                    os.makedirs(db_dir, exist_ok=True)
                except PermissionError:
                    raise Exception(
                        f"Permission denied creating database directory: {db_dir}. "
                        f"This usually means SQLite fallback failed. "
                        f"Please set DATABASE_URL to a proper PostgreSQL connection string."
                    )
        
        # Create all tables
        Base.metadata.create_all(bind=engine)
        print(f"Database initialized successfully: {settings.DATABASE_URL[:50]}...")
    except Exception as e:
        error_msg = str(e)
        # Provide helpful error message
        if "tazeindecor-data" in settings.DATABASE_URL:
            error_msg += (
                "\n\n⚠️  DATABASE_URL points to local Docker container 'tazeindecor-data' "
                "which is not available on this server.\n"
                "Please set DATABASE_URL to your production database connection string "
                "(e.g., Liara PostgreSQL)."
            )
        elif "sqlite" in settings.DATABASE_URL.lower() and "Permission denied" in error_msg:
            error_msg += (
                "\n\n⚠️  SQLite cannot be used in containerized environments due to permissions.\n"
                "Please set DATABASE_URL to PostgreSQL connection string."
            )
        raise Exception(f"Failed to initialize database: {error_msg}")


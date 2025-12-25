"""
Configuration settings for the application
"""
import os
from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import model_validator
import dotenv



class Settings(BaseSettings):
    """Application settings"""
    
    # Database
    DATABASE_URL: str = "sqlite:///./data/tazeindecor.db"
    
    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    
    # WooCommerce - Support both WOO_* and WOOCOMMERCE_* naming
    WOO_URL: Optional[str] = None
    WOO_CONSUMER_KEY: Optional[str] = None
    WOO_CONSUMER_SECRET: Optional[str] = None
    
    WOOCOMMERCE_URL: Optional[str] = "https://tazeindecor.com"
    WOOCOMMERCE_CONSUMER_KEY: str = ""
    WOOCOMMERCE_CONSUMER_SECRET: str = ""
    
    # CORS
    CORS_ORIGINS: list = ["*"]
    
    # File Upload
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_SIZE: int = 10 * 1024 * 1024  # 10MB
    
    # SMS (Twilio or similar)
    SMS_API_KEY: Optional[str] = None
    
    # App Version
    APP_VERSION: str = "1.0.1"
    
    @model_validator(mode='after')
    def sync_woo_variables(self):
        """Sync WOO_* variables to WOOCOMMERCE_* if WOOCOMMERCE_* are not set"""
        # Use WOO_* if WOOCOMMERCE_* is not provided
        if self.WOO_URL:
            self.WOOCOMMERCE_URL = self.WOO_URL
        if self.WOO_CONSUMER_KEY:
            self.WOOCOMMERCE_CONSUMER_KEY = self.WOO_CONSUMER_KEY
        if self.WOO_CONSUMER_SECRET:
            self.WOOCOMMERCE_CONSUMER_SECRET = self.WOO_CONSUMER_SECRET
        # Ensure WOOCOMMERCE_URL has a default
        if not self.WOOCOMMERCE_URL:
            self.WOOCOMMERCE_URL = "https://tazeindecor.com"
        return self
    
    @model_validator(mode='after')
    def check_database_url(self):
        """Validate and prepare database URL"""
        # Check if we're in production (Liara, Heroku, etc.)
        is_production = os.getenv("ENVIRONMENT", "development").lower() == "production"
        
        # If DATABASE_URL points to a Docker container that doesn't exist
        # AND we're in production, this is an error - don't fallback
        if is_production and "tazeindecor-data" in self.DATABASE_URL:
            raise ValueError(
                "DATABASE_URL points to local Docker container 'tazeindecor-data' "
                "which is not available in production. Please set DATABASE_URL to "
                "your production database (e.g., Liara PostgreSQL connection string)."
            )
        
        # Only fallback to SQLite in local development
        if not is_production and self.DATABASE_URL and "sqlite" not in self.DATABASE_URL.lower():
            if "tazeindecor-data" in self.DATABASE_URL:
                print("Warning: DATABASE_URL points to Docker container 'tazeindecor-data' which is not available locally.")
                print("Falling back to SQLite for local development.")
                db_dir = os.path.join(os.getcwd(), "data")
                os.makedirs(db_dir, exist_ok=True)
                db_path = os.path.join(db_dir, "tazeindecor.db")
                self.DATABASE_URL = f"sqlite:///{os.path.abspath(db_path)}"
        
        # Ensure SQLite database directory exists (only for SQLite)
        if "sqlite" in self.DATABASE_URL.lower():
            db_path = self.DATABASE_URL.replace("sqlite:///", "")
            if db_path.startswith("./"):
                db_path = db_path[2:]
            if not os.path.isabs(db_path):
                db_path = os.path.abspath(db_path)
            db_dir = os.path.dirname(db_path)
            if db_dir and db_dir != os.getcwd():
                os.makedirs(db_dir, exist_ok=True)
            self.DATABASE_URL = f"sqlite:///{db_path}"
        
        return self
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "allow"  # Allow extra fields to prevent validation errors


settings = Settings()


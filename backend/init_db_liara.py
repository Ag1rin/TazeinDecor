"""
Initialize database and create admin user for Liara
Run this via: liara shell -> python init_db_liara.py
"""
import os
import sys

# Ensure we're using the production database
os.environ.setdefault("ENVIRONMENT", "production")

from app.database import SessionLocal, init_db
from app.models import User, UserRole
from passlib.context import CryptContext

# Create password context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """Hash password with bcrypt"""
    try:
        password_bytes = password.encode('utf-8')
        if len(password_bytes) > 72:
            password = password_bytes[:72].decode('utf-8')
        return pwd_context.hash(password)
    except Exception as e:
        print(f"Error hashing password: {e}")
        import hashlib
        return hashlib.sha256(password.encode()).hexdigest()

def create_admin_user():
    """Create default admin user"""
    db = SessionLocal()
    
    try:
        # Check if admin exists
        existing = db.query(User).filter(User.username == "admin").first()
        if existing:
            print("=" * 50)
            print("Admin user already exists!")
            print(f"Username: {existing.username}")
            print("=" * 50)
            return
        
        # Create admin user
        password_hash = get_password_hash("admin123")
        admin = User(
            username="admin",
            password_hash=password_hash,
            full_name="مدیر سیستم",
            mobile="09123456789",
            role=UserRole.ADMIN,
            is_active=True
        )
        
        db.add(admin)
        db.commit()
        print("=" * 50)
        print("✅ Admin user created successfully!")
        print("=" * 50)
        print("Username: admin")
        print("Password: admin123")
        print("=" * 50)
        print("⚠️  IMPORTANT: Change the password after first login!")
        print("=" * 50)
        
    except Exception as e:
        print(f"❌ Error creating admin user: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    print("Initializing database on Liara...")
    print(f"DATABASE_URL: {os.getenv('DATABASE_URL', 'Not set')}")
    print()
    
    try:
        init_db()
        print("✅ Database initialized successfully!")
    except Exception as e:
        print(f"❌ Database initialization error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    
    print("\nCreating admin user...")
    create_admin_user()
    print("\n✅ Done! You can now login with admin/admin123")


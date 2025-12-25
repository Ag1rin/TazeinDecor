"""
Reset admin password - use this if password hash is corrupted
Run: python reset_admin_password.py
"""
import os
import sys

# Ensure we're using the production database
os.environ.setdefault("ENVIRONMENT", "production")

from app.database import SessionLocal
from app.models import User, UserRole
import bcrypt

def get_password_hash(password: str) -> str:
    """Hash password with bcrypt directly"""
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')

def reset_admin_password():
    """Reset admin password to 'admin123'"""
    db = SessionLocal()
    
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        
        if not admin:
            print("❌ Admin user not found!")
            print("Creating admin user...")
            admin = User(
                username="admin",
                password_hash=get_password_hash("admin123"),
                full_name="مدیر سیستم",
                mobile="09123456789",
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin)
        else:
            print(f"Found admin user: {admin.username}")
            print(f"Current hash preview: {admin.password_hash[:50] if admin.password_hash else 'None'}...")
            
            # Check if hash is valid
            is_valid = admin.password_hash and admin.password_hash.startswith('$2')
            if not is_valid:
                print("⚠️  Current password hash is INVALID (not bcrypt format)")
                print("   This is why login is failing!")
            else:
                print("✓ Current password hash format is valid")
            
            print("Resetting password to 'admin123'...")
            admin.password_hash = get_password_hash("admin123")
            admin.is_active = True  # Ensure user is active
        
        db.commit()
        db.refresh(admin)
        
        # Verify the new hash
        new_hash_valid = admin.password_hash and admin.password_hash.startswith('$2')
        print("=" * 50)
        if new_hash_valid:
            print("✅ Admin password reset successfully!")
            print(f"New hash preview: {admin.password_hash[:50]}...")
        else:
            print("❌ ERROR: New password hash is still invalid!")
        print("=" * 50)
        print("Username: admin")
        print("Password: admin123")
        print("=" * 50)
        print("⚠️  IMPORTANT: Change the password after login!")
        print("=" * 50)
        
    except Exception as e:
        print(f"❌ Error resetting password: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    print("Resetting admin password...")
    reset_admin_password()
    print("\n✅ Done!")


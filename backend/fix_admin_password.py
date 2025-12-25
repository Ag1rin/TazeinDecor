"""
Quick fix script to reset admin password - run this on Liara
Usage: python fix_admin_password.py
"""
import os
import sys

# Ensure we're using the production database
os.environ.setdefault("ENVIRONMENT", "production")

from app.database import SessionLocal
from app.models import User, UserRole
import bcrypt

def get_password_hash(password: str) -> str:
    """Hash password with bcrypt directly (bypassing passlib issues)"""
    # bcrypt passwords cannot be longer than 72 bytes
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        print(f"Warning: Password too long ({len(password_bytes)} bytes), truncating to 72 bytes")
        password_bytes = password_bytes[:72]
    
    # Generate salt and hash
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')

def fix_admin_password():
    """Fix admin password hash"""
    db = SessionLocal()
    
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        
        if not admin:
            print("Creating new admin user...")
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
            print(f"Old hash: {admin.password_hash[:50] if admin.password_hash else 'None'}...")
            
            # Always reset the password hash
            print("Setting new password hash...")
            admin.password_hash = get_password_hash("admin123")
            admin.is_active = True
        
        db.commit()
        db.refresh(admin)
        
        # Verify
        if admin.password_hash and admin.password_hash.startswith('$2'):
            print("=" * 60)
            print("✅ SUCCESS! Admin password has been reset")
            print("=" * 60)
            print("Username: admin")
            print("Password: admin123")
            print("=" * 60)
            print("You can now login with these credentials")
            print("=" * 60)
            
            # Test verification
            test_password = "admin123"
            test_bytes = test_password.encode('utf-8')
            if len(test_bytes) > 72:
                test_bytes = test_bytes[:72]
            if bcrypt.checkpw(test_bytes, admin.password_hash.encode('utf-8')):
                print("✓ Password verification test: PASSED")
            else:
                print("⚠️  Password verification test: FAILED (but hash looks valid)")
        else:
            print("❌ ERROR: Password hash is still invalid!")
            print(f"Hash: {admin.password_hash}")
            sys.exit(1)
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    print("Fixing admin password...")
    print()
    fix_admin_password()
    print("\n✅ Done!")


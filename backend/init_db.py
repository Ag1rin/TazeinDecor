"""
Initialize database with admin user
Run this script once to create the initial admin user
"""
from app.database import SessionLocal, init_db
from app.models import User, UserRole
from app.routers.auth import get_password_hash

def create_admin_user():
    """Create default admin user"""
    db = SessionLocal()
    
    try:
        # Check if admin exists
        existing = db.query(User).filter(User.username == "admin").first()
        if existing:
            print("Admin user already exists!")
            return
        
        # Create admin user
        admin = User(
            username="admin",
            password_hash=get_password_hash("admin123"),
            full_name="مدیر سیستم",
            mobile="09123456789",
            role=UserRole.ADMIN,
            is_active=True
        )
        
        db.add(admin)
        db.commit()
        print("Admin user created successfully!")
        print("Username: admin")
        print("Password: admin123")
        print("Please change the password after first login!")
        
    except Exception as e:
        print(f"Error creating admin user: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("Initializing database...")
    init_db()
    print("Creating admin user...")
    create_admin_user()
    print("Done!")


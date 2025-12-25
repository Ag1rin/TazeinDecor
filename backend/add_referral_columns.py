"""
Quick migration script to add referral_code to users and referrer_id to orders
Run this once to update the database schema
"""
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import text
from app.database import engine

def run_migration():
    """Add referral code columns to database"""
    print("Starting migration to add referral code columns...")
    
    with engine.connect() as conn:
        # Add referral_code column to users
        try:
            conn.execute(text("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(10) UNIQUE
            """))
            print("✅ Added referral_code column to users table")
        except Exception as e:
            if "already exists" in str(e).lower():
                print("✅ referral_code column already exists")
            else:
                print(f"⚠️ Error adding referral_code: {e}")
        
        # Add referrer_id column to orders
        try:
            conn.execute(text("""
                ALTER TABLE orders ADD COLUMN IF NOT EXISTS referrer_id INTEGER REFERENCES users(id)
            """))
            print("✅ Added referrer_id column to orders table")
        except Exception as e:
            if "already exists" in str(e).lower():
                print("✅ referrer_id column already exists")
            else:
                print(f"⚠️ Error adding referrer_id: {e}")
        
        # Create index for referral_code lookups
        try:
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_users_referral_code ON users(referral_code) WHERE referral_code IS NOT NULL
            """))
            print("✅ Created index for referral_code")
        except Exception as e:
            print(f"⚠️ Index creation note: {e}")
        
        # Create index for referrer_id lookups
        try:
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_orders_referrer_id ON orders(referrer_id) WHERE referrer_id IS NOT NULL
            """))
            print("✅ Created index for referrer_id")
        except Exception as e:
            print(f"⚠️ Index creation note: {e}")
        
        # Commit the changes
        conn.commit()
        print("✅ Migration completed successfully!")
        
        # Generate referral codes for existing sellers/store managers
        try:
            result = conn.execute(text("""
                SELECT COUNT(*) FROM users WHERE role IN ('seller', 'store_manager') AND referral_code IS NULL
            """))
            count = result.scalar()
            if count > 0:
                print(f"📝 Found {count} users without referral codes. Generating...")
                # Generate codes using Python
                import secrets
                import string
                
                result = conn.execute(text("""
                    SELECT id FROM users WHERE role IN ('seller', 'store_manager') AND referral_code IS NULL
                """))
                users = result.fetchall()
                
                for user in users:
                    # Generate unique code
                    while True:
                        code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
                        # Check if unique
                        check = conn.execute(text("SELECT COUNT(*) FROM users WHERE referral_code = :code"), {"code": code})
                        if check.scalar() == 0:
                            break
                    
                    conn.execute(text("UPDATE users SET referral_code = :code WHERE id = :id"), {"code": code, "id": user[0]})
                    print(f"  Generated code {code} for user {user[0]}")
                
                conn.commit()
                print(f"✅ Generated referral codes for {len(users)} users")
            else:
                print("✅ All eligible users already have referral codes")
        except Exception as e:
            print(f"⚠️ Error generating codes: {e}")

if __name__ == "__main__":
    run_migration()


"""
Quick migration runner - Add created_by column to users table
Run this script directly: python run_migration.py
"""
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from migrations.add_created_by_to_users import run_migration

if __name__ == "__main__":
    print("🔄 Running migration to add 'created_by' column to users table...")
    try:
        run_migration()
        print("✅ Migration completed!")
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        print("\n💡 Alternative: Run this SQL directly on your database:")
        print("   ALTER TABLE users ADD COLUMN created_by INTEGER REFERENCES users(id) ON DELETE SET NULL;")
        sys.exit(1)


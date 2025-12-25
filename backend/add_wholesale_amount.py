"""
Migration script to add wholesale_amount column to orders table
Works with both SQLite and PostgreSQL
"""
import os
import sys
from sqlalchemy import create_engine, text, inspect
from sqlalchemy.orm import sessionmaker
from app.config import settings

# Create database engine
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL.lower() else {},
)

SessionLocal = sessionmaker(bind=engine)

def column_exists(table_name, column_name, inspector):
    """Check if a column exists in a table"""
    columns = [col['name'] for col in inspector.get_columns(table_name)]
    return column_name in columns

def add_column_if_not_exists(table_name, column_name, column_type, session, inspector):
    """Add a column if it doesn't exist"""
    if column_exists(table_name, column_name, inspector):
        print(f"ℹ️  Column {column_name} already exists")
        return False
    
    try:
        if "sqlite" in settings.DATABASE_URL.lower():
            # SQLite syntax
            session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"))
        else:
            # PostgreSQL syntax
            session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"))
        session.commit()
        print(f"✅ Added column: {column_name}")
        return True
    except Exception as e:
        session.rollback()
        print(f"⚠️  Could not add {column_name}: {e}")
        return False

def run_migration():
    """Run the migration"""
    print(f"📦 Connecting to database: {settings.DATABASE_URL[:50]}...")
    
    inspector = inspect(engine)
    
    # Check if orders table exists
    if "orders" not in inspector.get_table_names():
        print("❌ Table 'orders' does not exist!")
        return False
    
    session = SessionLocal()
    added_fields = []
    
    try:
        # Add wholesale_amount column
        column_type = "REAL" if "sqlite" in settings.DATABASE_URL.lower() else "DOUBLE PRECISION"
        if add_column_if_not_exists("orders", "wholesale_amount", column_type, session, inspector):
            added_fields.append("wholesale_amount")
        
    finally:
        session.close()
    
    if added_fields:
        print(f"\n✅ Successfully added {len(added_fields)} new column(s) to orders table")
        print("📝 Added fields:", ", ".join(added_fields))
    else:
        print("\nℹ️  Column wholesale_amount already exists in the database")
    
    print("\n✨ Migration complete!")
    return True

def main():
    try:
        run_migration()
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        print("\n💡 Alternative: Run this SQL directly on your database:")
        if "postgresql" in settings.DATABASE_URL.lower():
            print("   ALTER TABLE orders ADD COLUMN wholesale_amount DOUBLE PRECISION;")
        else:
            print("   ALTER TABLE orders ADD COLUMN wholesale_amount REAL;")
        sys.exit(1)

if __name__ == "__main__":
    main()


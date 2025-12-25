"""
Migration script to add invoice fields to orders table
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

def main():
    print(f"📦 Connecting to database: {settings.DATABASE_URL[:50]}...")
    
    inspector = inspect(engine)
    
    # Check if orders table exists
    if "orders" not in inspector.get_table_names():
        print("❌ Table 'orders' does not exist!")
        sys.exit(1)
    
    session = SessionLocal()
    added_fields = []
    
    try:
        # Invoice fields
        invoice_fields = [
            ("invoice_number", "VARCHAR(255)" if "postgresql" in settings.DATABASE_URL.lower() else "TEXT"),
            ("issue_date", "TIMESTAMP WITH TIME ZONE" if "postgresql" in settings.DATABASE_URL.lower() else "TIMESTAMP"),
            ("due_date", "TIMESTAMP WITH TIME ZONE" if "postgresql" in settings.DATABASE_URL.lower() else "TIMESTAMP"),
            ("subtotal", "REAL" if "postgresql" in settings.DATABASE_URL.lower() else "REAL"),
            ("tax_amount", "REAL DEFAULT 0.0"),
            ("discount_amount", "REAL DEFAULT 0.0"),
            ("payment_terms", "TEXT"),
            ("edit_requested_by", "INTEGER"),
            ("edit_requested_at", "TIMESTAMP WITH TIME ZONE" if "postgresql" in settings.DATABASE_URL.lower() else "TIMESTAMP"),
            ("edit_approved_by", "INTEGER"),
            ("edit_approved_at", "TIMESTAMP WITH TIME ZONE" if "postgresql" in settings.DATABASE_URL.lower() else "TIMESTAMP"),
        ]
        
        for field_name, field_type in invoice_fields:
            if add_column_if_not_exists("orders", field_name, field_type, session, inspector):
                added_fields.append(field_name)
        
        # Add foreign key constraints for PostgreSQL
        if "postgresql" in settings.DATABASE_URL.lower():
            try:
                # Check if foreign key constraints exist
                constraints = inspector.get_foreign_keys("orders")
                fk_names = [fk['name'] for fk in constraints]
                
                # Add foreign key for edit_requested_by if column exists and constraint doesn't
                if "edit_requested_by" in [col['name'] for col in inspector.get_columns("orders")]:
                    if not any("edit_requested_by" in str(fk) for fk in constraints):
                        try:
                            session.execute(text(
                                "ALTER TABLE orders ADD CONSTRAINT fk_orders_edit_requested_by "
                                "FOREIGN KEY (edit_requested_by) REFERENCES users(id)"
                            ))
                            session.commit()
                            print("✅ Added foreign key constraint: edit_requested_by")
                        except Exception as e:
                            session.rollback()
                            if "already exists" not in str(e).lower():
                                print(f"⚠️  Could not add FK for edit_requested_by: {e}")
                
                # Add foreign key for edit_approved_by if column exists and constraint doesn't
                if "edit_approved_by" in [col['name'] for col in inspector.get_columns("orders")]:
                    if not any("edit_approved_by" in str(fk) for fk in constraints):
                        try:
                            session.execute(text(
                                "ALTER TABLE orders ADD CONSTRAINT fk_orders_edit_approved_by "
                                "FOREIGN KEY (edit_approved_by) REFERENCES users(id)"
                            ))
                            session.commit()
                            print("✅ Added foreign key constraint: edit_approved_by")
                        except Exception as e:
                            session.rollback()
                            if "already exists" not in str(e).lower():
                                print(f"⚠️  Could not add FK for edit_approved_by: {e}")
            except Exception as e:
                print(f"⚠️  Could not add foreign key constraints: {e}")
        
    finally:
        session.close()
    
    if added_fields:
        print(f"\n✅ Successfully added {len(added_fields)} new columns to orders table")
        print("📝 Added fields:", ", ".join(added_fields))
    else:
        print("\nℹ️  All invoice fields already exist in the database")
    
    print("\n✨ Migration complete!")

if __name__ == "__main__":
    main()

"""
Migration script to add new OrderStatus enum values to PostgreSQL
"""
from app.database import engine
from sqlalchemy import text, inspect

def run_migration():
    """Add new enum values to orderstatus enum in PostgreSQL"""
    try:
        inspector = inspect(engine)
        is_postgres = "postgresql" in str(engine.url).lower()
        
        if not is_postgres:
            print("⚠️  Not PostgreSQL, skipping enum migration")
            return
        
        with engine.begin() as conn:
            # Check if enum exists
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT 1 FROM pg_type WHERE typname = 'orderstatus'
                );
            """))
            enum_exists = result.scalar()
            
            if not enum_exists:
                print("⚠️  orderstatus enum does not exist, skipping")
                return
            
            # Add new enum values if they don't exist
            new_statuses = ['pending_completion', 'in_progress', 'settled']
            
            for status in new_statuses:
                try:
                    # Check if value already exists
                    result = conn.execute(text(f"""
                        SELECT EXISTS (
                            SELECT 1 FROM pg_enum 
                            WHERE enumlabel = '{status}' 
                            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'orderstatus')
                        );
                    """))
                    exists = result.scalar()
                    
                    if not exists:
                        conn.execute(text(f"""
                            ALTER TYPE orderstatus ADD VALUE IF NOT EXISTS '{status}';
                        """))
                        print(f"✅ Added enum value: {status}")
                    else:
                        print(f"✅ Enum value already exists: {status}")
                except Exception as e:
                    error_str = str(e).lower()
                    if "already exists" in error_str or "duplicate" in error_str:
                        print(f"✅ Enum value already exists: {status}")
                    else:
                        print(f"⚠️  Could not add enum value {status}: {e}")
        
        print("✅ Enum migration completed")
    except Exception as e:
        print(f"⚠️  Enum migration error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    run_migration()


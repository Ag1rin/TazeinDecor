"""
FastAPI main application
"""
from contextlib import asynccontextmanager
import asyncio
import os

# ---------------------------------------------------------------------------
# Temporary monkey patch for passlib + bcrypt compatibility on Python 3.12
# Newer bcrypt releases (>=4.1) removed the __about__ attribute that passlib
# 1.x expects. Add it back before anything imports passlib.
# ---------------------------------------------------------------------------
import bcrypt  # type: ignore

if not hasattr(bcrypt, "__about__"):
    class _About:
        __version__ = getattr(bcrypt, "__version__", "unknown")

    bcrypt.__about__ = _About()

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import tempfile
import traceback
import logging
from app.config import settings
from app.database import init_db
from app.routers import auth, users, products, orders, chat, companies, returns, installations, reports, discounts

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events"""
    # Startup
    try:
        init_db()
        print("✅ Database initialized successfully")
        
        # Run migrations
        try:
            import sys
            import os
            # Get the backend directory (parent of app directory)
            backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            migrations_path = os.path.join(backend_dir, 'migrations')
            
            # Migration 1: Add created_by to users
            if os.path.exists(os.path.join(migrations_path, 'add_created_by_to_users.py')):
                if migrations_path not in sys.path:
                    sys.path.insert(0, migrations_path)
                from add_created_by_to_users import run_migration as run_created_by_migration
                run_created_by_migration()
            
            # Migration 2: Add variation fields to order_items
            if os.path.exists(os.path.join(migrations_path, 'add_variation_fields_postgres.py')):
                if migrations_path not in sys.path:
                    sys.path.insert(0, migrations_path)
                from add_variation_fields_postgres import run_migration as run_variation_migration
                run_variation_migration()
            
            # Migration 3: Drop foreign key constraint from order_items.product_id
            if os.path.exists(os.path.join(migrations_path, 'drop_order_items_product_fk.py')):
                if migrations_path not in sys.path:
                    sys.path.insert(0, migrations_path)
                from drop_order_items_product_fk import run_migration as run_drop_fk_migration
                run_drop_fk_migration()
            
            # Migration 4: Create discounts table
            if os.path.exists(os.path.join(migrations_path, 'create_discounts_table.py')):
                if migrations_path not in sys.path:
                    sys.path.insert(0, migrations_path)
                from create_discounts_table import run_migration as run_discounts_migration
                run_discounts_migration()
            
            # Migration 5: Add new enum values to orderstatus
            invoice_migration_path = os.path.join(backend_dir, 'add_enum_statuses.py')
            if os.path.exists(invoice_migration_path):
                if backend_dir not in sys.path:
                    sys.path.insert(0, backend_dir)
                from add_enum_statuses import run_migration as run_enum_migration
                run_enum_migration()
                print("✅ Enum statuses migration executed.")
            
            # Migration 6: Add invoice fields to orders
            from app.database import engine
            from sqlalchemy import text, inspect
            inspector = inspect(engine)
            
            if "orders" in inspector.get_table_names():
                columns = [col['name'] for col in inspector.get_columns("orders")]
                is_postgres = "postgresql" in str(engine.url).lower()
                
                invoice_fields = [
                    ("invoice_number", "VARCHAR(255)" if is_postgres else "TEXT"),
                    ("issue_date", "TIMESTAMP WITH TIME ZONE" if is_postgres else "TIMESTAMP"),
                    ("due_date", "TIMESTAMP WITH TIME ZONE" if is_postgres else "TIMESTAMP"),
                    ("subtotal", "REAL"),
                    ("tax_amount", "REAL DEFAULT 0.0"),
                    ("discount_amount", "REAL DEFAULT 0.0"),
                    ("payment_terms", "TEXT"),
                    ("edit_requested_by", "INTEGER"),
                    ("edit_requested_at", "TIMESTAMP WITH TIME ZONE" if is_postgres else "TIMESTAMP"),
                    ("edit_approved_by", "INTEGER"),
                    ("edit_approved_at", "TIMESTAMP WITH TIME ZONE" if is_postgres else "TIMESTAMP"),
                ]
                
                with engine.begin() as conn:  # Use begin() for auto-commit
                    for field_name, field_type in invoice_fields:
                        if field_name not in columns:
                            try:
                                if is_postgres:
                                    conn.execute(text(f"ALTER TABLE orders ADD COLUMN IF NOT EXISTS {field_name} {field_type}"))
                                else:
                                    conn.execute(text(f"ALTER TABLE orders ADD COLUMN {field_name} {field_type}"))
                                print(f"✅ Added invoice column: {field_name}")
                            except Exception as e:
                                if "already exists" not in str(e).lower() and "duplicate" not in str(e).lower():
                                    print(f"⚠️  Could not add {field_name}: {e}")
                    
                    # Add foreign key constraints for PostgreSQL
                    if is_postgres:
                        try:
                            constraints = inspector.get_foreign_keys("orders")
                            fk_names = [fk['name'] for fk in constraints]
                            
                            if "edit_requested_by" in columns and "fk_orders_edit_requested_by" not in fk_names:
                                conn.execute(text("""
                                    DO $$
                                    BEGIN
                                        IF NOT EXISTS (
                                            SELECT 1 FROM pg_constraint 
                                            WHERE conname = 'fk_orders_edit_requested_by'
                                        ) THEN
                                            ALTER TABLE orders 
                                            ADD CONSTRAINT fk_orders_edit_requested_by 
                                            FOREIGN KEY (edit_requested_by) REFERENCES users(id);
                                        END IF;
                                    END $$;
                                """))
                                print("✅ Added FK constraint: edit_requested_by")
                            
                            if "edit_approved_by" in columns and "fk_orders_edit_approved_by" not in fk_names:
                                conn.execute(text("""
                                    DO $$
                                    BEGIN
                                        IF NOT EXISTS (
                                            SELECT 1 FROM pg_constraint 
                                            WHERE conname = 'fk_orders_edit_approved_by'
                                        ) THEN
                                            ALTER TABLE orders 
                                            ADD CONSTRAINT fk_orders_edit_approved_by 
                                            FOREIGN KEY (edit_approved_by) REFERENCES users(id);
                                        END IF;
                                    END $$;
                                """))
                                print("✅ Added FK constraint: edit_approved_by")
                        except Exception as e:
                            if "already exists" not in str(e).lower():
                                print(f"⚠️  Could not add FK constraints: {e}")
            
            # Migration 7: Fix OrderStatus enum case mismatch (database has UPPERCASE, Python expects lowercase)
            # CRITICAL: Split into two separate transactions to avoid "unsafe use of new value" error
            try:
                is_postgres = "postgresql" in str(engine.url).lower()
                if not is_postgres:
                    print("⚠️  Skipping enum migration (not PostgreSQL)")
                else:
                    # TRANSACTION 1: Add all lowercase enum values and COMMIT
                    print("🔄 Migration 7a: Adding lowercase enum values...")
                    with engine.begin() as conn:
                        # Check what enum values exist
                        result = conn.execute(text("""
                            SELECT enumlabel 
                            FROM pg_enum 
                            WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'orderstatus')
                            ORDER BY enumsortorder;
                        """))
                        existing_values = [row[0] for row in result]
                        print(f"📋 Existing enum values: {existing_values}")
                        
                        # Add lowercase enum values if they don't exist
                        lowercase_statuses = ['pending', 'confirmed', 'processing', 'delivered', 'returned', 'cancelled', 'pending_completion', 'in_progress', 'settled']
                        added_count = 0
                        for status in lowercase_statuses:
                            if status not in existing_values:
                                try:
                                    # Try with IF NOT EXISTS first (PostgreSQL 9.1+)
                                    conn.execute(text(f"ALTER TYPE orderstatus ADD VALUE IF NOT EXISTS '{status}'"))
                                    print(f"✅ Added enum value: {status}")
                                    added_count += 1
                                except Exception as e1:
                                    try:
                                        # Fallback: try without IF NOT EXISTS (older PostgreSQL)
                                        conn.execute(text(f"ALTER TYPE orderstatus ADD VALUE '{status}'"))
                                        print(f"✅ Added enum value: {status}")
                                        added_count += 1
                                    except Exception as e2:
                                        # Value might already exist or other error
                                        error_str = str(e2).lower()
                                        if "already exists" in error_str or "duplicate" in error_str:
                                            print(f"✅ Enum value already exists: {status}")
                                        else:
                                            print(f"⚠️  Could not add enum value {status}: {e2}")
                            else:
                                print(f"✅ Enum value already exists: {status}")
                    
                    # COMMIT happens here automatically when exiting 'with engine.begin()'
                    print(f"✅ Transaction 1 complete: Added {added_count} new enum values (committed)")
                    
                    # TRANSACTION 2: Convert uppercase values to lowercase using raw SQL (no enum cast in UPDATE)
                    print("🔄 Migration 7b: Converting uppercase status values to lowercase...")
                    uppercase_to_lowercase = {
                        'PENDING': 'pending',
                        'CONFIRMED': 'confirmed', 
                        'PROCESSING': 'processing',
                        'DELIVERED': 'delivered',
                        'RETURNED': 'returned',
                        'CANCELLED': 'cancelled',
                        'PENDING_COMPLETION': 'pending_completion',
                        'IN_PROGRESS': 'in_progress',
                        'SETTLED': 'settled'
                    }
                    
                    success_count = 0
                    total_converted = 0
                    
                    with engine.begin() as conn:
                        for upper, lower in uppercase_to_lowercase.items():
                            try:
                                # Check if any rows have uppercase value (using text comparison)
                                check_result = conn.execute(text(f"""
                                    SELECT COUNT(*) FROM orders 
                                    WHERE status::text = '{upper}'
                                """))
                                count = check_result.scalar()
                                if count > 0:
                                    print(f"🔄 Converting {count} orders from '{upper}' to '{lower}'")
                                    # Use direct string value in UPDATE - cast required for enum columns
                                    # Note: If column is VARCHAR, remove the ::orderstatus cast
                                    update_sql = text(f"""
                                        UPDATE orders 
                                        SET status = '{lower}'::orderstatus
                                        WHERE status::text = '{upper}'
                                    """)
                                    conn.execute(update_sql)
                                    total_converted += count
                                    success_count += 1
                                    print(f"✅ Converted {count} orders from '{upper}' to '{lower}'")
                            except Exception as e:
                                # Continue on failure - don't abort entire migration
                                print(f"⚠️  Could not convert '{upper}' to '{lower}': {e}")
                    
                    print(f"✅ Transaction 2 complete: Converted {total_converted} orders across {success_count} status types (committed)")
                    print("✅ Fixed OrderStatus enum case (converted to lowercase)")
            except Exception as e:
                print(f"⚠️  OrderStatus case fix error: {e}")
                import traceback
                traceback.print_exc()
            
            # Migration 8: Add referral code system
            if "users" in inspector.get_table_names():
                user_columns = [col['name'] for col in inspector.get_columns("users")]
                order_columns = [col['name'] for col in inspector.get_columns("orders")]
                
                with engine.begin() as conn:
                    # Add referral_code to users
                    if "referral_code" not in user_columns:
                        try:
                            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(10) UNIQUE"))
                            print("✅ Added referral_code column to users")
                        except Exception as e:
                            if "already exists" not in str(e).lower():
                                print(f"⚠️  Could not add referral_code: {e}")
                    
                    # Add referrer_id to orders
                    if "referrer_id" not in order_columns:
                        try:
                            conn.execute(text("ALTER TABLE orders ADD COLUMN IF NOT EXISTS referrer_id INTEGER REFERENCES users(id)"))
                            print("✅ Added referrer_id column to orders")
                        except Exception as e:
                            if "already exists" not in str(e).lower():
                                print(f"⚠️  Could not add referrer_id: {e}")
                    
                    # Create indexes
                    try:
                        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_users_referral_code ON users(referral_code) WHERE referral_code IS NOT NULL"))
                        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_orders_referrer_id ON orders(referrer_id) WHERE referrer_id IS NOT NULL"))
                    except Exception:
                        pass  # Indexes might already exist
                    
                    # Generate referral codes for existing sellers/store managers
                    try:
                        # Try both lowercase and uppercase enum values (depends on DB setup)
                        result = conn.execute(text("""
                            SELECT id FROM users 
                            WHERE (role::text IN ('seller', 'store_manager', 'SELLER', 'STORE_MANAGER')) 
                            AND referral_code IS NULL
                        """))
                        users_needing_codes = result.fetchall()
                        if users_needing_codes:
                            import secrets
                            import string
                            for user_row in users_needing_codes:
                                while True:
                                    code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
                                    check = conn.execute(text("SELECT COUNT(*) FROM users WHERE referral_code = :code"), {"code": code})
                                    if check.scalar() == 0:
                                        break
                                conn.execute(text("UPDATE users SET referral_code = :code WHERE id = :id"), {"code": code, "id": user_row[0]})
                            print(f"✅ Generated referral codes for {len(users_needing_codes)} users")
                    except Exception as e:
                        print(f"⚠️  Error generating referral codes: {e}")
            
            # Migration 9: Add wholesale_amount to orders
            if "orders" in inspector.get_table_names():
                order_columns = [col['name'] for col in inspector.get_columns("orders")]
                is_postgres = "postgresql" in str(engine.url).lower()
                
                if "wholesale_amount" not in order_columns:
                    try:
                        with engine.begin() as conn:
                            if is_postgres:
                                conn.execute(text("ALTER TABLE orders ADD COLUMN IF NOT EXISTS wholesale_amount DOUBLE PRECISION"))
                            else:
                                conn.execute(text("ALTER TABLE orders ADD COLUMN wholesale_amount REAL"))
                            print("✅ Added wholesale_amount column to orders")
                    except Exception as e:
                        if "already exists" not in str(e).lower() and "duplicate" not in str(e).lower():
                            print(f"⚠️  Could not add wholesale_amount: {e}")
                else:
                    print("ℹ️  Column wholesale_amount already exists in orders table")
                
                # Migration 10: Add cooperation_total_amount to orders
                if "cooperation_total_amount" not in order_columns:
                    try:
                        with engine.begin() as conn:
                            if is_postgres:
                                conn.execute(text("ALTER TABLE orders ADD COLUMN IF NOT EXISTS cooperation_total_amount DOUBLE PRECISION"))
                            else:
                                conn.execute(text("ALTER TABLE orders ADD COLUMN cooperation_total_amount REAL"))
                            print("✅ Added cooperation_total_amount column to orders")
                    except Exception as e:
                        if "already exists" not in str(e).lower() and "duplicate" not in str(e).lower():
                            print(f"⚠️  Could not add cooperation_total_amount: {e}")
                else:
                    print("ℹ️  Column cooperation_total_amount already exists in orders table")
                        
        except ImportError as import_error:
            # Migration file might not be accessible, that's okay
            print(f"⚠️  Could not import migration (this is okay if running in container): {import_error}")
        except Exception as migration_error:
            # Migration errors are not critical - column might already exist
            error_str = str(migration_error).lower()
            if "already exists" in error_str or "duplicate" in error_str:
                print("✅ Migration: columns already exist")
            else:
                print(f"⚠️  Migration warning: {migration_error}")
            
    except Exception as e:
        error_msg = str(e)
        is_production = os.getenv("ENVIRONMENT", "development").lower() == "production"
        
        if is_production:
            # In production, database errors are critical
            print(f"❌ CRITICAL: Database initialization failed: {error_msg}")
            print("⚠️  App may not function correctly. Please check DATABASE_URL.")
        else:
            # In development, might be from reload
            print(f"⚠️  Warning: Database initialization error (may be from reload): {error_msg}")
    
    try:
        yield
    except asyncio.CancelledError:
        # Gracefully handle cancellation during reload (Windows uvicorn reloader)
        pass
    finally:
        # Shutdown cleanup (if needed)
        pass

# Create FastAPI app
app = FastAPI(
    title="TazeinDecor API",
    description="E-commerce management API with WooCommerce integration",
    version=settings.APP_VERSION,
    lifespan=lifespan
)

# Debug middleware to log Authorization headers
class AuthDebugMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Log Authorization header for API endpoints
        if request.url.path.startswith("/api") and not request.url.path.startswith("/api/auth/login"):
            auth_header = request.headers.get("Authorization", "NOT PROVIDED")
            if auth_header == "NOT PROVIDED":
                print(f"⚠️  {request.method} {request.url.path} - NO Authorization header!")
                print(f"⚠️  All headers: {list(request.headers.keys())}")
            else:
                print(f"✅ {request.method} {request.url.path} - Authorization: {auth_header[:50]}...")
        response = await call_next(request)
        return response

app.add_middleware(AuthDebugMiddleware)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],  # Allow Authorization header
)

# Create upload directory with read-only filesystem handling
upload_dir = os.getenv("UPLOAD_DIR", settings.UPLOAD_DIR)
try:
    # Try to create and use the configured upload directory
    os.makedirs(upload_dir, exist_ok=True)
    # Check if directory is writable
    if not os.access(upload_dir, os.W_OK):
        raise OSError("Directory is not writable")
except (OSError, PermissionError) as e:
    # Fallback to temp directory if uploads directory is read-only
    upload_dir = tempfile.gettempdir()
    # Create a subdirectory in temp for uploads
    upload_dir = os.path.join(upload_dir, "uploads")
    os.makedirs(upload_dir, exist_ok=True)
    print(f"⚠️  Using temp directory for uploads: {upload_dir}")

# Mount static files for uploads
app.mount("/uploads", StaticFiles(directory=upload_dir), name="uploads")

# Include routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(discounts.router)
app.include_router(products.router)
app.include_router(orders.router)
app.include_router(chat.router)
app.include_router(companies.router)
app.include_router(returns.router)
app.include_router(installations.router)
app.include_router(reports.router)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "TazeinDecor API",
        "version": settings.APP_VERSION
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


# Global exception handler for ASGI exceptions
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle all unhandled exceptions to prevent ASGI crashes"""
    import traceback
    
    # Log the full traceback
    error_trace = traceback.format_exc()
    logging.error(f"Unhandled exception: {exc}\n{error_trace}")
    print(f"❌ Unhandled exception: {exc}")
    print(f"Traceback:\n{error_trace}")
    
    # Return a safe error response
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An internal server error occurred",
            "error": str(exc) if not isinstance(exc, HTTPException) else exc.detail
        }
    )


# Exception handler for HTTPException
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )


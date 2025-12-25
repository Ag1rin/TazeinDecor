# Fix Database Issue on Liara

## Current Problem

Your app is configured to use a local Docker database (`tazeindecor-data`) which doesn't exist on Liara. The code tries to fallback to SQLite, but SQLite fails in containers.

## Solution: Configure PostgreSQL on Liara

### Step 1: Create PostgreSQL Database

1. **Go to Liara Dashboard**
2. **Select your app**
3. **Go to "Databases" tab**
4. **Click "Create Database"**
5. **Select "PostgreSQL"**
6. **Note the connection details** (you'll need them)

### Step 2: Set Environment Variables

In Liara Dashboard → Your App → **Environment Variables**, set:

```env
DATABASE_URL=postgresql://username:password@host:port/database
ENVIRONMENT=production
```

**Example (from Liara):**
```env
DATABASE_URL=postgresql://postgres:abc123xyz@postgres.liara.cloud:5432/postgres
ENVIRONMENT=production
```

### Step 3: Set CORS (Important!)

Also set CORS to allow your frontend:

```env
CORS_ORIGINS=https://your-frontend-domain.com,https://www.your-frontend-domain.com
```

Or for testing (allow all):
```env
CORS_ORIGINS=*
```

### Step 4: Restart App

After setting environment variables, **restart your app** on Liara.

### Step 5: Create Admin User

After restart, connect via Liara shell:

```bash
liara shell
```

Then run:
```bash
python init_db_liara.py
```

This creates:
- Username: `admin`
- Password: `admin123`

## Verify

1. **Check logs** - Should see: "✅ Database initialized successfully"
2. **Test API**: `https://tazeindecor.liara.run/health`
3. **Test login** from frontend

## What Changed

- ✅ Removed SQLite fallback in production
- ✅ Better error messages
- ✅ Database initialization script for Liara
- ✅ Clear instructions

## Still Having Issues?

1. **Check DATABASE_URL** is correct (copy from Liara exactly)
2. **Verify ENVIRONMENT=production** is set
3. **Check PostgreSQL service** is running in Liara
4. **Review app logs** for specific error messages


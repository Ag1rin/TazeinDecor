# Quick Fix for Liara Database Issue

## The Problem

Your app is trying to use a local Docker database (`tazeindecor-data`) which doesn't exist on Liara, then falls back to SQLite which fails due to permissions.

## Quick Solution (3 Steps)

### Step 1: Get PostgreSQL Connection String from Liara

1. Go to Liara Dashboard → Your App → **Databases**
2. If you don't have a database, create one (PostgreSQL)
3. Copy the connection string (looks like):
   ```
   postgresql://postgres:password@postgres.liara.cloud:5432/postgres
   ```

### Step 2: Set Environment Variables in Liara

Go to Liara Dashboard → Your App → **Environment Variables**

Add/Update these:

```env
DATABASE_URL=postgresql://postgres:your_password@postgres.liara.cloud:5432/postgres
ENVIRONMENT=production
```

**Replace with your actual connection string from Liara!**

### Step 3: Restart Your App

Restart your app on Liara. The database will initialize automatically.

## Create Admin User

After restart, connect to your app shell:

```bash
liara shell
```

Then run:
```bash
python init_db_liara.py
```

This will create the admin user:
- Username: `admin`
- Password: `admin123`

## Verify It Works

1. Check app logs - should see "Database initialized successfully"
2. Test API: `https://tazeindecor.liara.run/health`
3. Test login from frontend

## That's It! ✅

Your database should now work properly on Liara.


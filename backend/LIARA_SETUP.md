# Liara Database Setup Guide

## Problem

Your `DATABASE_URL` points to a local Docker container (`tazeindecor-data`) which doesn't exist on Liara. The code tries to fallback to SQLite, but SQLite fails due to permission issues in containers.

## Solution: Use Liara PostgreSQL Database

### Step 1: Create PostgreSQL Database on Liara

1. Go to your Liara dashboard
2. Navigate to your app
3. Go to **Databases** section
4. Click **Create Database** → Select **PostgreSQL**
5. Note the connection details (host, port, database, username, password)

### Step 2: Set DATABASE_URL Environment Variable

In Liara dashboard, go to your app → **Environment Variables**:

Add or update:
```env
DATABASE_URL=postgresql://username:password@host:port/database_name
```

**Example from Liara:**
```env
DATABASE_URL=postgresql://postgres:your_password@postgres.liara.cloud:5432/postgres
```

### Step 3: Set Production Environment

Also set:
```env
ENVIRONMENT=production
```

This prevents the SQLite fallback.

### Step 4: Update CORS for Your Frontend

Set CORS to allow your frontend domain:
```env
CORS_ORIGINS=https://your-frontend-domain.com,https://www.your-frontend-domain.com
```

### Step 5: Initialize Database

After setting DATABASE_URL, restart your app. The database tables will be created automatically on first startup.

To create the admin user, you can:

**Option A: Use Liara CLI**
```bash
liara shell
python init_db.py
```

**Option B: Create via API**
Use the `/api/users` endpoint after logging in as admin (if you create admin manually first).

**Option C: Direct SQL (if you have access)**
```sql
INSERT INTO users (username, password_hash, full_name, mobile, role, is_active)
VALUES ('admin', '$2b$12$...', 'مدیر سیستم', '09123456789', 'admin', true);
```

## Liara PostgreSQL Connection String Format

Liara provides PostgreSQL connection strings in this format:
```
postgresql://[user]:[password]@[host]:[port]/[database]
```

Make sure to:
- Use the exact connection string from Liara dashboard
- Don't modify it
- Keep it secure (don't commit to git)

## Verify Database Connection

After setting DATABASE_URL, check your app logs:
- Should see: "Database initialized"
- Should NOT see: "Warning: DATABASE_URL points to Docker container"

## Troubleshooting

### Error: "DATABASE_URL points to local Docker container"
**Solution:** Set `ENVIRONMENT=production` in environment variables

### Error: "Connection refused" or "Database not found"
**Solution:** 
1. Verify DATABASE_URL is correct
2. Check PostgreSQL service is running in Liara
3. Verify credentials are correct

### Error: "Permission denied" (SQLite)
**Solution:** This means SQLite fallback is still happening. Make sure:
1. `ENVIRONMENT=production` is set
2. `DATABASE_URL` points to PostgreSQL (not SQLite)
3. Restart your app

## Complete .env Example for Liara

```env
# Database (from Liara PostgreSQL)
DATABASE_URL=postgresql://postgres:your_password@postgres.liara.cloud:5432/postgres

# Environment
ENVIRONMENT=production

# JWT Secret (CHANGE THIS!)
SECRET_KEY=your-very-secure-secret-key-minimum-32-characters

# WooCommerce
WOOCOMMERCE_URL=https://tazeindecor.com
WOOCOMMERCE_CONSUMER_KEY=your_key
WOOCOMMERCE_CONSUMER_SECRET=your_secret

# CORS
CORS_ORIGINS=https://your-frontend-domain.com

# App Version
APP_VERSION=1.0.0
```

## After Setup

1. Restart your app on Liara
2. Check logs for "Database initialized"
3. Test API: `https://tazeindecor.liara.run/health`
4. Create admin user if needed
5. Test login from frontend


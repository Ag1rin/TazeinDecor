# URGENT: Fix Admin Password Hash Error

## Problem
The admin user has an invalid password hash format. Login fails with:
```
Warning: User admin has invalid password hash format
```

## Quick Fix - Run This on Liara

### Option 1: Use the Fix Script (Recommended)

```bash
# Connect to Liara shell
liara shell

# Run the fix script
python fix_admin_password.py
```

This will:
- Find the admin user
- Reset password to `admin123`
- Create valid bcrypt hash
- Verify the hash is correct

### Option 2: Use API Endpoint (If script doesn't work)

Add this to your Liara environment variables:
```env
SECRET_RESET_KEY=your-secret-key-here
```

Then call:
```bash
curl -X POST https://tazeindecor.liara.run/api/auth/reset-admin-password \
  -H "Content-Type: application/json" \
  -d '{"secret_key": "your-secret-key-here"}'
```

### Option 3: Manual SQL (If you have database access)

```sql
-- Check current hash
SELECT username, LEFT(password_hash, 50) as hash_preview 
FROM users 
WHERE username = 'admin';

-- The hash should start with '$2' (bcrypt format)
-- If it doesn't, you need to reset it using one of the scripts above
```

## After Running Fix

1. **Test login:**
   - Username: `admin`
   - Password: `admin123`

2. **Change password** after first login (recommended)

3. **Verify** no more hash errors in logs

## Why This Happened

The password hash in the database is not in bcrypt format (should start with `$2a$`, `$2b$`, or `$2y$`). This can happen if:
- Database was migrated incorrectly
- Password was set manually
- Hash got corrupted

## Prevention

The code now:
- ✅ Validates hash format before use
- ✅ Provides clear error messages
- ✅ Has fix scripts ready

## Files Created

1. `fix_admin_password.py` - Simple fix script
2. `reset_admin_password.py` - More detailed reset script
3. API endpoint `/api/auth/reset-admin-password` - Emergency reset

## Next Steps

1. **Run `python fix_admin_password.py` on Liara**
2. **Test login**
3. **If still fails, check logs for errors**


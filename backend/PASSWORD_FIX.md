# Fix Password Hash Error

## Problem
Error: `hash could not be identified` when trying to login.

This means the password hash in the database is not in a valid bcrypt format.

## Solution

### Option 1: Reset Admin Password (Recommended)

Run this script on Liara to reset the admin password:

```bash
# Connect to Liara shell
liara shell

# Run the reset script
python reset_admin_password.py
```

This will:
- Reset admin password to `admin123`
- Create admin user if it doesn't exist
- Fix corrupted password hash

### Option 2: Re-create Admin User

If reset doesn't work, delete and recreate:

```bash
# Connect to Liara shell
liara shell

# Run init script (will skip if admin exists, or create if not)
python init_db_liara.py
```

### Option 3: Manual SQL Fix (Advanced)

If you have database access, you can manually update:

```sql
-- First, check current hash
SELECT username, LEFT(password_hash, 30) as hash_preview FROM users WHERE username = 'admin';

-- If hash doesn't start with $2, it's corrupted
-- You'll need to reset it using one of the scripts above
```

## What Changed

1. **Better error handling** in `verify_password()`:
   - Checks if hash format is valid before verification
   - Provides better error messages

2. **Login endpoint improvements**:
   - Validates hash format before attempting verification
   - Returns clear error if hash is corrupted

3. **Reset script** (`reset_admin_password.py`):
   - Can reset admin password if hash is corrupted
   - Creates admin user if missing

## After Fixing

1. **Test login** with:
   - Username: `admin`
   - Password: `admin123`

2. **Change password** after first login (recommended)

3. **Check logs** to ensure no more hash errors

## Prevention

The issue was likely caused by:
- Password hash being stored incorrectly
- Database migration issues
- Manual database edits

The new code prevents this by:
- Validating hash format before use
- Using consistent hashing method
- Better error messages for debugging


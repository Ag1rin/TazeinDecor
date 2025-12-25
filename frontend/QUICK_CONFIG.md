# Quick Configuration Guide

## Connect Frontend to Your Backend Server

### Step 1: Edit Config File

Open: `frontend/lib/config/app_config.dart`

Find this line (around line 12):
```dart
return 'https://your-server-url.com';
```

**Replace with your actual server URL:**

Examples:
```dart
// If your server is at https://api.tazeindecor.com
return 'https://api.tazeindecor.com';

// If your server is at http://192.168.1.100:8000
return 'http://192.168.1.100:8000';

// If your server is at https://backend.example.com
return 'https://backend.example.com';
```

### Step 2: Configure Backend CORS

On your server, edit `backend/.env`:

```env
CORS_ORIGINS=https://your-frontend-domain.com,http://localhost:3000
```

Or allow all (for testing):
```env
CORS_ORIGINS=*
```

### Step 3: Restart Backend

After changing CORS, restart your backend server.

### Step 4: Test

1. Run Flutter app: `flutter run`
2. Try to login with: `admin` / `admin123`

## That's It! 🎉

Your frontend should now connect to your backend server.

## Need Help?

- Check `SERVER_SETUP.md` for detailed instructions
- Verify backend is running: `curl https://your-server-url.com/health`
- Check CORS settings if you get connection errors


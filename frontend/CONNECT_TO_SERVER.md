# How to Connect Frontend to Backend Server

## Step 1: Update Frontend Configuration

Edit `frontend/lib/config/app_config.dart` and change the `baseUrl`:

```dart
class AppConfig {
  // Replace with your actual server URL
  static const String baseUrl = 'https://your-server-domain.com'; // ⚠️ CHANGE THIS
  static const String apiVersion = '/api';
  // ...
}
```

### Examples:

**If your backend is at:**
- `https://api.tazeindecor.com` → Use: `'https://api.tazeindecor.com'`
- `https://backend.example.com:8000` → Use: `'https://backend.example.com:8000'`
- `http://192.168.1.100:8000` (local network) → Use: `'http://192.168.1.100:8000'`

## Step 2: Configure Backend CORS

Make sure your backend allows requests from your frontend domain.

Edit `backend/app/config.py` or set in `.env`:

```env
CORS_ORIGINS=https://your-frontend-domain.com,https://www.your-frontend-domain.com
```

Or allow all origins (for development only):
```env
CORS_ORIGINS=*
```

## Step 3: WebSocket Configuration

The WebSocket URL is automatically generated from `baseUrl`:
- `http://` → `ws://`
- `https://` → `wss://`

Make sure your server supports WebSocket connections.

## Step 4: Test the Connection

1. **Update the config file:**
   ```dart
   static const String baseUrl = 'https://your-actual-server-url.com';
   ```

2. **Run Flutter app:**
   ```bash
   cd frontend
   flutter run
   ```

3. **Try to login:**
   - Username: `admin`
   - Password: `admin123`

## Step 5: Verify Backend is Accessible

Test your backend API:

```bash
# Test if backend is running
curl https://your-server-url.com/health

# Should return: {"status":"healthy"}
```

## Common Issues

### CORS Error
**Error:** `Access to XMLHttpRequest blocked by CORS policy`

**Solution:** Update backend CORS settings:
```python
# In backend/app/config.py or .env
CORS_ORIGINS = ["https://your-frontend-domain.com", "http://localhost:3000"]
```

### WebSocket Connection Failed
**Error:** `WebSocket connection failed`

**Solution:**
1. Make sure your server supports WebSocket (wss:// for HTTPS)
2. Check firewall/proxy settings
3. Verify WebSocket endpoint: `wss://your-server-url.com/api/chat/ws`

### Connection Timeout
**Error:** `Connection timeout`

**Solution:**
1. Check if backend server is running
2. Verify the URL is correct (no typos)
3. Check if port is open (if using custom port)
4. Test with browser: `https://your-server-url.com/docs`

## Production Checklist

- [ ] Updated `baseUrl` in `app_config.dart`
- [ ] Backend CORS configured for your domain
- [ ] SSL/HTTPS enabled (required for WebSocket in production)
- [ ] Backend server is accessible from internet
- [ ] Test login works
- [ ] WebSocket connection works (check chat room)

## Environment-Specific Configuration

For different environments, you can use:

```dart
class AppConfig {
  static const String baseUrl = kDebugMode 
    ? 'http://localhost:8000'  // Development
    : 'https://api.yourserver.com';  // Production
}
```

Don't forget to import:
```dart
import 'package:flutter/foundation.dart';
```


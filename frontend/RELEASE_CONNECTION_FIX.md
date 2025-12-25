# Fix: Frontend Not Connecting to Backend in Release Mode

## Problem
The app works in debug mode but can't connect to the backend in release mode.

## Root Causes & Fixes Applied

### 1. ✅ Missing INTERNET Permission
**Fixed:** Added `INTERNET` and `ACCESS_NETWORK_STATE` permissions to `AndroidManifest.xml`

### 2. ✅ Network Security Configuration
**Fixed:** Created `network_security_config.xml` to allow HTTPS connections to your backend server.

### 3. ✅ Better Error Logging
**Fixed:** Added debug logging to API service to help diagnose connection issues.

## Verification Steps

### 1. Check Backend is Running
Test your backend URL:
```bash
curl https://tazeindecor.liara.run/api/auth/version
```

Should return:
```json
{"version": "1.0.0"}
```

### 2. Check CORS Configuration
Make sure your backend allows requests from mobile apps. In `backend/app/config.py`:
```python
CORS_ORIGINS: list = ["*"]  # For testing, or specify your domains
```

### 3. Test Connection from App
1. Build release APK:
   ```bash
   flutter build apk --release
   ```

2. Install on device:
   ```bash
   flutter install
   ```

3. Check logs for connection errors:
   ```bash
   flutter logs
   ```

### 4. Common Issues & Solutions

#### Issue: "Connection refused" or "Network error"
**Solution:**
- Verify backend URL is correct: `https://tazeindecor.liara.run`
- Check backend is running and accessible
- Verify CORS settings allow mobile requests

#### Issue: "SSL certificate error"
**Solution:**
- Backend must have valid SSL certificate (Liara provides this)
- Check `network_security_config.xml` allows your domain

#### Issue: "401 Unauthorized"
**Solution:**
- Token might be expired
- Check authentication flow
- Verify token is being sent in headers

#### Issue: "WebSocket connection failed"
**Solution:**
- WebSocket URL should be `wss://tazeindecor.liara.run/api/chat/ws`
- Check backend WebSocket endpoint is working
- Verify token is passed correctly

## Debugging Tips

### Enable Verbose Logging
In `app_config.dart`, temporarily add:
```dart
static String get baseUrl {
  if (kDebugMode) {
    print('🔧 Using baseUrl: http://localhost:8000');
    return 'http://localhost:8000';
  } else {
    print('🔧 Using baseUrl: https://tazeindecor.liara.run');
    return 'https://tazeindecor.liara.run';
  }
}
```

### Test Backend Directly
```bash
# Test login endpoint
curl -X POST https://tazeindecor.liara.run/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### Check Network on Device
1. Make sure device has internet connection
2. Try accessing backend URL in device browser
3. Check firewall/network restrictions

## Configuration Checklist

- [x] INTERNET permission in AndroidManifest.xml
- [x] Network security config for HTTPS
- [x] Backend URL set correctly in `app_config.dart`
- [x] CORS configured on backend
- [x] Backend is running and accessible
- [x] SSL certificate is valid
- [x] WebSocket URL conversion (http→ws, https→wss)

## Next Steps

1. **Rebuild the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **Test on device:**
   - Install APK
   - Try logging in
   - Check Flutter logs for errors

3. **If still not working:**
   - Check backend logs on Liara
   - Verify environment variables are set
   - Test backend endpoints with curl/Postman
   - Check device network settings

## Backend CORS Configuration

Make sure your backend allows requests. In Liara, set:
```env
CORS_ORIGINS=*
```

Or for production:
```env
CORS_ORIGINS=https://your-frontend-domain.com,https://www.your-frontend-domain.com
```


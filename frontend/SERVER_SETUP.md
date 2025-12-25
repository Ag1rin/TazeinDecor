# Connect Frontend to Backend Server - Step by Step

## Quick Setup

### 1. Update Server URL

Edit `frontend/lib/config/app_config.dart`:

Find this line (around line 7):
```dart
return 'https://your-server-url.com';
```

Replace with your actual server URL:
```dart
return 'https://api.tazeindecor.com';  // Example
// OR
return 'http://192.168.1.100:8000';    // If using IP address
```

### 2. Configure Backend CORS

On your server, edit `backend/.env` or set environment variable:

```env
CORS_ORIGINS=https://your-frontend-domain.com,https://www.your-frontend-domain.com
```

**For testing, you can allow all:**
```env
CORS_ORIGINS=*
```

### 3. Restart Backend Server

After changing CORS settings, restart your backend:
```bash
# On your server
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 4. Test Connection

1. **Update config file** with your server URL
2. **Run Flutter app:**
   ```bash
   cd frontend
   flutter run
   ```
3. **Try to login** with admin credentials

## Examples

### Example 1: Server at `https://api.example.com`
```dart
return 'https://api.example.com';
```

### Example 2: Server at IP address `192.168.1.100:8000`
```dart
return 'http://192.168.1.100:8000';
```

### Example 3: Server with custom port `https://example.com:8443`
```dart
return 'https://example.com:8443';
```

## Important Notes

1. **HTTPS Required for Production:**
   - WebSocket requires `wss://` (secure WebSocket)
   - Make sure your server has SSL certificate
   - Use `https://` not `http://` in production

2. **WebSocket URL:**
   - Automatically converts:
     - `http://` → `ws://`
     - `https://` → `wss://`
   - Endpoint: `{baseUrl}/api/chat/ws`

3. **CORS Configuration:**
   - Backend must allow your frontend domain
   - Check `backend/app/config.py` for CORS settings

## Troubleshooting

### Error: "Failed to connect"
- Check if backend server is running
- Verify the URL is correct
- Test in browser: `https://your-server-url.com/health`

### Error: "CORS policy blocked"
- Update `CORS_ORIGINS` in backend `.env`
- Restart backend server
- Make sure frontend domain is in the list

### Error: "WebSocket connection failed"
- Check if server supports WebSocket
- For HTTPS, WebSocket must use `wss://`
- Check firewall/proxy settings

### Login Not Working
- Verify admin user exists on server
- Check backend logs for errors
- Test API directly: `https://your-server-url.com/api/auth/login`

## Testing Your Setup

1. **Test Backend Health:**
   ```bash
   curl https://your-server-url.com/health
   # Should return: {"status":"healthy"}
   ```

2. **Test API Endpoint:**
   ```bash
   curl https://your-server-url.com/api/auth/version
   # Should return: {"version":"1.0.0"}
   ```

3. **Test Login (from terminal):**
   ```bash
   curl -X POST https://your-server-url.com/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"admin123"}'
   ```

## Production Checklist

- [ ] Updated `baseUrl` in `app_config.dart` to production URL
- [ ] Backend CORS configured for your frontend domain
- [ ] SSL/HTTPS enabled on server
- [ ] WebSocket (wss://) working
- [ ] Tested login functionality
- [ ] Tested all API endpoints
- [ ] Backend server accessible from internet


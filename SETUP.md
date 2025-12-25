# Setup Guide

## Quick Start

### 1. Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your credentials
uvicorn app.main:app --reload
```

### 2. Frontend Setup

```bash
cd frontend
flutter pub get
# Update lib/config/app_config.dart with backend URL
flutter run
```

## Environment Configuration

### Backend (.env)

Create `backend/.env`:

```env
DATABASE_URL=sqlite:///./tazeindecor.db
SECRET_KEY=your-very-secure-secret-key-minimum-32-characters
WOOCOMMERCE_URL=https://tazeindecor.com
WOOCOMMERCE_CONSUMER_KEY=ck_xxxxxxxxxxxxx
WOOCOMMERCE_CONSUMER_SECRET=cs_xxxxxxxxxxxxx
CORS_ORIGINS=http://localhost:3000,http://localhost:8000
APP_VERSION=1.0.0
```

### Frontend

Update `frontend/lib/config/app_config.dart`:

```dart
static const String baseUrl = 'http://localhost:8000'; // Your backend URL
```

## First Run

1. Start backend server
2. The database will be created automatically
3. Create an admin user via API or directly in database
4. Start Flutter app
5. Login with admin credentials

## Creating Admin User

You can create an admin user via Python:

```python
from app.database import SessionLocal
from app.models import User
from app.routers.auth import get_password_hash

db = SessionLocal()
admin = User(
    username="admin",
    password_hash=get_password_hash("admin123"),
    full_name="Admin User",
    mobile="09123456789",
    role=UserRole.ADMIN
)
db.add(admin)
db.commit()
```

## Testing

- Backend API: http://localhost:8000/docs (Swagger UI)
- WebSocket: ws://localhost:8000/api/chat/ws

## Troubleshooting

- **Database locked**: Close other connections or use PostgreSQL
- **WebSocket fails**: Check firewall/proxy settings
- **WooCommerce sync fails**: Verify API credentials
- **Flutter build errors**: Run `flutter clean && flutter pub get`


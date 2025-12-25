# TazeinDecor E-Commerce Management System

A comprehensive e-commerce management application with Flutter frontend and FastAPI backend, featuring WooCommerce integration, role-based access control, and real-time chat.

## Features

### Access Levels
- **Admin**: Full system access, user management, credits assignment, sales reporting
- **Operator**: Invoice management, company management, product/stock management, installation calendar
- **Store Manager**: Seller management, sales reporting, installation management
- **Seller**: Product catalog, order registration, customer management, returns

### Key Features
- ✅ WooCommerce integration for products and categories
- ✅ Real-time chat with WebSocket support
- ✅ Role-based navigation and permissions
- ✅ Persian (RTL) language support
- ✅ Installation calendar with color coding
- ✅ Sales reports (day/month/year)
- ✅ Seller performance analytics
- ✅ Invoice management and PDF generation
- ✅ Returns management
- ✅ Company/supplier management
- ✅ Product catalog with tree categories
- ✅ Shopping cart with area-to-package conversion
- ✅ Order registration and tracking

## Project Structure

```
TazeinDecor-Main/
├── backend/
│   ├── app/
│   │   ├── routers/        # API endpoints
│   │   ├── models.py       # Database models
│   │   ├── schemas.py      # Pydantic schemas
│   │   ├── database.py     # Database setup
│   │   ├── config.py       # Configuration
│   │   └── websocket_manager.py  # WebSocket manager
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── lib/
│   │   ├── pages/          # Flutter pages
│   │   ├── services/       # API services
│   │   ├── providers/      # State management
│   │   ├── models/         # Data models
│   │   └── utils/          # Utilities
│   ├── pubspec.yaml
│   └── .env.example
└── README.md
```

## Setup Instructions

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Create virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Create `.env` file:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and add your WooCommerce credentials and secret key.

5. **Run the server:**
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Update API base URL:**
   Edit `lib/config/app_config.dart` and set the correct backend URL.

4. **Run the app:**
   ```bash
   flutter run
   ```

## Environment Variables

### Backend (.env)
- `DATABASE_URL`: Database connection string
- `SECRET_KEY`: JWT secret key (min 32 characters)
- `WOOCOMMERCE_URL`: WooCommerce site URL
- `WOOCOMMERCE_CONSUMER_KEY`: WooCommerce API consumer key
- `WOOCOMMERCE_CONSUMER_SECRET`: WooCommerce API consumer secret
- `CORS_ORIGINS`: Allowed CORS origins (comma-separated)

### Frontend
Update `lib/config/app_config.dart`:
- `baseUrl`: Backend API URL (default: http://localhost:8000)

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `GET /api/auth/me` - Get current user
- `GET /api/auth/version` - Get app version

### Products
- `GET /api/products` - Get products (with pagination, search, filters)
- `GET /api/products/{id}` - Get product details
- `GET /api/products/categories` - Get categories (tree structure)
- `POST /api/products/sync` - Sync from WooCommerce

### Orders
- `POST /api/orders` - Create order
- `GET /api/orders` - Get orders (role-based)
- `GET /api/orders/{id}` - Get order details
- `PUT /api/orders/{id}/confirm` - Confirm order (Operator)

### Chat
- `GET /api/chat` - Get messages
- `POST /api/chat` - Send text message
- `POST /api/chat/image` - Send image
- `POST /api/chat/voice` - Send voice
- `DELETE /api/chat/{id}` - Delete message (Admin/Operator)
- `WS /api/chat/ws` - WebSocket for real-time chat

### Reports
- `GET /api/reports/sales` - Sales report
- `GET /api/reports/seller-performance` - Seller performance

### Installations
- `GET /api/installations` - Get installations
- `GET /api/installations/tomorrow` - Get tomorrow's installations
- `POST /api/installations` - Create installation
- `PUT /api/installations/{id}` - Update installation
- `DELETE /api/installations/{id}` - Delete installation

## Testing

### Create Test Users

You can create test users via the API or directly in the database. Default roles:
- `admin` - Full access
- `operator` - Invoice and company management
- `store_manager` - Seller and sales management
- `seller` - Product catalog and orders

## Production Deployment

1. **Backend:**
   - Use PostgreSQL instead of SQLite
   - Set strong `SECRET_KEY`
   - Configure proper CORS origins
   - Use environment variables for all secrets
   - Set up SSL/TLS

2. **Frontend:**
   - Build for production: `flutter build web` or `flutter build apk`
   - Update API base URL to production backend
   - Configure PWA settings in `web/manifest.json`

## Troubleshooting

### Backend Issues
- **Database errors**: Ensure database file permissions or PostgreSQL connection
- **WooCommerce sync fails**: Check API credentials in `.env`
- **WebSocket not working**: Ensure WebSocket support in your server/proxy

### Frontend Issues
- **Packages not installing**: Run `flutter clean` then `flutter pub get`
- **API connection errors**: Check backend URL in `app_config.dart`
- **WebSocket connection fails**: Verify WebSocket URL format (ws:// or wss://)

## License

This project is proprietary software for TazeinDecor.

## Support

For issues and questions, please contact the development team.


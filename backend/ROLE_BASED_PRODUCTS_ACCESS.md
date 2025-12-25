# Role-Based Products Access Control

## ✅ Changes Implemented

### Backend Changes (`backend/app/routers/products.py`)

1. **Created new dependency function** `require_seller_or_store_manager()`:
   - Checks if user has SELLER or STORE_MANAGER role
   - Returns 403 Forbidden with message: "Access to products is only allowed for sellers and store managers"
   - Used for all product endpoints except sync

2. **Updated product endpoints** to require SELLER or STORE_MANAGER:
   - `GET /api/products/categories` - Now requires SELLER or STORE_MANAGER
   - `GET /api/products` - Now requires SELLER or STORE_MANAGER
   - `GET /api/products/{product_id}` - Now requires SELLER or STORE_MANAGER

3. **Sync endpoint** remains ADMIN only:
   - `POST /api/products/sync` - Requires ADMIN role only (changed from ADMIN/OPERATOR)

4. **Price/Stock update endpoints** remain OPERATOR only:
   - `PUT /api/products/{product_id}/price` - OPERATOR only
   - `PUT /api/products/{product_id}/stock` - OPERATOR only

### Frontend Changes

1. **Updated `home_screen.dart`**:
   - Added `ProductsHome` to STORE_MANAGER navigation
   - STORE_MANAGER now has: Products, Reports, Users, Chat, Profile
   - SELLER has: Products, Orders, Chat, Profile (unchanged)
   - ADMIN and OPERATOR do NOT have Products (as required)

2. **Updated `product_service.dart`**:
   - Added error logging for 403 Forbidden responses
   - Better error messages for access denied scenarios

## Access Matrix

| Endpoint | ADMIN | OPERATOR | STORE_MANAGER | SELLER |
|----------|-------|----------|---------------|--------|
| `GET /api/products/categories` | ❌ 403 | ❌ 403 | ✅ | ✅ |
| `GET /api/products` | ❌ 403 | ❌ 403 | ✅ | ✅ |
| `GET /api/products/{id}` | ❌ 403 | ❌ 403 | ✅ | ✅ |
| `POST /api/products/sync` | ✅ | ❌ 403 | ❌ 403 | ❌ 403 |
| `PUT /api/products/{id}/price` | ❌ 403 | ✅ | ❌ 403 | ❌ 403 |
| `PUT /api/products/{id}/stock` | ❌ 403 | ✅ | ❌ 403 | ❌ 403 |

## Frontend Navigation

### ADMIN
- Reports
- Users
- Chat
- Profile
- ❌ **No Products** (hidden)

### OPERATOR
- Dashboard
- Companies
- Chat
- Profile
- ❌ **No Products** (hidden)

### STORE_MANAGER
- ✅ **Products** (newly added)
- Reports
- Users
- Chat
- Profile

### SELLER
- ✅ **Products**
- Orders
- Chat
- Profile

## Error Responses

### 403 Forbidden (Access Denied)
```json
{
  "detail": "Access to products is only allowed for sellers and store managers"
}
```

### 401 Unauthorized (Not Authenticated)
```json
{
  "detail": "Could not validate credentials"
}
```

## Testing

### Test as SELLER:
1. Login as seller
2. Navigate to Products tab
3. Should see products list
4. Should be able to view product details

### Test as STORE_MANAGER:
1. Login as store manager
2. Navigate to Products tab (first tab)
3. Should see products list
4. Should be able to view product details

### Test as ADMIN:
1. Login as admin
2. Products tab should NOT appear in navigation
3. Direct API call to `/api/products` should return 403

### Test as OPERATOR:
1. Login as operator
2. Products tab should NOT appear in navigation
3. Direct API call to `/api/products` should return 403
4. Can still sync products (if needed via Swagger)

## Notes

- **Sync endpoint** is now ADMIN only (not OPERATOR)
- If OPERATOR needs to sync, they must use ADMIN account or sync endpoint can be updated
- All product viewing/browsing is restricted to SELLER and STORE_MANAGER
- ADMIN and OPERATOR have different responsibilities and don't need product access

## Migration Notes

If you have existing code that calls product endpoints:
- Update to use SELLER or STORE_MANAGER accounts
- Or remove product access for ADMIN/OPERATOR users
- Sync endpoint requires ADMIN role (not OPERATOR anymore)


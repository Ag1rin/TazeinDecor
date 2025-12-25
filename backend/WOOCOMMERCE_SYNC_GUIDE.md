# WooCommerce Product Sync Guide

## Problem Analysis

### Issues Found:
1. **Route Conflict**: `/sync` route was defined AFTER `/{product_id}`, causing FastAPI to try parsing "sync" as an integer → 422 error
2. **Wrong HTTP Method**: Sync endpoint is `POST` but was called with `GET`
3. **Empty Database**: Products haven't been synced yet, so `/api/products` returns empty list

## ✅ Fixes Applied

1. **Moved `/sync` route BEFORE `/{product_id}`** - Routes are now in correct order
2. **Enhanced error handling** - Better logging and error messages
3. **Improved sync response** - Returns detailed sync statistics

## How to Sync Products

### Method 1: Using Swagger UI (Recommended)

1. **Open Swagger UI**: Navigate to `https://tazeindecor.liara.run/docs`
2. **Login First**:
   - Click on `/api/auth/login` endpoint
   - Click "Try it out"
   - Enter credentials:
     ```json
     {
       "username": "admin",
       "password": "admin123"
     }
     ```
   - Click "Execute"
   - Copy the `access_token` from response

3. **Authorize in Swagger**:
   - Click the green "Authorize" button at top right
   - Paste the token (without "Bearer " prefix)
   - Click "Authorize", then "Close"

4. **Sync Products**:
   - Find `/api/products/sync` endpoint
   - Click "Try it out"
   - Click "Execute"
   - Wait for response (may take 30-60 seconds depending on product count)

5. **Verify Sync**:
   - Check `/api/products` endpoint - should now return products
   - Response will show sync statistics:
     ```json
     {
       "success": true,
       "message": "Sync completed successfully",
       "categories": 15,
       "products": {
         "total": 120,
         "new": 120,
         "updated": 0
       }
     }
     ```

### Method 2: Using cURL

```bash
# 1. Login and get token
TOKEN=$(curl -X POST "https://tazeindecor.liara.run/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  | jq -r '.access_token')

# 2. Sync products
curl -X POST "https://tazeindecor.liara.run/api/products/sync" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### Method 3: Using Postman

1. Create a POST request to: `https://tazeindecor.liara.run/api/products/sync`
2. In Headers tab, add:
   - Key: `Authorization`
   - Value: `Bearer YOUR_TOKEN_HERE`
3. Send request

## Endpoint Details

### POST `/api/products/sync`

**Authentication**: Required (Admin or Operator role)

**Request Body**: None (empty JSON `{}`)

**Response**:
```json
{
  "success": true,
  "message": "Sync completed successfully",
  "categories": 15,
  "products": {
    "total": 120,
    "new": 120,
    "updated": 0
  }
}
```

**What it does**:
1. Fetches all categories from WooCommerce
2. Syncs categories to local database
3. Updates category parent relationships
4. Fetches all products from WooCommerce
5. Syncs products to local database
6. Links products to categories

## Troubleshooting

### Issue: 422 Unprocessable Entity
- **Cause**: Using GET instead of POST, or route conflict
- **Fix**: Use `POST /api/products/sync` (not GET)

### Issue: 401 Unauthorized
- **Cause**: Missing or invalid token
- **Fix**: Login first and include `Authorization: Bearer <token>` header

### Issue: 403 Forbidden
- **Cause**: User doesn't have Admin or Operator role
- **Fix**: Use admin or operator account

### Issue: Empty product list after sync
- **Cause**: WooCommerce credentials incorrect or no products in WooCommerce
- **Fix**: 
  1. Check `.env` file has correct WooCommerce credentials
  2. Verify WooCommerce has products
  3. Check backend logs for WooCommerce API errors

### Issue: Sync takes too long
- **Cause**: Large number of products/categories
- **Fix**: This is normal. Wait for completion. Check logs for progress.

## Environment Variables

Make sure these are set in your `.env` file or Liara environment:

```env
WOOCOMMERCE_URL=https://tazeindecor.com
WOOCOMMERCE_CONSUMER_KEY=ck_xxxxxxxxxxxxx
WOOCOMMERCE_CONSUMER_SECRET=cs_xxxxxxxxxxxxx
```

Or use alternative names:
```env
WOO_URL=https://tazeindecor.com
WOO_CONSUMER_KEY=ck_xxxxxxxxxxxxx
WOO_CONSUMER_SECRET=cs_xxxxxxxxxxxxx
```

## After Successful Sync

1. **Check Products**: `GET /api/products` should return products
2. **Check Categories**: `GET /api/products/categories` should return categories
3. **Frontend**: Products should now appear in the app

## Sync Frequency

- **Manual**: Call `/api/products/sync` whenever you want to update
- **Recommended**: Sync after adding/updating products in WooCommerce
- **Automatic**: Can be scheduled via cron job (not implemented yet)

## Notes

- Sync preserves local price/stock overrides (if set)
- Products are matched by `woo_id` (WooCommerce product ID)
- Categories are matched by `woo_id` (WooCommerce category ID)
- Sync may take 30-60 seconds for 100+ products


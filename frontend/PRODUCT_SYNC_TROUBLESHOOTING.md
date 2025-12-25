# Product Sync Troubleshooting Guide

## ✅ Changes Made

1. **Added debug logging** to product service - check console/logs for errors
2. **Added sync button** in products page (top right, sync icon)
3. **Improved error messages** - shows helpful messages when no products found
4. **Better sync feedback** - shows success message with counts after sync

## How to Sync Products

### Method 1: Using the App (Easiest)

1. **Open Products Page** in the app
2. **Click the Sync Icon** (🔄) in the top right of the app bar
3. **Wait for sync** - may take 30-60 seconds
4. **Check success message** - shows number of categories and products synced
5. **Products should appear** automatically after sync

### Method 2: Using Swagger UI

1. Go to: `https://tazeindecor.liara.run/docs`
2. Login first (get token from `/api/auth/login`)
3. Click "Authorize" and paste token
4. Find `/api/products/sync` endpoint
5. Click "Try it out" → "Execute"
6. Wait for response

## Troubleshooting Steps

### Step 1: Check if Sync Was Run

**In the app:**
- Look for sync button in products page
- If you see "محصولی یافت نشد" (No products found), click the sync button

**In backend logs:**
- Look for: `🔄 Starting WooCommerce sync...`
- Look for: `✅ Synced X categories`
- Look for: `✅ Synced X new products`

### Step 2: Verify WooCommerce Connection

**Check environment variables:**
```env
WOOCOMMERCE_URL=https://tazeindecor.com
WOOCOMMERCE_CONSUMER_KEY=ck_xxxxxxxxxxxxx
WOOCOMMERCE_CONSUMER_SECRET=cs_xxxxxxxxxxxxx
```

**Test in Swagger:**
1. Go to `/docs`
2. Try `/api/products/sync` endpoint
3. Check response - should show categories and products count

### Step 3: Check Backend Logs

Look for these messages:
- ✅ `🔄 Starting WooCommerce sync...` - Sync started
- ✅ `📁 Syncing categories...` - Categories being synced
- ✅ `Found X categories in WooCommerce` - Categories found
- ✅ `📦 Syncing products...` - Products being synced
- ✅ `Found X products in WooCommerce` - Products found
- ❌ `Error fetching categories: ...` - WooCommerce connection issue
- ❌ `Error fetching products: ...` - WooCommerce connection issue

### Step 4: Check Frontend Logs

**In debug mode, check console for:**
- `🔄 Starting product sync...` - Sync started
- `✅ Sync successful: {...}` - Sync completed
- `✅ Products fetched: X products` - Products loaded
- `❌ Sync error: ...` - Sync failed
- `❌ Products fetch error: ...` - Fetch failed

### Step 5: Verify API Response

**Test `/api/products` endpoint:**
```bash
curl https://tazeindecor.liara.run/api/products?page=1&per_page=20
```

Should return JSON array of products:
```json
[
  {
    "id": 1,
    "woo_id": 123,
    "name": "Product Name",
    "price": 100000,
    ...
  }
]
```

If returns `[]` (empty array), products haven't been synced yet.

## Common Issues

### Issue 1: "محصولی یافت نشد" (No products found)

**Causes:**
- Products haven't been synced yet
- WooCommerce has no products
- WooCommerce credentials incorrect

**Solution:**
1. Click sync button in app
2. Check backend logs for errors
3. Verify WooCommerce credentials
4. Check if WooCommerce has products

### Issue 2: Sync Button Does Nothing

**Causes:**
- Not logged in (no token)
- Network error
- Backend error

**Solution:**
1. Check if you're logged in
2. Check network connection
3. Check backend logs for errors
4. Try sync via Swagger UI

### Issue 3: Sync Takes Too Long

**Causes:**
- Large number of products (100+)
- Slow WooCommerce API
- Network latency

**Solution:**
- This is normal for large catalogs
- Wait for completion (30-60 seconds)
- Check backend logs for progress

### Issue 4: Sync Fails with Error

**Check backend logs for:**
- `Error fetching categories: ...` - WooCommerce connection issue
- `Error fetching products: ...` - WooCommerce connection issue
- `Sync failed: ...` - Database or other error

**Solution:**
1. Verify WooCommerce URL is correct
2. Verify Consumer Key and Secret are correct
3. Check WooCommerce REST API is enabled
4. Check network connectivity to WooCommerce

### Issue 5: Products Show But Images Don't Load

**Causes:**
- Image URLs are incorrect
- CORS issues
- Network issues

**Solution:**
1. Check product `image_url` in API response
2. Verify image URLs are accessible
3. Check CORS settings on WooCommerce

## Verification Checklist

- [ ] WooCommerce credentials are set in environment variables
- [ ] WooCommerce REST API is enabled
- [ ] WooCommerce has products
- [ ] Sync endpoint returns 200 OK
- [ ] `/api/products` returns products (not empty array)
- [ ] Frontend can fetch products (check console logs)
- [ ] Products appear in app after sync

## Next Steps

1. **Run sync** using sync button in app
2. **Check logs** for any errors
3. **Verify products** appear in app
4. **If still empty**, check WooCommerce connection and credentials

## Debug Mode

To see detailed logs:
1. Run app in debug mode
2. Check console/logcat for debug messages
3. Look for `✅` (success) and `❌` (error) markers

## Support

If products still don't show after following these steps:
1. Check backend logs for detailed error messages
2. Verify WooCommerce API is accessible
3. Test sync endpoint directly via Swagger UI
4. Check network connectivity between backend and WooCommerce


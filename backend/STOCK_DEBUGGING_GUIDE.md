# Stock Quantity Debugging Guide

## Quick Test

### 1. Check Backend Logs
When you fetch products, the backend will log the first 3 products with their stock data:
```
🔍 [DEBUG] Product 1 raw data:
   stock_quantity: 50
   stock_status: instock
   manage_stock: True
   in_stock: True
   → Calculated stock_qty: 50, status: available
```

### 2. Use Debug Endpoint (Admin Only)
Test a specific product's raw WooCommerce data:
```
GET /api/products/debug/{product_id}
```

Example response:
```json
{
  "product_id": 123,
  "raw_woocommerce": {
    "id": 123,
    "name": "Product Name",
    "stock_quantity": 50,
    "stock_status": "instock",
    "manage_stock": true,
    "in_stock": true
  },
  "stock_info": {
    "stock_quantity": 50,
    "stock_status": "instock",
    "manage_stock": true,
    "in_stock": true,
    "backorders": "no"
  },
  "transformed": {
    "id": 123,
    "stock_quantity": 50,
    "status": "available"
  }
}
```

### 3. Test Direct WooCommerce API
Test if WooCommerce is returning stock data correctly:
```bash
curl "https://your-woocommerce-site.com/wp-json/wc/v3/products/123?consumer_key=xxx&consumer_secret=yyy"
```

Look for these fields in the response:
- `stock_quantity`: Should be a number or null
- `stock_status`: Should be "instock", "outofstock", or "onbackorder"
- `manage_stock`: Should be true or false
- `in_stock`: Should be true or false

## Common Scenarios

### Scenario 1: Product with Stock Management Enabled
```json
{
  "stock_quantity": 50,
  "stock_status": "instock",
  "manage_stock": true
}
```
**Result**: `stock_qty = 50`, status = AVAILABLE ✅

### Scenario 2: Product with Stock Management Disabled
```json
{
  "stock_quantity": null,
  "stock_status": "instock",
  "manage_stock": false
}
```
**Result**: `stock_qty = 999`, status = AVAILABLE ✅

### Scenario 3: Out of Stock Product
```json
{
  "stock_quantity": 0,
  "stock_status": "outofstock",
  "manage_stock": true
}
```
**Result**: `stock_qty = 0`, status = UNAVAILABLE ✅

### Scenario 4: Limited Stock Product
```json
{
  "stock_quantity": 3,
  "stock_status": "instock",
  "manage_stock": true
}
```
**Result**: `stock_qty = 3`, status = LIMITED ✅

### Scenario 5: Stock Management Enabled but Quantity is Null
```json
{
  "stock_quantity": null,
  "stock_status": "instock",
  "manage_stock": true
}
```
**Result**: `stock_qty = 10`, status = AVAILABLE ✅

## WooCommerce Settings Check

### Global Settings
1. Go to **WooCommerce → Settings → Products → Inventory**
2. Check:
   - ✅ "Enable stock management" is checked
   - ✅ "Hold stock (minutes)" is set (e.g., 60)

### Per-Product Settings
For each product:
1. Edit product in WooCommerce
2. Go to **Inventory** tab
3. Check:
   - ✅ "Manage stock?" checkbox is checked (if you want to track quantity)
   - ✅ "Stock quantity" is set (if managing stock)
   - ✅ "Stock status" is "In stock" (if not managing stock)

## Troubleshooting

### All Products Show as Out of Stock

**Possible Causes:**
1. **Stock management disabled globally**
   - Fix: Enable in WooCommerce → Settings → Products → Inventory

2. **All products have `stock_quantity = null` and `stock_status = "outofstock"`**
   - Fix: Update products in WooCommerce to set stock status to "In stock"

3. **WooCommerce API not returning stock data**
   - Fix: Check API credentials and test direct API call

### Some Products Show Correctly, Others Don't

**Possible Causes:**
1. **Mixed stock management settings**
   - Some products have `manage_stock = true`, others `false`
   - Fix: Standardize stock management settings

2. **Inconsistent stock_status values**
   - Some products have `stock_status = "instock"`, others `null` or empty
   - Fix: Update all products to have proper stock_status

## Expected Behavior

| WooCommerce Data | Calculated stock_qty | Status | Frontend Display |
|------------------|---------------------|--------|-----------------|
| `stock_quantity: 50, manage_stock: true` | 50 | AVAILABLE | موجود (green) |
| `stock_quantity: null, manage_stock: false, stock_status: "instock"` | 999 | AVAILABLE | موجود (green) |
| `stock_quantity: 0, stock_status: "outofstock"` | 0 | UNAVAILABLE | ناموجود (red) |
| `stock_quantity: 3, stock_status: "instock"` | 3 | LIMITED | موجودی محدود (orange) |
| `stock_quantity: null, manage_stock: true, stock_status: "instock"` | 10 | AVAILABLE | موجود (green) |

## Next Steps

1. **Check backend logs** for debug output
2. **Test debug endpoint** with a known product ID
3. **Verify WooCommerce settings** (global and per-product)
4. **Test direct WooCommerce API** to see raw data
5. **Update products** if stock data is incorrect in WooCommerce


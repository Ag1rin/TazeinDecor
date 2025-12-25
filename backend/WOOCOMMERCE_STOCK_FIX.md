# WooCommerce Stock Quantity Fix

## Problem
All products showing as "ناموجود" (out of stock) even though they have stock in WooCommerce.

## Root Cause Analysis

### WooCommerce Stock Fields:
1. **`stock_quantity`**: Actual numeric quantity (can be `null` if stock management disabled)
2. **`stock_status`**: "instock", "outofstock", "onbackorder" (always present)
3. **`manage_stock`**: Boolean - if `false`, stock tracking is disabled
4. **`in_stock`**: Boolean - alternative stock indicator

### Issues Found:
- Code was defaulting `stock_quantity` to 0 when `null`
- Not checking `manage_stock` flag
- Not using `stock_status` as fallback
- Not handling unlimited stock scenarios

## Fix Applied

### Updated `_transform_woo_product()` Function:

1. **Proper Stock Quantity Handling**:
   ```python
   # If stock_quantity exists, use it
   if stock_quantity is not None:
       stock_qty = int(float(stock_quantity))
   
   # If manage_stock is false, stock is unlimited
   elif not manage_stock:
       if stock_status == "instock":
           stock_qty = 999  # Represent unlimited
       else:
           stock_qty = 0
   
   # If manage_stock is true but stock_quantity is null
   else:
       if stock_status == "instock":
           stock_qty = 10  # Assume available
       else:
           stock_qty = 0
   ```

2. **Status Calculation with Fallbacks**:
   ```python
   if stock_qty == 0 or stock_status == "outofstock":
       status = UNAVAILABLE
   elif stock_qty < 5 and stock_qty > 0:
       status = LIMITED
   elif stock_qty >= 5 or stock_status == "instock":
       status = AVAILABLE
   ```

3. **Debug Logging**:
   - Logs first 3 products with raw WooCommerce data
   - Shows stock_quantity, stock_status, manage_stock, in_stock
   - Shows calculated stock_qty and status

## WooCommerce Settings Check

### Required Settings:
1. **WooCommerce → Settings → Products → Inventory**:
   - ✅ "Enable stock management" should be checked
   - ✅ "Hold stock (minutes)" should be set

2. **Per-Product Settings**:
   - ✅ "Manage stock?" checkbox should be enabled for products with stock
   - ✅ "Stock quantity" should be set
   - ✅ "Stock status" should be "In stock"

### Common Issues:
- **Stock management disabled globally**: All products show as out of stock
- **Stock management disabled per-product**: Product shows as available but no quantity
- **stock_quantity is null**: WooCommerce doesn't track quantity, only status

## Testing

### Test Product with Stock:
```json
{
  "id": 123,
  "stock_quantity": 50,
  "stock_status": "instock",
  "manage_stock": true
}
```
**Expected**: stock_qty = 50, status = AVAILABLE

### Test Product without Stock Management:
```json
{
  "id": 124,
  "stock_quantity": null,
  "stock_status": "instock",
  "manage_stock": false
}
```
**Expected**: stock_qty = 999, status = AVAILABLE

### Test Out of Stock Product:
```json
{
  "id": 125,
  "stock_quantity": 0,
  "stock_status": "outofstock",
  "manage_stock": true
}
```
**Expected**: stock_qty = 0, status = UNAVAILABLE

## Debug Logging

The code now logs the first 3 products with:
- Raw `stock_quantity` value
- `stock_status` value
- `manage_stock` flag
- `in_stock` flag
- Calculated `stock_qty`
- Final `status`

Check backend logs to see what WooCommerce is actually returning.

## Frontend Display Logic

Frontend already uses `stock_quantity` directly:
- `stock_quantity == 0` → "ناموجود" (red)
- `0 < stock_quantity < 5` → "موجودی محدود" (orange)
- `stock_quantity >= 5` → "موجود" (green)

This matches the backend status calculation.

## Next Steps

1. **Check backend logs** for debug output of first 3 products
2. **Verify WooCommerce settings** (stock management enabled)
3. **Test with products** that have known stock quantities
4. **Check if products show correctly** after fix

## Additional Notes

- Products with `manage_stock = false` and `stock_status = "instock"` are treated as available
- Products with `stock_quantity = null` but `stock_status = "instock"` are treated as available (stock_qty = 10)
- Products with `stock_status = "outofstock"` are always unavailable, regardless of quantity


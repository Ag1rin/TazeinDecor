"""
Product and category routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status  # pyright: ignore[reportMissingImports]
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from app.database import get_db
from app.models import Product, Category, User, UserRole, ProductStatus
from app.schemas import ProductResponse, CategoryResponse
from app.dependencies import require_role, get_current_user
from app.woocommerce_client import woocommerce_client
from app.woocommerce_cache import woocommerce_cache
import json

router = APIRouter(prefix="/api/products", tags=["products"])


def require_seller_or_store_manager(current_user: User = Depends(get_current_user)) -> User:
    """Dependency to require SELLER or STORE_MANAGER role"""
    if current_user.role not in [UserRole.SELLER, UserRole.STORE_MANAGER]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access to products is only allowed for sellers and store managers"
        )
    return current_user


def _transform_woo_category(woo_cat: Dict[str, Any]) -> CategoryResponse:
    """Transform WooCommerce category to CategoryResponse format"""
    return CategoryResponse(
        id=woo_cat.get("id", 0),
        woo_id=woo_cat.get("id", 0),
        name=woo_cat.get("name", ""),
        slug=woo_cat.get("slug", ""),
        description=woo_cat.get("description", ""),
        image_url=woo_cat.get("image", {}).get("src") if woo_cat.get("image") else None,
        parent_id=woo_cat.get("parent") if woo_cat.get("parent") else None,
        children=[]
    )


def _build_category_tree(categories: List[CategoryResponse]) -> List[CategoryResponse]:
    """Build category tree structure from flat list"""
    category_dict = {cat.id: cat for cat in categories}
    root_categories = []
    
    for cat in categories:
        if cat.parent_id:
            parent = category_dict.get(cat.parent_id)
            if parent:
                parent.children.append(cat)
        else:
            root_categories.append(cat)
    
    return root_categories


@router.get("/categories", response_model=List[CategoryResponse])
async def get_categories(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_seller_or_store_manager)
):
    """Get all categories from WooCommerce (Seller/Store Manager only)"""
    print(f"📁 Fetching categories - User ID: {current_user.id}, Role: {current_user.role}")
    try:
        # Check cache first
        cache_key = "categories"
        cached_data = woocommerce_cache.get(cache_key)
        if cached_data is not None:
            print("📦 Using cached categories")
            return [CategoryResponse(**cat) for cat in cached_data]
        
        # Fetch from WooCommerce
        print("🔄 Fetching categories from WooCommerce...")
        woo_categories = woocommerce_client.get_all_categories()
        
        if not woo_categories:
            print("⚠️  No categories found in WooCommerce")
            return []
        
        # Filter to only show allowed categories
        allowed_category_names = [
            "پارکت",
            "پارکت لمینت",
            "کاغذ دیواری",
            "ابزار پارکت",
            "ابزار های پارکت",
            "درب",
            "کفپوش",
            "کفپوش pvc"
        ]
        
        # Filter categories by name
        filtered_categories = []
        for cat in woo_categories:
            cat_name = cat.get("name", "").strip()
            if any(allowed_name.lower() in cat_name.lower() or cat_name.lower() in allowed_name.lower() 
                   for allowed_name in allowed_category_names):
                filtered_categories.append(cat)
                print(f"  ✓ Found category: {cat_name} (ID: {cat.get('id')})")
        
        print(f"📁 Filtered to {len(filtered_categories)} allowed categories (from {len(woo_categories)} total)")
        
        if len(filtered_categories) == 0:
            print("⚠️  WARNING: No categories matched the allowed list!")
            print(f"   Allowed categories: {allowed_category_names}")
            print(f"   Available categories from WooCommerce:")
            for cat in woo_categories[:10]:  # Show first 10
                print(f"     - {cat.get('name', 'Unknown')} (ID: {cat.get('id')})")
        
        # Transform WooCommerce categories
        transformed_categories = [_transform_woo_category(cat) for cat in filtered_categories]
        
        # Build tree structure
        tree_categories = _build_category_tree(transformed_categories)
        
        # Cache the result (as dict for serialization)
        cache_data = [cat.model_dump() for cat in tree_categories]
        woocommerce_cache.set(cache_key, cache_data)
        
        print(f"✅ Fetched {len(tree_categories)} root categories from WooCommerce")
        return tree_categories
        
    except Exception as e:
        print(f"❌ Error fetching categories from WooCommerce: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch categories from WooCommerce: {str(e)}"
        )


def _transform_woo_product(woo_product: Dict[str, Any]) -> Dict[str, Any]:
    """Transform WooCommerce product to ProductResponse format"""
    # Log raw product data for first few products (debugging)
    product_id = woo_product.get("id", 0)
    if product_id and product_id <= 3:  # Log first 3 products
        print(f"\n🔍 [DEBUG] Product {product_id} raw data:")
        print(f"   stock_quantity: {woo_product.get('stock_quantity')}")
        print(f"   stock_status: {woo_product.get('stock_status')}")
        print(f"   manage_stock: {woo_product.get('manage_stock')}")
        print(f"   in_stock: {woo_product.get('in_stock')}")
    
    # Handle stock_quantity with proper WooCommerce logic
    stock_quantity = woo_product.get("stock_quantity")
    stock_status = woo_product.get("stock_status", "").lower()
    manage_stock = woo_product.get("manage_stock", False)
    in_stock = woo_product.get("in_stock", False)
    
    # Determine actual stock quantity
    stock_qty = 0
    if stock_quantity is not None:
        try:
            stock_qty = int(float(stock_quantity))  # Handle string numbers
        except (ValueError, TypeError):
            stock_qty = 0
    elif not manage_stock:
        # If stock management is disabled, treat as available (unlimited stock)
        # Use stock_status to determine availability
        if stock_status == "instock" or in_stock:
            stock_qty = 999  # Represent unlimited as high number
        elif stock_status == "outofstock":
            stock_qty = 0
        else:
            stock_qty = 0
    else:
        # manage_stock is true but stock_quantity is null - use stock_status
        if stock_status == "instock" or in_stock:
            stock_qty = 10  # Assume available if instock but no quantity
        elif stock_status == "outofstock":
            stock_qty = 0
        else:
            stock_qty = 0
    
    # Determine status based on stock_quantity and stock_status
    status = ProductStatus.AVAILABLE
    if stock_qty == 0 or stock_status == "outofstock":
        status = ProductStatus.UNAVAILABLE
    elif stock_qty < 5 and stock_qty > 0:
        status = ProductStatus.LIMITED
    elif stock_qty >= 5 or stock_status == "instock" or (not manage_stock and stock_status != "outofstock"):
        status = ProductStatus.AVAILABLE
    
    if product_id and product_id <= 3:
        print(f"   → Calculated stock_qty: {stock_qty}, status: {status.value}\n")
    
    # Get images - use full size if available, otherwise large, otherwise src
    images = []
    if woo_product.get("images"):
        for img in woo_product["images"]:
            if img.get("src"):
                # Prefer full size, then large, then regular src
                image_url = img.get("full", img.get("large", img.get("src", "")))
                if image_url:
                    images.append(image_url)
    
    # Get category ID and name (use first category if available)
    category_id = None
    category_name = None
    if woo_product.get("categories") and len(woo_product["categories"]) > 0:
        category_id = woo_product["categories"][0].get("id")
        category_name = woo_product["categories"][0].get("name", "")
    
    # Handle price - use sale_price if available, otherwise regular_price or price
    price = 0.0
    regular_price = None
    sale_price = None
    
    if woo_product.get("sale_price"):
        sale_price = float(woo_product["sale_price"])
        price = sale_price
        regular_price = float(woo_product.get("regular_price", sale_price))
    elif woo_product.get("regular_price"):
        regular_price = float(woo_product["regular_price"])
        price = regular_price
    elif woo_product.get("price"):
        price = float(woo_product["price"])
    
    # Extract custom attributes from WooCommerce
    album_code = None
    design_code = None
    brand = None
    package_area = None
    roll_count = None
    
    if woo_product.get("attributes"):
        for attr in woo_product["attributes"]:
            attr_name = attr.get("name", "").lower()
            attr_options = attr.get("options", [])
            
            if attr_options:
                attr_value = attr_options[0] if isinstance(attr_options, list) else str(attr_options)
                
                if "کد آلبوم" in attr_name or "album" in attr_name or "album_code" in attr_name:
                    album_code = attr_value
                elif "کد طراحی" in attr_name or "design" in attr_name or "design_code" in attr_name:
                    design_code = attr_value
                elif "برند" in attr_name or "brand" in attr_name:
                    brand = attr_value
                elif "مساحت" in attr_name or "area" in attr_name or "package_area" in attr_name:
                    try:
                        package_area = float(attr_value)
                    except (ValueError, TypeError):
                        pass
                elif "رول" in attr_name or "roll" in attr_name or "roll_count" in attr_name:
                    try:
                        roll_count = int(float(attr_value))
                    except (ValueError, TypeError):
                        pass
    
    return {
        "id": woo_product.get("id", 0),
        "woo_id": woo_product.get("id", 0),
        "name": woo_product.get("name", ""),
        "slug": woo_product.get("slug", ""),
        "sku": woo_product.get("sku", ""),
        "description": woo_product.get("description", ""),
        "short_description": woo_product.get("short_description", ""),
        "price": price,
        "regular_price": regular_price,
        "sale_price": sale_price,
        "stock_quantity": stock_qty,
        "status": status,
        "image_url": images[0] if images else None,
        "images": json.dumps(images) if images else None,
        "category_id": category_id,
        "package_area": package_area,
        "design_code": design_code,
        "album_code": album_code,
        "roll_count": roll_count,
        "company_id": None,  # Not in WooCommerce by default
        "local_price": None,  # Only in local DB
        "local_stock": None,  # Only in local DB
        "brand": brand,  # Custom field for brand
    }


@router.get("", response_model=List[ProductResponse])
async def get_products(
    category_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=1000),  # Increased limit to allow fetching all products for a category
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_seller_or_store_manager)
):
    """Get products from WooCommerce with pagination and filters (Seller/Store Manager only)"""
    try:
        # Build cache key
        # For category views, we fetch all products, so cache key should reflect that
        cache_params = {}
        if category_id:
            cache_params["category"] = category_id
            # For category views, we fetch all products (no pagination)
            cache_params["all"] = True
        else:
            cache_params["page"] = page
            cache_params["per_page"] = per_page
        if search:
            cache_params["search"] = search
        
        cache_key = "products"
        cached_data = woocommerce_cache.get(cache_key, cache_params)
        if cached_data is not None:
            if category_id:
                print(f"📦 Using cached products for category {category_id} (all products)")
            else:
                print(f"📦 Using cached products (page {page})")
            return [ProductResponse(**p) for p in cached_data]
        
        # Define allowed category names (must match get_categories)
        allowed_category_names = [
            "پارکت",
            "پارکت لمینت",
            "کاغذ دیواری",
            "ابزار پارکت",
            "ابزار های پارکت",
            "درب",
            "کفپوش",
            "کفپوش pvc"
        ]
        
        # Get allowed category IDs
        woo_categories = woocommerce_client.get_all_categories()
        allowed_category_ids = []
        category_name_to_id = {}  # Map for debugging
        for cat in woo_categories:
            cat_name = cat.get("name", "").strip()
            cat_id = cat.get("id")
            category_name_to_id[cat_name] = cat_id
            
            if any(allowed_name.lower() in cat_name.lower() or cat_name.lower() in allowed_name.lower() 
                   for allowed_name in allowed_category_names):
                allowed_category_ids.append(cat_id)
                print(f"  ✓ Allowed category: {cat_name} (ID: {cat_id})")
        
        print(f"📋 Allowed category IDs: {allowed_category_ids}")
        
        # Debug: Show category ID for "کاغذ دیواری" specifically
        for name, cat_id in category_name_to_id.items():
            if "کاغذ" in name or "دیواری" in name:
                print(f"🔍 Found wallpaper category: '{name}' (ID: {cat_id})")
        
        # If category_id is provided, validate it's in allowed list and fetch products
        if category_id:
            # Validate category is allowed
            if category_id not in allowed_category_ids:
                print(f"⚠️  Category {category_id} is not in allowed list. Allowed IDs: {allowed_category_ids}")
                return []
            
            # For category views, fetch ALL products (no pagination) sorted by date descending (newest first)
            print(f"🔄 Fetching ALL products from WooCommerce for category {category_id} (sorted newest first)...")
            if search:
                print(f"   Search term: '{search}'")
                # If search is provided, use paginated search (cap per_page at 100 for search)
                effective_per_page = min(per_page, 100)  # Cap at 100 for search queries
                woo_products = woocommerce_client.get_products(
                    page=page,
                    per_page=effective_per_page,
                    category=category_id,
                    search=search,
                    orderby="date",
                    order="desc"
                )
            else:
                # Fetch all products for the category, sorted by date descending (newest first)
                woo_products = woocommerce_client.get_all_products(
                    category=category_id,
                    orderby="date",
                    order="desc"
                )
            print(f"   Raw products returned from WooCommerce: {len(woo_products) if woo_products else 0}")
            
            # Since category_id is validated as allowed, trust WooCommerce results
            # WooCommerce already filters by category (including child categories), so we can trust the results
            # Only do a minimal safety check - if WooCommerce returned it for this category, include it
            if woo_products:
                original_count = len(woo_products)
                filtered_products = []
                for product in woo_products:
                    product_categories = product.get("categories", [])
                    product_category_ids = [cat.get("id") for cat in product_categories]
                    product_name = product.get("name", "")
                    
                    # If product was returned by WooCommerce for this category_id, trust it
                    # This handles parent/child category relationships
                    if category_id in product_category_ids:
                        filtered_products.append(product)
                    # Check if product belongs to any allowed category
                    elif any(cat_id in allowed_category_ids for cat_id in product_category_ids):
                        filtered_products.append(product)
                    # Also check product name contains allowed category name (fallback)
                    elif any(allowed_name.lower() in product_name.lower() 
                            for allowed_name in allowed_category_names):
                        filtered_products.append(product)
                    else:
                        # Only filter out if product clearly doesn't belong
                        print(f"   ⚠️  Product '{product_name[:50]}' filtered out - categories: {product_category_ids}, requested: {category_id}")
                
                woo_products = filtered_products
                if len(woo_products) < original_count:
                    print(f"✅ Filtered to {len(woo_products)} products from allowed categories (from {original_count} total)")
                else:
                    print(f"✅ All {len(woo_products)} products are valid for category {category_id}")
        else:
            # If no category_id, fetch products with pagination (for "all products" view)
            print(f"🔄 Fetching products from WooCommerce (page {page}, per_page {per_page}, sorted newest first)...")
            woo_products = woocommerce_client.get_products(
                page=page,
                per_page=per_page,
                category=None,
                search=search,
                orderby="date",
                order="desc"
            )
            
            # Filter products by allowed categories (using already computed allowed_category_ids)
            if woo_products:
                filtered_products = []
                for product in woo_products:
                    product_categories = product.get("categories", [])
                    product_category_ids = [cat.get("id") for cat in product_categories]
                    
                    # Check if product belongs to any allowed category
                    if any(cat_id in allowed_category_ids for cat_id in product_category_ids):
                        filtered_products.append(product)
                    # Also check product name contains allowed category name (fallback)
                    elif any(allowed_name.lower() in product.get("name", "").lower() 
                            for allowed_name in allowed_category_names):
                        filtered_products.append(product)
                
                woo_products = filtered_products
                print(f"✅ Filtered to {len(woo_products)} products from allowed categories")
        
        if not woo_products:
            print("⚠️  No products found in WooCommerce")
            # Don't cache empty results - this allows retrying immediately if products are added
            # Empty results might be due to temporary API issues or actual empty categories
            return []
        
        # Transform WooCommerce products to ProductResponse
        # Store original date_created for sorting
        products_with_dates = []
        for p in woo_products:
            transformed = _transform_woo_product(p)
            # Extract date_created from WooCommerce product if available
            date_created = p.get("date_created")
            if date_created:
                try:
                    from datetime import datetime
                    # Parse ISO format date string
                    date_obj = datetime.fromisoformat(date_created.replace('Z', '+00:00'))
                    transformed["_sort_date"] = date_obj.timestamp()
                except:
                    transformed["_sort_date"] = p.get("id", 0)
            else:
                # Fallback to ID (higher ID typically means newer product)
                transformed["_sort_date"] = p.get("id", 0)
            products_with_dates.append((transformed, transformed["_sort_date"]))
        
        # Sort by date descending (newest first)
        products_with_dates.sort(key=lambda x: x[1], reverse=True)
        
        # Remove temporary sort field and create ProductResponse objects
        transformed_products = [
            ProductResponse(**{k: v for k, v in p.items() if k != "_sort_date"})
            for p, _ in products_with_dates
        ]
        
        # Cache the result (as dict for serialization)
        cache_data = [p.model_dump() for p in transformed_products]
        woocommerce_cache.set(cache_key, cache_data, cache_params)
        
        print(f"✅ Fetched {len(transformed_products)} products from WooCommerce (sorted newest first)")
        return transformed_products
        
    except Exception as e:
        print(f"❌ Error fetching products from WooCommerce: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch products from WooCommerce: {str(e)}"
        )


@router.post("/sync")
async def sync_products(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN))
):
    """Sync products and categories from WooCommerce to local database (Admin only) - DEPRECATED"""
    raise HTTPException(
        status_code=404,
        detail="Sync endpoint is no longer available. Products are fetched directly from WooCommerce."
    )
    return


@router.get("/debug/{product_id}")
async def debug_product(
    product_id: int,
    current_user: User = Depends(require_role(UserRole.ADMIN))
):
    """Debug endpoint to see raw WooCommerce product data (Admin only)"""
    try:
        woo_product = woocommerce_client.get_product(product_id)
        if not woo_product:
            raise HTTPException(status_code=404, detail="Product not found in WooCommerce")
        
        # Return raw WooCommerce data with stock info highlighted
        return {
            "product_id": product_id,
            "raw_woocommerce": woo_product,
            "stock_info": {
                "stock_quantity": woo_product.get("stock_quantity"),
                "stock_status": woo_product.get("stock_status"),
                "manage_stock": woo_product.get("manage_stock"),
                "in_stock": woo_product.get("in_stock"),
                "backorders": woo_product.get("backorders"),
            },
            "transformed": _transform_woo_product(woo_product)
        }
    except Exception as e:
        print(f"❌ Debug error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Debug error: {str(e)}")


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_seller_or_store_manager)
):
    """Get single product from WooCommerce (Seller/Store Manager only)"""
    try:
        # Check cache first
        cache_key = f"product_{product_id}"
        cached_data = woocommerce_cache.get(cache_key)
        if cached_data is not None:
            print(f"📦 Using cached product {product_id}")
            return ProductResponse(**cached_data)
        
        # Fetch from WooCommerce
        print(f"🔄 Fetching product {product_id} from WooCommerce...")
        woo_product = woocommerce_client.get_product(product_id)
        
        if not woo_product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Transform WooCommerce product to ProductResponse
        transformed_product = ProductResponse(**_transform_woo_product(woo_product))
        
        # Cache the result (as dict for serialization)
        cache_data = transformed_product.model_dump()
        woocommerce_cache.set(cache_key, cache_data)
        
        print(f"✅ Fetched product {product_id} from WooCommerce")
        return transformed_product
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching product {product_id} from WooCommerce: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch product from WooCommerce: {str(e)}"
        )


@router.get("/{product_id}/variations")
async def get_product_variations(
    product_id: int,
    current_user: User = Depends(require_seller_or_store_manager)
):
    """Get product variations from WooCommerce (Seller/Store Manager only)"""
    try:
        print(f"🔄 Fetching variations for product {product_id} from WooCommerce...")
        variations = woocommerce_client.get_product_variations(product_id)
        
        if not variations:
            return []
        
        # Transform variations to include pattern attribute
        def _to_float(val, default=0.0):
            try:
                if val in (None, "", []):
                    return default
                return float(val)
            except (ValueError, TypeError):
                return default

        transformed_variations = []
        def _extract_pattern(attrs: list) -> str | None:
            """Extract pattern/tarh code from variation attributes."""
            if not attrs:
                return None
            for attr in attrs:
                option = attr.get("option")
                name = (attr.get("name") or "").lower()
                slug = (attr.get("slug") or "").lower()
                if not option:
                    continue
                if (
                    "pattern" in name
                    or "tarh" in name
                    or "طرح" in name
                    or "pattern" in slug
                    or "tarh" in slug
                    or "طرح" in slug
                    or name.startswith("pa_pattern")
                    or name.startswith("pa_tarh")
                    or slug.startswith("pa_pattern")
                    or slug.startswith("pa_tarh")
                ):
                    return option
            # Fallback: first option
            first = attrs[0].get("option")
            return first if first else None

        for variation in variations:
            pattern_value = _extract_pattern(variation.get("attributes") or [])
            
            transformed_variations.append({
                "id": variation.get("id"),
                "sku": variation.get("sku"),
                "price": _to_float(variation.get("price"), 0.0),
                "regular_price": (
                    _to_float(variation.get("regular_price"))
                    if variation.get("regular_price") not in (None, "", [])
                    else None
                ),
                "sale_price": (
                    _to_float(variation.get("sale_price"))
                    if variation.get("sale_price") not in (None, "", [])
                    else None
                ),
                "stock_quantity": variation.get("stock_quantity", 0),
                "stock_status": variation.get("stock_status", "instock"),
                "image": variation.get("image", {}).get("src") if variation.get("image") else None,
                "attributes": variation.get("attributes", []),
                "pattern": pattern_value,  # Extract pattern value
            })
        
        print(f"✅ Fetched {len(transformed_variations)} variations for product {product_id}")
        return transformed_variations
        
    except Exception as e:
        print(f"❌ Error fetching variations for product {product_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch variations from WooCommerce: {str(e)}"
        )


@router.put("/{product_id}/price")
async def update_product_price(
    product_id: int,
    price: float,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Update product price in WooCommerce (Operator only) - Direct API call"""
    try:
        # Update price directly in WooCommerce
        update_data = {
            "regular_price": str(price)
        }
        
        response = woocommerce_client.update_product(product_id, update_data)
        if not response:
            raise HTTPException(status_code=404, detail="Product not found in WooCommerce")
        
        return {"message": "Price updated in WooCommerce", "product_id": product_id, "price": price}
    except Exception as e:
        print(f"❌ Error updating product price: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update price: {str(e)}")


@router.put("/{product_id}/stock")
async def update_product_stock(
    product_id: int,
    stock: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Update product stock in WooCommerce (Operator only) - Direct API call"""
    try:
        # Update stock directly in WooCommerce
        update_data = {
            "stock_quantity": stock,
            "manage_stock": True
        }
        
        response = woocommerce_client.update_product(product_id, update_data)
        if not response:
            raise HTTPException(status_code=404, detail="Product not found in WooCommerce")
        
        return {"message": "Stock updated in WooCommerce", "product_id": product_id, "stock": stock}
    except Exception as e:
        print(f"❌ Error updating product stock: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update stock: {str(e)}")


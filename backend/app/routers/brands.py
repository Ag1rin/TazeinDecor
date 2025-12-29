"""
Brand management routes - Fetch brands from WooCommerce
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from app.database import get_db
from app.dependencies import get_current_user
from app.woocommerce_client import woocommerce_client
from app.woocommerce_cache import WooCommerceCache

# Create a cache instance with 10 minutes TTL for brands
brands_cache = WooCommerceCache(ttl_minutes=10)
from app.config import settings
import requests
from pydantic import BaseModel

router = APIRouter(prefix="/api/brands", tags=["brands"])


class BrandResponse(BaseModel):
    """Brand response model"""
    id: int
    name: str
    thumbnail_url: Optional[str] = None


def _extract_thumbnail_url(brand_data: Dict[str, Any]) -> Optional[str]:
    """Extract thumbnail URL from brand data with fallback options"""
    # Priority 1: image.thumbnail
    if isinstance(brand_data.get('image'), dict):
        image = brand_data['image']
        if image.get('thumbnail'):
            return image['thumbnail']
        # Fallback: image.src
        if image.get('src'):
            return image['src']
    
    # Priority 2: thumbnail field (custom field)
    if brand_data.get('thumbnail'):
        return brand_data['thumbnail']
    
    # Priority 3: acf.thumbnail (Advanced Custom Fields)
    if isinstance(brand_data.get('acf'), dict):
        if brand_data['acf'].get('thumbnail'):
            return brand_data['acf']['thumbnail']
    
    # Priority 4: featured_media or featured_image
    if brand_data.get('featured_media'):
        # This would need another API call to get the media URL
        # For now, return None
        pass
    
    return None


async def _fetch_brands_from_woocommerce() -> List[Dict[str, Any]]:
    """Fetch brands from WooCommerce with fallback endpoints"""
    base_url = settings.WOOCOMMERCE_URL
    consumer_key = settings.WOOCOMMERCE_CONSUMER_KEY
    consumer_secret = settings.WOOCOMMERCE_CONSUMER_SECRET
    
    if not base_url or not consumer_key or not consumer_secret:
        print("⚠️  WooCommerce credentials not configured")
        return []
    
    auth = (consumer_key, consumer_secret)
    
    # Try endpoints in priority order
    endpoints = [
        # Priority 1: WooCommerce 9.6+ native brands
        f"{base_url}/wp-json/wc/store/v1/products/brands",
        # Priority 2: Perfect WooCommerce Brands plugin
        f"{base_url}/wp-json/wc/v3/brands",
        # Priority 3: Custom taxonomy product_brand
        f"{base_url}/wp-json/wp/v2/product_brand?per_page=100",
    ]
    
    for endpoint_url in endpoints:
        try:
            print(f"🔄 Trying endpoint: {endpoint_url}")
            response = requests.get(
                endpoint_url,
                auth=auth,
                params={"per_page": 100},
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Successfully fetched brands from: {endpoint_url}")
                
                # Handle different response formats
                brands = []
                if isinstance(data, list):
                    brands = data
                elif isinstance(data, dict) and 'items' in data:
                    brands = data['items']
                elif isinstance(data, dict) and 'data' in data:
                    brands = data['data']
                
                if brands:
                    return brands
            else:
                print(f"⚠️  Endpoint returned {response.status_code}: {endpoint_url}")
        except requests.exceptions.RequestException as e:
            print(f"⚠️  Error fetching from {endpoint_url}: {e}")
            continue
        except Exception as e:
            print(f"⚠️  Unexpected error with {endpoint_url}: {e}")
            continue
    
    print("❌ No brands endpoint available")
    return []


@router.get("", response_model=List[BrandResponse])
async def get_brands(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Get all product brands from WooCommerce with caching.
    Returns brands with id, name, and thumbnail_url.
    """
    # Check cache first (10 minutes TTL)
    cache_key = "/api/brands"
    cached_brands = brands_cache.get(cache_key)
    
    if cached_brands is not None:
        print("✅ Returning cached brands")
        return [BrandResponse(**brand) for brand in cached_brands]
    
    # Fetch from WooCommerce
    print("📦 Fetching brands from WooCommerce...")
    woo_brands = await _fetch_brands_from_woocommerce()
    
    if not woo_brands:
        # Return empty list if no brands found
        return []
    
    # Transform to our format
    brands = []
    for woo_brand in woo_brands:
        try:
            brand_id = woo_brand.get('id') or woo_brand.get('term_id')
            brand_name = woo_brand.get('name') or woo_brand.get('title', '')
            
            if not brand_id or not brand_name:
                continue
            
            thumbnail_url = _extract_thumbnail_url(woo_brand)
            
            brands.append({
                'id': int(brand_id),
                'name': str(brand_name),
                'thumbnail_url': thumbnail_url
            })
        except Exception as e:
            print(f"⚠️  Error processing brand: {e}")
            continue
    
    # Cache for 10 minutes
    brands_cache.set(cache_key, brands)
    
    print(f"✅ Fetched {len(brands)} brands")
    return [BrandResponse(**brand) for brand in brands]


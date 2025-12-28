"""
WooCommerce API client
"""
import requests
from typing import List, Dict, Optional
from app.config import settings


class WooCommerceClient:
    """Client for WooCommerce REST API"""
    
    def __init__(self):
        self.base_url = settings.WOOCOMMERCE_URL
        self.consumer_key = settings.WOOCOMMERCE_CONSUMER_KEY
        self.consumer_secret = settings.WOOCOMMERCE_CONSUMER_SECRET
        self.api_url = f"{self.base_url}/wp-json/wc/v3"
    
    def _get_auth(self):
        """Get authentication tuple"""
        return (self.consumer_key, self.consumer_secret)
    
    def get_categories(self, page: int = 1, per_page: int = 100) -> List[Dict]:
        """Get all product categories"""
        try:
            response = requests.get(
                f"{self.api_url}/products/categories",
                auth=self._get_auth(),
                params={"page": page, "per_page": per_page, "orderby": "id", "order": "asc"},
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching categories (page {page}): {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:200]}")
            return []
        except Exception as e:
            print(f"❌ Unexpected error fetching categories: {e}")
            return []
    
    def get_products(self, page: int = 1, per_page: int = 100, category: Optional[int] = None, search: Optional[str] = None, orderby: str = "date", order: str = "desc") -> List[Dict]:
        """Get products - sorted by date descending (newest first) by default
        
        FIXED: WooCommerce per_page limited to 100 with full pagination
        WooCommerce REST API v3 only allows max per_page=100, so we cap it here.
        For fetching all products, use get_all_products() which handles pagination automatically.
        """
        try:
            # Cap per_page at 100 (WooCommerce API maximum)
            per_page = min(per_page, 100)
            
            params = {"page": page, "per_page": per_page, "orderby": orderby, "order": order}
            if category:
                params["category"] = category
            if search:
                params["search"] = search
            
            response = requests.get(
                f"{self.api_url}/products",
                auth=self._get_auth(),
                params=params,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching products (page {page}): {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:200]}")
            return []
        except Exception as e:
            print(f"❌ Unexpected error fetching products: {e}")
            return []
    
    def get_product(self, product_id: int) -> Optional[Dict]:
        """Get single product by ID"""
        try:
            response = requests.get(
                f"{self.api_url}/products/{product_id}",
                auth=self._get_auth()
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error fetching product {product_id}: {e}")
            return None

    def get_category(self, category_id: int) -> Optional[Dict]:
        """Get single category by ID"""
        try:
            response = requests.get(
                f"{self.api_url}/products/categories/{category_id}",
                auth=self._get_auth(),
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching category {category_id}: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:500]}")
            return None
        except Exception as e:
            print(f"❌ Unexpected error fetching category: {e}")
            return None
    
    def get_all_categories(self) -> List[Dict]:
        """Get all categories with pagination"""
        all_categories = []
        page = 1
        print(f"📁 Fetching categories from WooCommerce (URL: {self.api_url})...")
        while True:
            categories = self.get_categories(page=page)
            if not categories:
                if page == 1:
                    print("⚠️  No categories found in WooCommerce (check credentials and URL)")
                break
            all_categories.extend(categories)
            print(f"   Page {page}: {len(categories)} categories")
            if len(categories) < 100:
                break
            page += 1
        print(f"✅ Total categories fetched: {len(all_categories)}")
        return all_categories
    
    def get_all_products(self, category: Optional[int] = None, orderby: str = "date", order: str = "desc") -> List[Dict]:
        """Get all products with pagination - sorted by date descending (newest first) by default
        
        FIXED: WooCommerce per_page limited to 100 with full pagination
        Implements proper pagination loop:
        - Starts with page=1
        - Fetches with per_page=100 (WooCommerce maximum)
        - Continues until empty page is returned
        - Returns complete list of all products
        """
        all_products = []
        page = 1
        per_page = 100  # WooCommerce API maximum
        total_pages = None
        
        print(f"📦 Fetching ALL products from WooCommerce (sorted by {orderby} {order})...")
        print(f"   Using per_page={per_page} (WooCommerce API maximum)")
        
        while True:
            products = self.get_products(page=page, per_page=per_page, category=category, orderby=orderby, order=order)
            
            # Check if we got an empty page (end of results)
            if not products:
                if page == 1:
                    print("⚠️  No products found in WooCommerce (check if WooCommerce has products)")
                break
            
            all_products.extend(products)
            print(f"   Page {page}: {len(products)} products (total so far: {len(all_products)})")
            
            # If we got fewer products than per_page, we've reached the last page
            if len(products) < per_page:
                total_pages = page
                break
            
            page += 1
        
        if total_pages:
            print(f"✅ Total products fetched: {len(all_products)} across {total_pages} page(s) (sorted newest first)")
        else:
            print(f"✅ Total products fetched: {len(all_products)} (sorted newest first)")
        
        return all_products
    
    def get_product_variations(self, product_id: int) -> List[Dict]:
        """Get all variations for a variable product"""
        try:
            response = requests.get(
                f"{self.api_url}/products/{product_id}/variations",
                auth=self._get_auth(),
                params={"per_page": 100},
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching variations for product {product_id}: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:200]}")
            return []
        except Exception as e:
            print(f"❌ Unexpected error fetching variations: {e}")
            return []

    def create_order(self, order_payload: Dict) -> Optional[Dict]:
        """Create an order in WooCommerce"""
        try:
            response = requests.post(
                f"{self.api_url}/orders",
                auth=self._get_auth(),
                json=order_payload,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error creating WooCommerce order: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:500]}")
            return None
        except Exception as e:
            print(f"❌ Unexpected error creating WooCommerce order: {e}")
            return None

    def update_product(self, product_id: int, update_data: Dict) -> Optional[Dict]:
        """Update a product in WooCommerce"""
        try:
            response = requests.put(
                f"{self.api_url}/products/{product_id}",
                auth=self._get_auth(),
                json=update_data,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error updating product {product_id}: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:500]}")
            return None
        except Exception as e:
            print(f"❌ Unexpected error updating product: {e}")
            return None

    def get_order(self, order_id: int) -> Optional[Dict]:
        """Get a single order from WooCommerce"""
        try:
            response = requests.get(
                f"{self.api_url}/orders/{order_id}",
                auth=self._get_auth(),
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching WooCommerce order {order_id}: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:500]}")
            return None
        except Exception as e:
            print(f"❌ Unexpected error fetching WooCommerce order: {e}")
            return None

    def update_order(self, order_id: int, update_data: Dict) -> Optional[Dict]:
        """Update an order in WooCommerce"""
        try:
            response = requests.put(
                f"{self.api_url}/orders/{order_id}",
                auth=self._get_auth(),
                json=update_data,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error updating WooCommerce order {order_id}: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:500]}")
            return None
        except Exception as e:
            print(f"❌ Unexpected error updating WooCommerce order: {e}")
            return None

    def delete_order(self, order_id: int, force: bool = True) -> bool:
        """Delete an order from WooCommerce"""
        try:
            response = requests.delete(
                f"{self.api_url}/orders/{order_id}",
                auth=self._get_auth(),
                params={"force": force},
                timeout=30
            )
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            print(f"❌ Error deleting WooCommerce order {order_id}: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response status: {e.response.status_code}")
                print(f"   Response body: {e.response.text[:500]}")
            return False
        except Exception as e:
            print(f"❌ Unexpected error deleting WooCommerce order: {e}")
            return False


woocommerce_client = WooCommerceClient()


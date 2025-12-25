"""
Simple in-memory cache for WooCommerce API responses
"""
from typing import Dict, Optional, Any
from datetime import datetime, timedelta
import threading


class WooCommerceCache:
    """Thread-safe in-memory cache for WooCommerce API responses"""
    
    def __init__(self, ttl_minutes: int = 5):
        self.cache: Dict[str, Dict[str, Any]] = {}
        self.ttl_minutes = ttl_minutes
        self.lock = threading.Lock()
    
    def _get_cache_key(self, endpoint: str, params: Optional[Dict] = None) -> str:
        """Generate cache key from endpoint and params"""
        if params:
            sorted_params = sorted(params.items())
            param_str = "&".join(f"{k}={v}" for k, v in sorted_params)
            return f"{endpoint}?{param_str}"
        return endpoint
    
    def get(self, endpoint: str, params: Optional[Dict] = None) -> Optional[Any]:
        """Get cached value if not expired"""
        with self.lock:
            key = self._get_cache_key(endpoint, params)
            if key in self.cache:
                entry = self.cache[key]
                if datetime.now() < entry['expires_at']:
                    return entry['data']
                else:
                    # Expired, remove it
                    del self.cache[key]
            return None
    
    def set(self, endpoint: str, data: Any, params: Optional[Dict] = None):
        """Set cache value with TTL"""
        with self.lock:
            key = self._get_cache_key(endpoint, params)
            self.cache[key] = {
                'data': data,
                'expires_at': datetime.now() + timedelta(minutes=self.ttl_minutes)
            }
    
    def clear(self):
        """Clear all cache"""
        with self.lock:
            self.cache.clear()
    
    def clear_pattern(self, pattern: str):
        """Clear cache entries matching pattern"""
        with self.lock:
            keys_to_delete = [k for k in self.cache.keys() if pattern in k]
            for key in keys_to_delete:
                del self.cache[key]


# Global cache instance (5 minutes TTL)
woocommerce_cache = WooCommerceCache(ttl_minutes=5)


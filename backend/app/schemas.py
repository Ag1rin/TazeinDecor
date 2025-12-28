"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, EmailStr, field_validator, model_validator
from typing import Optional, List
from datetime import datetime
from app.models import UserRole, OrderStatus, PaymentMethod, DeliveryMethod, ProductStatus


# User Schemas
class UserBase(BaseModel):
    username: str
    full_name: str
    mobile: str
    role: UserRole


class UserCreate(UserBase):
    password: str
    national_id: Optional[str] = None
    store_address: Optional[str] = None
    # Discount fields
    discount_percentage: Optional[float] = None  # e.g., 3.0 for 3%
    discount_category_ids: Optional[List[int]] = None  # List of category IDs, empty list means all categories


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    mobile: Optional[str] = None
    role: Optional[UserRole] = None
    credit: Optional[float] = None
    store_address: Optional[str] = None
    is_active: Optional[bool] = None
    # Discount fields
    discount_percentage: Optional[float] = None  # e.g., 3.0 for 3%
    discount_category_ids: Optional[List[int]] = None  # List of category IDs, empty list means all categories, None means no change


class UserResponse(UserBase):
    id: int
    credit: float
    store_address: Optional[str]
    is_active: bool
    referral_code: Optional[str] = None  # Unique referral code for sellers/store managers
    created_at: datetime
    
    class Config:
        from_attributes = True


# Auth Schemas
class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    """Public registration request - role defaults to SELLER"""
    username: str
    password: str
    full_name: str
    mobile: str
    national_id: Optional[str] = None
    store_address: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# Product Schemas
class ProductBase(BaseModel):
    name: str
    price: float
    sku: Optional[str] = None


class ProductResponse(ProductBase):
    id: int
    woo_id: int
    slug: Optional[str]
    description: Optional[str]
    short_description: Optional[str]
    regular_price: Optional[float]
    sale_price: Optional[float]
    stock_quantity: int
    status: ProductStatus
    package_area: Optional[float]
    design_code: Optional[str]
    album_code: Optional[str]
    roll_count: Optional[int]
    image_url: Optional[str]
    images: Optional[str]
    category_id: Optional[int]
    company_id: Optional[int]
    local_price: Optional[float]
    local_stock: Optional[int]
    brand: Optional[str] = None  # Brand from WooCommerce attributes
    
    class Config:
        from_attributes = True


# Category Schemas
class CategoryResponse(BaseModel):
    id: int
    woo_id: int
    name: str
    slug: Optional[str]
    parent_id: Optional[int]
    description: Optional[str]
    image_url: Optional[str]
    children: List['CategoryResponse'] = []
    
    class Config:
        from_attributes = True


# Order Schemas
class OrderItemCreate(BaseModel):
    product_id: int
    quantity: float
    unit: str = "package"
    price: float
    variation_id: Optional[int] = None
    variation_pattern: Optional[str] = None  # Selected pattern (طرح)


class OrderCreate(BaseModel):
    customer_name: str
    customer_mobile: str
    customer_address: Optional[str] = None
    items: List[OrderItemCreate]
    payment_method: Optional[PaymentMethod] = None
    delivery_method: Optional[DeliveryMethod] = None
    installation_date: Optional[datetime] = None
    installation_notes: Optional[str] = None
    notes: Optional[str] = None
    referral_code: Optional[str] = None  # Optional referral code (کد معرف)


class OrderItemResponse(BaseModel):
    id: int
    product_id: int
    quantity: float
    unit: str
    price: float
    total: float
    variation_id: Optional[int] = None
    variation_pattern: Optional[str] = None  # Selected pattern (طرح)
    product: Optional[ProductResponse] = None
    
    class Config:
        from_attributes = True


class OrderResponse(BaseModel):
    id: int
    order_number: str
    seller_id: int
    customer_id: int
    company_id: Optional[int]
    status: OrderStatus
    payment_method: Optional[PaymentMethod]
    delivery_method: Optional[DeliveryMethod]
    installation_date: Optional[datetime]
    installation_notes: Optional[str]
    total_amount: float  # Retail price (customer price)
    wholesale_amount: Optional[float] = None  # Wholesale/cooperation price (seller payment)
    cooperation_total_amount: Optional[float] = None  # Calculated total from calculator (sum of item.total + tax - discount)
    notes: Optional[str]
    is_new: bool
    created_at: datetime
    items: List[OrderItemResponse] = []
    # Invoice fields
    invoice_number: Optional[str] = None
    issue_date: Optional[datetime] = None
    due_date: Optional[datetime] = None
    subtotal: Optional[float] = None
    tax_amount: float = 0.0
    discount_amount: float = 0.0
    payment_terms: Optional[str] = None
    # Edit approval fields
    edit_requested_by: Optional[int] = None
    edit_requested_at: Optional[datetime] = None
    edit_approved_by: Optional[int] = None
    edit_approved_at: Optional[datetime] = None
    # Referral tracking
    referrer_id: Optional[int] = None
    referrer_name: Optional[str] = None  # Referrer's full name for display
    # Customer details (for admin/operator view)
    customer_name: Optional[str] = None
    customer_mobile: Optional[str] = None
    customer_address: Optional[str] = None
    
    @field_validator('status', mode='before')
    @classmethod
    def convert_status_to_enum(cls, v):
        """Convert string status to OrderStatus enum"""
        if v is None:
            return OrderStatus.PENDING  # Default fallback
        if isinstance(v, OrderStatus):
            return v
        if isinstance(v, str):
            # Try case-insensitive conversion
            v_lower = v.lower().strip()
            try:
                # First try _missing_ for case-insensitive lookup
                result = OrderStatus._missing_(v_lower)
                if result is not None:
                    return result
                # Fallback: try direct lowercase match
                return OrderStatus(v_lower)
            except (ValueError, AttributeError) as e:
                # If conversion fails, log and return default
                print(f"⚠️  Failed to convert status '{v}' to OrderStatus enum: {e}")
                return OrderStatus.PENDING  # Fallback
        # For any other type, try to convert to string first
        try:
            return cls.convert_status_to_enum(str(v))
        except Exception:
            return OrderStatus.PENDING
    
    class Config:
        from_attributes = True
    
    @model_validator(mode='before')
    @classmethod
    def ensure_status_enum(cls, data):
        """Ensure status is converted to enum when loading from attributes"""
        # If it's a SQLAlchemy model object, convert status using status_enum property
        if hasattr(data, 'status_enum') and hasattr(data, '__dict__'):
            # For SQLAlchemy models, Pydantic will use from_attributes=True
            # We need to ensure status is converted before validation
            # The field_validator should handle this, but this is a backup
            if hasattr(data, 'status') and not isinstance(data.status, OrderStatus):
                # Replace the status attribute with the enum version
                original_status = data.status
                try:
                    data.status = data.status_enum
                except Exception:
                    # If status_enum fails, try manual conversion
                    if isinstance(original_status, str):
                        try:
                            data.status = OrderStatus._missing_(original_status.lower()) or OrderStatus(original_status.lower())
                        except (ValueError, AttributeError):
                            data.status = OrderStatus.PENDING
        elif isinstance(data, dict) and 'status' in data:
            # If status is a string in dict, convert it
            if isinstance(data['status'], str):
                try:
                    data['status'] = OrderStatus._missing_(data['status'].lower()) or OrderStatus(data['status'].lower())
                except (ValueError, AttributeError):
                    data['status'] = OrderStatus.PENDING
        return data
    
    class Config:
        from_attributes = True


# Customer Schemas
class CustomerCreate(BaseModel):
    name: str
    mobile: str
    address: Optional[str] = None


class CustomerResponse(BaseModel):
    id: int
    name: str
    mobile: str
    address: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


# Company Schemas
class CompanyCreate(BaseModel):
    name: str
    mobile: Optional[str] = None
    address: Optional[str] = None
    logo: Optional[str] = None
    notes: Optional[str] = None


class CompanyResponse(BaseModel):
    id: int
    name: str
    mobile: Optional[str]
    address: Optional[str]
    logo: Optional[str]
    notes: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


# Chat Schemas
class ChatMessageCreate(BaseModel):
    message: Optional[str] = None
    message_type: str = "text"


class ChatMessageResponse(BaseModel):
    id: int
    user_id: int
    user_name: str
    message: Optional[str]
    image_url: Optional[str]
    voice_url: Optional[str]
    message_type: str
    created_at: datetime
    
    class Config:
        from_attributes = True


# Return Schemas
class ReturnCreate(BaseModel):
    order_id: int
    reason: Optional[str] = None
    items: List[dict]  # List of items to return


class ReturnResponse(BaseModel):
    id: int
    order_id: int
    reason: Optional[str]
    items: str  # JSON string - will be parsed on frontend
    status: str
    is_new: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    order_number: Optional[str] = None  # Include order number for display
    
    class Config:
        from_attributes = True
    
    @classmethod
    def from_orm(cls, obj):
        """Custom from_orm to include order number"""
        data = {
            "id": obj.id,
            "order_id": obj.order_id,
            "reason": obj.reason,
            "items": obj.items,
            "status": obj.status,
            "is_new": obj.is_new,
            "created_at": obj.created_at,
            "updated_at": obj.updated_at,
            "order_number": obj.order.order_number if obj.order else None,
        }
        return cls(**data)


# Installation Schemas
class InstallationCreate(BaseModel):
    order_id: int
    installation_date: datetime
    notes: Optional[str] = None
    color: Optional[str] = None


class InstallationResponse(BaseModel):
    id: int
    order_id: int
    installation_date: datetime
    notes: Optional[str]
    color: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# Invoice Schemas
class InvoiceUpdate(BaseModel):
    """Invoice update schema"""
    invoice_number: Optional[str] = None
    issue_date: Optional[datetime] = None
    due_date: Optional[datetime] = None
    subtotal: Optional[float] = None
    tax_amount: Optional[float] = None
    discount_amount: Optional[float] = None
    payment_terms: Optional[str] = None
    notes: Optional[str] = None


# Discount Schemas
class DiscountCreate(BaseModel):
    user_id: int
    category_id: Optional[int] = None  # None means all categories
    discount_percentage: float  # e.g., 5.0 for 5%
    is_active: bool = True


class DiscountUpdate(BaseModel):
    category_id: Optional[int] = None
    discount_percentage: Optional[float] = None
    is_active: Optional[bool] = None


class DiscountResponse(BaseModel):
    id: int
    user_id: int
    category_id: Optional[int]
    discount_percentage: float
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]
    user: Optional[UserResponse] = None
    category: Optional[CategoryResponse] = None
    
    class Config:
        from_attributes = True


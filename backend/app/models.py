"""
Database models
"""
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text, Enum as SQLEnum, TypeDecorator
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func, cast
from sqlalchemy.dialects.postgresql import ENUM as PGEnum
from datetime import datetime
import enum
from app.database import Base


class CaseInsensitiveEnum(TypeDecorator):
    """Custom type decorator to handle case-insensitive enum conversion from DB"""
    # Use String as base type - we'll handle enum conversion ourselves
    impl = String
    cache_ok = True
    
    def __init__(self, enum_class, name=None, *args, **kwargs):
        self.enum_class = enum_class
        self.enum_name = name or enum_class.__name__.lower()
        # Store enum values for validation
        self.enum_values = [member.value for member in enum_class]
        super().__init__(*args, **kwargs)
    
    def load_dialect_impl(self, dialect):
        """Return String for all dialects - we handle enum conversion ourselves"""
        # Always use String to avoid PGEnum validation issues
        # This ensures we read enum values as strings, not as PGEnum types
        return dialect.type_descriptor(String())
    
    def result_processor(self, dialect, coltype):
        """Process result values - convert to string immediately to avoid PGEnum validation"""
        def process(value):
            if value is None:
                return None
            # CRITICAL: Convert to string immediately, before any PGEnum validation
            # This handles both string values and enum types from PostgreSQL
            # If PGEnum somehow processes it first, this will still convert it
            try:
                # Try to get string representation
                if isinstance(value, str):
                    return value
                # Handle enum-like objects (from PGEnum or database)
                # Get the actual string value, not the enum object
                str_repr = str(value)
                # If it looks like an enum object, try to get its value attribute
                if hasattr(value, 'value') and not isinstance(value, str):
                    return str(value.value) if value.value else str_repr
                return str_repr
            except Exception:
                # Fallback: just convert to string
                return str(value) if value is not None else None
        return process
    
    def process_bind_param(self, value, dialect):
        """When writing to DB, convert to lowercase string"""
        if value is None:
            return None
        
        # Convert enum member to its value (lowercase string)
        if isinstance(value, self.enum_class):
            return value.value
        if isinstance(value, str):
            return value.lower()
        return str(value).lower()
    
    def bind_expression(self, bindvalue):
        """Cast bind value to enum type for PostgreSQL using explicit SQL"""
        # Don't use bind_expression for default values - causes "Literal Python value expected" error
        # Only use it for actual bind parameters in queries
        # For defaults, SQLAlchemy needs literal values, not expressions
        return None  # Let the base String type handle it, we'll cast in process_bind_param
    
    
    def process_result_value(self, value, dialect):
        """When reading from DB, handle both upper and lowercase (prioritize lowercase)"""
        if value is None:
            return None
        
        # Convert to string if not already (handles enum types from DB)
        str_value = str(value) if not isinstance(value, str) else value
        
        # First try to match by value (lowercase - current DB format)
        lower_val = str_value.lower()
        for member in self.enum_class:
            if member.value == lower_val:
                return member
        
        # Fallback: try to match by name (uppercase - legacy format like 'PENDING')
        upper_val = str_value.upper()
        for member in self.enum_class:
            if member.name == upper_val:
                return member
        
        # If no match, try case-insensitive value match
        for member in self.enum_class:
            if member.value.lower() == lower_val:
                return member
        
        # Last resort: use OrderStatus._missing_ if available
        if hasattr(self.enum_class, '_missing_'):
            result = self.enum_class._missing_(str_value)
            if result is not None:
                return result
        
        # Default fallback - return first enum member or None
        return None


class UserRole(str, enum.Enum):
    """User roles"""
    ADMIN = "admin"
    OPERATOR = "operator"
    STORE_MANAGER = "store_manager"
    SELLER = "seller"


class OrderStatus(str, enum.Enum):
    """Order status - values must match PostgreSQL enum exactly (lowercase)"""
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    DELIVERED = "delivered"
    RETURNED = "returned"
    CANCELLED = "cancelled"
    # Invoice statuses
    PENDING_COMPLETION = "pending_completion"
    IN_PROGRESS = "in_progress"
    SETTLED = "settled"
    
    @classmethod
    def _missing_(cls, value):
        """Handle case-insensitive lookup for enum values"""
        if isinstance(value, str):
            # Try lowercase match
            lower_value = value.lower()
            for member in cls:
                if member.value == lower_value:
                    return member
                # Also try matching the enum name (for UPPERCASE values from DB)
                if member.name == value.upper():
                    return member
        return None
    
    @classmethod
    def from_db_value(cls, value):
        """Convert database value (might be uppercase) to enum"""
        if value is None:
            return None
        if isinstance(value, cls):
            return value
        # Handle uppercase values from database
        lookup = value.lower() if isinstance(value, str) else value
        for member in cls:
            if member.value == lookup:
                return member
        return cls.PENDING  # Default fallback


class PaymentMethod(str, enum.Enum):
    """Payment methods"""
    ONLINE = "online"
    CREDIT = "credit"
    INVOICE = "invoice"


class DeliveryMethod(str, enum.Enum):
    """Delivery methods"""
    IN_PERSON = "in_person"
    TO_CUSTOMER = "to_customer"
    TO_STORE = "to_store"


class ProductStatus(str, enum.Enum):
    """Product availability status"""
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"
    LIMITED = "limited"


class User(Base):
    """User model"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    national_id = Column(String, unique=True, nullable=True)
    mobile = Column(String, nullable=False)
    role = Column(SQLEnum(UserRole), nullable=False, default=UserRole.SELLER)
    credit = Column(Float, default=0.0)
    store_address = Column(Text, nullable=True)
    business_card_image = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)  # Store manager who created this seller
    referral_code = Column(String(10), unique=True, nullable=True, index=True)  # Unique referral code for sellers/store managers
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    orders = relationship("Order", back_populates="seller", primaryjoin="User.id == Order.seller_id")
    messages = relationship("ChatMessage", back_populates="user")
    discounts = relationship("Discount", foreign_keys=lambda: [Discount.user_id], back_populates="user")
    referred_orders = relationship("Order", back_populates="referrer", foreign_keys="Order.referrer_id")


class Company(Base):
    """Supplier company model"""
    __tablename__ = "companies"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    mobile = Column(String, nullable=True)
    address = Column(Text, nullable=True)
    logo = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    products = relationship("Product", back_populates="company")
    orders = relationship("Order", back_populates="company")


class Category(Base):
    """Product category model (synced from WooCommerce)"""
    __tablename__ = "categories"
    
    id = Column(Integer, primary_key=True, index=True)
    woo_id = Column(Integer, unique=True, nullable=False)
    name = Column(String, nullable=False)
    slug = Column(String, nullable=True)
    parent_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    description = Column(Text, nullable=True)
    image_url = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    products = relationship("Product", back_populates="category")
    children = relationship("Category", back_populates="parent", remote_side=[id])
    parent = relationship("Category", back_populates="children")
    discounts = relationship("Discount", back_populates="category")


class Product(Base):
    """Product model (synced from WooCommerce)"""
    __tablename__ = "products"
    
    id = Column(Integer, primary_key=True, index=True)
    woo_id = Column(Integer, unique=True, nullable=False)
    name = Column(String, nullable=False)
    slug = Column(String, nullable=True)
    sku = Column(String, nullable=True)
    description = Column(Text, nullable=True)
    short_description = Column(Text, nullable=True)
    price = Column(Float, nullable=False, default=0.0)
    regular_price = Column(Float, nullable=True)
    sale_price = Column(Float, nullable=True)
    stock_quantity = Column(Integer, default=0)
    status = Column(SQLEnum(ProductStatus), default=ProductStatus.AVAILABLE)
    package_area = Column(Float, nullable=True)  # m² per package
    design_code = Column(String, nullable=True)
    album_code = Column(String, nullable=True)
    roll_count = Column(Integer, nullable=True)
    image_url = Column(String, nullable=True)
    images = Column(Text, nullable=True)  # JSON array of image URLs
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    company_id = Column(Integer, ForeignKey("companies.id"), nullable=True)
    local_price = Column(Float, nullable=True)  # Local price override
    local_stock = Column(Integer, nullable=True)  # Local stock override
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    category = relationship("Category", back_populates="products")
    company = relationship("Company", back_populates="products")
    # order_items relationship removed as products are no longer locally synced


class Customer(Base):
    """Customer model"""
    __tablename__ = "customers"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    mobile = Column(String, nullable=False, index=True)
    address = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    orders = relationship("Order", back_populates="customer")


class Order(Base):
    """Order model"""
    __tablename__ = "orders"
    
    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String, unique=True, nullable=False, index=True)
    seller_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)
    company_id = Column(Integer, ForeignKey("companies.id"), nullable=True)
    # Use String(50) to avoid enum validation issues and simplify default handling
    # The enum conversion is handled in process_result_value when reading from DB
    status = Column(
        String(50),
        default='pending',  # Use string literal for default to avoid TypeDecorator issues
        nullable=False
    )
    payment_method = Column(SQLEnum(PaymentMethod), nullable=True)
    delivery_method = Column(SQLEnum(DeliveryMethod), nullable=True)
    installation_date = Column(DateTime(timezone=True), nullable=True)
    installation_notes = Column(Text, nullable=True)
    total_amount = Column(Float, nullable=False, default=0.0)  # Retail price (customer price)
    wholesale_amount = Column(Float, nullable=True)  # Wholesale/cooperation price (seller payment)
    notes = Column(Text, nullable=True)
    is_new = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Invoice fields
    invoice_number = Column(String, nullable=True, index=True)
    issue_date = Column(DateTime(timezone=True), nullable=True)
    due_date = Column(DateTime(timezone=True), nullable=True)
    subtotal = Column(Float, nullable=True)
    tax_amount = Column(Float, default=0.0)
    discount_amount = Column(Float, default=0.0)
    payment_terms = Column(Text, nullable=True)
    
    # Edit approval fields
    edit_requested_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    edit_requested_at = Column(DateTime(timezone=True), nullable=True)
    edit_approved_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    edit_approved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Referral tracking
    referrer_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # User who referred this order
    
    # Relationships
    seller = relationship("User", back_populates="orders", foreign_keys=[seller_id])
    customer = relationship("Customer", back_populates="orders")
    company = relationship("Company", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    edit_requester = relationship("User", foreign_keys=[edit_requested_by])
    edit_approver = relationship("User", foreign_keys=[edit_approved_by])
    referrer = relationship("User", back_populates="referred_orders", foreign_keys=[referrer_id])
    
    @property
    def status_enum(self) -> OrderStatus:
        """Convert string status to OrderStatus enum"""
        if isinstance(self.status, OrderStatus):
            return self.status
        if isinstance(self.status, str):
            # Try to convert string to enum (case-insensitive)
            try:
                return OrderStatus._missing_(self.status) or OrderStatus(self.status.lower())
            except (ValueError, AttributeError):
                # Fallback to PENDING if conversion fails
                return OrderStatus.PENDING
        return OrderStatus.PENDING
    
    def set_status(self, status: OrderStatus | str):
        """Set status, accepting either enum or string"""
        if isinstance(status, OrderStatus):
            self.status = status.value
        else:
            self.status = str(status).lower()


class OrderItem(Base):
    """Order item model"""
    __tablename__ = "order_items"
    
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    product_id = Column(Integer, nullable=False)  # WooCommerce product ID (no ForeignKey to products table)
    quantity = Column(Float, nullable=False)  # Can be packages or m²
    unit = Column(String, nullable=False, default="package")  # "package" or "m2"
    price = Column(Float, nullable=False)
    total = Column(Float, nullable=False)
    variation_id = Column(Integer, nullable=True)  # WooCommerce variation ID
    variation_pattern = Column(String, nullable=True)  # Selected pattern (طرح)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    order = relationship("Order", back_populates="items")
    # Note: product relationship removed - we use WooCommerce IDs directly, no local Product table needed


class ChatMessage(Base):
    """Chat message model"""
    __tablename__ = "chat_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    message = Column(Text, nullable=True)
    image_url = Column(String, nullable=True)
    voice_url = Column(String, nullable=True)
    message_type = Column(String, default="text")  # text, image, voice
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="messages")


class Discount(Base):
    """Discount model for user-category discounts"""
    __tablename__ = "discounts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True)  # None means all categories
    discount_percentage = Column(Float, nullable=False)  # e.g., 5.0 for 5%
    is_active = Column(Boolean, default=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)  # Admin who created this
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", foreign_keys=[user_id], back_populates="discounts")
    category = relationship("Category", back_populates="discounts")
    creator = relationship("User", foreign_keys=[created_by])


class Return(Base):
    """Return request model"""
    __tablename__ = "returns"
    
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    reason = Column(Text, nullable=True)
    items = Column(Text, nullable=True)  # JSON array of returned items
    status = Column(String, default="pending")  # pending, approved, rejected
    is_new = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    order = relationship("Order")


class Installation(Base):
    """Installation calendar model"""
    __tablename__ = "installations"
    
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    installation_date = Column(DateTime(timezone=True), nullable=False)
    notes = Column(Text, nullable=True)
    color = Column(String, nullable=True)  # For calendar coloring
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    order = relationship("Order")

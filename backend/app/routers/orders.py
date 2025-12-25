"""
Order management routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime
from app.database import get_db
from app.models import Order, OrderItem, Customer, User, UserRole, OrderStatus, PaymentMethod, Discount
from app.schemas import OrderCreate, OrderResponse, OrderItemResponse, InvoiceUpdate
from app.dependencies import get_current_user, require_role
from app.woocommerce_client import woocommerce_client
import uuid
import asyncio

router = APIRouter(prefix="/api/orders", tags=["orders"])


def _get_manager_seller_ids(db: Session, manager_id: int) -> List[int]:
    """Get list of seller IDs created by a store manager"""
    sellers = db.query(User.id).filter(
        User.role == UserRole.SELLER,
        User.created_by == manager_id
    ).all()
    return [seller_id[0] for seller_id in sellers]


def _get_user_discount_for_category(db: Session, user_id: int, category_id: Optional[int]) -> Optional[Discount]:
    """Get applicable discount for a user and category.
    Returns discount for specific category if exists, otherwise general discount (category_id=None).
    """
    # First try to get discount for specific category
    if category_id:
        discount = db.query(Discount).filter(
            Discount.user_id == user_id,
            Discount.category_id == category_id,
            Discount.is_active == True
        ).first()
        if discount:
            return discount
    
    # If no category-specific discount, get general discount (category_id=None)
    discount = db.query(Discount).filter(
        Discount.user_id == user_id,
        Discount.category_id == None,  # General discount for all categories
        Discount.is_active == True
    ).first()
    
    return discount


def _enrich_order_with_customer(order: Order) -> dict:
    """Helper function to enrich order dict with customer details"""
    order_dict = order.__dict__.copy()
    
    # Remove SQLAlchemy internal attributes
    order_dict.pop('_sa_instance_state', None)
    
    # Explicitly include items relationship (SQLAlchemy relationships aren't in __dict__)
    if hasattr(order, 'items') and order.items:
        order_dict['items'] = order.items
    
    # Include customer details
    if order.customer:
        order_dict['customer_name'] = order.customer.name
        order_dict['customer_mobile'] = order.customer.mobile
        order_dict['customer_address'] = order.customer.address
    
    return order_dict


@router.post("", response_model=OrderResponse)
async def create_order(
    order_data: OrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create new order (Seller or Store Manager)"""
    print(f"🔍 Creating order - User ID: {current_user.id}, Role: {current_user.role}")
    print(f"🔍 Allowed roles: {[UserRole.SELLER, UserRole.STORE_MANAGER]}")
    
    if current_user.role not in [UserRole.SELLER, UserRole.STORE_MANAGER]:
        print(f"❌ Access denied - User role {current_user.role} not in allowed roles")
        raise HTTPException(status_code=403, detail="Only sellers and store managers can create orders")
    
    print(f"✅ Access granted for user {current_user.id} with role {current_user.role}")
    
    # Find or create customer
    customer = db.query(Customer).filter(Customer.mobile == order_data.customer_mobile).first()
    if not customer:
        customer = Customer(
            name=order_data.customer_name,
            mobile=order_data.customer_mobile,
            address=order_data.customer_address
        )
        db.add(customer)
        db.flush()
    
    # Calculate totals - use wholesale price from frontend (colleague_price) for seller payment
    # and retail price from WooCommerce for customer reference
    total = 0.0  # Retail total (for WooCommerce)
    wholesale_total = 0.0  # Wholesale total (actual seller payment)
    woo_line_items = []
    
    for item_data in order_data.items:
        # item_data.product_id is WooCommerce product ID (from frontend)
        woo_product_id = item_data.product_id
        
        # Fetch product directly from WooCommerce
        print(f"🔄 Fetching product {woo_product_id} from WooCommerce...")
        woo_product = woocommerce_client.get_product(woo_product_id)
        
        if not woo_product:
            raise HTTPException(
                status_code=404,
                detail=f"Product {woo_product_id} not found in WooCommerce"
            )
        
        # Get retail price from WooCommerce product (for WooCommerce order)
        retail_price = float(woo_product.get('price', 0))
        
        # Get wholesale price from frontend (item_data.price is colleague_price)
        # This is the actual price the seller pays
        wholesale_price = float(item_data.price) if item_data.price else retail_price
        
        # Apply user discount if applicable
        # Get product categories from WooCommerce
        product_categories = woo_product.get('categories', [])
        category_ids = [cat.get('id') for cat in product_categories] if product_categories else []
        
        # Get applicable discount (check each category, then general discount)
        applicable_discount = None
        if category_ids:
            for cat_id in category_ids:
                discount = _get_user_discount_for_category(db, current_user.id, cat_id)
                if discount:
                    applicable_discount = discount
                    break
        
        # If no category-specific discount found, check for general discount
        if not applicable_discount:
            applicable_discount = _get_user_discount_for_category(db, current_user.id, None)
        
        # Apply discount to wholesale price (seller payment)
        if applicable_discount and applicable_discount.discount_percentage > 0:
            discount_amount = wholesale_price * (applicable_discount.discount_percentage / 100.0)
            wholesale_price = wholesale_price - discount_amount
            print(f"✅ Applied {applicable_discount.discount_percentage}% discount to product {woo_product_id}. Original: {float(item_data.price) if item_data.price else retail_price}, Discounted: {wholesale_price}")
        
        # If variation_id is provided, get variation price
        if item_data.variation_id:
            try:
                # Convert variation_id to integer for comparison
                try:
                    variation_id_int = int(item_data.variation_id)
                except (ValueError, TypeError):
                    variation_id_int = None
                
                if variation_id_int:
                    variations = woocommerce_client.get_product_variations(woo_product_id)
                    variation = next((v for v in variations if v.get('id') == variation_id_int), None)
                    if variation and variation.get('price'):
                        retail_price = float(variation.get('price', retail_price))
                        # Keep wholesale_price from frontend (it's already the correct colleague_price)
            except Exception as e:
                print(f"⚠️  Could not fetch variation price: {e}")
        
        # Calculate totals
        retail_item_total = item_data.quantity * retail_price  # For WooCommerce
        wholesale_item_total = item_data.quantity * wholesale_price  # Actual seller payment
        total += retail_item_total
        wholesale_total += wholesale_item_total
        
        # Prepare line item for WooCommerce
        line_meta = []
        if item_data.variation_pattern:
            line_meta.append({"key": "pattern", "value": item_data.variation_pattern})

        # Convert variation_id to integer if provided
        variation_id = None
        if item_data.variation_id:
            try:
                variation_id = int(item_data.variation_id)
            except (ValueError, TypeError):
                print(f"⚠️  Invalid variation_id: {item_data.variation_id}, skipping variation")
                variation_id = None
        
        woo_line_item = {
            "product_id": woo_product_id,
            "quantity": max(1, int(round(item_data.quantity))),
            "subtotal": str(retail_item_total),
            "total": str(retail_item_total),
            "meta_data": line_meta
        }
        
        # Only add variation_id if it's a valid integer
        if variation_id:
            woo_line_item["variation_id"] = variation_id
        
        woo_line_items.append(woo_line_item)

    # Create order directly in WooCommerce FIRST
    billing_email = f"{order_data.customer_mobile}@example.local"
    billing_info = {
        "first_name": order_data.customer_name or "Customer",
        "last_name": "",
        "phone": order_data.customer_mobile,
        "email": billing_email,
        "address_1": order_data.customer_address or "",
        "country": "IR"
    }

    woo_status = "pending"
    if order_data.payment_method == PaymentMethod.ONLINE:
        woo_status = "processing"

    woo_payload = {
        "status": woo_status,
        "payment_method": (order_data.payment_method.value if order_data.payment_method else "bacs"),
        "payment_method_title": "App Order",
        "billing": billing_info,
        "shipping": billing_info,
        "line_items": woo_line_items,
        "customer_note": order_data.notes or "",
    }

    # Create order in WooCommerce directly
    print("🔄 Creating order in WooCommerce...")
    woo_order = await asyncio.to_thread(woocommerce_client.create_order, woo_payload)
    
    if not woo_order:
        raise HTTPException(
            status_code=500,
            detail="Failed to create order in WooCommerce"
        )
    
    print(f"✅ Order created in WooCommerce: {woo_order.get('id')}")
    
    # Now save to local DB for tracking (using WooCommerce order ID)
    woo_order_id = woo_order.get('id')
    order_number = f"ORD-{datetime.now().strftime('%Y%m%d')}-{woo_order_id}"
    
    # Handle credit payment - check balance and deduct if using credit
    # Use wholesale_total (actual seller payment) for credit deduction
    if order_data.payment_method == PaymentMethod.CREDIT:
        # Refresh user to get latest credit balance
        db.refresh(current_user)
        
        if current_user.credit is None or current_user.credit < wholesale_total:
            raise HTTPException(
                status_code=400,
                detail=f"اعتبار کافی نیست. موجودی اعتبار: {current_user.credit or 0:.0f} تومان، مبلغ سفارش: {wholesale_total:.0f} تومان"
            )
        
        # Deduct credit using wholesale price (actual seller payment)
        current_user.credit -= wholesale_total
        print(f"✅ Deducted {wholesale_total:.0f} (wholesale) from seller {current_user.id} credit. Remaining: {current_user.credit:.0f}")
    
    # Look up referrer by referral code if provided
    referrer_id = None
    if order_data.referral_code:
        referrer = db.query(User).filter(
            User.referral_code == order_data.referral_code.upper(),
            User.is_active == True,
            User.role.in_([UserRole.SELLER, UserRole.STORE_MANAGER])
        ).first()
        if referrer:
            referrer_id = referrer.id
            print(f"✅ Order referred by: {referrer.full_name} (ID: {referrer.id})")
        else:
            print(f"⚠️ Invalid referral code: {order_data.referral_code}")
    
    # Create order in local DB for tracking
    order = Order(
        order_number=order_number,
        seller_id=current_user.id,
        customer_id=customer.id,
        payment_method=order_data.payment_method,
        delivery_method=order_data.delivery_method,
        installation_date=order_data.installation_date,
        installation_notes=order_data.installation_notes,
        notes=order_data.notes,
        status='pending',  # Use string value for String(50) column
        is_new=True,
        total_amount=total,  # Retail price (customer price)
        wholesale_amount=wholesale_total,  # Wholesale price (seller payment)
        referrer_id=referrer_id
    )
    
    db.add(order)
    db.flush()
    
    # Auto-create installation entry if installation_date is provided
    if order_data.installation_date:
        from app.models import Installation
        installation = Installation(
            order_id=order.id,
            installation_date=order_data.installation_date,
            notes=order_data.installation_notes,
            color=None  # Default color, can be customized later
        )
        db.add(installation)
        print(f"✅ Auto-created installation entry for order {order.id}")
    
    # Create order items in local DB (for tracking, using WooCommerce IDs)
    # Store wholesale prices in order items (actual seller payment)
    for i, item_data in enumerate(order_data.items):
        woo_item = woo_line_items[i]
        # Calculate unit price safely
        item_quantity = woo_item['quantity']
        retail_item_total = float(woo_item['total'])  # Retail price for WooCommerce
        wholesale_item_total = item_data.quantity * float(item_data.price)  # Wholesale price (seller payment)
        
        # Use wholesale price for order item (what seller actually pays)
        unit_price = float(item_data.price) if item_data.price else (retail_item_total / item_quantity if item_quantity > 0 else retail_item_total)
        item_total = wholesale_item_total
        
        order_item = OrderItem(
            order_id=order.id,
            product_id=woo_item['product_id'],  # Store WooCommerce ID directly
            quantity=item_data.quantity,
            unit=item_data.unit,
            price=unit_price,  # Wholesale unit price
            total=item_total,  # Wholesale total
            variation_id=item_data.variation_id,
            variation_pattern=item_data.variation_pattern
        )
        db.add(order_item)
    
    try:
        db.commit()
        db.refresh(order)
    except Exception as db_error:
        print(f"❌ Database error after WooCommerce order creation: {db_error}")
        import traceback
        traceback.print_exc()
        
        # Rollback and try to create order items without variation fields if they don't exist
        db.rollback()
        try:
            # Try again without variation fields (in case columns don't exist)
            for i, item_data in enumerate(order_data.items):
                woo_item = woo_line_items[i]
                item_quantity = woo_item['quantity']
                retail_item_total = float(woo_item['total'])  # Retail price
                wholesale_item_total = item_data.quantity * float(item_data.price) if item_data.price else retail_item_total
                
                # Use wholesale price (what seller actually pays)
                unit_price = float(item_data.price) if item_data.price else (retail_item_total / item_quantity if item_quantity > 0 else retail_item_total)
                item_total = wholesale_item_total
                
                # Try to create order item, catching any column errors
                try:
                    order_item = OrderItem(
                        order_id=order.id,
                        product_id=woo_item['product_id'],
                        quantity=item_data.quantity,
                        unit=item_data.unit,
                        price=unit_price,  # Wholesale unit price
                        total=item_total,  # Wholesale total
                        variation_id=item_data.variation_id,
                        variation_pattern=item_data.variation_pattern
                    )
                    db.add(order_item)
                except Exception as item_error:
                    # If variation columns don't exist, create without them
                    if "variation" in str(item_error).lower():
                        print(f"⚠️  Variation columns may not exist, trying without them...")
                        # Re-create order item without variation fields
                        order_item = OrderItem(
                            order_id=order.id,
                            product_id=woo_item['product_id'],
                            quantity=item_data.quantity,
                            unit=item_data.unit,
                            price=unit_price,
                            total=item_total
                        )
                        db.add(order_item)
                    else:
                        raise
            
            db.commit()
            db.refresh(order)
        except Exception as retry_error:
            print(f"❌ Retry also failed: {retry_error}")
            # Order is created in WooCommerce, so return success anyway
            # Just return the order object we have
            pass
    
    # Include customer details in response
    order_dict = _enrich_order_with_customer(order)
    return OrderResponse.model_validate(order_dict)


@router.get("", response_model=List[OrderResponse])
async def get_orders(
    status: Optional[str] = Query(None, description="Filter by order status (case-insensitive)"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get orders based on role"""
    query = db.query(Order)
    
    # Filter by role
    if current_user.role == UserRole.SELLER:
        query = query.filter(Order.seller_id == current_user.id)
    elif current_user.role == UserRole.STORE_MANAGER:
        # Store Manager sees only orders from sellers they created
        seller_ids = _get_manager_seller_ids(db, current_user.id)
        if seller_ids:
            query = query.filter(Order.seller_id.in_(seller_ids))
        else:
            # If manager has no sellers, return empty result
            query = query.filter(Order.id == -1)  # Impossible condition
    
    if status:
        # Convert string status to lowercase for comparison (status column is String(50))
        try:
            # Normalize to lowercase string for comparison
            status_lower = str(status).lower()
            query = query.filter(Order.status == status_lower)
        except Exception as e:
            # Invalid status value, log and skip filter
            print(f"⚠️  Invalid status value: {status}, error: {e}, skipping filter")
    
    # Eager load customer and items relationships to avoid N+1 queries
    from sqlalchemy.orm import selectinload
    query = query.options(
        joinedload(Order.customer),
        selectinload(Order.items)  # Eager load order items
    )
    
    # Pagination
    offset = (page - 1) * per_page
    orders = query.order_by(Order.created_at.desc()).offset(offset).limit(per_page).all()
    
    # Create responses using Pydantic's from_attributes (handles relationships properly)
    responses = []
    for o in orders:
        response = OrderResponse.model_validate(o, from_attributes=True)
        # Enrich with customer details
        if o.customer:
            response.customer_name = o.customer.name
            response.customer_mobile = o.customer.mobile
            response.customer_address = o.customer.address
        responses.append(response)
    
    return responses


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get single order"""
    # Eager load customer and items relationships
    from sqlalchemy.orm import selectinload
    order = db.query(Order).options(
        joinedload(Order.customer),
        selectinload(Order.items)  # Eager load order items
    ).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Check permissions
    if current_user.role == UserRole.SELLER and order.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    elif current_user.role == UserRole.STORE_MANAGER:
        # Store Manager can only access orders from their sellers
        seller_ids = _get_manager_seller_ids(db, current_user.id)
        if not seller_ids or order.seller_id not in seller_ids:
            raise HTTPException(status_code=403, detail="Access denied")
    
    # Debug: Check if items are loaded
    items_count = len(order.items) if order.items else 0
    print(f"🔍 Order {order_id} - items count: {items_count}")
    if items_count > 0:
        print(f"   - First item: product_id={order.items[0].product_id}, quantity={order.items[0].quantity}")
    
    # Create response using Pydantic's from_attributes (handles relationships)
    response = OrderResponse.model_validate(order, from_attributes=True)
    
    # Enrich with customer details
    if order.customer:
        response.customer_name = order.customer.name
        response.customer_mobile = order.customer.mobile
        response.customer_address = order.customer.address
    
    # Debug: Verify items are in response
    print(f"🔍 OrderResponse - items count: {len(response.items) if response.items else 0}")
    
    return response


@router.put("/{order_id}/confirm")
async def confirm_order(
    order_id: int,
    company_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Confirm order and assign to company (Operator only)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    order.status = 'confirmed'  # Use string value for String(50) column
    order.is_new = False
    if company_id:
        order.company_id = company_id
    
    db.commit()
    
    return {"message": "Order confirmed", "order_id": order_id}


@router.put("/{order_id}/status")
async def update_order_status(
    order_id: int,
    status: OrderStatus,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Update order status (Operator only)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    order.status = status.value if isinstance(status, OrderStatus) else str(status).lower()
    if status != OrderStatus.PENDING:
        order.is_new = False
    
    db.commit()
    
    return {"message": "Status updated", "order_id": order_id, "status": status}


@router.put("/{order_id}/mark-read")
async def mark_order_read(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark order as read (remove flashing)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    order.is_new = False
    db.commit()
    
    return {"message": "Order marked as read"}


@router.put("/{order_id}/return")
async def return_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Return order (Seller or Operator)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Check permissions - Seller can return their own orders, Operator can return any
    if current_user.role == UserRole.SELLER and order.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Only allow return if order is not already returned or cancelled
    if order.status_enum == OrderStatus.RETURNED:
        raise HTTPException(status_code=400, detail="Order already returned")
    if order.status_enum == OrderStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Cannot return cancelled order")
    
    order.status = 'returned'  # Use string value for String(50) column
    order.is_new = False
    db.commit()
    
    return {"message": "Order returned", "order_id": order_id}


# Invoice endpoints
@router.put("/{order_id}/invoice-status")
async def update_invoice_status(
    order_id: int,
    status: str = Query(..., description="Invoice status: pending_completion, in_progress, or settled"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR, UserRole.ADMIN))
):
    """Update invoice status (Clerk/Operator only)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Normalize status to lowercase
    status = status.lower().strip()
    
    # Validate status and map to enum
    status_map = {
        "pending_completion": OrderStatus.PENDING_COMPLETION,
        "in_progress": OrderStatus.IN_PROGRESS,
        "settled": OrderStatus.SETTLED
    }
    
    if status not in status_map:
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {', '.join(status_map.keys())}")
    
    # Get the enum member
    status_enum = status_map[status]
    
    try:
        # Use SQLAlchemy ORM update - this properly handles PostgreSQL enum types
        # Directly assign the enum value - SQLAlchemy will handle the conversion
        order.status = status_enum
        order.is_new = False
        # updated_at will be set automatically by onupdate=func.now()
        
        # Flush to ensure changes are tracked
        db.flush()
        db.commit()
        db.refresh(order)
        print(f"✅ Invoice status updated: {status_enum.value} for order {order_id}")
    except Exception as e:
        db.rollback()
        error_str = str(e)
        print(f"❌ Error updating invoice status: {error_str}")
        import traceback
        traceback.print_exc()
        
        # Provide more helpful error message
        error_detail = str(e)
        if "syntax error" in error_detail.lower() or "enum" in error_detail.lower():
            # If there's still an error, try using raw SQL with proper parameter binding
            # Use bindparam to properly handle the enum casting
            try:
                from sqlalchemy import text, bindparam
                # Use bindparam with explicit type casting - this works with psycopg2
                # Cast the string value to the enum type using PostgreSQL syntax
                status_value = status_enum.value  # Get the string value
                db.execute(
                    text("UPDATE orders SET status = CAST(:status_val AS orderstatus), is_new = false, updated_at = NOW() WHERE id = :order_id_val"),
                    {"status_val": status_value, "order_id_val": order_id}
                )
                db.commit()
                print(f"✅ Invoice status updated (fallback method): {status_value} for order {order_id}")
                return {"message": "Invoice status updated", "order_id": order_id, "status": status}
            except Exception as e2:
                error_str2 = str(e2)
                print(f"❌ Fallback method also failed: {error_str2}")
                traceback.print_exc()
                error_detail = f"Database error: {error_str2}"
        
        raise HTTPException(
            status_code=500, 
            detail=f"Error updating invoice status: {error_detail}"
        )
    
    return {"message": "Invoice status updated", "order_id": order_id, "status": status}


@router.put("/{order_id}/invoice", response_model=OrderResponse)
async def update_invoice(
    order_id: int,
    invoice_data: InvoiceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update invoice details
    
    - Clerk (Operator/Admin): Direct edit, saves immediately
    - Seller/Manager: Request edit, requires Clerk approval
    """
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Check permissions
    is_clerk = current_user.role in [UserRole.OPERATOR, UserRole.ADMIN]
    is_seller_or_manager = current_user.role in [UserRole.SELLER, UserRole.STORE_MANAGER]
    
    if not (is_clerk or is_seller_or_manager):
        raise HTTPException(status_code=403, detail="Access denied")
    
    if is_seller_or_manager:
        # Seller/Manager can only edit their own orders
        if current_user.role == UserRole.SELLER and order.seller_id != current_user.id:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Request edit (requires approval)
        order.edit_requested_by = current_user.id
        order.edit_requested_at = datetime.now()
        order.edit_approved_by = None
        order.edit_approved_at = None
    else:
        # Clerk can edit directly
        order.edit_approved_by = current_user.id
        order.edit_approved_at = datetime.now()
    
    # Update invoice fields
    if invoice_data.invoice_number is not None:
        order.invoice_number = invoice_data.invoice_number
    if invoice_data.issue_date is not None:
        order.issue_date = invoice_data.issue_date
    if invoice_data.due_date is not None:
        order.due_date = invoice_data.due_date
    if invoice_data.subtotal is not None:
        order.subtotal = invoice_data.subtotal
    if invoice_data.tax_amount is not None:
        order.tax_amount = invoice_data.tax_amount
    if invoice_data.discount_amount is not None:
        order.discount_amount = invoice_data.discount_amount
    if invoice_data.payment_terms is not None:
        order.payment_terms = invoice_data.payment_terms
    if invoice_data.notes is not None:
        order.notes = invoice_data.notes
    
    # If Clerk is editing, approve immediately
    if is_clerk:
        order.edit_approved_by = current_user.id
        order.edit_approved_at = datetime.now()
    
    db.commit()
    db.refresh(order)
    
    # Include customer details in response
    order_dict = _enrich_order_with_customer(order)
    return OrderResponse.model_validate(order_dict)


@router.put("/{order_id}/approve-edit", response_model=OrderResponse)
async def approve_invoice_edit(
    order_id: int,
    invoice_data: InvoiceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR, UserRole.ADMIN))
):
    """Approve invoice edit request (Clerk/Operator only)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    if not order.edit_requested_by:
        raise HTTPException(status_code=400, detail="No edit request pending")
    
    # Update invoice fields
    if invoice_data.invoice_number is not None:
        order.invoice_number = invoice_data.invoice_number
    if invoice_data.issue_date is not None:
        order.issue_date = invoice_data.issue_date
    if invoice_data.due_date is not None:
        order.due_date = invoice_data.due_date
    if invoice_data.subtotal is not None:
        order.subtotal = invoice_data.subtotal
    if invoice_data.tax_amount is not None:
        order.tax_amount = invoice_data.tax_amount
    if invoice_data.discount_amount is not None:
        order.discount_amount = invoice_data.discount_amount
    if invoice_data.payment_terms is not None:
        order.payment_terms = invoice_data.payment_terms
    if invoice_data.notes is not None:
        order.notes = invoice_data.notes
    
    # Approve the edit
    order.edit_approved_by = current_user.id
    order.edit_approved_at = datetime.now()
    
    db.commit()
    db.refresh(order)
    
    # Include customer details in response
    order_dict = _enrich_order_with_customer(order)
    return OrderResponse.model_validate(order_dict)


@router.get("/search", response_model=List[OrderResponse])
async def search_invoices(
    q: Optional[str] = Query(None, description="Search query (invoice number, customer name, etc.)"),
    status: Optional[str] = Query(None, description="Filter by status"),
    start_date: Optional[str] = Query(None, description="Start date (ISO format, accepts various formats)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format, accepts various formats)"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Search invoices by number, date, customer, or status"""
    try:
        query = db.query(Order)
        
        # Filter by role
        if current_user.role == UserRole.SELLER:
            query = query.filter(Order.seller_id == current_user.id)
        elif current_user.role == UserRole.STORE_MANAGER:
            # Store Manager sees only orders from sellers they created
            seller_ids = _get_manager_seller_ids(db, current_user.id)
            if seller_ids:
                query = query.filter(Order.seller_id.in_(seller_ids))
            else:
                # If manager has no sellers, return empty result
                query = query.filter(Order.id == -1)  # Impossible condition
        
        # Search by query string
        if q:
            query = query.filter(
                (Order.order_number.ilike(f"%{q}%")) |
                (Order.invoice_number.ilike(f"%{q}%")) |
                (Order.notes.ilike(f"%{q}%"))
            )
        
        # Filter by status
        if status:
            # Convert to lowercase string for comparison (status column is String(50))
            status_lower = str(status).lower()
            query = query.filter(Order.status == status_lower)
        
        # Eager load customer relationship to avoid N+1 queries
        query = query.options(joinedload(Order.customer))
        
        # Filter by date range
        # FIXED: Flexible datetime parsing for search to prevent 422 errors
        # Handles ISO strings with milliseconds, timezones, and various formats
        if start_date:
            start = None
            try:
                # Handle dates with microseconds but no timezone (e.g., 2025-12-23T00:00:00.000)
                date_str = start_date.strip()
                
                # If it has microseconds but no timezone, strip microseconds first
                if '.' in date_str and '+' not in date_str and 'Z' not in date_str:
                    # Split by '.' and take first part (date + time without microseconds)
                    date_str = date_str.split('.')[0]
                
                # Replace Z with +00:00 for timezone
                if 'Z' in date_str:
                    date_str = date_str.replace('Z', '+00:00')
                
                # Try parsing with fromisoformat
                try:
                    start = datetime.fromisoformat(date_str)
                except ValueError:
                    # Fallback: Try with strptime
                    from datetime import timezone
                    # Try common formats
                    for fmt in ['%Y-%m-%dT%H:%M:%S', '%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%d %H:%M:%S', '%Y-%m-%d']:
                        try:
                            start = datetime.strptime(date_str.split('+')[0].split('Z')[0], fmt)
                            break
                        except ValueError:
                            continue
                    if start is None:
                        raise ValueError("Could not parse date")
            except (ValueError, AttributeError) as e:
                # If all parsing fails, log and skip this filter (don't fail the request)
                print(f"⚠️  Could not parse start_date '{start_date}': {e}. Skipping date filter.")
                start = None
            
            if start:
                # If naive datetime, make it timezone-aware (assume UTC)
                if start.tzinfo is None:
                    from datetime import timezone
                    start = start.replace(tzinfo=timezone.utc)
                query = query.filter(Order.created_at >= start)
        
        if end_date:
            end = None
            try:
                # Handle dates with microseconds but no timezone (e.g., 2025-12-23T14:04:45.917765)
                date_str = end_date.strip()
                
                # If it has microseconds but no timezone, strip microseconds first
                if '.' in date_str and '+' not in date_str and 'Z' not in date_str:
                    # Split by '.' and take first part (date + time without microseconds)
                    date_str = date_str.split('.')[0]
                
                # Replace Z with +00:00 for timezone
                if 'Z' in date_str:
                    date_str = date_str.replace('Z', '+00:00')
                
                # Try parsing with fromisoformat
                try:
                    end = datetime.fromisoformat(date_str)
                except ValueError:
                    # Fallback: Try with strptime
                    from datetime import timezone
                    # Try common formats
                    for fmt in ['%Y-%m-%dT%H:%M:%S', '%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%d %H:%M:%S', '%Y-%m-%d']:
                        try:
                            end = datetime.strptime(date_str.split('+')[0].split('Z')[0], fmt)
                            break
                        except ValueError:
                            continue
                    if end is None:
                        raise ValueError("Could not parse date")
            except (ValueError, AttributeError) as e:
                # If all parsing fails, log and skip this filter (don't fail the request)
                print(f"⚠️  Could not parse end_date '{end_date}': {e}. Skipping date filter.")
                end = None
            
            if end:
                # If naive datetime, make it timezone-aware (assume UTC)
                if end.tzinfo is None:
                    from datetime import timezone
                    end = end.replace(tzinfo=timezone.utc)
                query = query.filter(Order.created_at <= end)
        
        # Pagination
        offset = (page - 1) * per_page
        orders = query.order_by(Order.created_at.desc()).offset(offset).limit(per_page).all()
        
        # Convert orders to response, handling validation errors gracefully
        result = []
        for order in orders:
            try:
                # Manually construct order data to handle missing wholesale_amount column
                order_dict = {
                    'id': order.id,
                    'order_number': order.order_number,
                    'seller_id': order.seller_id,
                    'customer_id': order.customer_id,
                    'company_id': order.company_id,
                    'status': order.status_enum,  # Use status_enum property
                    'payment_method': order.payment_method,
                    'delivery_method': order.delivery_method,
                    'installation_date': order.installation_date,
                    'installation_notes': order.installation_notes,
                    'total_amount': order.total_amount,
                    'wholesale_amount': getattr(order, 'wholesale_amount', None),  # Handle missing column gracefully
                    'notes': order.notes,
                    'is_new': order.is_new,
                    'created_at': order.created_at,
                    'items': [OrderItemResponse.model_validate(item) for item in order.items],
                    'invoice_number': order.invoice_number,
                    'issue_date': order.issue_date,
                    'due_date': order.due_date,
                    'subtotal': order.subtotal,
                    'tax_amount': order.tax_amount,
                    'discount_amount': order.discount_amount,
                    'payment_terms': order.payment_terms,
                    'edit_requested_by': order.edit_requested_by,
                    'edit_requested_at': order.edit_requested_at,
                    'edit_approved_by': order.edit_approved_by,
                    'edit_approved_at': order.edit_approved_at,
                    'referrer_id': order.referrer_id,
                    'referrer_name': getattr(order.referrer, 'full_name', None) if hasattr(order, 'referrer') and order.referrer else None,
                    # Customer details
                    'customer_name': order.customer.name if order.customer else None,
                    'customer_mobile': order.customer.mobile if order.customer else None,
                    'customer_address': order.customer.address if order.customer else None,
                }
                result.append(OrderResponse.model_validate(order_dict))
            except Exception as e:
                print(f"⚠️  Error validating order {order.id} in search: {e}")
                import traceback
                traceback.print_exc()
                # Try fallback validation
                try:
                    # Ensure status is converted to enum and handle missing wholesale_amount
                    order_data = order.__dict__.copy()
                    if 'status' in order_data and not isinstance(order_data['status'], OrderStatus):
                        order_data['status'] = order.status_enum
                    # Ensure wholesale_amount exists (set to None if missing)
                    if 'wholesale_amount' not in order_data:
                        order_data['wholesale_amount'] = None
                    result.append(OrderResponse.model_validate(order_data))
                except Exception as e2:
                    print(f"❌ Failed to validate order {order.id}: {e2}")
                    # Skip this order rather than failing the entire request
                    continue
        
        return result
    except Exception as e:
        print(f"❌ Error in search_invoices endpoint: {e}")
        import traceback
        traceback.print_exc()
        # Return empty list rather than raising 500 error
        # This prevents 422/500 errors from breaking the frontend
        return []


@router.delete("/{order_id}")
async def delete_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR))
):
    """Delete order/invoice (Admin/Operator only)"""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    try:
        # Delete related records first (to avoid foreign key constraint violations)
        # 1. Delete installations
        from app.models import Installation
        installations = db.query(Installation).filter(Installation.order_id == order_id).all()
        installation_count = len(installations)
        for installation in installations:
            db.delete(installation)
        if installation_count > 0:
            db.flush()  # Ensure installations are deleted before proceeding
            print(f"✅ Deleted {installation_count} installation(s) for order {order_id}")
        
        # 2. Delete returns
        from app.models import Return
        returns = db.query(Return).filter(Return.order_id == order_id).all()
        return_count = len(returns)
        for return_record in returns:
            db.delete(return_record)
        if return_count > 0:
            db.flush()  # Ensure returns are deleted before proceeding
            print(f"✅ Deleted {return_count} return(s) for order {order_id}")
        
        # 3. Delete order (cascade will delete order items automatically via relationship)
        # Order items are configured with cascade="all, delete-orphan" in the Order model
        db.delete(order)
        db.commit()
        
        print(f"✅ Successfully deleted order {order_id} and all related records (installations: {installation_count}, returns: {return_count})")
        return {
            "message": "Order deleted successfully",
            "order_id": order_id,
            "deleted_installations": installation_count,
            "deleted_returns": return_count
        }
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting order {order_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete order: {str(e)}"
        )




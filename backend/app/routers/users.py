"""
User management routes
"""
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models import User, UserRole, ChatMessage, Discount
from app.schemas import UserCreate, UserUpdate, UserResponse
from app.dependencies import require_role, get_current_user
from app.routers.auth import get_password_hash, generate_referral_code
import os
import uuid
from app.config import settings

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("", response_model=List[UserResponse])
async def get_users(
    search: Optional[str] = Query(None),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.STORE_MANAGER)),
    db: Session = Depends(get_db)
):
    """Get all users (Admin and Store Manager only) with optional search"""
    from sqlalchemy import or_
    
    query = db.query(User)
    
    if current_user.role == UserRole.ADMIN:
        # Admin sees all users
        pass
    else:
        # Store Manager can only see sellers they created (and themselves)
        from sqlalchemy import or_
        query = query.filter(
            or_(
                (User.role == UserRole.SELLER) & (User.created_by == current_user.id),
                (User.id == current_user.id)  # Include themselves
            )
        )
    
    # Add search filter if provided
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            or_(
                User.full_name.ilike(search_term),
                User.username.ilike(search_term),
                User.mobile.ilike(search_term),
                User.national_id.ilike(search_term) if User.national_id else False
            )
        )
    
    users = query.all()
    return [UserResponse.model_validate(u) for u in users]


@router.post("", response_model=UserResponse)
async def create_user(
    user_data: UserCreate,
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.STORE_MANAGER)),
    db: Session = Depends(get_db)
):
    """Create new user"""
    # Check if username exists
    existing = db.query(User).filter(User.username == user_data.username).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="نام کاربری قبلاً استفاده شده است"
        )
    
    # Store Manager can only create sellers
    if current_user.role == UserRole.STORE_MANAGER and user_data.role != UserRole.SELLER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="مدیر فروشگاه فقط می‌تواند فروشنده ایجاد کند"
        )
    
    # Generate referral code for sellers and store managers
    referral_code = None
    if user_data.role in [UserRole.SELLER, UserRole.STORE_MANAGER]:
        referral_code = generate_referral_code(db)
    
    new_user = User(
        username=user_data.username,
        password_hash=get_password_hash(user_data.password),
        full_name=user_data.full_name,
        national_id=user_data.national_id,
        mobile=user_data.mobile,
        role=user_data.role,
        store_address=user_data.store_address,
        created_by=current_user.id if current_user.role == UserRole.STORE_MANAGER else None,
        referral_code=referral_code
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Create discount if provided (only for sellers and store managers)
    if user_data.discount_percentage is not None and user_data.discount_percentage > 0:
        if user_data.role in [UserRole.SELLER, UserRole.STORE_MANAGER]:
            # If category_ids is empty list, create discount for all categories (category_id=None)
            # If category_ids has values, create discount for each category
            # If category_ids is None, create discount for all categories
            category_ids = user_data.discount_category_ids if user_data.discount_category_ids is not None else []
            
            if len(category_ids) == 0:
                # Apply to all categories (category_id = None)
                discount = Discount(
                    user_id=new_user.id,
                    category_id=None,  # None means all categories
                    discount_percentage=user_data.discount_percentage,
                    is_active=True,
                    created_by=current_user.id
                )
                db.add(discount)
            else:
                # Create discount for each selected category
                for category_id in category_ids:
                    discount = Discount(
                        user_id=new_user.id,
                        category_id=category_id,
                        discount_percentage=user_data.discount_percentage,
                        is_active=True,
                        created_by=current_user.id
                    )
                    db.add(discount)
            
            db.commit()
    
    return UserResponse.model_validate(new_user)


@router.put("/{user_id}/credit")
async def update_user_credit(
    user_id: int,
    credit: float = Query(..., description="Credit amount to set"),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR)),
    db: Session = Depends(get_db)
):
    """Update user credit (Admin/Operator only)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="کاربر یافت نشد")
    
    # Only allow credit for sellers
    if user.role != UserRole.SELLER:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="اعتبار فقط برای فروشندگان قابل تنظیم است"
        )
    
    user.credit = credit
    db.commit()
    db.refresh(user)
    
    return {"message": "Credit updated", "user_id": user_id, "credit": credit}


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    current_user: User = Depends(require_role(UserRole.ADMIN)),
    db: Session = Depends(get_db)
):
    """
    Permanently delete a user and their chat messages (Admin only).
    Orders belonging to the user will be reassigned to the admin performing the deletion.
    """
    from app.models import Order
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Prevent self-deletion
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="نمی‌توانید حساب کاربری خود را حذف کنید"
        )

    # Reassign orders to the admin performing the deletion
    orders_count = db.query(Order).filter(Order.seller_id == user_id).count()
    if orders_count > 0:
        print(f"🔄 Reassigning {orders_count} order(s) from user {user_id} to admin {current_user.id}")
        db.query(Order).filter(Order.seller_id == user_id).update({"seller_id": current_user.id})
    
    # Handle referred orders - set referrer_id to NULL (it's nullable)
    referred_orders_count = db.query(Order).filter(Order.referrer_id == user_id).count()
    if referred_orders_count > 0:
        print(f"🔄 Clearing referrer_id for {referred_orders_count} referred order(s)")
        db.query(Order).filter(Order.referrer_id == user_id).update({"referrer_id": None})
    
    # Handle edit request/approval fields - set to NULL if they reference this user
    db.query(Order).filter(Order.edit_requested_by == user_id).update({"edit_requested_by": None})
    db.query(Order).filter(Order.edit_approved_by == user_id).update({"edit_approved_by": None})
    
    # Check if user created other users (Store Manager created sellers)
    created_users_count = db.query(User).filter(User.created_by == user_id).count()
    if created_users_count > 0:
        # Set created_by to NULL for users created by this user
        print(f"🔄 Clearing created_by for {created_users_count} user(s) created by this user")
        db.query(User).filter(User.created_by == user_id).update({"created_by": None})

    # Remove user's chat messages to clean up chat rooms
    chat_messages_count = db.query(ChatMessage).filter(ChatMessage.user_id == user_id).count()
    if chat_messages_count > 0:
        print(f"🔄 Deleting {chat_messages_count} chat message(s)")
        db.query(ChatMessage).filter(ChatMessage.user_id == user_id).delete()

    # Delete the user
    print(f"🗑️  Deleting user {user_id} ({user.username})")
    db.delete(user)
    db.commit()

    return None


@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.STORE_MANAGER)),
    db: Session = Depends(get_db)
):
    """Update user"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Store Manager can only update sellers
    if current_user.role == UserRole.STORE_MANAGER:
        if user.role != UserRole.SELLER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="فقط می‌توان فروشندگان را به‌روزرسانی کرد"
            )
        # Store Manager cannot change role
        if user_data.role and user_data.role != UserRole.SELLER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="نمی‌توان نقش را تغییر داد"
            )
    
    # Update fields
    if user_data.full_name is not None:
        user.full_name = user_data.full_name
    if user_data.mobile is not None:
        user.mobile = user_data.mobile
    if user_data.role is not None and current_user.role == UserRole.ADMIN:
        user.role = user_data.role
    if user_data.credit is not None and current_user.role == UserRole.ADMIN:
        user.credit = user_data.credit
    if user_data.store_address is not None:
        user.store_address = user_data.store_address
    if user_data.is_active is not None and current_user.role == UserRole.ADMIN:
        user.is_active = user_data.is_active
    
    # Update discount if provided (only for sellers and store managers, and only by admin)
    if current_user.role == UserRole.ADMIN and user.role in [UserRole.SELLER, UserRole.STORE_MANAGER]:
        if user_data.discount_percentage is not None or user_data.discount_category_ids is not None:
            # Delete existing active discounts for this user
            existing_discounts = db.query(Discount).filter(
                Discount.user_id == user.id,
                Discount.is_active == True
            ).all()
            for discount in existing_discounts:
                discount.is_active = False  # Deactivate instead of delete
                # updated_at will be automatically updated by SQLAlchemy's onupdate
            
            # Create new discounts if percentage is provided
            if user_data.discount_percentage is not None and user_data.discount_percentage > 0:
                category_ids = user_data.discount_category_ids if user_data.discount_category_ids is not None else []
                
                if len(category_ids) == 0:
                    # Apply to all categories (category_id = None)
                    discount = Discount(
                        user_id=user.id,
                        category_id=None,  # None means all categories
                        discount_percentage=user_data.discount_percentage,
                        is_active=True,
                        created_by=current_user.id
                    )
                    db.add(discount)
                else:
                    # Create discount for each selected category
                    for category_id in category_ids:
                        discount = Discount(
                            user_id=user.id,
                            category_id=category_id,
                            discount_percentage=user_data.discount_percentage,
                            is_active=True,
                            created_by=current_user.id
                        )
                        db.add(discount)
            elif user_data.discount_percentage is not None and user_data.discount_percentage == 0:
                # If percentage is 0, deactivate all discounts (already done above)
                pass
    
    db.commit()
    db.refresh(user)
    
    return UserResponse.model_validate(user)


@router.post("/{user_id}/business-card")
async def upload_business_card(
    user_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.STORE_MANAGER)),
    db: Session = Depends(get_db)
):
    """Upload business card image"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Use /tmp directory in production (read-only file system workaround)
    import tempfile
    upload_dir = os.getenv("UPLOAD_DIR", settings.UPLOAD_DIR)
    if not os.path.exists(upload_dir) or not os.access(upload_dir, os.W_OK):
        # Fallback to /tmp if uploads directory is read-only
        upload_dir = tempfile.gettempdir()
        print(f"⚠️  Using temp directory for uploads: {upload_dir}")
    
    # Create upload directory
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"business_card_{user_id}_{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(upload_dir, filename)
    
    # Save file
    try:
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
    except OSError as e:
        # If still fails, use /tmp
        upload_dir = tempfile.gettempdir()
        file_path = os.path.join(upload_dir, filename)
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        print(f"⚠️  Saved to temp directory: {file_path}")
    
    # Update user
    user.business_card_image = filename
    db.commit()
    
    return {"message": "Business card uploaded", "filename": filename}


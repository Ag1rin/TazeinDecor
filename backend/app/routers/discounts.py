"""
Discount management routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models import Discount, User, UserRole, Category
from app.schemas import DiscountCreate, DiscountUpdate, DiscountResponse
from app.dependencies import require_role, get_current_user

router = APIRouter(prefix="/api/discounts", tags=["discounts"])


@router.post("", response_model=DiscountResponse)
async def create_discount(
    discount_data: DiscountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR))
):
    """Create discount for user (Admin/Operator only)"""
    # Verify user exists and is a seller
    user = db.query(User).filter(User.id == discount_data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.role != UserRole.SELLER:
        raise HTTPException(
            status_code=400,
            detail="Discounts can only be set for sellers"
        )
    
    # Verify category exists if provided
    if discount_data.category_id:
        category = db.query(Category).filter(Category.id == discount_data.category_id).first()
        if not category:
            raise HTTPException(status_code=404, detail="Category not found")
    
    # Check if discount already exists for this user-category combination
    existing = db.query(Discount).filter(
        Discount.user_id == discount_data.user_id,
        Discount.category_id == discount_data.category_id,
        Discount.is_active == True
    ).first()
    
    if existing:
        # Update existing discount
        existing.discount_percentage = discount_data.discount_percentage
        existing.is_active = discount_data.is_active
        db.commit()
        db.refresh(existing)
        return DiscountResponse.model_validate(existing)
    
    # Create new discount
    discount = Discount(
        user_id=discount_data.user_id,
        category_id=discount_data.category_id,
        discount_percentage=discount_data.discount_percentage,
        is_active=discount_data.is_active,
        created_by=current_user.id
    )
    
    db.add(discount)
    db.commit()
    db.refresh(discount)
    
    return DiscountResponse.model_validate(discount)


@router.get("", response_model=List[DiscountResponse])
async def get_discounts(
    user_id: Optional[int] = Query(None),
    category_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR))
):
    """Get all discounts (Admin/Operator only)"""
    query = db.query(Discount)
    
    if user_id:
        query = query.filter(Discount.user_id == user_id)
    if category_id:
        query = query.filter(Discount.category_id == category_id)
    
    discounts = query.all()
    return [DiscountResponse.model_validate(d) for d in discounts]


@router.get("/user/{user_id}", response_model=List[DiscountResponse])
async def get_user_discounts(
    user_id: int,
    category_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get discounts for a specific user"""
    # Users can only see their own discounts, or Admin/Operator can see any
    if current_user.role not in [UserRole.ADMIN, UserRole.OPERATOR] and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    query = db.query(Discount).filter(
        Discount.user_id == user_id,
        Discount.is_active == True
    )
    
    if category_id:
        # Get discount for specific category or general (category_id=None)
        query = query.filter(
            (Discount.category_id == category_id) | (Discount.category_id == None)
        )
    
    discounts = query.all()
    return [DiscountResponse.model_validate(d) for d in discounts]


@router.put("/{discount_id}", response_model=DiscountResponse)
async def update_discount(
    discount_id: int,
    discount_data: DiscountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR))
):
    """Update discount (Admin/Operator only)"""
    discount = db.query(Discount).filter(Discount.id == discount_id).first()
    if not discount:
        raise HTTPException(status_code=404, detail="Discount not found")
    
    if discount_data.category_id is not None:
        discount.category_id = discount_data.category_id
    if discount_data.discount_percentage is not None:
        discount.discount_percentage = discount_data.discount_percentage
    if discount_data.is_active is not None:
        discount.is_active = discount_data.is_active
    
    db.commit()
    db.refresh(discount)
    
    return DiscountResponse.model_validate(discount)


@router.delete("/{discount_id}", status_code=204)
async def delete_discount(
    discount_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR))
):
    """Delete discount (Admin/Operator only)"""
    discount = db.query(Discount).filter(Discount.id == discount_id).first()
    if not discount:
        raise HTTPException(status_code=404, detail="Discount not found")
    
    db.delete(discount)
    db.commit()
    
    return None


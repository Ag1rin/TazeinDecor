"""
Returns management routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models import Return, Order, User, UserRole
from app.schemas import ReturnCreate, ReturnResponse
from app.dependencies import get_current_user, require_role
import json

router = APIRouter(prefix="/api/returns", tags=["returns"])


@router.post("", response_model=ReturnResponse)
async def create_return(
    return_data: ReturnCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create return (Seller or Store Manager)"""
    if current_user.role not in [UserRole.SELLER, UserRole.STORE_MANAGER]:
        raise HTTPException(status_code=403, detail="Only sellers and store managers can create returns")
    
    # Verify order belongs to seller or store manager
    order = db.query(Order).filter(Order.id == return_data.order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Check permissions
    if current_user.role == UserRole.SELLER and order.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    elif current_user.role == UserRole.STORE_MANAGER:
        # Store manager can return orders from their sellers or their own orders
        if order.seller_id != current_user.id:
            seller = db.query(User).filter(User.id == order.seller_id).first()
            if not seller or seller.created_by != current_user.id:
                raise HTTPException(status_code=403, detail="Access denied")
    
    # Validate items - ensure at least one item is selected
    if not return_data.items or len(return_data.items) == 0:
        raise HTTPException(status_code=400, detail="At least one item must be selected for return")
    
    # Validate items belong to the order
    from app.models import OrderItem
    order_item_ids = {item.id for item in order.items}
    for item in return_data.items:
        if 'order_item_id' in item:
            order_item_id = item['order_item_id']
            if not isinstance(order_item_id, int):
                try:
                    order_item_id = int(order_item_id)
                except (ValueError, TypeError):
                    raise HTTPException(status_code=400, detail="Invalid order_item_id format")
            if order_item_id not in order_item_ids:
                raise HTTPException(status_code=400, detail=f"Item {order_item_id} does not belong to this order")
            # Validate quantity doesn't exceed original
            order_item = db.query(OrderItem).filter(OrderItem.id == order_item_id).first()
            if order_item:
                return_quantity = item.get('quantity', 0)
                if return_quantity > order_item.quantity:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Return quantity ({return_quantity}) exceeds original quantity ({order_item.quantity})"
                    )
    
    return_obj = Return(
        order_id=return_data.order_id,
        reason=return_data.reason,
        items=json.dumps(return_data.items),
        status="pending",
        is_new=True
    )
    
    db.add(return_obj)
    db.commit()
    db.refresh(return_obj)
    
    print(f"✅ Return request created: ID {return_obj.id} for order {return_data.order_id}")
    return ReturnResponse.model_validate(return_obj)


@router.get("", response_model=List[ReturnResponse])
async def get_returns(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get returns based on role"""
    query = db.query(Return)
    
    # Filter by role
    if current_user.role == UserRole.SELLER:
        query = query.join(Order).filter(Order.seller_id == current_user.id)
    elif current_user.role == UserRole.STORE_MANAGER:
        # Store Manager sees only returns from their sellers
        seller_ids = db.query(User.id).filter(
            User.role == UserRole.SELLER,
            User.created_by == current_user.id
        ).all()
        seller_id_list = [sid[0] for sid in seller_ids]
        
        if seller_id_list:
            query = query.join(Order).filter(Order.seller_id.in_(seller_id_list))
        else:
            # If manager has no sellers, return empty result
            query = query.filter(Return.id == -1)  # Impossible condition
    
    # Pagination
    offset = (page - 1) * per_page
    returns = query.order_by(Return.created_at.desc()).offset(offset).limit(per_page).all()
    
    # Convert to response with order number
    result = []
    for r in returns:
        return_dict = {
            "id": r.id,
            "order_id": r.order_id,
            "reason": r.reason,
            "items": r.items,
            "status": r.status,
            "is_new": r.is_new,
            "created_at": r.created_at,
            "updated_at": r.updated_at,
            "order_number": r.order.order_number if r.order else None,
        }
        result.append(ReturnResponse(**return_dict))
    
    return result


@router.get("/{return_id}", response_model=ReturnResponse)
async def get_return(
    return_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get single return"""
    return_obj = db.query(Return).filter(Return.id == return_id).first()
    if not return_obj:
        raise HTTPException(status_code=404, detail="Return not found")
    
    # Check permissions
    if current_user.role == UserRole.SELLER:
        order = db.query(Order).filter(Order.id == return_obj.order_id).first()
        if order and order.seller_id != current_user.id:
            raise HTTPException(status_code=403, detail="Access denied")
    elif current_user.role == UserRole.STORE_MANAGER:
        # Store Manager can only access returns from their sellers
        order = db.query(Order).filter(Order.id == return_obj.order_id).first()
        if order:
            seller_ids = db.query(User.id).filter(
                User.role == UserRole.SELLER,
                User.created_by == current_user.id
            ).all()
            seller_id_list = [sid[0] for sid in seller_ids]
            if not seller_id_list or order.seller_id not in seller_id_list:
                raise HTTPException(status_code=403, detail="Access denied")
    
    return ReturnResponse.model_validate(return_obj)


@router.put("/{return_id}/mark-read")
async def mark_return_read(
    return_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark return as read (remove flashing)"""
    return_obj = db.query(Return).filter(Return.id == return_id).first()
    if not return_obj:
        raise HTTPException(status_code=404, detail="Return not found")
    
    return_obj.is_new = False
    db.commit()
    
    return {"message": "Return marked as read"}


@router.put("/{return_id}/approve")
async def approve_return(
    return_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR, UserRole.ADMIN))
):
    """Approve return request (Operator/Admin only)"""
    return_obj = db.query(Return).filter(Return.id == return_id).first()
    if not return_obj:
        raise HTTPException(status_code=404, detail="Return not found")
    
    if return_obj.status != "pending":
        raise HTTPException(status_code=400, detail=f"Return is already {return_obj.status}")
    
    return_obj.status = "approved"
    return_obj.is_new = False
    db.commit()
    
    print(f"✅ Return {return_id} approved by {current_user.id}")
    return {"message": "Return approved", "return_id": return_id, "status": "approved"}


@router.put("/{return_id}/reject")
async def reject_return(
    return_id: int,
    reason: Optional[str] = Query(None, description="Rejection reason"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR, UserRole.ADMIN))
):
    """Reject return request (Operator/Admin only)"""
    return_obj = db.query(Return).filter(Return.id == return_id).first()
    if not return_obj:
        raise HTTPException(status_code=404, detail="Return not found")
    
    if return_obj.status != "pending":
        raise HTTPException(status_code=400, detail=f"Return is already {return_obj.status}")
    
    return_obj.status = "rejected"
    return_obj.is_new = False
    # Store rejection reason in the reason field if provided
    if reason:
        current_reason = return_obj.reason or ""
        return_obj.reason = f"{current_reason}\n[رد شده: {reason}]" if current_reason else f"[رد شده: {reason}]"
    db.commit()
    
    print(f"✅ Return {return_id} rejected by {current_user.id}")
    return {"message": "Return rejected", "return_id": return_id, "status": "rejected"}


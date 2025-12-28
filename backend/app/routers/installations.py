"""
Installation management routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date, timedelta
from app.database import get_db
from app.models import Installation, Order, User, UserRole
from app.schemas import InstallationCreate, InstallationResponse
from app.dependencies import get_current_user, require_role

router = APIRouter(prefix="/api/installations", tags=["installations"])


@router.post("", response_model=InstallationResponse)
async def create_installation(
    installation_data: InstallationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create installation date"""
    # Verify order belongs to seller
    order = db.query(Order).filter(Order.id == installation_data.order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="سفارش یافت نشد")
    
    if current_user.role == UserRole.SELLER and order.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="دسترسی رد شد")
    
    installation = Installation(
        order_id=installation_data.order_id,
        installation_date=installation_data.installation_date,
        notes=installation_data.notes,
        color=installation_data.color
    )
    
    db.add(installation)
    db.commit()
    db.refresh(installation)
    
    return InstallationResponse.model_validate(installation)


@router.get("", response_model=List[InstallationResponse])
async def get_installations(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get installations with date range - includes both Installation entries and orders with installation_date"""
    from sqlalchemy import or_
    
    # Get installations from Installation table
    installation_query = db.query(Installation)
    if start_date:
        installation_query = installation_query.filter(Installation.installation_date >= datetime.combine(start_date, datetime.min.time()))
    if end_date:
        installation_query = installation_query.filter(Installation.installation_date <= datetime.combine(end_date, datetime.max.time()))
    
    # Also get orders that have installation_date but no Installation entry
    order_query = db.query(Order).filter(
        Order.installation_date.isnot(None)
    )
    if start_date:
        order_query = order_query.filter(Order.installation_date >= datetime.combine(start_date, datetime.min.time()))
    if end_date:
        order_query = order_query.filter(Order.installation_date <= datetime.combine(end_date, datetime.max.time()))
    
    # Filter by user role
    if current_user.role == UserRole.SELLER:
        order_query = order_query.filter(Order.seller_id == current_user.id)
        installation_query = installation_query.join(Order, Installation.order_id == Order.id).filter(Order.seller_id == current_user.id)
    elif current_user.role == UserRole.STORE_MANAGER:
        # Store Manager sees only installations from sellers they created
        seller_ids = db.query(User.id).filter(
            User.role == UserRole.SELLER,
            User.created_by == current_user.id
        ).all()
        seller_id_list = [sid[0] for sid in seller_ids]
        
        if seller_id_list:
            order_query = order_query.filter(Order.seller_id.in_(seller_id_list))
            installation_query = installation_query.join(Order, Installation.order_id == Order.id).filter(
                Order.seller_id.in_(seller_id_list)
            )
        else:
            # If manager has no sellers, return empty result
            order_query = order_query.filter(Order.id == -1)  # Impossible condition
            installation_query = installation_query.filter(Installation.id == -1)  # Impossible condition
    
    installations = installation_query.all()
    orders_with_installation = order_query.all()
    
    # Create InstallationResponse objects from orders that don't have Installation entries
    existing_order_ids = {inst.order_id for inst in installations}
    result = [InstallationResponse.model_validate(i) for i in installations]
    
    for order in orders_with_installation:
        if order.id not in existing_order_ids:
            # Create a virtual InstallationResponse from the order
            result.append(InstallationResponse(
                id=-order.id,  # Use negative ID to distinguish from real installations
                order_id=order.id,
                installation_date=order.installation_date,
                notes=order.installation_notes,
                color=None,
                created_at=order.created_at,
                updated_at=getattr(order, 'updated_at', None)
            ))
    
    # Sort by installation_date
    result.sort(key=lambda x: x.installation_date)
    
    return result


@router.get("/tomorrow")
async def get_tomorrow_installations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get tomorrow's installations count and details"""
    tomorrow = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
    next_day = tomorrow + timedelta(days=1)
    
    installations = db.query(Installation).filter(
        Installation.installation_date >= tomorrow,
        Installation.installation_date < next_day
    ).all()
    
    result = []
    for inst in installations:
        order = db.query(Order).filter(Order.id == inst.order_id).first()
        result.append({
            "id": inst.id,
            "order_id": inst.order_id,
            "order_number": order.order_number if order else None,
            "installation_date": inst.installation_date,
            "notes": inst.notes,
            "color": inst.color
        })
    
    return {"count": len(installations), "installations": result}


@router.delete("/{installation_id}")
async def delete_installation(
    installation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.STORE_MANAGER, UserRole.ADMIN))
):
    """Delete installation (Store Manager and Admin only)"""
    installation = db.query(Installation).filter(Installation.id == installation_id).first()
    if not installation:
        raise HTTPException(status_code=404, detail="نصب یافت نشد")
    
    db.delete(installation)
    db.commit()
    
    return {"message": "Installation deleted"}


@router.put("/{installation_id}", response_model=InstallationResponse)
async def update_installation(
    installation_id: int,
    installation_data: InstallationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.STORE_MANAGER, UserRole.ADMIN))
):
    """Update installation (Store Manager and Admin only)"""
    installation = db.query(Installation).filter(Installation.id == installation_id).first()
    if not installation:
        raise HTTPException(status_code=404, detail="نصب یافت نشد")
    
    installation.installation_date = installation_data.installation_date
    installation.notes = installation_data.notes
    installation.color = installation_data.color
    
    db.commit()
    db.refresh(installation)
    
    return InstallationResponse.model_validate(installation)


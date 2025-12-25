"""
Reports routes
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
from datetime import datetime, date, timedelta
from app.database import get_db
from app.models import Order, User, UserRole
from app.dependencies import get_current_user, require_role

router = APIRouter(prefix="/api/reports", tags=["reports"])


@router.get("/sales")
async def get_sales_report(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    period: str = Query("day"),  # day, month, year
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.STORE_MANAGER))
):
    """Get sales report"""
    query = db.query(Order).filter(Order.status != "cancelled")
    
    # Filter by role
    if current_user.role == UserRole.STORE_MANAGER:
        # Store Manager sees only orders from sellers they created
        seller_ids = db.query(User.id).filter(
            User.role == UserRole.SELLER,
            User.created_by == current_user.id
        ).all()
        seller_id_list = [sid[0] for sid in seller_ids]
        
        if seller_id_list:
            query = query.filter(Order.seller_id.in_(seller_id_list))
        else:
            # If manager has no sellers, return empty result
            query = query.filter(Order.id == -1)  # Impossible condition
    elif current_user.role == UserRole.ADMIN:
        # Admin sees all orders
        pass
    elif current_user.role == UserRole.OPERATOR:
        # Operator sees all orders
        pass
    
    if start_date:
        query = query.filter(Order.created_at >= datetime.combine(start_date, datetime.min.time()))
    if end_date:
        query = query.filter(Order.created_at <= datetime.combine(end_date, datetime.max.time()))
    
    orders = query.all()
    
    # Group by period
    report_data = {}
    for order in orders:
        if period == "day":
            key = order.created_at.date().isoformat()
        elif period == "month":
            key = order.created_at.strftime("%Y-%m")
        else:  # year
            key = str(order.created_at.year)
        
        if key not in report_data:
            report_data[key] = {"date": key, "count": 0, "total": 0.0}
        
        report_data[key]["count"] += 1
        report_data[key]["total"] += order.total_amount
    
    return {"period": period, "data": list(report_data.values())}


@router.get("/seller-performance")
async def get_seller_performance(
    seller_id: Optional[int] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.STORE_MANAGER))
):
    """Get seller performance report"""
    from sqlalchemy import or_, and_
    
    try:
        # Start with base query - include both SELLER and STORE_MANAGER
        query = db.query(Order, User).join(User, Order.seller_id == User.id).filter(
            User.role.in_([UserRole.SELLER, UserRole.STORE_MANAGER])
        )
        
        # Filter by role
        if current_user.role == UserRole.STORE_MANAGER:
            # Store Manager sees only sellers they created
            seller_ids = db.query(User.id).filter(
                User.role == UserRole.SELLER,
                User.created_by == current_user.id
            ).all()
            seller_id_list = [sid[0] for sid in seller_ids]
            
            if seller_id_list:
                query = query.filter(Order.seller_id.in_(seller_id_list))
            else:
                # If manager has no sellers, return empty result
                query = query.filter(Order.id == -1)  # Impossible condition
        elif current_user.role == UserRole.ADMIN:
            # Admin sees all sellers and store managers
            pass
        elif current_user.role == UserRole.OPERATOR:
            # Operator sees all sellers and store managers
            pass
        
        if seller_id:
            query = query.filter(Order.seller_id == seller_id)
        
        if start_date:
            query = query.filter(Order.created_at >= datetime.combine(start_date, datetime.min.time()))
        if end_date:
            query = query.filter(Order.created_at <= datetime.combine(end_date, datetime.max.time()))
        
        results = query.all()
        
        seller_stats = {}
        for order, seller in results:
            if seller.id not in seller_stats:
                seller_stats[seller.id] = {
                    "seller_id": seller.id,
                    "seller_name": seller.full_name or seller.username or f"User {seller.id}",
                    "order_count": 0,
                    "total_sales": 0.0
                }
            
            seller_stats[seller.id]["order_count"] += 1
            seller_stats[seller.id]["total_sales"] += float(order.total_amount or 0.0)
        
        return {"sellers": list(seller_stats.values())}
    except Exception as e:
        import traceback
        print(f"❌ Error in seller-performance report: {e}")
        traceback.print_exc()
        raise

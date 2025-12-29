"""
Company management routes
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Set
from app.database import get_db
from app.models import Company, User, UserRole
from app.schemas import CompanyCreate, CompanyResponse
from app.dependencies import get_current_user, require_role
from app.woocommerce_client import woocommerce_client
import os
import uuid
import tempfile
from app.config import settings

router = APIRouter(prefix="/api/companies", tags=["companies"])


@router.get("", response_model=List[CompanyResponse])
async def get_companies(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Get all companies from WooCommerce product brands (Operator only)
    
    Fetches all unique brands from WooCommerce products and returns them as companies.
    Also includes any manually created companies from the database.
    """
    # Get unique brands from WooCommerce products
    brands: Set[str] = set()
    page = 1
    per_page = 100
    
    print("🔍 Fetching brands from WooCommerce products...")
    
    while True:
        products = woocommerce_client.get_products(page=page, per_page=per_page)
        if not products:
            break
        
        for product in products:
            # Extract brand from product attributes
            brand = None
            
            # First, check product attributes (most common location)
            if product.get("attributes"):
                for attr in product["attributes"]:
                    attr_name = attr.get("name", "").lower()
                    attr_options = attr.get("options", [])
                    
                    if attr_options:
                        attr_value = attr_options[0] if isinstance(attr_options, list) else str(attr_options)
                        
                        # Check if this attribute is for brand
                        if ("برند" in attr_name or "brand" in attr_name) and attr_value:
                            brand = str(attr_value).strip()
                            if brand and brand.lower() not in ["none", "null", ""]:
                                break
            
            # Also check for product_brand in meta_data (custom fields)
            if not brand and product.get("meta_data"):
                for meta in product["meta_data"]:
                    meta_key = meta.get("key", "").lower()
                    meta_value = meta.get("value")
                    
                    if meta_value and ("brand" in meta_key or "product_brand" in meta_key):
                        brand = str(meta_value).strip()
                        if brand and brand.lower() not in ["none", "null", ""]:
                            break
            
            # Add brand if found and valid
            if brand and brand.strip() and brand.lower() not in ["none", "null", ""]:
                brands.add(brand.strip())
        
        # Check if we've fetched all products
        if len(products) < per_page:
            break
        page += 1
    
    print(f"✅ Found {len(brands)} unique brands from WooCommerce")
    
    # Get manually created companies from database
    db_companies = db.query(Company).all()
    db_company_names = {c.name for c in db_companies}
    
    # Create CompanyResponse objects for brands (as companies)
    brand_companies = []
    for brand in sorted(brands):
        # Check if this brand already exists as a manual company
        existing_company = next((c for c in db_companies if c.name == brand), None)
        if existing_company:
            # Use existing company from DB (with logo, mobile, etc.)
            brand_companies.append(CompanyResponse.model_validate(existing_company))
        else:
            # Create a virtual company from brand
            brand_companies.append(CompanyResponse(
                id=0,  # Virtual company, no DB ID
                name=brand,
                mobile=None,
                address=None,
                logo=None,
                notes=None,
                created_at=None  # No creation date for virtual companies
            ))
    
    # Add any manual companies that aren't brands
    for db_company in db_companies:
        if db_company.name not in brands:
            brand_companies.append(CompanyResponse.model_validate(db_company))
    
    return brand_companies


@router.post("", response_model=CompanyResponse)
async def create_company(
    company_data: CompanyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Create new company (Operator only)"""
    company = Company(
        name=company_data.name,
        mobile=company_data.mobile,
        address=company_data.address,
        logo=company_data.logo,
        notes=company_data.notes,
        brand_name=company_data.brand_name,
        brand_thumbnail=company_data.brand_thumbnail
    )
    
    db.add(company)
    db.commit()
    db.refresh(company)
    
    return CompanyResponse.model_validate(company)


@router.put("/{company_id}", response_model=CompanyResponse)
async def update_company(
    company_id: int,
    company_data: CompanyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Update company (Operator only)"""
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="شرکت یافت نشد")
    
    company.name = company_data.name
    company.mobile = company_data.mobile
    company.address = company_data.address
    company.logo = company_data.logo
    company.notes = company_data.notes
    company.brand_name = company_data.brand_name
    company.brand_thumbnail = company_data.brand_thumbnail
    
    db.commit()
    db.refresh(company)
    
    return CompanyResponse.model_validate(company)


@router.post("/{company_id}/logo")
async def upload_logo(
    company_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Upload company logo (Operator only)"""
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="شرکت یافت نشد")
    
    # Use the same upload directory as configured in main.py
    # Get from environment or settings, matching main.py logic
    upload_dir = os.getenv("UPLOAD_DIR", settings.UPLOAD_DIR)
    try:
        # Try to create and use the configured upload directory
        os.makedirs(upload_dir, exist_ok=True)
        # Check if directory is writable
        if not os.access(upload_dir, os.W_OK):
            raise OSError("Directory is not writable")
    except (OSError, PermissionError) as e:
        # Fallback to temp directory if uploads directory is read-only
        upload_dir = tempfile.gettempdir()
        # Create a subdirectory in temp for uploads (matching main.py)
        upload_dir = os.path.join(upload_dir, "uploads")
        os.makedirs(upload_dir, exist_ok=True)
        print(f"⚠️  Using temp directory for uploads: {upload_dir}")
    
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"company_logo_{company_id}_{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(upload_dir, filename)
    
    # Save file with error handling
    try:
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
    except OSError as e:
        # If still fails, try temp directory
        if "read-only" in str(e).lower() or "permission denied" in str(e).lower():
            upload_dir = tempfile.gettempdir()
            file_path = os.path.join(upload_dir, filename)
            with open(file_path, "wb") as f:
                f.write(content)
            print(f"⚠️  Saved to temp directory: {file_path}")
        else:
            raise HTTPException(status_code=500, detail=f"خطا در ذخیره فایل: {str(e)}")
    
    company.logo = filename
    db.commit()
    
    return {"message": "Logo uploaded", "filename": filename}


@router.post("/{company_id}/brand-thumbnail")
async def upload_brand_thumbnail(
    company_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Upload brand thumbnail (Operator only)"""
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="شرکت یافت نشد")
    
    # Use the same upload directory as configured in main.py
    upload_dir = os.getenv("UPLOAD_DIR", settings.UPLOAD_DIR)
    try:
        os.makedirs(upload_dir, exist_ok=True)
        if not os.access(upload_dir, os.W_OK):
            raise OSError("Directory is not writable")
    except (OSError, PermissionError) as e:
        upload_dir = tempfile.gettempdir()
        upload_dir = os.path.join(upload_dir, "uploads")
        os.makedirs(upload_dir, exist_ok=True)
        print(f"⚠️  Using temp directory for uploads: {upload_dir}")
    
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"brand_thumbnail_{company_id}_{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(upload_dir, filename)
    
    # Save file with error handling
    try:
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
    except OSError as e:
        if "read-only" in str(e).lower() or "permission denied" in str(e).lower():
            upload_dir = tempfile.gettempdir()
            file_path = os.path.join(upload_dir, filename)
            with open(file_path, "wb") as f:
                f.write(content)
            print(f"⚠️  Saved to temp directory: {file_path}")
        else:
            raise HTTPException(status_code=500, detail=f"خطا در ذخیره فایل: {str(e)}")
    
    company.brand_thumbnail = filename
    db.commit()
    
    return {"message": "Brand thumbnail uploaded", "filename": filename}


@router.delete("/{company_id}")
async def delete_company(
    company_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Delete company (Operator only)"""
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="شرکت یافت نشد")
    
    db.delete(company)
    db.commit()
    
    return {"message": "Company deleted successfully"}


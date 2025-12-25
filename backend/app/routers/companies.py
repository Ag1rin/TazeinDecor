"""
Company management routes
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Company, User, UserRole
from app.schemas import CompanyCreate, CompanyResponse
from app.dependencies import get_current_user, require_role
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
    """Get all companies (Operator only)"""
    companies = db.query(Company).all()
    return [CompanyResponse.model_validate(c) for c in companies]


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
        notes=company_data.notes
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
        raise HTTPException(status_code=404, detail="Company not found")
    
    company.name = company_data.name
    company.mobile = company_data.mobile
    company.address = company_data.address
    company.logo = company_data.logo
    company.notes = company_data.notes
    
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
        raise HTTPException(status_code=404, detail="Company not found")
    
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
            raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")
    
    company.logo = filename
    db.commit()
    
    return {"message": "Logo uploaded", "filename": filename}


@router.delete("/{company_id}")
async def delete_company(
    company_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OPERATOR))
):
    """Delete company (Operator only)"""
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    db.delete(company)
    db.commit()
    
    return {"message": "Company deleted successfully"}


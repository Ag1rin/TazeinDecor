"""
Authentication routes
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from passlib.context import CryptContext
import os
import secrets
import string
from app.database import get_db
from app.models import User, UserRole
from app.schemas import LoginRequest, RegisterRequest, TokenResponse, UserResponse
from app.dependencies import create_access_token, get_current_user
from app.config import settings
from datetime import timedelta

router = APIRouter(prefix="/api/auth", tags=["auth"])


def generate_referral_code(db: Session, length: int = 8) -> str:
    """Generate a unique referral code for sellers/store managers"""
    # Use alphanumeric characters (uppercase for readability)
    alphabet = string.ascii_uppercase + string.digits
    
    while True:
        # Generate a random code
        code = ''.join(secrets.choice(alphabet) for _ in range(length))
        
        # Check if it's unique
        existing = db.query(User).filter(User.referral_code == code).first()
        if not existing:
            return code

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password with error handling"""
    try:
        # Check if hash looks valid (bcrypt hashes start with $2a$, $2b$, or $2y$)
        if not hashed_password or not hashed_password.startswith('$2'):
            print(f"Warning: Invalid password hash format for user")
            return False
        
        try:
            # Try passlib first
            return pwd_context.verify(plain_password, hashed_password)
        except Exception as e:
            # Fallback to direct bcrypt if passlib fails
            print(f"Warning: passlib verify failed ({e}), trying direct bcrypt")
            import bcrypt
            password_bytes = plain_password.encode('utf-8')
            if len(password_bytes) > 72:
                password_bytes = password_bytes[:72]
            return bcrypt.checkpw(password_bytes, hashed_password.encode('utf-8'))
    except Exception as e:
        print(f"Password verification error: {e}")
        print(f"Hash format: {hashed_password[:20] if hashed_password else 'None'}...")
        return False


def get_password_hash(password: str) -> str:
    """Hash password, truncating if necessary for bcrypt compatibility"""
    try:
        # Try using passlib first
        password_bytes = password.encode('utf-8')
        if len(password_bytes) > 72:
            print("Warning: Password too long for bcrypt, truncating.")
            password = password_bytes[:72].decode('utf-8', 'ignore')
        return pwd_context.hash(password)
    except Exception as e:
        # Fallback to direct bcrypt if passlib fails
        print(f"Warning: passlib failed ({e}), using direct bcrypt")
        import bcrypt
        password_bytes = password.encode('utf-8')
        if len(password_bytes) > 72:
            password_bytes = password_bytes[:72]
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password_bytes, salt)
        return hashed.decode('utf-8')


@router.post("/login", response_model=TokenResponse)
async def login(
    login_data: LoginRequest,
    db: Session = Depends(get_db)
):
    """Login endpoint"""
    try:
        user = db.query(User).filter(User.username == login_data.username).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password"
            )
        
        # Check if password hash is valid
        if not user.password_hash or not user.password_hash.startswith('$2'):
            print(f"Warning: User {user.username} has invalid password hash format")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Password hash is corrupted. Please contact administrator to reset your password."
            )
        
        if not verify_password(login_data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password"
            )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User account is inactive"
            )
        
        access_token = create_access_token(data={"sub": user.username})
        
        return TokenResponse(
            access_token=access_token,
            user=UserResponse.model_validate(user)
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user info"""
    return UserResponse.model_validate(current_user)


@router.post("/register", response_model=TokenResponse)
async def register(
    register_data: RegisterRequest,
    db: Session = Depends(get_db)
):
    """Public registration endpoint - creates a new user with SELLER role"""
    # Check if username already exists
    existing_user = db.query(User).filter(User.username == register_data.username).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists"
        )
    
    # Generate referral code for sellers
    referral_code = generate_referral_code(db)
    
    # Create new user with SELLER role by default
    new_user = User(
        username=register_data.username,
        password_hash=get_password_hash(register_data.password),
        full_name=register_data.full_name,
        mobile=register_data.mobile,
        national_id=register_data.national_id,
        store_address=register_data.store_address,
        role=UserRole.SELLER,  # Default to SELLER for public registrations
        is_active=True,  # Auto-activate new registrations
        credit=0.0,  # Start with zero credit
        referral_code=referral_code  # Unique referral code
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Automatically log in the new user
    access_token = create_access_token(data={"sub": new_user.username})
    
    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(new_user)
    )


@router.post("/change-password")
async def change_password(
    request: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Change user password
    Requires authentication (current user can only change their own password)
    
    Request body: {"old_password": "current", "new_password": "new"}
    """
    old_password = request.get("old_password", "")
    new_password = request.get("new_password", "")
    
    if not old_password or not new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Both old_password and new_password are required"
        )
    
    # Validate new password length
    if len(new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 6 characters long"
        )
    
    # Verify old password
    if not verify_password(old_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect current password"
        )
    
    # Check if new password is same as old password
    if verify_password(new_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password"
        )
    
    try:
        # Update password
        current_user.password_hash = get_password_hash(new_password)
        db.commit()
        db.refresh(current_user)
        
        return {
            "success": True,
            "message": "Password changed successfully"
        }
    except Exception as e:
        db.rollback()
        print(f"❌ Error changing password: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error changing password: {str(e)}"
        )


@router.get("/version")
async def get_version():
    """Get app version"""
    return {"version": settings.APP_VERSION}


@router.post("/reset-admin-password")
async def reset_admin_password_endpoint(
    request: dict,
    db: Session = Depends(get_db)
):
    """
    Emergency endpoint to reset admin password
    Requires a secret key to prevent unauthorized access
    Set SECRET_RESET_KEY in environment variables
    
    Request body: {"secret_key": "your-secret-key"}
    """
    # Check secret key
    secret_key = request.get("secret_key", "")
    expected_key = os.getenv("SECRET_RESET_KEY", "CHANGE_THIS_IN_PRODUCTION")
    
    if not secret_key or secret_key != expected_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid secret key"
        )
    
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        
        if not admin:
            # Create admin if doesn't exist
            admin = User(
                username="admin",
                password_hash=get_password_hash("admin123"),
                full_name="مدیر سیستم",
                mobile="09123456789",
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin)
        else:
            # Reset password
            admin.password_hash = get_password_hash("admin123")
            admin.is_active = True
        
        db.commit()
        
        return {
            "success": True,
            "message": "Admin password reset to 'admin123'",
            "username": "admin",
            "password": "admin123"
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error resetting password: {str(e)}"
        )


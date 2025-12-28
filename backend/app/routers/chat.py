"""
Chat room routes
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import SessionLocal, get_db
from app.models import ChatMessage, User, UserRole
from app.schemas import ChatMessageCreate, ChatMessageResponse
from app.dependencies import get_current_user, require_role, get_user_from_token
from app.websocket_manager import manager
import os
import uuid
import re
import json
import tempfile
from app.config import settings

router = APIRouter(prefix="/api/chat", tags=["chat"])


def filter_mobile_numbers(text: str) -> str:
    """Filter mobile numbers from text"""
    if not text:
        return text
    # Replace Iranian mobile numbers (09xxxxxxxxx) with stars
    pattern = r'09\d{9}'
    return re.sub(pattern, '***********', text)


@router.post("", response_model=ChatMessageResponse)
async def send_message(
    message_data: ChatMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send text message"""
    # Filter mobile numbers
    filtered_message = filter_mobile_numbers(message_data.message) if message_data.message else None
    
    chat_message = ChatMessage(
        user_id=current_user.id,
        message=filtered_message,
        message_type=message_data.message_type
    )
    
    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)
    
    # Broadcast via WebSocket
    await manager.broadcast({
        "type": "new_message",
        "id": chat_message.id,
        "user_id": current_user.id,
        "user_name": current_user.full_name,
        "message": chat_message.message,
        "image_url": chat_message.image_url,
        "voice_url": chat_message.voice_url,
        "message_type": chat_message.message_type,
        "created_at": chat_message.created_at.isoformat()
    })
    
    return ChatMessageResponse(
        id=chat_message.id,
        user_id=chat_message.user_id,
        user_name=current_user.full_name,
        message=chat_message.message,
        image_url=chat_message.image_url,
        voice_url=chat_message.voice_url,
        message_type=chat_message.message_type,
        created_at=chat_message.created_at
    )


@router.post("/image")
async def send_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send image message"""
    # Check if upload directory is writable, fallback to temp if not
    upload_dir = os.getenv("UPLOAD_DIR", settings.UPLOAD_DIR)
    if not os.path.exists(upload_dir) or not os.access(upload_dir, os.W_OK):
        # Fallback to /tmp if uploads directory is read-only
        upload_dir = tempfile.gettempdir()
        print(f"⚠️  Using temp directory for uploads: {upload_dir}")
    
    # Create upload directory
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"chat_image_{uuid.uuid4()}{file_ext}"
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
    
    chat_message = ChatMessage(
        user_id=current_user.id,
        image_url=filename,
        message_type="image"
    )
    
    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)
    
    # Broadcast via WebSocket
    await manager.broadcast({
        "type": "new_message",
        "id": chat_message.id,
        "user_id": current_user.id,
        "user_name": current_user.full_name,
        "message": chat_message.message,
        "image_url": chat_message.image_url,
        "voice_url": chat_message.voice_url,
        "message_type": chat_message.message_type,
        "created_at": chat_message.created_at.isoformat()
    })
    
    return ChatMessageResponse(
        id=chat_message.id,
        user_id=chat_message.user_id,
        user_name=current_user.full_name,
        message=chat_message.message,
        image_url=chat_message.image_url,
        voice_url=chat_message.voice_url,
        message_type=chat_message.message_type,
        created_at=chat_message.created_at
    )


@router.post("/voice")
async def send_voice(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send voice message"""
    # Check if upload directory is writable, fallback to temp if not
    upload_dir = os.getenv("UPLOAD_DIR", settings.UPLOAD_DIR)
    if not os.path.exists(upload_dir) or not os.access(upload_dir, os.W_OK):
        # Fallback to /tmp if uploads directory is read-only
        upload_dir = tempfile.gettempdir()
        print(f"⚠️  Using temp directory for uploads: {upload_dir}")
    
    # Create upload directory
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1] or ".ogg"
    filename = f"chat_voice_{uuid.uuid4()}{file_ext}"
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
    
    chat_message = ChatMessage(
        user_id=current_user.id,
        voice_url=filename,
        message_type="voice"
    )
    
    db.add(chat_message)
    db.commit()
    db.refresh(chat_message)
    
    # Broadcast via WebSocket
    await manager.broadcast({
        "type": "new_message",
        "id": chat_message.id,
        "user_id": current_user.id,
        "user_name": current_user.full_name,
        "message": chat_message.message,
        "image_url": chat_message.image_url,
        "voice_url": chat_message.voice_url,
        "message_type": chat_message.message_type,
        "created_at": chat_message.created_at.isoformat()
    })
    
    return ChatMessageResponse(
        id=chat_message.id,
        user_id=chat_message.user_id,
        user_name=current_user.full_name,
        message=chat_message.message,
        image_url=chat_message.image_url,
        voice_url=chat_message.voice_url,
        message_type=chat_message.message_type,
        created_at=chat_message.created_at
    )


@router.get("", response_model=List[ChatMessageResponse])
async def get_messages(
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get chat messages"""
    messages = db.query(ChatMessage).order_by(ChatMessage.created_at.desc()).limit(limit).all()
    
    result = []
    for msg in reversed(messages):
        user = db.query(User).filter(User.id == msg.user_id).first()
        result.append(ChatMessageResponse(
            id=msg.id,
            user_id=msg.user_id,
            user_name="System" if msg.message_type == "system" else (user.full_name if user else "Unknown"),
            message=msg.message,
            image_url=msg.image_url,
            voice_url=msg.voice_url,
            message_type=msg.message_type,
            created_at=msg.created_at
        ))
    
    return result


@router.delete("/{message_id}")
async def delete_message(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.OPERATOR))
):
    """Soft-delete message and broadcast system replacement (Admin/Operator)."""
    message = db.query(ChatMessage).filter(ChatMessage.id == message_id).first()
    if not message:
        raise HTTPException(status_code=404, detail="پیام یافت نشد")

    # Replace content with system message instead of hard delete
    message.message = "This message was deleted by an admin."
    message.message_type = "system"
    message.image_url = None
    message.voice_url = None
    db.commit()
    db.refresh(message)

    payload = {
        "type": "message_deleted",
        "message_id": message_id,
        "updated_message": {
            "id": message.id,
            "user_id": message.user_id,
            "user_name": "System",
            "message": message.message,
            "image_url": None,
            "voice_url": None,
            "message_type": message.message_type,
            "created_at": message.created_at.isoformat()
        }
    }

    # Broadcast deletion update to all clients
    await manager.broadcast(payload)
    
    return payload["updated_message"]


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = None):
    """WebSocket endpoint for real-time chat"""
    db = SessionLocal()
    user = None
    
    try:
        # Get token from query parameter or header BEFORE accepting
        if not token:
            # Try query parameter
            query_params = dict(websocket.query_params)
            token = query_params.get("token")
            
            # Try Authorization header
            if not token:
                auth_header = websocket.headers.get("Authorization", "")
                if auth_header.startswith("Bearer "):
                    token = auth_header.replace("Bearer ", "")
        
        if not token:
            # Accept then immediately close if no token
            await websocket.accept()
            await websocket.close(code=1008, reason="No token provided")
            return
        
        # Authenticate user BEFORE accepting connection
        user = await get_user_from_token(token, db)
        if not user:
            await websocket.accept()
            await websocket.close(code=1008, reason="Invalid token")
            return
        
        # Now accept the WebSocket connection
        await websocket.accept()
        
        # Store connection
        if user.id in manager.active_connections:
            # Disconnect existing connection
            try:
                await manager.active_connections[user.id].close()
            except:
                pass
        
        manager.active_connections[user.id] = websocket
        manager.connection_metadata[user.id] = {"username": user.full_name, "role": user.role.value}
        print(f"User {user.id} ({user.full_name}) connected via WebSocket")
        
        # Send connection confirmation
        await websocket.send_json({
            "type": "connected",
            "user_id": user.id,
            "username": user.full_name
        })
        
        # Listen for messages
        while True:
            data = await websocket.receive_json()
            
            if data.get("type") == "send_message":
                # Filter mobile numbers
                message_text = filter_mobile_numbers(data.get("message", ""))
                
                # Save to database
                chat_message = ChatMessage(
                    user_id=user.id,
                    message=message_text if message_text else None,
                    message_type=data.get("message_type", "text"),
                    image_url=data.get("image_url"),
                    voice_url=data.get("voice_url")
                )
                db.add(chat_message)
                db.commit()
                db.refresh(chat_message)
                
                # Broadcast to all clients
                await manager.broadcast({
                    "type": "new_message",
                    "id": chat_message.id,
                    "user_id": user.id,
                    "user_name": user.full_name,
                    "message": chat_message.message,
                    "image_url": chat_message.image_url,
                    "voice_url": chat_message.voice_url,
                    "message_type": chat_message.message_type,
                    "created_at": chat_message.created_at.isoformat()
                })
            
            elif data.get("type") == "delete_message":
                # Check permissions
                if user.role not in [UserRole.ADMIN, UserRole.OPERATOR]:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Insufficient permissions"
                    })
                    continue
                
                message_id = data.get("message_id")
                message = db.query(ChatMessage).filter(ChatMessage.id == message_id).first()
                if message:
                    message.message = "This message was deleted by an admin."
                    message.message_type = "system"
                    message.image_url = None
                    message.voice_url = None
                    db.commit()
                    db.refresh(message)
                    
                    # Broadcast deletion
                    await manager.broadcast({
                        "type": "message_deleted",
                        "message_id": message_id,
                        "updated_message": {
                            "id": message.id,
                            "user_id": message.user_id,
                            "user_name": "System",
                            "message": message.message,
                            "image_url": None,
                            "voice_url": None,
                            "message_type": message.message_type,
                            "created_at": message.created_at.isoformat()
                        }
                    })
    
    except WebSocketDisconnect:
        if user:
            manager.disconnect(user.id)
    except Exception as e:
        print(f"WebSocket error: {e}")
        if user:
            manager.disconnect(user.id)
    finally:
        db.close()


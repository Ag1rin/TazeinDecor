"""
WebSocket manager for real-time chat
"""
from typing import Dict, List
from fastapi import WebSocket, WebSocketDisconnect
import json
import asyncio


class ConnectionManager:
    """Manages WebSocket connections"""
    
    def __init__(self):
        # Dictionary to store active connections: {user_id: WebSocket}
        self.active_connections: Dict[int, WebSocket] = {}
        # Dictionary to store connection metadata: {user_id: {"username": str, "role": str}}
        self.connection_metadata: Dict[int, Dict] = {}
        # Legacy alias for backward compatibility
        self.user_info: Dict[int, Dict] = self.connection_metadata
    
    async def connect(self, websocket: WebSocket, user_id: int, username: str, role: str):
        """Accept a new WebSocket connection"""
        await websocket.accept()
        self.active_connections[user_id] = websocket
        self.connection_metadata[user_id] = {
            "username": username,
            "role": role
        }
        print(f"User {user_id} ({username}) connected")
    
    def disconnect(self, user_id: int):
        """Remove a WebSocket connection"""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        if user_id in self.connection_metadata:
            del self.connection_metadata[user_id]
        print(f"User {user_id} disconnected")
    
    async def send_personal_message(self, message: dict, user_id: int):
        """Send a message to a specific user"""
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_json(message)
            except Exception as e:
                print(f"Error sending message to user {user_id}: {e}")
                self.disconnect(user_id)
    
    async def broadcast(self, message: dict, exclude_user_id: int = None):
        """Broadcast a message to all connected users"""
        disconnected = []
        for user_id, connection in self.active_connections.items():
            if exclude_user_id and user_id == exclude_user_id:
                continue
            try:
                await connection.send_json(message)
            except Exception as e:
                print(f"Error broadcasting to user {user_id}: {e}")
                disconnected.append(user_id)
        
        # Clean up disconnected users
        for user_id in disconnected:
            self.disconnect(user_id)
    
    def get_connected_users(self) -> List[Dict]:
        """Get list of connected users"""
        return [
            {"user_id": user_id, **metadata}
            for user_id, metadata in self.connection_metadata.items()
        ]


# Global connection manager instance
manager = ConnectionManager()


#!/usr/bin/env python3
"""
اسکریپت ساخت یوزرهای تستی روی سرور لیارا
با هش صحیح bcrypt — کاملاً هماهنگ با پروژه
"""

import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal, engine, Base
from app.models.users import User as DBUser
from app.routers.auth import get_password_hash # مهم: از همین تابع پروژه استفاده کن

# ساخت تیبل‌ها اگه وجود نداشته باشن
print("در حال ساخت تیبل‌ها در دیتابیس سرور...")
Base.metadata.create_all(bind=engine)
print("تیبل‌ها آماده شدند.")

db = SessionLocal()

users_to_create = [
    {
        "username": "admin",
        "password": "admin123",
        "email": "admin@tazeindecor.com",
        "full_name": "مدیر اصلی",
        "mobile": "09121111111",
        "role": "admin",
        "is_active": True
    },
    {
        "username": "seller",
        "password": "seller123",
        "email": "seller@tazeindecor.com",
        "full_name": "فروشنده تست",
        "mobile": "09122222222",
        "role": "seller",
        "is_active": True
    },
    {
        "username": "manager",
        "password": "manager123",
        "email": "manager@tazeindecor.com",
        "full_name": "مدیر فروش",
        "mobile": "09123333333",
        "role": "manager",
        "is_active": True
    },
    {
        "username": "clerk",
        "password": "clerk123",
        "email": "clerk@tazeindecor.com",
        "full_name": "کارمند انبار",
        "mobile": "09124444444",
        "role": "clerk",
        "is_active": True
    }
]

try:
    created_count = 0
    for user_data in users_to_create:
        username = user_data["username"]
        
        # چک کن قبلاً ساخته شده یا نه
        if db.query(DBUser).filter(DBUser.username == username).first():
            print(f"یوزر '{username}' قبلاً وجود داره — رد شد.")
            continue
        
        # هش پسورد با bcrypt (همون که تو لاگین استفاده می‌شه)
        hashed_password = get_password_hash(user_data["password"])
        
        new_user = DBUser(
            username=username,
            email=user_data["email"],
            password=hashed_password,
            full_name=user_data["full_name"],
            mobile=user_data["mobile"],
            role=user_data["role"],
            is_active=user_data["is_active"]
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        created_count += 1
        
        print(f"یوزر ساخته شد: {username} | پسورد: {user_data['password']} | نقش: {user_data['role']}")

    print("\n" + "="*60)
    if created_count > 0:
        print(f"{created_count} یوزر تستی با موفقیت ساخته شد!")
    else:
        print("همه یوزرها قبلاً وجود داشتن — چیزی ساخته نشد.")
    print("="*60)
    print("لاگین کن با:")
    print("   admin     → admin123")
    print("   seller    → seller123")
    print("   manager   → manager123")
    print("   clerk     → clerk123")
    print("="*60)
    print("پروژه کاملاً آماده استفاده است!")

except Exception as e:
    db.rollback()
    print(f"خطا در ساخت یوزرها: {e}")
    import traceback
    traceback.print_exc()
finally:
    db.close()
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_permission
from app.core.security import get_password_hash
from app.database import get_db
from app.models.user import User
from app.services.audit_logger import AuditLogger

router = APIRouter(tags=["Users"])


@router.get("/users")
def index(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    users = db.query(User).order_by(User.id.desc()).all()
    return [
        {
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "role": u.role,
            "is_active": bool(u.is_active),
            "phone": u.phone,
        }
        for u in users
    ]


@router.post("/users", status_code=201)
def store(
    payload: dict,
    current_user: User = Depends(require_permission("settings")),
    db: Session = Depends(get_db),
):
    name = payload.get("name")
    email = payload.get("email")
    password = payload.get("password")
    role = payload.get("role", "admin")

    if not name or not email or not password:
        raise HTTPException(status_code=422, detail={"errors": {"name": ["Required fields missing."]}})

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=422, detail={"errors": {"email": ["Email already taken."]}})

    user = User(
        name=name,
        email=email,
        password=get_password_hash(password),
        role=role,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    AuditLogger(db).write(current_user, "Created", "User", name)
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "is_active": bool(user.is_active),
    }


@router.put("/users/{user_id}")
def update(
    user_id: int,
    payload: dict,
    current_user: User = Depends(require_permission("settings")),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    if "is_active" in payload:
        user.is_active = bool(payload.get("is_active"))
    if "name" in payload:
        user.name = payload.get("name")
    if "phone" in payload:
        user.phone = payload.get("phone")

    db.commit()
    db.refresh(user)
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "is_active": bool(user.is_active),
    }


@router.delete("/users/{user_id}")
def destroy(
    user_id: int,
    current_user: User = Depends(require_permission("settings")),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    if user.id == current_user.id:
        raise HTTPException(status_code=422, detail="Cannot delete your own account.")
    db.delete(user)
    db.commit()
    return {"message": "User deleted."}

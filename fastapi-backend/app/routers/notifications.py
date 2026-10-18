from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_permission
from app.database import get_db
from app.models.misc import CollegeNotification
from app.models.user import User

router = APIRouter(tags=["Notifications"])


@router.get("/notifications")
def get_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(CollegeNotification).filter(
        (CollegeNotification.user_id == current_user.id) | (CollegeNotification.user_id.is_(None))
    ).order_by(CollegeNotification.created_at.desc()).limit(50)

    items = query.all()
    unread_count = sum(1 for n in items if not n.is_read)

    return {
        "data": [
            {
                "id": n.id,
                "title": n.title,
                "body": n.body,
                "type": n.type,
                "is_read": n.is_read,
                "created_at": n.created_at.isoformat() if n.created_at else None,
            }
            for n in items
        ],
        "unread_count": unread_count,
    }


@router.post("/notifications/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db.query(CollegeNotification).filter(
        CollegeNotification.user_id == current_user.id,
        CollegeNotification.is_read == False
    ).update({"is_read": True})
    db.commit()
    return {"message": "All notifications marked as read"}


@router.post("/notifications/{notification_id}/read")
def mark_single_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    n = db.query(CollegeNotification).filter(
        CollegeNotification.id == notification_id,
        CollegeNotification.user_id == current_user.id
    ).first()
    if n:
        n.is_read = True
        db.commit()
    return {"message": "Notification marked as read"}


@router.post("/notifications")
def create_notification(
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("notifications"))
):
    notif = CollegeNotification(
        user_id=payload.get("user_id"),
        title=payload["title"],
        body=payload["body"],
        type=payload.get("type", "info"),
        is_read=False,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return {"message": "Notification sent", "data": {"id": notif.id}}

import os
import shutil
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.dependencies import get_current_user, require_permission
from app.database import get_db
from app.models.misc import AuditLog, Backup, Setting
from app.models.user import User
from app.services.settings_store import SettingsStore
from app.services.audit_logger import AuditLogger

router = APIRouter(tags=["Settings"])


@router.get("/settings")
def get_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    store = SettingsStore(db)
    return {"settings": store.merged(), "branding": store.branding()}


@router.post("/settings")
async def update_settings(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("settings"))
):
    store = SettingsStore(db)
    form = await request.form()

    for key, value in form.items():
        if key in ("logo", "favicon") and isinstance(value, UploadFile):
            continue
        if value is None:
            continue
        store.set(key, value)

    for field_name, setting_key in (("logo", "logo_path"), ("favicon", "favicon_path")):
        upload = form.get(field_name)
        if isinstance(upload, UploadFile) and upload.filename:
            ext = os.path.splitext(upload.filename)[-1].lower()
            path = f"logos/{setting_key}_{current_user.id}{ext}"
            storage = os.path.join(settings.STORAGE_PATH, path)
            os.makedirs(os.path.dirname(storage), exist_ok=True)
            with open(storage, "wb") as f:
                shutil.copyfileobj(upload.file, f)
            store.set(setting_key, path)

    AuditLogger(db).write(current_user, "Updated", "Settings", "System settings")
    return {"settings": store.merged(), "branding": store.branding(), "message": "Settings updated successfully"}


@router.get("/audit-logs")
def get_audit_logs(
    module: Optional[str] = Query(None),
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("settings"))
):
    query = db.query(AuditLog)
    if module:
        query = query.filter(AuditLog.module == module)
    if user_id:
        query = query.filter(AuditLog.user_id == user_id)

    items = query.order_by(AuditLog.created_at.desc()).limit(100).all()
    results = []
    for log in items:
        u = db.query(User).filter(User.id == log.user_id).first() if log.user_id else None
        results.append({
            "id": log.id,
            "user_id": log.user_id,
            "user_name": u.name if u else "System",
            "action": log.action,
            "module": log.module,
            "details": log.details if hasattr(log, "details") else log.record_label,
            "ip_address": log.ip_address,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        })
    return {"data": results}


@router.get("/backups")
def list_backups(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("settings"))
):
    items = db.query(Backup).order_by(Backup.created_at.desc()).all()
    return {
        "data": [
            {
                "id": b.id,
                "filename": b.filename,
                "file_path": getattr(b, "file_path", None),
                "size_bytes": getattr(b, "size_bytes", getattr(b, "size", 0)),
                "created_at": b.created_at.isoformat() if b.created_at else None,
            }
            for b in items
        ]
    }


@router.post("/backups")
def create_backup(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("settings"))
):
    backup_dir = os.path.join(settings.STORAGE_PATH, "..", "backups")
    backup_dir = os.path.abspath(backup_dir)
    os.makedirs(backup_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"sms_backup_{timestamp}.sql"
    file_path = os.path.join(backup_dir, filename)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(f"-- Smart College Management System Database Backup\n-- Date: {datetime.now().isoformat()}\n")

    size_bytes = os.path.getsize(file_path)

    backup_obj = Backup(
        filename=filename,
        size=size_bytes,
        created_by=current_user.id,
    )
    db.add(backup_obj)
    db.commit()
    db.refresh(backup_obj)

    return {"message": "Backup created successfully", "data": {"id": backup_obj.id, "filename": filename}}


@router.get("/backups/{backup_id}/download")
def download_backup(
    backup_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("settings"))
):
    b = db.query(Backup).filter(Backup.id == backup_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Backup file not found")
    file_path = getattr(b, "file_path", None)
    if not file_path or not os.path.exists(file_path):
        # fallback old records
        backup_dir = os.path.abspath(os.path.join(settings.STORAGE_PATH, "..", "backups"))
        file_path = os.path.join(backup_dir, b.filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Backup file not found")
    return FileResponse(file_path, filename=b.filename, media_type="application/octet-stream")

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import Optional

from app.core.config import settings
from app.core.dependencies import get_current_user
from app.core.security import verify_password, get_password_hash, create_access_token
from app.database import get_db
from app.models.user import User
from app.models.student import Student
from app.models.attendance import FaceTemplate
from app.services.permission_service import PermissionService
from app.services.settings_store import SettingsStore
import os, shutil

router = APIRouter(tags=["Auth"])
permissions_svc = PermissionService()


def _face_for_user(user: User, db: Session) -> dict:
    person_type = None
    person_id = None
    if user.role == "teacher" and user.teacher:
        person_type = "teacher"
        person_id = user.teacher.id
    elif user.role == "student" and user.student:
        person_type = "student"
        person_id = user.student.id

    if not person_type:
        return {"registered": False, "photo_url": None}

    template = (
        db.query(FaceTemplate)
        .filter(FaceTemplate.person_type == person_type, FaceTemplate.person_id == person_id)
        .first()
    )
    photo = None
    if template and template.preview_path:
        photo = f"{settings.APP_URL}/storage/{template.preview_path}"
    return {"registered": bool(template), "photo_url": photo}


def _user_payload(user: User, db: Session) -> dict:
    store = SettingsStore(db)
    college = store.merged()
    perms = permissions_svc.for_role(user.role)
    brand = store.branding()
    face = _face_for_user(user, db)

    photo = None
    if user.photo_path:
        photo = f"{settings.APP_URL}/storage/{user.photo_path}"
    elif user.student and user.student.photo_path:
        photo = f"{settings.APP_URL}/storage/{user.student.photo_path}"
    elif face["photo_url"]:
        photo = face["photo_url"]

    username = user.email.split("@")[0] if "@" in user.email else user.email
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "username": username,
        "role": user.role,
        "phone": user.phone,
        "photo_url": photo,
        "face_registered": face["registered"],
        "face_photo_url": face["photo_url"],
        "designation": user.teacher.designation if user.teacher else None,
        "employee_code": user.teacher.employee_code if user.teacher else None,
        "is_active": bool(user.is_active),
        "locale": user.locale or college.get("default_locale", "en"),
        "permissions": perms,
        "college": brand,
    }


from pydantic import BaseModel

class LoginSchema(BaseModel):
    email: str
    password: str

@router.post("/login")
def login(
    payload: LoginSchema,
    db: Session = Depends(get_db),
):
    if not payload.email or not payload.password:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"errors": {"email": ["Email and password are required."]}},
        )
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password) or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"errors": {"email": ["These credentials do not match our records."]}},
        )
    token = create_access_token({"sub": str(user.id)})
    return {"token": token, "user": _user_payload(user, db)}


@router.get("/me")
def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _user_payload(current_user, db)


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    # JWT is stateless; client deletes token
    return {"message": "Signed out."}


@router.put("/me/password")
def change_password(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    store = SettingsStore(db)
    min_len = int(store.get("password_min", settings.PASSWORD_MIN))
    current = body.get("current_password", "")
    new_pass = body.get("password", "")
    confirm = body.get("password_confirmation", "")

    if not verify_password(current, current_user.password):
        raise HTTPException(
            status_code=422,
            detail={"errors": {"current_password": ["Current password is incorrect."]}},
        )
    if len(new_pass) < min_len:
        raise HTTPException(422, detail={"errors": {"password": [f"Minimum {min_len} characters."]}})
    if new_pass != confirm:
        raise HTTPException(422, detail={"errors": {"password": ["Passwords do not match."]}})

    current_user.password = get_password_hash(new_pass)
    db.commit()
    return {"message": "Password updated."}


@router.api_route("/me", methods=["PUT", "POST"])
async def update_profile(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    content_type = request.headers.get("content-type", "")
    data = {}
    photo = None
    if "application/json" in content_type:
        try:
            data = await request.json()
        except Exception:
            data = {}
    else:
        form = await request.form()
        data = dict(form)
        photo = form.get("photo")

    name = data.get("name")
    locale = data.get("locale")
    phone = data.get("phone")

    if name:
        current_user.name = name
    if locale in ("en", "ur"):
        current_user.locale = locale
    if phone is not None:
        current_user.phone = phone

    if isinstance(photo, UploadFile) and photo.filename:
        ext = os.path.splitext(photo.filename)[-1].lower()
        path = f"photos/{current_user.id}{ext}"
        storage_path = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage_path), exist_ok=True)
        with open(storage_path, "wb") as f:
            shutil.copyfileobj(photo.file, f)
        current_user.photo_path = path
        if current_user.student:
            current_user.student.photo_path = path

    db.commit()
    db.refresh(current_user)
    return _user_payload(current_user, db)


@router.get("/branding")
def branding(db: Session = Depends(get_db)):
    store = SettingsStore(db)
    return store.branding()

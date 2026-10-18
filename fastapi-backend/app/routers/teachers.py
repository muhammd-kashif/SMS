import os
import shutil
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.dependencies import get_current_user
from app.core.security import get_password_hash
from app.database import get_db
from app.models.teacher import Teacher, TeacherAssignment
from app.models.user import User
from app.services.audit_logger import AuditLogger

router = APIRouter(tags=["Teachers"])


def _brief(teacher: Teacher) -> dict:
    photo = None
    if teacher.user and teacher.user.photo_path:
        photo = f"{settings.APP_URL}/storage/{teacher.user.photo_path}"
    face_photo = None
    if teacher.face_template and teacher.face_template.preview_path:
        face_photo = f"{settings.APP_URL}/storage/{teacher.face_template.preview_path}"
    return {
        "id": teacher.id,
        "user_id": teacher.user_id,
        "name": teacher.user.name if teacher.user else None,
        "email": teacher.user.email if teacher.user else None,
        "employee_code": teacher.employee_code,
        "designation": teacher.designation,
        "gender": teacher.gender,
        "qualification": teacher.qualification,
        "salary": float(teacher.monthly_salary) if teacher.monthly_salary is not None else None,
        "phone": teacher.phone,
        "joining_date": teacher.joining_date.isoformat() if teacher.joining_date else None,
        "status": teacher.status,
        "is_active": teacher.user.is_active if teacher.user else False,
        "photo_url": photo,
        "face_registered": teacher.face_template is not None,
        "face_photo_url": face_photo,
        "assignments": [
            {
                "id": a.id,
                "class_id": a.class_id,
                "section_id": a.section_id,
                "subject_id": a.subject_id,
                "class_name": a.school_class.name if a.school_class else None,
                "section_name": a.section.name if a.section else None,
                "subject_name": a.subject.name if a.subject else None,
            }
            for a in teacher.assignments
        ],
    }


@router.get("/teachers")
def index(
    search: Optional[str] = None,
    status_filter: Optional[str] = None,
    page: int = 1,
    per_page: int = 20,
    all: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Teacher).join(Teacher.user)
    if search:
        query = query.filter(
            (Teacher.employee_code.ilike(f"%{search}%"))
            | (Teacher.designation.ilike(f"%{search}%"))
            | (User.name.ilike(f"%{search}%"))
        )
    if status_filter:
        query = query.filter(Teacher.status == status_filter)
    total = query.count()
    teachers = query.offset((page - 1) * per_page).limit(per_page if not all else 500).all()
    return {
        "data": [_brief(t) for t in teachers],
        "total": total,
        "current_page": page,
        "last_page": max(1, (total + per_page - 1) // per_page),
    }


@router.post("/teachers", status_code=201)
def store(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(403, "Admin only.")

    name = payload.get("name")
    email = payload.get("email")
    password = payload.get("password")
    employee_code = payload.get("employee_code") or payload.get("code")
    designation = payload.get("designation")
    phone = payload.get("phone")
    gender = payload.get("gender")
    qualification = payload.get("qualification")
    monthly_salary = payload.get("salary")
    joining_date = payload.get("joining_date")

    if not name or not email or not password or not employee_code:
        raise HTTPException(422, detail={"errors": {"name": ["Required fields missing."]}})

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(422, detail={"errors": {"email": ["Email already taken."]}})
    if db.query(Teacher).filter(Teacher.employee_code == employee_code).first():
        raise HTTPException(422, detail={"errors": {"employee_code": ["Employee code already taken."]}})

    user = User(
        name=name, email=email, password=get_password_hash(password),
        role="teacher", phone=phone, is_active=True,
    )
    db.add(user)
    db.flush()

    teacher = Teacher(
        user_id=user.id,
        employee_code=employee_code,
        gender=gender,
        qualification=qualification,
        designation=designation,
        monthly_salary=float(monthly_salary) if monthly_salary not in (None, "") else None,
        phone=phone,
        joining_date=date.fromisoformat(joining_date) if joining_date else None,
    )
    db.add(teacher)
    db.commit()
    db.refresh(teacher)

    # assignments optional
    assignments = payload.get("assignments") or []
    if isinstance(assignments, list):
        for a in assignments:
            if a and a.get("class_id") and a.get("subject_id"):
                ta = TeacherAssignment(
                    teacher_id=teacher.id,
                    class_id=a.get("class_id"),
                    section_id=a.get("section_id"),
                    subject_id=a.get("subject_id"),
                )
                db.add(ta)
        db.commit()

    AuditLogger(db).write(current_user, "Created", "Teacher", name)
    db.refresh(teacher)
    return _brief(teacher)


@router.get("/teachers/{teacher_id}")
def show(
    teacher_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
    if not teacher:
        raise HTTPException(404)
    return _brief(teacher)


@router.put("/teachers/{teacher_id}")
def update(
    teacher_id: int,
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(403, "Admin only.")
    teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
    if not teacher:
        raise HTTPException(404)
    user = teacher.user
    if not user:
        raise HTTPException(404)

    if "name" in payload:
        user.name = payload.get("name") or user.name
    if "email" in payload and payload.get("email"):
        existing = db.query(User).filter(User.email == payload.get("email"), User.id != user.id).first()
        if existing:
            raise HTTPException(422, detail={"errors": {"email": ["Email already taken."]}})
        user.email = payload.get("email")
    if "phone" in payload:
        user.phone = payload.get("phone")
        teacher.phone = payload.get("phone")
    if "password" in payload and payload.get("password"):
        user.password = get_password_hash(payload.get("password"))
    if "gender" in payload:
        teacher.gender = payload.get("gender")
    if "qualification" in payload:
        teacher.qualification = payload.get("qualification")
    if "designation" in payload:
        teacher.designation = payload.get("designation")
    if "salary" in payload:
        val = payload.get("salary")
        teacher.monthly_salary = float(val) if val not in (None, "") else None
    if "joining_date" in payload:
        val = payload.get("joining_date")
        teacher.joining_date = date.fromisoformat(val) if val else None
    if "status" in payload:
        teacher.status = payload.get("status")
        user.is_active = payload.get("status") == "active"

    # replace assignments if provided
    if "assignments" in payload and isinstance(payload.get("assignments"), list):
        # remove old
        db.query(TeacherAssignment).filter(TeacherAssignment.teacher_id == teacher.id).delete()
        for a in payload.get("assignments") or []:
            if a and a.get("class_id") and a.get("subject_id"):
                db.add(TeacherAssignment(
                    teacher_id=teacher.id,
                    class_id=a.get("class_id"),
                    section_id=a.get("section_id"),
                    subject_id=a.get("subject_id"),
                ))

    db.commit()
    db.refresh(teacher)
    AuditLogger(db).write(current_user, "Updated", "Teacher", user.name)
    return _brief(teacher)


@router.put("/teachers/{teacher_id}/status")
def set_status(
    teacher_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(403)
    teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
    if not teacher:
        raise HTTPException(404)
    new_status = body.get("status")
    if new_status not in ("active", "inactive"):
        raise HTTPException(422)
    teacher.status = new_status
    if teacher.user:
        teacher.user.is_active = new_status == "active"
    db.commit()
    AuditLogger(db).write(current_user, new_status.capitalize() + "d", "Teacher", teacher.user.name if teacher.user else "")
    db.refresh(teacher)
    return _brief(teacher)


@router.delete("/teachers/{teacher_id}")
def destroy(
    teacher_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(403)
    teacher = db.query(Teacher).filter(Teacher.id == teacher_id).first()
    if not teacher:
        raise HTTPException(404)
    teacher.status = "inactive"
    if teacher.user:
        teacher.user.is_active = False
    db.commit()
    AuditLogger(db).write(current_user, "Deactivated", "Teacher", teacher.user.name if teacher.user else "")
    return {"message": "Teacher deactivated."}

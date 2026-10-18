import os
import shutil
from datetime import date as dtdate
from typing import Optional

from fastapi import (
    APIRouter, Depends, File, Form, HTTPException, Request,
    Query, UploadFile, status,
)
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.dependencies import get_current_user
from app.core.security import get_password_hash
from app.database import get_db
from app.models.student import Guardian, Student
from app.models.structure import Section
from app.models.user import User
from app.services.attendance_service import AttendanceService
from app.services.audit_logger import AuditLogger
from app.services.settings_store import SettingsStore

router = APIRouter(tags=["Students"])


def _photo_url(path: Optional[str]) -> Optional[str]:
    if path:
        return f"{settings.APP_URL}/storage/{path}"
    return None


def _brief(student: Student) -> dict:
    return {
        "id": student.id,
        "name": student.user.name if student.user else None,
        "email": student.user.email if student.user else None,
        "student_code": student.student_code,
        "roll_number": student.roll_number,
        "father_name": student.father_name,
        "gender": student.gender,
        "phone": student.phone,
        "parent_phone": student.parent_phone,
        "class_id": student.class_id,
        "section_id": student.section_id,
        "session_id": student.session_id,
        "class_name": student.school_class.name if student.school_class else None,
        "section_name": student.section.name if student.section else None,
        "session_name": student.session.name if student.session else None,
        "status": student.status,
        "photo_url": _photo_url(student.photo_path),
        "face_registered": student.face_template is not None,
        "face_photo_url": student.face_template.preview_url if student.face_template else None,
        "admission_date": student.admission_date.isoformat() if student.admission_date else None,
    }


def _full(student: Student, db: Session) -> dict:
    att_svc = AttendanceService(db)
    base = _brief(student)
    guardian = student.guardian
    fees = student.fees
    total = round(sum(f.total_due for f in fees), 2)
    paid = round(sum(float(f.paid_amount or 0) for f in fees), 2)
    pending = round(total - paid, 2)
    return {
        **base,
        "dob": student.dob.isoformat() if student.dob else None,
        "address": student.address,
        "leave_allowance": student.leave_allowance,
        "guardian": {
            "id": guardian.id,
            "name": guardian.name,
            "phone": guardian.phone,
            "email": guardian.email,
        } if guardian else None,
        "attendance": att_svc.summary_for_student(student),
        "fees": {
            "total": total,
            "paid": paid,
            "pending": pending,
            "items": [
                {
                    "id": f.id,
                    "title": f.title,
                    "amount": float(f.amount),
                    "paid_amount": float(f.paid_amount or 0),
                    "pending_amount": f.pending_amount,
                    "due_date": f.due_date.isoformat() if f.due_date else None,
                    "status": f.status,
                    "fee_type": f.fee_type,
                }
                for f in fees
            ],
        },
        "payments": [
            {
                "id": p.id,
                "receipt_no": p.receipt_no,
                "amount": float(p.amount),
                "method": p.method,
                "paid_at": p.paid_at.isoformat() if p.paid_at else None,
                "status": p.status,
            }
            for p in student.payments
        ],
        "marks": [
            {
                "id": m.id,
                "subject": m.subject.name if m.subject else None,
                "total_marks": float(m.total_marks),
                "obtained_marks": float(m.obtained_marks),
                "grade": m.grade,
                "remarks": m.remarks,
            }
            for m in student.marks
        ],
        "leaves": [
            {
                "id": lv.id,
                "leave_type": lv.leave_type,
                "start_date": lv.start_date.isoformat() if lv.start_date else None,
                "end_date": lv.end_date.isoformat() if lv.end_date else None,
                "status": lv.status,
                "days": lv.days,
            }
            for lv in student.leaves
        ],
    }


def _require_admin(user: User):
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Only an administrator can change student records.")


def _assert_section(class_id: int, section_id: int, db: Session):
    section = db.query(Section).filter(Section.id == section_id).first()
    if not section or section.class_id != class_id:
        raise HTTPException(status_code=422, detail="The selected section does not belong to the class.")


def _guardian_id(data: dict, db: Session) -> Optional[int]:
    parent_name = data.get("parent_name")
    parent_email = data.get("parent_email")
    if not parent_name and not parent_email:
        return None
    parent_user = None
    if parent_email:
        parent_user = db.query(User).filter(User.email == parent_email).first()
        if not parent_user:
            parent_user = User(
                name=parent_name or "Parent",
                email=parent_email,
                password=get_password_hash(data.get("password", "College@123")),
                role="parent",
                phone=data.get("parent_phone"),
                is_active=True,
            )
            db.add(parent_user)
            db.flush()
    attrs = {
        "name": parent_name or (parent_user.name if parent_user else "Parent"),
        "phone": data.get("parent_phone"),
        "email": parent_email,
        "address": data.get("address"),
    }
    if parent_user:
        g = db.query(Guardian).filter(Guardian.user_id == parent_user.id).first()
        if g:
            for k, v in attrs.items():
                setattr(g, k, v)
        else:
            g = Guardian(**attrs, user_id=parent_user.id)
            db.add(g)
        db.flush()
        return g.id
    g = Guardian(**attrs)
    db.add(g)
    db.flush()
    return g.id


@router.get("/students")
def index(
    search: Optional[str] = None,
    class_id: Optional[int] = None,
    section_id: Optional[int] = None,
    gender: Optional[str] = None,
    session_id: Optional[int] = None,
    status_filter: Optional[str] = Query(None, alias="status"),
    face: Optional[str] = None,
    sort: str = "roll_number",
    direction: str = "asc",
    page: int = 1,
    per_page: int = 20,
    all: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Student)
        .join(Student.user)
        .outerjoin(Student.school_class)
        .outerjoin(Student.section)
        .outerjoin(Student.session)
    )
    if search:
        query = query.filter(
            (Student.student_code.ilike(f"%{search}%"))
            | (Student.roll_number.ilike(f"%{search}%"))
            | (Student.father_name.ilike(f"%{search}%"))
            | (Student.phone.ilike(f"%{search}%"))
            | (User.name.ilike(f"%{search}%"))
        )
    if class_id:
        query = query.filter(Student.class_id == class_id)
    if section_id:
        query = query.filter(Student.section_id == section_id)
    if gender:
        query = query.filter(Student.gender == gender)
    if session_id:
        query = query.filter(Student.session_id == session_id)
    if status_filter:
        query = query.filter(Student.status == status_filter)

    total = query.count()
    students = query.offset((page - 1) * per_page).limit(per_page if not all else 500).all()
    return {
        "data": [_brief(s) for s in students],
        "total": total,
        "current_page": page,
        "last_page": max(1, (total + per_page - 1) // per_page),
    }


@router.post("/students", status_code=201)
async def store(
    name: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    roll_number: str = Form(...),
    class_id: int = Form(...),
    section_id: int = Form(...),
    session_id: Optional[int] = Form(None),
    father_name: Optional[str] = Form(None),
    dob: Optional[str] = Form(None),
    gender: Optional[str] = Form(None),
    phone: Optional[str] = Form(None),
    parent_phone: Optional[str] = Form(None),
    address: Optional[str] = Form(None),
    admission_date: Optional[str] = Form(None),
    leave_allowance: Optional[int] = Form(None),
    parent_name: Optional[str] = Form(None),
    parent_email: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    _assert_section(class_id, section_id, db)

    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise HTTPException(422, detail={"errors": {"email": ["Email already taken."]}})

    store_svc = SettingsStore(db)
    user = User(
        name=name, email=email,
        password=get_password_hash(password),
        role="student", phone=phone, is_active=True,
        locale=store_svc.get("default_locale", "en"),
    )
    db.add(user)
    db.flush()

    data = {
        "name": name, "email": email, "password": password,
        "parent_name": parent_name, "parent_email": parent_email,
        "parent_phone": parent_phone, "address": address,
    }
    guardian_id = _guardian_id(data, db)

    last_id = (db.query(Student).count() or 0)
    student_code = f"STU-{str(last_id + 1).zfill(5)}"

    photo_path = None
    if photo and photo.filename:
        ext = os.path.splitext(photo.filename)[-1].lower()
        path = f"photos/student_{user.id}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(photo.file, f)
        photo_path = path

    from datetime import date as dtdate
    student = Student(
        user_id=user.id,
        guardian_id=guardian_id,
        student_code=student_code,
        roll_number=roll_number,
        class_id=class_id,
        section_id=section_id,
        session_id=session_id,
        father_name=father_name,
        dob=dtdate.fromisoformat(dob) if dob else None,
        gender=gender,
        phone=phone,
        parent_phone=parent_phone,
        address=address,
        admission_date=dtdate.fromisoformat(admission_date) if admission_date else dtdate.today(),
        leave_allowance=leave_allowance or int(store_svc.get("default_leave_allowance", 20)),
        photo_path=photo_path,
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    AuditLogger(db).write(current_user, "Created", "Student", user.name)
    return _full(student, db)


@router.put("/students/{student_id}")
async def update(
    student_id: int,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(404, detail="Student not found.")

    form = await request.form()

    # Update user (name, email, phone, password)
    user = student.user
    if "name" in form:
        user.name = form.get("name") or user.name
    if "email" in form and form.get("email"):
        existing = db.query(User).filter(User.email == form.get("email"), User.id != user.id).first()
        if existing:
            raise HTTPException(422, detail={"errors": {"email": ["Email already taken."]}})
        user.email = form.get("email")
    if "phone" in form:
        user.phone = form.get("phone") or None
    if "password" in form and form.get("password"):
        user.password = get_password_hash(form.get("password"))
    if "status" in form:
        student.status = form.get("status")
        user.is_active = form.get("status") == "active"

    # Class/section validation
    class_id = form.get("class_id")
    section_id = form.get("section_id")
    if class_id and section_id:
        _assert_section(int(class_id), int(section_id), db)
        student.class_id = int(class_id)
        student.section_id = int(section_id)

    simple_fields = ["father_name", "gender", "parent_phone", "address", "roll_number", "student_code"]
    # not update student_code unless provided
    for key in ["father_name", "gender", "parent_phone", "address", "roll_number"]:
        if key in form:
            setattr(student, key, form.get(key) or getattr(student, key))

    if "dob" in form and form.get("dob"):
        try:
            student.dob = dtdate.fromisoformat(form.get("dob"))
        except Exception:
            pass
    if "admission_date" in form and form.get("admission_date"):
        try:
            student.admission_date = dtdate.fromisoformat(form.get("admission_date"))
        except Exception:
            pass
    if "leave_allowance" in form and form.get("leave_allowance"):
        try:
            student.leave_allowance = int(form.get("leave_allowance"))
        except Exception:
            pass
    if "session_id" in form:
        val = form.get("session_id")
        student.session_id = int(val) if val else None

    # Guardian upsert
    if "parent_name" in form or "parent_email" in form:
        data = {
            "parent_name": form.get("parent_name"),
            "parent_email": form.get("parent_email"),
            "parent_phone": form.get("parent_phone"),
            "address": form.get("address"),
            "password": form.get("password") or "College@123",
        }
        guardian_id = _guardian_id(data, db)
        if guardian_id:
            student.guardian_id = guardian_id

    # Photo upload
    photo = form.get("photo")
    if hasattr(photo, "filename") and photo.filename:
        ext = os.path.splitext(photo.filename)[-1].lower()
        path = f"photos/student_{user.id}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(photo.file, f)
        student.photo_path = path
        user.photo_path = path

    db.commit()
    db.refresh(student)
    AuditLogger(db).write(current_user, "Updated", "Student", user.name)
    return _full(student, db)


@router.get("/students/{student_id}")
def show(
    student_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(404, detail="Student not found.")
    return _full(student, db)


@router.put("/students/{student_id}/status")
def set_status(
    student_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(404)
    new_status = body.get("status")
    if new_status not in ("active", "inactive"):
        raise HTTPException(422, detail="Invalid status.")
    student.status = new_status
    if student.user:
        student.user.is_active = new_status == "active"
    db.commit()
    AuditLogger(db).write(current_user, new_status.capitalize() + "d", "Student", student.user.name if student.user else "")
    db.refresh(student)
    return _brief(student)


@router.delete("/students/{student_id}")
def destroy(
    student_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(404)
    student.status = "withdrawn"
    if student.user:
        student.user.is_active = False
    db.commit()
    AuditLogger(db).write(current_user, "Withdrew", "Student", student.user.name if student.user else "")
    return {"message": "Student withdrawn."}

from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.attendance import Attendance
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.user import User
from app.services.attendance_service import AttendanceService
from app.services.audit_logger import AuditLogger

router = APIRouter(tags=["Attendance"])


def _att_row(row: Attendance, person, person_type: str) -> dict:
    return {
        "id": row.id,
        "person_type": person_type,
        "person_id": row.person_id,
        "name": person.user.name if person and person.user else None,
        "code": person.student_code if person_type == "student" else person.employee_code if person else None,
        "roll_number": person.roll_number if person_type == "student" else None,
        "class_name": person.school_class.name if person_type == "student" and person and person.school_class else None,
        "section_name": person.section.name if person_type == "student" and person and person.section else None,
        "date": row.attendance_date.isoformat() if row.attendance_date else None,
        "check_in": row.check_in_time.strftime("%I:%M %p") if row.check_in_time else None,
        "status": row.status,
        "source": row.source,
        "notes": row.notes,
        "confidence": float(row.confidence) if row.confidence else None,
    }


@router.get("/attendance")
def index(
    person_type: str = "student",
    date_filter: Optional[str] = Query(None, alias="date"),
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    status_filter: Optional[str] = Query(None, alias="status"),
    source: Optional[str] = None,
    student_id: Optional[int] = None,
    class_id: Optional[int] = None,
    section_id: Optional[int] = None,
    search: Optional[str] = None,
    page: int = 1,
    per_page: int = 20,
    all: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Attendance).filter(Attendance.person_type == person_type)
    if date_filter:
        query = query.filter(Attendance.attendance_date == date.fromisoformat(date_filter))
    if from_date:
        query = query.filter(Attendance.attendance_date >= date.fromisoformat(from_date))
    if to_date:
        query = query.filter(Attendance.attendance_date <= date.fromisoformat(to_date))
    if status_filter:
        query = query.filter(Attendance.status == status_filter)
    if source:
        query = query.filter(Attendance.source == source)

    if person_type == "student":
        student_ids_query = db.query(Student.id)
        if student_id:
            student_ids_query = student_ids_query.filter(Student.id == student_id)
        if class_id:
            student_ids_query = student_ids_query.filter(Student.class_id == class_id)
        if section_id:
            student_ids_query = student_ids_query.filter(Student.section_id == section_id)
        ids = [r[0] for r in student_ids_query.all()]
        query = query.filter(Attendance.person_id.in_(ids))

    query = query.order_by(Attendance.attendance_date.desc())
    total = query.count()
    rows = query.offset((page - 1) * per_page).limit(per_page if not all else 5000).all()

    person_ids = list({r.person_id for r in rows})
    if person_type == "student":
        people = {s.id: s for s in db.query(Student).filter(Student.id.in_(person_ids)).all()}
    else:
        people = {t.id: t for t in db.query(Teacher).filter(Teacher.id.in_(person_ids)).all()}

    summary_q = db.query(Attendance).filter(Attendance.person_type == person_type)
    if person_type == "student" and ids:
        summary_q = summary_q.filter(Attendance.person_id.in_(ids))
    all_rows = summary_q.all()
    summary = {
        "present": sum(1 for r in all_rows if r.status == "present"),
        "absent": sum(1 for r in all_rows if r.status == "absent"),
        "late": sum(1 for r in all_rows if r.status == "late"),
        "leave": sum(1 for r in all_rows if r.status == "leave"),
    }

    return {
        "summary": summary,
        "data": [_att_row(r, people.get(r.person_id), person_type) for r in rows],
        "total": total,
        "current_page": page,
        "last_page": max(1, (total + per_page - 1) // per_page),
        "from": (page - 1) * per_page + 1 if rows else 0,
        "to": (page - 1) * per_page + len(rows),
    }


@router.post("/attendance/manual")
def manual(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    person_type = body.get("person_type", "student")
    person_id = int(body.get("person_id", 0))
    dt = body.get("date")
    time_str = body.get("time", "08:00")
    status = body.get("status", "present")
    notes = body.get("notes")

    if status not in ("present", "absent", "late", "leave"):
        raise HTTPException(422, "Invalid status.")

    if person_type == "student":
        if not db.query(Student).filter(Student.id == person_id).first():
            raise HTTPException(404, "Student not found.")
    else:
        if not db.query(Teacher).filter(Teacher.id == person_id).first():
            raise HTTPException(404, "Teacher not found.")

    at = datetime.fromisoformat(f"{dt}T{time_str}:00")
    svc = AttendanceService(db)
    result = svc.mark(person_type, person_id, at, status, "manual", notes=notes, overwrite=True)

    AuditLogger(db).write(current_user, f"Marked {status}", "Attendance", f"{person_type} #{person_id}")

    row = result["attendance"]
    return {
        "id": row.id,
        "person_type": row.person_type,
        "person_id": row.person_id,
        "date": row.attendance_date.isoformat() if row.attendance_date else None,
        "status": row.status,
        "source": row.source,
        "notes": row.notes,
    }


@router.post("/attendance/close-day")
def close_day(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(403)
    day = date.fromisoformat(body.get("date"))
    class_id = body.get("class_id")
    section_id = body.get("section_id")
    svc = AttendanceService(db)
    count = svc.close_day(day, class_id, section_id)
    AuditLogger(db).write(current_user, "Closed day", "Attendance", f"{day} ({count} records)")
    return {"created": count}

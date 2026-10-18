from datetime import date, datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status
from sqlalchemy.orm import Session
import os
import shutil

from app.core.config import settings
from app.core.dependencies import get_current_user, require_permission
from app.database import get_db
from app.models.academic import Homework, Assignment, AssignmentSubmission, TimetableSlot, Announcement
from app.models.structure import SchoolClass, Section, Subject
from app.models.teacher import Teacher
from app.models.user import User

router = APIRouter(tags=["Academics"])

from datetime import time as _t
def _time(v):
    if v is None or v == "":
        return None
    if isinstance(v, _t):
        return v
    try:
        h, m = str(v).split(":")[:2]
        return _t(int(h), int(m))
    except Exception:
        return v


# Homework
@router.get("/homework")
def get_homework_list(
    class_id: Optional[int] = Query(None),
    section_id: Optional[int] = Query(None),
    subject_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Homework)
    if class_id:
        query = query.filter(Homework.class_id == class_id)
    if section_id:
        query = query.filter(Homework.section_id == section_id)
    if subject_id:
        query = query.filter(Homework.subject_id == subject_id)

    items = query.order_by(Homework.created_at.desc()).all()
    results = []
    for hw in items:
        results.append({
            "id": hw.id,
            "class_id": hw.class_id,
            "school_class": {"id": hw.school_class.id, "name": hw.school_class.name} if hw.school_class else None,
            "section_id": hw.section_id,
            "section": {"id": hw.section.id, "name": hw.section.name} if hw.section else None,
            "subject_id": hw.subject_id,
            "subject": {"id": hw.subject.id, "name": hw.subject.name} if hw.subject else None,
            "title": hw.title,
            "description": hw.description,
            "due_date": hw.due_date.isoformat() if hw.due_date else None,
            "attachment_path": hw.file_path,
        })
    return results


@router.post("/homework")
async def create_homework(
    title: str = Form(...),
    class_id: int = Form(...),
    subject_id: Optional[int] = Form(None),
    section_id: Optional[int] = Form(None),
    due_date: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    file_path = None
    if file and file.filename:
        ext = os.path.splitext(file.filename)[-1].lower()
        path = f"homework/hw_{current_user.id}_{int(datetime.now().timestamp())}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(file.file, f)
        file_path = path

    hw = Homework(
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        title=title,
        description=description,
        due_date=date.fromisoformat(due_date) if due_date else date.today(),
        file_path=file_path,
    )
    db.add(hw)
    db.commit()
    db.refresh(hw)
    return {"message": "Homework created successfully", "data": {"id": hw.id}}


@router.put("/homework/{homework_id}")
async def update_homework(
    homework_id: int,
    title: str = Form(None),
    class_id: Optional[int] = Form(None),
    subject_id: Optional[int] = Form(None),
    section_id: Optional[int] = Form(None),
    due_date: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    hw = db.query(Homework).filter(Homework.id == homework_id).first()
    if not hw:
        raise HTTPException(status_code=404, detail="Homework not found")
    if title is not None:
        hw.title = title
    if class_id is not None:
        hw.class_id = class_id
    if subject_id is not None:
        hw.subject_id = subject_id
    if section_id is not None:
        hw.section_id = section_id
    if due_date:
        hw.due_date = date.fromisoformat(due_date)
    if description is not None:
        hw.description = description
    if file and file.filename:
        ext = os.path.splitext(file.filename)[-1].lower()
        path = f"homework/hw_{current_user.id}_{int(datetime.now().timestamp())}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(file.file, f)
        hw.file_path = path
    db.commit()
    db.refresh(hw)
    return {"message": "Homework updated", "data": {"id": hw.id}}


@router.delete("/homework/{homework_id}")
def delete_homework(
    homework_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    hw = db.query(Homework).filter(Homework.id == homework_id).first()
    if not hw:
        raise HTTPException(status_code=404, detail="Homework not found")
    db.delete(hw)
    db.commit()
    return {"message": "Homework deleted"}


# Assignments
@router.get("/assignments")
def get_assignments(
    class_id: Optional[int] = Query(None),
    section_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Assignment)
    if class_id:
        query = query.filter(Assignment.class_id == class_id)
    if section_id:
        query = query.filter(Assignment.section_id == section_id)

    items = query.order_by(Assignment.created_at.desc()).all()
    results = []
    for ass in items:
        results.append({
            "id": ass.id,
            "class_id": ass.class_id,
            "school_class": {"id": ass.school_class.id, "name": ass.school_class.name} if ass.school_class else None,
            "section_id": ass.section_id,
            "section": {"id": ass.section.id, "name": ass.section.name} if ass.section else None,
            "subject_id": ass.subject_id,
            "subject": {"id": ass.subject.id, "name": ass.subject.name} if ass.subject else None,
            "title": ass.title,
            "description": ass.description,
            "total_marks": ass.total_marks,
            "due_date": ass.due_date.isoformat() if ass.due_date else None,
            "attachment_path": ass.file_path,
        })
    return results


@router.post("/assignments")
async def create_assignment(
    title: str = Form(...),
    class_id: int = Form(...),
    subject_id: Optional[int] = Form(None),
    section_id: Optional[int] = Form(None),
    due_date: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    total_marks: Optional[int] = Form(100),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    file_path = None
    if file and file.filename:
        ext = os.path.splitext(file.filename)[-1].lower()
        path = f"assignments/asg_{current_user.id}_{int(datetime.now().timestamp())}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(file.file, f)
        file_path = path

    ass = Assignment(
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        title=title,
        description=description,
        total_marks=total_marks or 100,
        due_date=date.fromisoformat(due_date) if due_date else date.today(),
        file_path=file_path,
    )
    db.add(ass)
    db.commit()
    db.refresh(ass)
    return {"message": "Assignment created", "data": {"id": ass.id}}


@router.put("/assignments/{assignment_id}")
async def update_assignment(
    assignment_id: int,
    title: str = Form(None),
    class_id: Optional[int] = Form(None),
    subject_id: Optional[int] = Form(None),
    section_id: Optional[int] = Form(None),
    due_date: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    total_marks: Optional[int] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ass = db.query(Assignment).filter(Assignment.id == assignment_id).first()
    if not ass:
        raise HTTPException(status_code=404, detail="Assignment not found")
    if title is not None:
        ass.title = title
    if class_id is not None:
        ass.class_id = class_id
    if subject_id is not None:
        ass.subject_id = subject_id
    if section_id is not None:
        ass.section_id = section_id
    if due_date:
        ass.due_date = date.fromisoformat(due_date)
    if description is not None:
        ass.description = description
    if total_marks is not None:
        ass.total_marks = total_marks
    if file and file.filename:
        ext = os.path.splitext(file.filename)[-1].lower()
        path = f"assignments/asg_{current_user.id}_{int(datetime.now().timestamp())}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(file.file, f)
        ass.file_path = path
    db.commit()
    db.refresh(ass)
    return {"message": "Assignment updated", "data": {"id": ass.id}}


@router.post("/assignments/{assignment_id}/submit")
async def submit_assignment(
    assignment_id: int,
    student_id: int = Form(...),
    note: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    assignment = db.query(Assignment).filter(Assignment.id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    file_path = None
    if file and file.filename:
        ext = os.path.splitext(file.filename)[-1].lower()
        path = f"assignments/submission_{assignment_id}_{student_id}_{int(datetime.now().timestamp())}{ext}"
        storage = os.path.join(settings.STORAGE_PATH, path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            shutil.copyfileobj(file.file, f)
        file_path = path

    sub = AssignmentSubmission(
        assignment_id=assignment_id,
        student_id=student_id,
        file_path=file_path,
        note=note,
        submitted_at=datetime.now(),
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return {"message": "Assignment submitted", "data": {"id": sub.id}}


@router.delete("/assignments/{assignment_id}")
def delete_assignment(
    assignment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ass = db.query(Assignment).filter(Assignment.id == assignment_id).first()
    if not ass:
        raise HTTPException(status_code=404, detail="Assignment not found")
    db.delete(ass)
    db.commit()
    return {"message": "Assignment deleted"}


# Timetable
@router.get("/timetable")
def get_timetable(
    class_id: Optional[int] = Query(None),
    section_id: Optional[int] = Query(None),
    day_of_week: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(TimetableSlot)
    if class_id:
        query = query.filter(TimetableSlot.class_id == class_id)
    if section_id:
        query = query.filter(TimetableSlot.section_id == section_id)
    if day_of_week is not None:
        query = query.filter(TimetableSlot.day_of_week == day_of_week)

    items = query.order_by(TimetableSlot.day_of_week.asc(), TimetableSlot.start_time.asc()).all()
    results = []
    for slot in items:
        results.append({
            "id": slot.id,
            "class_id": slot.class_id,
            "school_class": {"id": slot.school_class.id, "name": slot.school_class.name} if slot.school_class else None,
            "section_id": slot.section_id,
            "section": {"id": slot.section.id, "name": slot.section.name} if slot.section else None,
            "subject_id": slot.subject_id,
            "subject": {"id": slot.subject.id, "name": slot.subject.name} if slot.subject else None,
            "teacher_id": slot.teacher_id,
            "teacher": {"id": slot.teacher.id, "name": (slot.teacher.user.name if slot.teacher and slot.teacher.user else None)} if slot.teacher else None,
            "day_of_week": slot.day_of_week,
            "start_time": str(slot.start_time) if slot.start_time else None,
            "end_time": str(slot.end_time) if slot.end_time else None,
            "room": slot.room,
        })
    return results


@router.post("/timetable")
def save_timetable_slot(
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("academics"))
):
    slot = TimetableSlot(
        class_id=payload["class_id"],
        section_id=payload["section_id"],
        subject_id=payload["subject_id"],
        teacher_id=payload.get("teacher_id"),
        day_of_week=payload["day_of_week"],
        start_time=_time(payload.get("start_time")),
        end_time=_time(payload.get("end_time")),
        room=payload.get("room"),
    )
    db.add(slot)
    db.commit()
    db.refresh(slot)
    return {"message": "Timetable slot added", "data": {"id": slot.id}}


@router.put("/timetable/{slot_id}")
def update_timetable_slot(
    slot_id: int,
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("academics"))
):
    slot = db.query(TimetableSlot).filter(TimetableSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(status_code=404, detail="Timetable slot not found.")
    slot.class_id = payload.get("class_id", slot.class_id)
    slot.section_id = payload.get("section_id", slot.section_id)
    slot.subject_id = payload.get("subject_id", slot.subject_id)
    slot.teacher_id = payload.get("teacher_id", slot.teacher_id)
    slot.day_of_week = payload.get("day_of_week", slot.day_of_week)
    slot.start_time = _time(payload.get("start_time")) or slot.start_time
    slot.end_time = _time(payload.get("end_time")) or slot.end_time
    slot.room = payload.get("room", slot.room)
    db.commit()
    db.refresh(slot)
    return {"message": "Timetable slot updated", "data": {"id": slot.id}}


@router.delete("/timetable/{slot_id}")
def delete_timetable_slot(
    slot_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("academics"))
):
    slot = db.query(TimetableSlot).filter(TimetableSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(status_code=404, detail="Timetable slot not found.")
    db.delete(slot)
    db.commit()
    return {"message": "Timetable slot deleted"}


# Announcements
@router.get("/announcements")
def get_announcements(
    audience: Optional[str] = Query(None),
    class_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    date: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Announcement)
    if audience:
        query = query.filter(Announcement.audience == audience)
    if class_id:
        query = query.filter(Announcement.class_id == class_id)
    if status == "published":
        query = query.filter(Announcement.published == True)
    elif status == "unpublished":
        query = query.filter(Announcement.published == False)
    if date:
        query = query.filter(Announcement.created_at >= date)

    items = query.order_by(Announcement.created_at.desc(), Announcement.id.desc()).all()

    def brief(a):
        return {
            "id": a.id,
            "title": a.title,
            "body": a.body,
            "audience": a.audience,
            "class_id": a.class_id,
            "school_class": {"id": a.school_class.id, "name": a.school_class.name} if a.school_class else None,
            "section_id": a.section_id,
            "published": bool(a.published),
            "created_at": a.created_at.isoformat() if a.created_at else None,
        }

    return {"data": [brief(a) for a in items], "total": len(items), "last_page": 1, "from": 1 if items else 0, "to": len(items)}


@router.post("/announcements")
def create_announcement(
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("notifications"))
):
    class_id = payload.get("class_id") or None
    if class_id == "":
        class_id = None
    section_id = payload.get("section_id") or None
    if section_id == "":
        section_id = None
    anc = Announcement(
        title=payload["title"],
        body=payload.get("body") or payload.get("content") or "",
        audience=payload.get("audience", "all"),
        class_id=class_id,
        section_id=section_id,
        published=payload.get("published", True),
        created_by=current_user.id,
    )
    db.add(anc)
    db.commit()
    db.refresh(anc)
    return {"message": "Announcement published", "data": {"id": anc.id}}


@router.put("/announcements/{announcement_id}")
def update_announcement(
    announcement_id: int,
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("notifications"))
):
    anc = db.query(Announcement).filter(Announcement.id == announcement_id).first()
    if not anc:
        raise HTTPException(status_code=404, detail="Announcement not found")
    if "title" in payload:
        anc.title = payload.get("title", anc.title)
    if "body" in payload:
        anc.body = payload.get("body", anc.body)
    if "audience" in payload:
        anc.audience = payload.get("audience", anc.audience)
    if "class_id" in payload:
        val = payload.get("class_id")
        anc.class_id = val if val not in ("", None) else None
    if "section_id" in payload:
        val = payload.get("section_id")
        anc.section_id = val if val not in ("", None) else None
    if "published" in payload:
        anc.published = bool(payload.get("published"))
    db.commit()
    db.refresh(anc)
    return {"message": "Announcement updated", "data": {"id": anc.id, "published": anc.published}}


@router.delete("/announcements/{announcement_id}")
def delete_announcement(
    announcement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("notifications"))
):
    anc = db.query(Announcement).filter(Announcement.id == announcement_id).first()
    if not anc:
        raise HTTPException(status_code=404, detail="Announcement not found")
    db.delete(anc)
    db.commit()
    return {"message": "Announcement deleted"}

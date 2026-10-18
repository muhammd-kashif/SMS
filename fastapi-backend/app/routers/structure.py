from datetime import date as dtdate
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.structure import AcademicSession, SchoolClass, Section, Subject
from app.models.user import User

router = APIRouter(tags=["Structure"])


# ── /api/structure ──────────────────────────────────────────────────────────
# Frontend calls this to populate all class/section/session dropdowns.
# Returns classes with nested sections, plus flat sessions and subjects.

@router.get("/structure")
def get_structure(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sessions = (
        db.query(AcademicSession)
        .order_by(AcademicSession.is_current.desc(), AcademicSession.id.desc())
        .all()
    )
    classes = (
        db.query(SchoolClass)
        .order_by(SchoolClass.display_order.asc(), SchoolClass.name.asc())
        .all()
    )
    all_sections = db.query(Section).all()
    subjects = db.query(Subject).order_by(Subject.name.asc()).all()

    sections_by_class: dict[int, list] = {}
    for sec in all_sections:
        sections_by_class.setdefault(sec.class_id, []).append(
            {"id": sec.id, "name": sec.name, "class_id": sec.class_id,
             "room_no": sec.room_no, "capacity": sec.capacity}
        )

    return {
        "classes": [
            {
                "id": c.id,
                "name": c.name,
                "code": c.code,
                "numeric_grade": c.numeric_grade,
                "display_order": c.display_order,
                "sections": sections_by_class.get(c.id, []),
            }
            for c in classes
        ],
        "sessions": [
            {
                "id": s.id,
                "name": s.name,
                "year": s.year,
                "start_date": s.start_date.isoformat() if s.start_date else None,
                "end_date": s.end_date.isoformat() if s.end_date else None,
                "is_current": bool(s.is_current),
            }
            for s in sessions
        ],
        "subjects": [
            {
                "id": sub.id,
                "name": sub.name,
                "code": sub.code,
                "class_id": sub.class_id,
                "type": sub.type,
                "passing_marks": sub.passing_marks,
                "total_marks": sub.total_marks,
            }
            for sub in subjects
        ],
    }


# ── Classes ──────────────────────────────────────────────────────────────────

@router.get("/classes")
def list_classes(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    classes = db.query(SchoolClass).order_by(SchoolClass.display_order, SchoolClass.name).all()
    return [{"id": c.id, "name": c.name, "code": c.code, "numeric_grade": c.numeric_grade, "display_order": c.display_order} for c in classes]


@router.post("/classes", status_code=201)
def create_class(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    cls = SchoolClass(
        name=payload["name"],
        code=payload.get("code"),
        numeric_grade=payload.get("numeric_grade", 1),
        display_order=payload.get("display_order", 0),
    )
    db.add(cls)
    db.commit()
    db.refresh(cls)
    return {"id": cls.id, "name": cls.name, "code": cls.code, "numeric_grade": cls.numeric_grade, "display_order": cls.display_order}


@router.put("/classes/{class_id}")
def update_class(class_id: int, payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    cls = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not cls:
        raise HTTPException(404, "Class not found.")
    cls.name = payload.get("name", cls.name)
    cls.code = payload.get("code", cls.code)
    cls.numeric_grade = payload.get("numeric_grade", cls.numeric_grade)
    cls.display_order = payload.get("display_order", cls.display_order)
    db.commit()
    db.refresh(cls)
    return {"id": cls.id, "name": cls.name, "code": cls.code, "numeric_grade": cls.numeric_grade, "display_order": cls.display_order}


@router.delete("/classes/{class_id}")
def delete_class(class_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    cls = db.query(SchoolClass).filter(SchoolClass.id == class_id).first()
    if not cls:
        raise HTTPException(404, "Class not found.")
    db.delete(cls)
    db.commit()
    return {"message": "Class deleted."}


# ── Sections ─────────────────────────────────────────────────────────────────

@router.get("/sections")
def list_sections(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sections = db.query(Section).all()
    return [{"id": s.id, "name": s.name, "class_id": s.class_id, "room_no": s.room_no, "capacity": s.capacity} for s in sections]


@router.post("/sections", status_code=201)
def create_section(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sec = Section(
        class_id=payload["class_id"],
        name=payload["name"],
        room_no=payload.get("room_no"),
        capacity=payload.get("capacity", 40),
    )
    db.add(sec)
    db.commit()
    db.refresh(sec)
    return {"id": sec.id, "name": sec.name, "class_id": sec.class_id, "room_no": sec.room_no, "capacity": sec.capacity}


@router.put("/sections/{section_id}")
def update_section(section_id: int, payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sec = db.query(Section).filter(Section.id == section_id).first()
    if not sec:
        raise HTTPException(404, "Section not found.")
    sec.name = payload.get("name", sec.name)
    sec.class_id = payload.get("class_id", sec.class_id)
    sec.room_no = payload.get("room_no", sec.room_no)
    sec.capacity = payload.get("capacity", sec.capacity)
    db.commit()
    db.refresh(sec)
    return {"id": sec.id, "name": sec.name, "class_id": sec.class_id, "room_no": sec.room_no, "capacity": sec.capacity}


@router.delete("/sections/{section_id}")
def delete_section(section_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sec = db.query(Section).filter(Section.id == section_id).first()
    if not sec:
        raise HTTPException(404, "Section not found.")
    db.delete(sec)
    db.commit()
    return {"message": "Section deleted."}


# ── Subjects ─────────────────────────────────────────────────────────────────

@router.get("/subjects")
def list_subjects(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    subjects = db.query(Subject).order_by(Subject.name).all()
    return [{"id": s.id, "name": s.name, "code": s.code, "class_id": s.class_id, "type": s.type, "passing_marks": s.passing_marks, "total_marks": s.total_marks} for s in subjects]


@router.post("/subjects", status_code=201)
def create_subject(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sub = Subject(
        name=payload["name"],
        code=payload.get("code"),
        class_id=payload.get("class_id"),
        type=payload.get("type", "theory"),
        passing_marks=payload.get("passing_marks", 40),
        total_marks=payload.get("total_marks", 100),
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return {"id": sub.id, "name": sub.name, "code": sub.code, "class_id": sub.class_id, "type": sub.type}


@router.put("/subjects/{subject_id}")
def update_subject(subject_id: int, payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sub = db.query(Subject).filter(Subject.id == subject_id).first()
    if not sub:
        raise HTTPException(404, "Subject not found.")
    sub.name = payload.get("name", sub.name)
    sub.code = payload.get("code", sub.code)
    sub.class_id = payload.get("class_id", sub.class_id)
    sub.type = payload.get("type", sub.type)
    sub.passing_marks = payload.get("passing_marks", sub.passing_marks)
    sub.total_marks = payload.get("total_marks", sub.total_marks)
    db.commit()
    db.refresh(sub)
    return {"id": sub.id, "name": sub.name, "code": sub.code, "class_id": sub.class_id, "type": sub.type}


@router.delete("/subjects/{subject_id}")
def delete_subject(subject_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sub = db.query(Subject).filter(Subject.id == subject_id).first()
    if not sub:
        raise HTTPException(404, "Subject not found.")
    db.delete(sub)
    db.commit()
    return {"message": "Subject deleted."}


# ── Academic Sessions ─────────────────────────────────────────────────────────

@router.get("/sessions")
def list_sessions(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    sessions = db.query(AcademicSession).order_by(AcademicSession.is_current.desc(), AcademicSession.year.desc()).all()
    return [
        {"id": s.id, "name": s.name, "year": s.year,
         "start_date": s.start_date.isoformat() if s.start_date else None,
         "end_date": s.end_date.isoformat() if s.end_date else None,
         "is_current": bool(s.is_current)}
        for s in sessions
    ]


@router.post("/sessions", status_code=201)
def create_session(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if payload.get("is_current"):
        db.query(AcademicSession).update({"is_current": False})
    session_obj = AcademicSession(
        name=payload["name"],
        year=payload.get("year", dtdate.today().year),
        start_date=payload.get("start_date"),
        end_date=payload.get("end_date"),
        is_current=payload.get("is_current", False),
    )
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)
    return {
        "id": session_obj.id, "name": session_obj.name, "year": session_obj.year,
        "start_date": session_obj.start_date.isoformat() if session_obj.start_date else None,
        "end_date": session_obj.end_date.isoformat() if session_obj.end_date else None,
        "is_current": bool(session_obj.is_current),
    }


@router.put("/sessions/{session_id}")
def update_session(session_id: int, payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    session_obj = db.query(AcademicSession).filter(AcademicSession.id == session_id).first()
    if not session_obj:
        raise HTTPException(404, "Session not found.")
    if payload.get("is_current") and not session_obj.is_current:
        db.query(AcademicSession).update({"is_current": False})
    session_obj.name = payload.get("name", session_obj.name)
    session_obj.year = payload.get("year", session_obj.year)
    if payload.get("start_date"):
        session_obj.start_date = payload["start_date"]
    if payload.get("end_date"):
        session_obj.end_date = payload["end_date"]
    if "is_current" in payload:
        session_obj.is_current = payload["is_current"]
    db.commit()
    db.refresh(session_obj)
    return {
        "id": session_obj.id, "name": session_obj.name, "year": session_obj.year,
        "start_date": session_obj.start_date.isoformat() if session_obj.start_date else None,
        "end_date": session_obj.end_date.isoformat() if session_obj.end_date else None,
        "is_current": bool(session_obj.is_current),
    }


@router.delete("/sessions/{session_id}")
def delete_session(session_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    session_obj = db.query(AcademicSession).filter(AcademicSession.id == session_id).first()
    if not session_obj:
        raise HTTPException(404, "Session not found.")
    db.delete(session_obj)
    db.commit()
    return {"message": "Session deleted."}

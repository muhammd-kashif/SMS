from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.exam import Exam, ExamSchedule, Mark
from app.models.student import Student
from app.models.user import User
from app.services.audit_logger import AuditLogger

router = APIRouter(tags=["Exams"])

GRADE_SCALE = [
    (90, "A+"), (80, "A"), (70, "B+"), (60, "B"), (50, "C"), (40, "D"), (0, "F")
]


def grade_from_pct(pct: float) -> str:
    for threshold, grade in GRADE_SCALE:
        if pct >= threshold:
            return grade
    return "F"


def _exam_dict(exam: Exam) -> dict:
    return {
        "id": exam.id,
        "name": exam.name,
        "exam_type": exam.exam_type,
        "class_id": exam.class_id,
        "section_id": exam.section_id,
        "session_id": exam.session_id,
        "class_name": exam.school_class.name if exam.school_class else None,
        "section_name": exam.section.name if exam.section else None,
        "start_date": exam.start_date.isoformat() if exam.start_date else None,
        "end_date": exam.end_date.isoformat() if exam.end_date else None,
        "published": exam.published,
        "schedules": [
            {
                "id": s.id,
                "subject_id": s.subject_id,
                "subject_name": s.subject.name if s.subject else None,
                "exam_date": s.exam_date.isoformat() if s.exam_date else None,
                "start_time": str(s.start_time),
                "end_time": str(s.end_time),
                "room": s.room,
                "teacher_id": s.teacher_id,
                "teacher_name": s.teacher.user.name if s.teacher and s.teacher.user else None,
            }
            for s in exam.schedules
        ],
    }


@router.get("/exams")
def index(
    search: Optional[str] = None,
    class_id: Optional[int] = None,
    section_id: Optional[int] = None,
    page: int = 1,
    per_page: int = 20,
    all: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Exam)
    if search:
        query = query.filter(Exam.name.ilike(f"%{search}%"))
    if class_id:
        query = query.filter(Exam.class_id == class_id)
    if section_id:
        query = query.filter(Exam.section_id == section_id)
    total = query.count()
    exams = query.order_by(Exam.id.desc()).offset((page - 1) * per_page).limit(per_page if not all else 200).all()
    return {
        "data": [_exam_dict(e) for e in exams],
        "total": total,
        "current_page": page,
        "last_page": max(1, (total + per_page - 1) // per_page),
    }


@router.post("/exams", status_code=201)
def store(body: dict, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    exam = Exam(
        name=body["name"],
        exam_type=body["exam_type"],
        class_id=body["class_id"],
        section_id=body.get("section_id"),
        session_id=body.get("session_id"),
        start_date=date.fromisoformat(body["start_date"]) if body.get("start_date") else None,
        end_date=date.fromisoformat(body["end_date"]) if body.get("end_date") else None,
    )
    db.add(exam)
    db.commit()
    db.refresh(exam)
    AuditLogger(db).write(current_user, "Created", "Exam", exam.name)
    return _exam_dict(exam)


@router.put("/exams/{exam_id}")
def update(exam_id: int, body: dict, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(404)
    for field in ("name", "exam_type", "class_id", "section_id", "session_id"):
        if field in body:
            setattr(exam, field, body[field])
    if "start_date" in body and body["start_date"]:
        exam.start_date = date.fromisoformat(body["start_date"])
    if "end_date" in body and body["end_date"]:
        exam.end_date = date.fromisoformat(body["end_date"])
    db.commit()
    db.refresh(exam)
    return _exam_dict(exam)


@router.post("/exams/{exam_id}/publish")
def publish(exam_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(404)
    exam.published = not exam.published
    db.commit()
    db.refresh(exam)
    AuditLogger(db).write(current_user, "Published" if exam.published else "Unpublished", "Exam", exam.name)
    return _exam_dict(exam)


@router.delete("/exams/{exam_id}")
def destroy(exam_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(404)
    AuditLogger(db).write(current_user, "Deleted", "Exam", exam.name)
    db.delete(exam)
    db.commit()
    return {"message": "Exam removed."}


@router.post("/exams/{exam_id}/schedules", status_code=201)
def store_schedule(exam_id: int, body: dict, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(404)
    from datetime import time
    schedule = ExamSchedule(
        exam_id=exam_id,
        subject_id=body["subject_id"],
        exam_date=date.fromisoformat(body["exam_date"]),
        start_time=time.fromisoformat(body["start_time"]),
        end_time=time.fromisoformat(body["end_time"]),
        room=body.get("room"),
        teacher_id=body.get("teacher_id"),
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return {
        "id": schedule.id,
        "subject_id": schedule.subject_id,
        "subject_name": schedule.subject.name if schedule.subject else None,
        "exam_date": schedule.exam_date.isoformat(),
        "start_time": str(schedule.start_time),
        "end_time": str(schedule.end_time),
        "room": schedule.room,
    }


@router.put("/exam-schedules/{schedule_id}")
def update_schedule(schedule_id: int, body: dict, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    schedule = db.query(ExamSchedule).filter(ExamSchedule.id == schedule_id).first()
    if not schedule:
        raise HTTPException(404)
    from datetime import time
    if "subject_id" in body:
        schedule.subject_id = body["subject_id"]
    if "exam_date" in body:
        schedule.exam_date = date.fromisoformat(body["exam_date"])
    if "start_time" in body:
        schedule.start_time = time.fromisoformat(body["start_time"])
    if "end_time" in body:
        schedule.end_time = time.fromisoformat(body["end_time"])
    if "room" in body:
        schedule.room = body.get("room")
    if "teacher_id" in body:
        schedule.teacher_id = body.get("teacher_id")
    db.commit()
    db.refresh(schedule)
    return {"id": schedule.id, "subject_id": schedule.subject_id}


@router.delete("/exam-schedules/{schedule_id}")
def destroy_schedule(schedule_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    schedule = db.query(ExamSchedule).filter(ExamSchedule.id == schedule_id).first()
    if not schedule:
        raise HTTPException(404)
    db.delete(schedule)
    db.commit()
    return {"message": "Schedule row removed."}


@router.post("/marks")
def store_mark(body: dict, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    total = float(body["total_marks"])
    obtained = float(body["obtained_marks"])
    if obtained > total:
        raise HTTPException(422, "Obtained marks cannot exceed total marks.")
    pct = (obtained / total) * 100
    mark = db.query(Mark).filter(
        Mark.exam_id == body["exam_id"],
        Mark.student_id == body["student_id"],
        Mark.subject_id == body["subject_id"],
    ).first()
    if mark:
        mark.total_marks = total
        mark.obtained_marks = obtained
        mark.grade = grade_from_pct(pct)
        mark.remarks = body.get("remarks")
        mark.entered_by = current_user.id
    else:
        mark = Mark(
            exam_id=body["exam_id"],
            student_id=body["student_id"],
            subject_id=body["subject_id"],
            total_marks=total,
            obtained_marks=obtained,
            grade=grade_from_pct(pct),
            remarks=body.get("remarks"),
            entered_by=current_user.id,
        )
        db.add(mark)
    db.commit()
    db.refresh(mark)
    AuditLogger(db).write(current_user, "Entered marks", "Result", f"student #{body['student_id']}")
    return {
        "id": mark.id,
        "exam_id": mark.exam_id,
        "student_id": mark.student_id,
        "subject_id": mark.subject_id,
        "total_marks": float(mark.total_marks),
        "obtained_marks": float(mark.obtained_marks),
        "grade": mark.grade,
        "remarks": mark.remarks,
    }


@router.get("/results")
def results(
    exam_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    exam = db.query(Exam).filter(Exam.id == exam_id).first()
    if not exam:
        raise HTTPException(404)
    students = db.query(Student).filter(Student.class_id == exam.class_id).all()
    if exam.section_id:
        students = [s for s in students if s.section_id == exam.section_id]
    marks_by_student = {}
    for m in db.query(Mark).filter(Mark.exam_id == exam_id).all():
        marks_by_student.setdefault(m.student_id, []).append(m)

    rows = []
    for student in students:
        marks = marks_by_student.get(student.id, [])
        total = sum(float(m.total_marks) for m in marks)
        obtained = sum(float(m.obtained_marks) for m in marks)
        pct = round((obtained / total) * 100, 1) if total > 0 else 0
        rows.append({
            "student_id": student.id,
            "name": student.user.name if student.user else None,
            "roll_number": student.roll_number,
            "class_name": student.school_class.name if student.school_class else None,
            "section_name": student.section.name if student.section else None,
            "subjects": [
                {
                    "subject": m.subject.name if m.subject else None,
                    "total": float(m.total_marks),
                    "obtained": float(m.obtained_marks),
                    "grade": m.grade,
                }
                for m in marks
            ],
            "total": total,
            "obtained": obtained,
            "percentage": pct,
            "grade": grade_from_pct(pct),
            "result": "Pending" if not marks else ("Pass" if pct >= 40 else "Fail"),
        })
    return {"exam": _exam_dict(exam), "students": rows}

from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.academic import Homework, Assignment, TimetableSlot, Announcement, Leave
from app.models.attendance import Attendance
from app.models.exam import Exam, Mark
from app.models.fee import FeeItem, Payment
from app.models.student import Student, Guardian
from app.models.structure import SchoolClass, Section, Subject
from app.models.user import User
from app.services.attendance_service import AttendanceService


router = APIRouter(tags=["Portal"])


def _brief_student(s: Student) -> dict:
    face_photo = s.face_template.preview_url if s.face_template else None
    photo = f"{settings.APP_URL}/storage/{s.photo_path}" if s.photo_path else None
    return {
        "id": s.id,
        "name": s.user.name if s.user else (s.father_name or "Student"),
        "student_code": s.student_code,
        "roll_number": s.roll_number,
        "class_id": s.class_id,
        "section_id": s.section_id,
        "class_name": s.school_class.name if s.school_class else None,
        "section_name": s.section.name if s.section else None,
        "photo_url": photo,
        "face_photo_url": face_photo,
    }


def portal_data(current_user: User, db: Session, student_id: Optional[int] = None) -> dict:
    children_list = []
    selected_student = None

    if current_user.role == "student":
        selected_student = db.query(Student).filter(Student.user_id == current_user.id).first()
        if selected_student:
            children_list = [_brief_student(selected_student)]
    elif current_user.role == "parent":
        guardian = db.query(Guardian).filter(Guardian.user_id == current_user.id).first()
        if guardian:
            kids = db.query(Student).filter(Student.guardian_id == guardian.id).all()
            children_list = [_brief_student(k) for k in kids]
            if student_id:
                selected_student = next((k for k in kids if k.id == student_id), None)
            if not selected_student and kids:
                selected_student = kids[0]
    else:
        # Admin or teacher opening portal
        if student_id:
            selected_student = db.query(Student).filter(Student.id == student_id).first()

    if not selected_student:
        return {
            "student": {},
            "children": children_list,
            "attendance": {"present": 0, "absent": 0, "late": 0, "leave": 0, "percentage": 0, "remaining_leave": 20},
            "attendance_history": [],
            "fees": {"total": 0, "paid": 0, "pending": 0, "items": []},
            "payments": [],
            "exams": [],
            "results": [],
            "timetable": [],
            "homework": [],
            "assignments": [],
            "announcements": [],
            "leaves": [],
        }

    att_svc = AttendanceService(db)
    att_summary = att_svc.summary_for_student(selected_student)

    # Attendance history (all records for this student)
    history_rows = (
        db.query(Attendance)
        .filter(Attendance.person_type == "student", Attendance.person_id == selected_student.id)
        .order_by(Attendance.attendance_date.desc())
        .all()
    )
    att_history = [
        {
            "id": r.id,
            "date": r.attendance_date.isoformat(),
            "status": r.status,
            "check_in_time": str(r.check_in_time) if r.check_in_time else None,
            "verification_method": r.verification_method,
        }
        for r in history_rows
    ]

    # Fees & Payments
    fees = selected_student.fees or []
    total_fee = round(sum(f.total_due for f in fees), 2)
    paid_fee = round(sum(float(f.paid_amount or 0) for f in fees), 2)
    pending_fee = round(total_fee - paid_fee, 2)
    fee_items = [
        {
            "id": f.id,
            "title": f.title,
            "amount": float(f.amount),
            "total_due": float(f.total_due),
            "paid_amount": float(f.paid_amount or 0),
            "pending_amount": float(f.pending_amount),
            "due_date": f.due_date.isoformat() if f.due_date else None,
            "status": f.status,
            "fee_type": f.fee_type,
        }
        for f in fees
    ]
    payments = [
        {
            "id": p.id,
            "receipt_no": p.receipt_no,
            "amount": float(p.amount),
            "method": p.method,
            "paid_at": p.paid_at.isoformat() if p.paid_at else None,
            "status": p.status,
        }
        for p in (selected_student.payments or [])
    ]

    # Exams for student's class
    exams_query = db.query(Exam).filter(Exam.class_id == selected_student.class_id, Exam.published == True).all()
    exams_data = [
        {
            "id": ex.id,
            "name": ex.name,
            "exam_type": ex.exam_type,
            "start_date": ex.start_date.isoformat() if ex.start_date else None,
            "end_date": ex.end_date.isoformat() if ex.end_date else None,
        }
        for ex in exams_query
    ]

    # Results (Marks for student)
    marks_query = db.query(ExamMark).filter(ExamMark.student_id == selected_student.id).all()
    results_map = {}
    for m in marks_query:
        if m.exam_id not in results_map:
            ex = db.query(Exam).filter(Exam.id == m.exam_id).first()
            if ex and ex.published:
                results_map[m.exam_id] = {"exam_id": ex.id, "exam": ex.name, "obtained": 0, "total": 0, "grade": "F", "result": "pass"}
        if m.exam_id in results_map:
            results_map[m.exam_id]["obtained"] += float(m.obtained_marks or 0)
            results_map[m.exam_id]["total"] += float(m.total_marks or 100)

    results_data = []
    for ex_id, res in results_map.items():
        pct = round((res["obtained"] / res["total"]) * 100, 1) if res["total"] > 0 else 0
        res["percentage"] = pct
        if pct >= 80:
            res["grade"] = "A+"
        elif pct >= 70:
            res["grade"] = "A"
        elif pct >= 60:
            res["grade"] = "B"
        elif pct >= 50:
            res["grade"] = "C"
        elif pct >= 40:
            res["grade"] = "D"
        else:
            res["grade"] = "F"
            res["result"] = "fail"
        results_data.append(res)

    # Timetable
    tt_slots = (
        db.query(TimetableSlot)
        .filter(TimetableSlot.class_id == selected_student.class_id, TimetableSlot.section_id == selected_student.section_id)
        .order_by(TimetableSlot.day_of_week.asc(), TimetableSlot.period_number.asc())
        .all()
    )
    tt_data = [
        {
            "id": s.id,
            "day_of_week": s.day_of_week,
            "period_number": s.period_number,
            "start_time": str(s.start_time) if s.start_time else None,
            "end_time": str(s.end_time) if s.end_time else None,
            "subject": {"id": s.subject.id, "name": s.subject.name} if s.subject else None,
            "room": s.room_no or "Classroom",
        }
        for s in tt_slots
    ]

    # Homework
    hw_rows = (
        db.query(Homework)
        .filter(Homework.class_id == selected_student.class_id, Homework.section_id == selected_student.section_id)
        .order_by(Homework.id.desc())
        .all()
    )
    hw_data = [
        {
            "id": h.id,
            "title": h.title,
            "description": h.description,
            "due_date": h.due_date.isoformat() if h.due_date else None,
            "subject": {"id": h.subject.id, "name": h.subject.name} if h.subject else None,
        }
        for h in hw_rows
    ]

    # Assignments
    ass_rows = (
        db.query(Assignment)
        .filter(Assignment.class_id == selected_student.class_id, Assignment.section_id == selected_student.section_id)
        .order_by(Assignment.id.desc())
        .all()
    )
    ass_data = [
        {
            "id": a.id,
            "title": a.title,
            "description": a.description,
            "due_date": a.due_date.isoformat() if a.due_date else None,
            "subject": {"id": a.subject.id, "name": a.subject.name} if a.subject else None,
        }
        for a in ass_rows
    ]

    # Announcements
    anc_rows = (
        db.query(Announcement)
        .filter(
            Announcement.is_active == True,
            (Announcement.target_role.in_(["all", current_user.role]))
        )
        .order_by(Announcement.id.desc())
        .all()
    )
    anc_data = [
        {
            "id": a.id,
            "title": a.title,
            "body": a.content,
            "created_at": a.created_at.isoformat() if a.created_at else None,
        }
        for a in anc_rows
    ]

    # Leaves
    leave_rows = (
        db.query(Leave)
        .filter(Leave.person_type == "student", Leave.person_id == selected_student.id)
        .order_by(Leave.id.desc())
        .all()
    )
    leave_data = [
        {
            "id": lv.id,
            "leave_type": lv.leave_type,
            "start_date": lv.start_date.isoformat() if lv.start_date else None,
            "end_date": lv.end_date.isoformat() if lv.end_date else None,
            "status": lv.status,
            "reason": lv.reason,
            "days": lv.days,
        }
        for lv in leave_rows
    ]

    return {
        "student": _brief_student(selected_student),
        "children": children_list,
        "attendance": att_summary,
        "attendance_history": att_history,
        "fees": {"total": total_fee, "paid": paid_fee, "pending": pending_fee, "items": fee_items},
        "payments": payments,
        "exams": exams_data,
        "results": results_data,
        "timetable": tt_data,
        "homework": hw_data,
        "assignments": ass_data,
        "announcements": anc_data,
        "leaves": leave_data,
    }


@router.get("/portal")
def get_portal(
    student_id: Optional[int] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return portal_data(current_user, db, student_id=student_id)

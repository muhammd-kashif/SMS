from datetime import date, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.attendance import Attendance
from app.models.exam import Exam
from app.models.fee import FeeItem, Payment
from app.models.misc import AuditLog
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.structure import SchoolClass
from app.models.user import User

router = APIRouter(tags=["Dashboard"])


@router.get("/dashboard")
def dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role in ("student", "parent"):
        from app.routers.portal import portal_data
        return portal_data(current_user, db)

    # Student IDs in scope
    student_ids = [s.id for s in db.query(Student.id).all()]

    today = date.today()
    today_rows = (
        db.query(Attendance)
        .filter(
            Attendance.person_type == "student",
            Attendance.person_id.in_(student_ids),
            Attendance.attendance_date == today,
        )
        .all()
    )
    present = sum(1 for r in today_rows if r.status == "present")
    absent = sum(1 for r in today_rows if r.status == "absent")
    late = sum(1 for r in today_rows if r.status == "late")
    leave = sum(1 for r in today_rows if r.status == "leave")
    marked = present + absent + late
    active_students = db.query(Student).filter(Student.id.in_(student_ids), Student.status == "active").count()

    # 7-day trend
    trend = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        rows = (
            db.query(Attendance)
            .filter(
                Attendance.person_type == "student",
                Attendance.person_id.in_(student_ids),
                Attendance.attendance_date == day,
            )
            .all()
        )
        trend.append({
            "date": day.isoformat(),
            "present": sum(1 for r in rows if r.status == "present"),
            "absent": sum(1 for r in rows if r.status == "absent"),
            "late": sum(1 for r in rows if r.status == "late"),
        })

    # Fees
    fees = db.query(FeeItem).filter(FeeItem.student_id.in_(student_ids)).all()
    payments_q = (
        db.query(Payment)
        .filter(Payment.student_id.in_(student_ids), Payment.status == "posted")
    )
    collected = float(sum(float(p.amount) for p in payments_q.all()))
    today_payments = payments_q.filter(Payment.paid_at >= today).all()
    today_collection = float(sum(float(p.amount) for p in today_payments))
    month_start = today.replace(day=1)
    month_payments = [p for p in payments_q.all() if p.paid_at and p.paid_at.date() >= month_start]
    month_collection = float(sum(float(p.amount) for p in month_payments))
    pending = round(sum(f.pending_amount for f in fees), 2)
    defaulters = len(set(
        f.student_id for f in fees
        if f.pending_amount > 0 and f.due_date and f.due_date < today
    ))

    # Class counts
    classes = db.query(SchoolClass).all()
    class_counts = []
    for cls in classes:
        count = db.query(Student).filter(Student.class_id == cls.id, Student.status == "active").count()
        class_counts.append({"name": cls.name, "students": count})

    # Upcoming exams
    upcoming_exams = (
        db.query(Exam)
        .filter(Exam.start_date >= today)
        .order_by(Exam.start_date)
        .limit(5)
        .all()
    )
    upcoming = []
    for ex in upcoming_exams:
        upcoming.append({
            "id": ex.id,
            "name": ex.name,
            "type": ex.exam_type,
            "class_name": ex.school_class.name if ex.school_class else None,
            "start_date": ex.start_date.isoformat() if ex.start_date else None,
        })

    # Fee trend (6 months)
    fee_trend = []
    for m in range(5, -1, -1):
        month_date = today.replace(day=1) - timedelta(days=m * 30)
        month_date = month_date.replace(day=1)
        next_month = (month_date.replace(day=28) + timedelta(days=4)).replace(day=1)
        amount = sum(
            float(p.amount)
            for p in db.query(Payment)
            .filter(
                Payment.student_id.in_(student_ids),
                Payment.status == "posted",
                Payment.paid_at >= month_date,
                Payment.paid_at < next_month,
            )
            .all()
        )
        fee_trend.append({"label": month_date.strftime("%b"), "amount": amount})

    # Class attendance
    class_attendance = []
    for cls in classes:
        cls_student_ids = [
            s.id for s in db.query(Student.id)
            .filter(Student.class_id == cls.id, Student.status == "active", Student.id.in_(student_ids))
            .all()
        ]
        rows = (
            db.query(Attendance)
            .filter(
                Attendance.person_type == "student",
                Attendance.person_id.in_(cls_student_ids),
                Attendance.attendance_date == today,
            )
            .all()
        )
        class_attendance.append({
            "name": cls.name,
            "present": sum(1 for r in rows if r.status == "present"),
            "absent": sum(1 for r in rows if r.status == "absent"),
            "late": sum(1 for r in rows if r.status == "late"),
            "leave": sum(1 for r in rows if r.status == "leave"),
        })

    # Audit logs
    audit = []
    if current_user.role == "admin":
        logs = (
            db.query(AuditLog)
            .order_by(AuditLog.id.desc())
            .limit(8)
            .all()
        )
        for log in logs:
            user = db.query(User).filter(User.id == log.user_id).first()
            audit.append({
                "id": log.id,
                "user": user.name if user else None,
                "action": log.action,
                "module": log.module,
                "record": log.record_label,
                "at": log.created_at.strftime("%d-%b-%Y %I:%M %p") if log.created_at else None,
            })

    return {
        "students": active_students,
        "teachers": db.query(Teacher).filter(Teacher.status == "active").count(),
        "attendance": {
            "present": present,
            "absent": absent,
            "late": late,
            "leave": leave,
            "percentage": round((present / marked) * 100, 1) if marked else 0,
        },
        "trend": trend,
        "fees": {
            "collected": collected,
            "pending": pending,
            "today": today_collection,
            "month": month_collection,
            "defaulters": defaulters,
        },
        "classes": class_counts,
        "class_attendance": class_attendance,
        "fee_trend": fee_trend,
        "upcoming_exams": upcoming,
        "audit": audit,
    }

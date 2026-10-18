from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_permission
from app.database import get_db
from app.models.academic import Leave
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.user import User

router = APIRouter(tags=["Leaves"])


@router.get("/leaves")
def get_leaves(
    status_filter: Optional[str] = Query(None, alias="status"),
    applicant_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Leave)

    if current_user.role == "student":
        student = db.query(Student).filter(Student.user_id == current_user.id).first()
        if student:
            query = query.filter(Leave.student_id == student.id)
    elif current_user.role == "teacher":
        teacher = db.query(Teacher).filter(Teacher.user_id == current_user.id).first()
        if teacher:
            query = query.filter(Leave.teacher_id == teacher.id)

    if status_filter:
        query = query.filter(Leave.status == status_filter)
    if applicant_type:
        query = query.filter(Leave.applicant_type == applicant_type)

    items = query.order_by(Leave.created_at.desc(), Leave.id.desc()).all()
    results = []
    for l in items:
        applicant_name = "Unknown"
        if l.applicant_type == "student" and l.student_id:
            s = db.query(Student).filter(Student.id == l.student_id).first()
            if s:
                applicant_name = (s.user.name if s.user else "Unknown")
        elif l.applicant_type == "teacher" and l.teacher_id:
            t = db.query(Teacher).filter(Teacher.id == l.teacher_id).first()
            if t:
                applicant_name = (t.user.name if t and t.user else "Unknown")

        results.append({
            "id": l.id,
            "applicant_type": l.applicant_type,
            "applicant_name": applicant_name,
            "student_id": l.student_id,
            "teacher_id": l.teacher_id,
            "leave_type": l.leave_type,
            "start_date": l.start_date.isoformat() if l.start_date else None,
            "end_date": l.end_date.isoformat() if l.end_date else None,
            "reason": l.reason,
            "status": l.status,
            "rejection_reason": l.rejection_reason,
            "created_at": l.created_at.isoformat() if l.created_at else None,
        })

    return {"data": results}


@router.post("/leaves")
def apply_leave(
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    student_id = payload.get("student_id")
    teacher_id = payload.get("teacher_id")
    applicant_type = payload.get("applicant_type")

    if current_user.role == "student":
        s = db.query(Student).filter(Student.user_id == current_user.id).first()
        if s:
            student_id = s.id
            applicant_type = "student"
    elif current_user.role == "teacher":
        t = db.query(Teacher).filter(Teacher.user_id == current_user.id).first()
        if t:
            teacher_id = t.id
            applicant_type = "teacher"

    from datetime import date as dtdate
    start = payload["start_date"]
    end = payload["end_date"]
    if isinstance(start, str):
        start = dtdate.fromisoformat(start)
    if isinstance(end, str):
        end = dtdate.fromisoformat(end)
    leave = Leave(
        applicant_type=applicant_type or "student",
        student_id=student_id,
        teacher_id=teacher_id,
        leave_type=payload.get("leave_type", "casual"),
        start_date=start,
        end_date=end,
        reason=payload.get("reason", ""),
        status="pending",
    )
    db.add(leave)
    db.commit()
    db.refresh(leave)
    return {"message": "Leave application submitted successfully", "data": {"id": leave.id}}


@router.post("/leaves/{leave_id}/approve")
def approve_leave(
    leave_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("leaves"))
):
    leave = db.query(Leave).filter(Leave.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")

    leave.status = "approved"
    leave.approved_by_user_id = current_user.id
    db.commit()
    return {"message": "Leave approved successfully"}


@router.post("/leaves/{leave_id}/reject")
def reject_leave(
    leave_id: int,
    payload: dict = {},
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("leaves"))
):
    leave = db.query(Leave).filter(Leave.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")

    leave.status = "rejected"
    leave.rejection_reason = payload.get("rejection_reason")
    leave.approved_by_user_id = current_user.id
    db.commit()
    return {"message": "Leave rejected successfully"}


@router.delete("/leaves/{leave_id}")
def delete_leave(
    leave_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    leave = db.query(Leave).filter(Leave.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")

    db.delete(leave)
    db.commit()
    return {"message": "Leave deleted"}

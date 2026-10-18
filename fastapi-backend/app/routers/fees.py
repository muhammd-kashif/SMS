from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.fee import FeeItem, Payment
from app.models.student import Student
from app.models.user import User
from app.services.audit_logger import AuditLogger
from app.services.fee_service import FeeService
from app.services.settings_store import SettingsStore

router = APIRouter(tags=["Fees"])


def _fee_dict(fee: FeeItem) -> dict:
    s = fee.student
    return {
        "id": fee.id,
        "student_id": fee.student_id,
        "student_name": s.user.name if s and s.user else None,
        "student_code": s.student_code if s else None,
        "class_name": s.school_class.name if s and s.school_class else None,
        "section_name": s.section.name if s and s.section else None,
        "fee_type": fee.fee_type,
        "title": fee.title,
        "amount": float(fee.amount),
        "paid_amount": float(fee.paid_amount or 0),
        "pending_amount": fee.pending_amount,
        "total_due": fee.total_due,
        "late_fee": float(fee.late_fee or 0),
        "due_date": fee.due_date.isoformat() if fee.due_date else None,
        "grace_days": fee.grace_days,
        "status": fee.status,
        "is_active": fee.is_active,
    }


def _payment_dict(p: Payment) -> dict:
    s = p.student
    return {
        "id": p.id,
        "student_id": p.student_id,
        "student_name": s.user.name if s and s.user else None,
        "student_code": s.student_code if s else None,
        "class_name": s.school_class.name if s and s.school_class else None,
        "section_name": s.section.name if s and s.section else None,
        "receipt_no": p.receipt_no,
        "amount": float(p.amount),
        "method": p.method,
        "paid_at": p.paid_at.isoformat() if p.paid_at else None,
        "status": p.status,
        "fee_title": p.fee_item.title if p.fee_item else None,
        "reversal_reason": p.reversal_reason,
    }


@router.get("/fees")
def index(
    student_id: Optional[int] = None,
    class_id: Optional[int] = None,
    section_id: Optional[int] = None,
    status_filter: Optional[str] = Query(None, alias="status"),
    pending: bool = False,
    include_inactive: bool = False,
    search: Optional[str] = None,
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    page: int = 1,
    per_page: int = 20,
    all: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(FeeItem).join(FeeItem.student).join(Student.user)
    if not include_inactive:
        query = query.filter(FeeItem.is_active == True)
    if student_id:
        query = query.filter(FeeItem.student_id == student_id)
    if class_id:
        query = query.filter(Student.class_id == class_id)
    if section_id:
        query = query.filter(Student.section_id == section_id)
    if status_filter:
        query = query.filter(FeeItem.status == status_filter)
    if pending:
        query = query.filter(FeeItem.status != "paid")
    if from_date:
        query = query.filter(FeeItem.due_date >= date.fromisoformat(from_date))
    if to_date:
        query = query.filter(FeeItem.due_date <= date.fromisoformat(to_date))
    if search:
        query = query.filter(
            FeeItem.title.ilike(f"%{search}%")
            | Student.student_code.ilike(f"%{search}%")
            | User.name.ilike(f"%{search}%")
        )
    total = query.count()
    fees = query.order_by(FeeItem.due_date).offset((page - 1) * per_page).limit(per_page if not all else 500).all()
    return {
        "data": [_fee_dict(f) for f in fees],
        "total": total,
        "current_page": page,
        "last_page": max(1, (total + per_page - 1) // per_page),
    }


@router.post("/fees", status_code=201)
def store(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    store_svc = SettingsStore(db)
    fee = FeeItem(
        student_id=body["student_id"],
        fee_type=body["fee_type"],
        title=body["title"],
        amount=body["amount"],
        due_date=date.fromisoformat(body["due_date"]),
        grace_days=body.get("grace_days", int(store_svc.get("grace_days", 3))),
        late_fee=0,
        is_active=True,
    )
    fee.refresh_status()
    db.add(fee)
    db.commit()
    db.refresh(fee)
    AuditLogger(db).write(current_user, "Created", "Fee", fee.title)
    return _fee_dict(fee)


@router.put("/fees/{fee_id}")
def update(
    fee_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fee = db.query(FeeItem).filter(FeeItem.id == fee_id).first()
    if not fee:
        raise HTTPException(404)
    if "amount" in body:
        if float(fee.paid_amount or 0) > 0 and float(body["amount"]) + float(fee.late_fee or 0) < float(fee.paid_amount):
            raise HTTPException(422, "Amount cannot be less than amount already paid.")
        fee.amount = body["amount"]
    if "title" in body:
        fee.title = body["title"]
    if "due_date" in body:
        fee.due_date = date.fromisoformat(body["due_date"])
    if "grace_days" in body:
        fee.grace_days = body["grace_days"]
    if "is_active" in body:
        fee.is_active = body["is_active"]
    fee.refresh_status()
    db.commit()
    db.refresh(fee)
    AuditLogger(db).write(current_user, "Updated" if fee.is_active else "Deactivated", "Fee", fee.title)
    return _fee_dict(fee)


@router.post("/payments", status_code=201)
def pay(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fee = db.query(FeeItem).filter(FeeItem.id == body["fee_item_id"]).first()
    if not fee:
        raise HTTPException(404, "Fee not found.")
    if not fee.is_active:
        raise HTTPException(422, "This fee is inactive.")

    store_svc = SettingsStore(db)
    methods = store_svc.get("payment_methods", ["cash", "bank", "online", "other"])
    if body.get("method") not in methods:
        raise HTTPException(422, "That payment method is not enabled.")

    from datetime import datetime
    paid_at = datetime.fromisoformat(body["paid_at"]) if body.get("paid_at") else None
    svc = FeeService(db)
    payment = svc.pay(fee, float(body["amount"]), body["method"], current_user, paid_at)
    AuditLogger(db).write(current_user, "Recorded payment", "Fee", payment.receipt_no)
    return _payment_dict(payment)


@router.get("/payments")
def payments(
    student_id: Optional[int] = None,
    method: Optional[str] = None,
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    search: Optional[str] = None,
    page: int = 1,
    per_page: int = 20,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Payment).join(Payment.student).join(Student.user)
    if student_id:
        query = query.filter(Payment.student_id == student_id)
    if method:
        query = query.filter(Payment.method == method)
    if from_date:
        query = query.filter(Payment.paid_at >= date.fromisoformat(from_date))
    if to_date:
        query = query.filter(Payment.paid_at <= date.fromisoformat(to_date))
    if search:
        query = query.filter(
            Payment.receipt_no.ilike(f"%{search}%") | User.name.ilike(f"%{search}%")
        )
    total = query.count()
    pmts = query.order_by(Payment.paid_at.desc()).offset((page - 1) * per_page).limit(per_page).all()
    return {
        "data": [_payment_dict(p) for p in pmts],
        "total": total,
        "current_page": page,
        "last_page": max(1, (total + per_page - 1) // per_page),
    }


@router.post("/payments/{payment_id}/reverse")
def reverse(
    payment_id: int,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(404)
    svc = FeeService(db)
    payment = svc.reverse(payment, body.get("reason", ""))
    AuditLogger(db).write(current_user, "Reversed payment", "Fee", payment.receipt_no)
    return _payment_dict(payment)


@router.post("/fees/assign-class", status_code=201)
def assign_class(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    store_svc = SettingsStore(db)
    students = db.query(Student).filter(
        Student.class_id == body["class_id"],
        Student.status == "active",
    )
    if body.get("section_id"):
        students = students.filter(Student.section_id == body["section_id"])
    created = 0
    for student in students.all():
        fee = FeeItem(
            student_id=student.id,
            fee_type=body["fee_type"],
            title=body["title"],
            amount=body["amount"],
            due_date=date.fromisoformat(body["due_date"]),
            grace_days=body.get("grace_days", int(store_svc.get("grace_days", 3))),
            is_active=True,
        )
        fee.refresh_status()
        db.add(fee)
        created += 1
    db.commit()
    AuditLogger(db).write(current_user, "Assigned class fee", "Fee", f"{body['title']} ({created})")
    return {"created": created}


@router.get("/fees/defaulters")
def defaulters(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    fees = db.query(FeeItem).filter(FeeItem.is_active == True).all()
    result = [
        _fee_dict(f) for f in fees
        if f.pending_amount > 0 and f.due_date and f.due_date < today
    ]
    return result


@router.post("/fees/reminders")
def reminders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in ("admin", "accountant"):
        raise HTTPException(403)
    svc = FeeService(db)
    return svc.apply_late_fees_and_remind()

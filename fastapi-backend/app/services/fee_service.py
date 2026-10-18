from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models.fee import FeeItem, Payment
from app.models.user import User


class FeeService:
    def __init__(self, db: Session):
        self._db = db

    def pay(
        self,
        fee: FeeItem,
        amount: float,
        method: str,
        user: User,
        paid_at: Optional[datetime] = None,
    ) -> Payment:
        previous_balance = fee.pending_amount
        paid_at = paid_at or datetime.now()

        # Generate receipt number
        last = self._db.query(Payment).order_by(Payment.id.desc()).first()
        seq = (last.id if last else 0) + 1
        receipt_no = f"RCP-{str(seq).zfill(6)}"

        # Update fee paid amount
        new_paid = float(fee.paid_amount or 0) + amount
        fee.paid_amount = round(min(new_paid, fee.total_due), 2)
        fee.refresh_status()
        self._db.add(fee)

        remaining = max(0, round(float(fee.total_due) - float(fee.paid_amount), 2))
        payment = Payment(
            student_id=fee.student_id,
            fee_item_id=fee.id,
            receipt_no=receipt_no,
            amount=amount,
            method=method,
            paid_at=paid_at,
            previous_balance=previous_balance,
            remaining_balance=remaining,
            received_by=user.id,
            status="posted",
        )
        self._db.add(payment)
        self._db.commit()
        self._db.refresh(payment)
        return payment

    def reverse(self, payment: Payment, reason: str) -> Payment:
        if payment.status == "reversed":
            from fastapi import HTTPException
            raise HTTPException(status_code=422, detail="Payment already reversed.")

        fee = payment.fee_item
        if fee:
            new_paid = max(0, float(fee.paid_amount or 0) - float(payment.amount))
            fee.paid_amount = round(new_paid, 2)
            fee.refresh_status()
            self._db.add(fee)

        payment.status = "reversed"
        payment.reversal_reason = reason
        self._db.add(payment)
        self._db.commit()
        self._db.refresh(payment)
        return payment

    def apply_late_fees_and_remind(self) -> dict:
        from datetime import date
        today = date.today()
        updated = 0
        fees = self._db.query(FeeItem).filter(
            FeeItem.is_active == True,
            FeeItem.status != "paid",
            FeeItem.late_fee_applied == False,
        ).all()

        for fee in fees:
            if fee.due_date and fee.due_date < today:
                from app.services.settings_store import SettingsStore
                # This would require DB, simplified here
                fee.late_fee_applied = True
                self._db.add(fee)
                fee.refresh_status()
                updated += 1

        self._db.commit()
        return {"updated": updated}

from sqlalchemy import (
    Boolean, Column, Date, DateTime, ForeignKey, Integer,
    Numeric, SmallInteger, String, func
)
from sqlalchemy.orm import relationship

from app.database import Base


class FeeItem(Base):
    __tablename__ = "fee_items"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    fee_type = Column(String(50), nullable=False)  # monthly|admission|examination|other
    title = Column(String(120), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    due_date = Column(Date, nullable=False)
    grace_days = Column(SmallInteger, default=0)
    late_fee = Column(Numeric(12, 2), default=0)
    late_fee_applied = Column(Boolean, default=False)
    paid_amount = Column(Numeric(12, 2), default=0)
    status = Column(String(30), default="pending")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    student = relationship("Student", back_populates="fees")
    payments = relationship("Payment", back_populates="fee_item")

    @property
    def total_due(self):
        return float(self.amount) + float(self.late_fee or 0)

    @property
    def pending_amount(self):
        return max(0, round(self.total_due - float(self.paid_amount or 0), 2))

    def refresh_status(self):
        paid = float(self.paid_amount or 0)
        total = self.total_due
        if paid <= 0:
            self.status = "pending"
        elif paid >= total:
            self.status = "paid"
        else:
            self.status = "partial"


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    fee_item_id = Column(Integer, ForeignKey("fee_items.id", ondelete="SET NULL"), nullable=True)
    receipt_no = Column(String(50), unique=True, nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    method = Column(String(30), default="cash")
    paid_at = Column(DateTime, nullable=False)
    previous_balance = Column(Numeric(12, 2), default=0)
    remaining_balance = Column(Numeric(12, 2), default=0)
    status = Column(String(30), default="posted")
    reversal_reason = Column(String(300), nullable=True)
    received_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    student = relationship("Student", back_populates="payments")
    fee_item = relationship("FeeItem", back_populates="payments")
    receiver = relationship("User", foreign_keys=[received_by])

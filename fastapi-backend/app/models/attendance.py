from sqlalchemy import (
    Column, Date, DateTime, ForeignKey, Integer, Numeric,
    String, Text, Time, UniqueConstraint, func, Index
)
from sqlalchemy.orm import relationship

from app.database import Base


class Attendance(Base):
    __tablename__ = "attendances"

    id = Column(Integer, primary_key=True, index=True)
    person_type = Column(String(20), nullable=False)  # student | teacher
    person_id = Column(Integer, nullable=False)
    attendance_date = Column(Date, nullable=False)
    check_in_time = Column(Time, nullable=True)
    status = Column(String(20), nullable=False)  # present|absent|late|leave
    source = Column(String(30), default="manual")
    confidence = Column(Numeric(8, 4), nullable=True)
    client_uuid = Column(String(36), unique=True, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("person_type", "person_id", "attendance_date", name="attendance_person_day_unique"),
        Index("ix_attendance_date_status", "attendance_date", "status"),
    )


class FaceTemplate(Base):
    __tablename__ = "face_templates"

    id = Column(Integer, primary_key=True, index=True)
    person_type = Column(String(20), nullable=False)
    person_id = Column(Integer, nullable=False)
    embedding = Column(Text, nullable=False)
    model = Column(String(50), default="sface")
    preview_path = Column(String(255), nullable=True)
    registered_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("person_type", "person_id"),
    )

    @property
    def preview_url(self):
        from app.core.config import settings
        if self.preview_path:
            return f"{settings.APP_URL}/storage/{self.preview_path}"
        return None

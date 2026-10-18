from sqlalchemy import (
    Column, Date, ForeignKey, Integer, SmallInteger,
    String, Text, DateTime, func, Index
)
from sqlalchemy.orm import relationship

from app.database import Base


class Guardian(Base):
    __tablename__ = "guardians"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    name = Column(String(120), nullable=False)
    phone = Column(String(30), nullable=True)
    email = Column(String(191), nullable=True)
    address = Column(String(500), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="guardian")
    students = relationship("Student", back_populates="guardian")


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    guardian_id = Column(Integer, ForeignKey("guardians.id", ondelete="SET NULL"), nullable=True)
    student_code = Column(String(50), unique=True, nullable=False)
    roll_number = Column(String(30), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id"), nullable=False)
    session_id = Column(Integer, ForeignKey("academic_sessions.id", ondelete="SET NULL"), nullable=True)
    father_name = Column(String(120), nullable=True)
    dob = Column(Date, nullable=True)
    gender = Column(String(20), nullable=True)
    phone = Column(String(30), nullable=True)
    parent_phone = Column(String(30), nullable=True)
    address = Column(Text, nullable=True)
    admission_date = Column(Date, nullable=True)
    photo_path = Column(String(255), nullable=True)
    leave_allowance = Column(SmallInteger, default=20)
    status = Column(String(30), default="active")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="student")
    guardian = relationship("Guardian", back_populates="students")
    school_class = relationship("SchoolClass", back_populates="students")
    section = relationship("Section", back_populates="students")
    session = relationship("AcademicSession")
    face_template = relationship("FaceTemplate", primaryjoin="and_(FaceTemplate.person_type=='student', foreign(FaceTemplate.person_id)==Student.id)", uselist=False)
    fees = relationship("FeeItem", back_populates="student")
    payments = relationship("Payment", back_populates="student")
    marks = relationship("Mark", back_populates="student")
    leaves = relationship("Leave", back_populates="student")

    __table_args__ = (
        Index("ix_students_class_section", "class_id", "section_id"),
    )

    @property
    def photo_url(self):
        from app.core.config import settings
        if self.photo_path:
            return f"{settings.APP_URL}/storage/{self.photo_path}"
        return None

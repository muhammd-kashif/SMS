from sqlalchemy import (
    Boolean, Column, Date, DateTime, ForeignKey, Integer,
    Numeric, String, Text, Time, UniqueConstraint, func
)
from sqlalchemy.orm import relationship

from app.database import Base


class Exam(Base):
    __tablename__ = "exams"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    exam_type = Column(String(50), nullable=False)  # class_test|monthly|mid_term|final|practical|quiz
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="SET NULL"), nullable=True)
    session_id = Column(Integer, ForeignKey("academic_sessions.id", ondelete="SET NULL"), nullable=True)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    published = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    school_class = relationship("SchoolClass")
    section = relationship("Section")
    schedules = relationship("ExamSchedule", back_populates="exam", cascade="all, delete-orphan")
    marks = relationship("Mark", back_populates="exam", cascade="all, delete-orphan")


class ExamSchedule(Base):
    __tablename__ = "exam_schedules"

    id = Column(Integer, primary_key=True, index=True)
    exam_id = Column(Integer, ForeignKey("exams.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    exam_date = Column(Date, nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    room = Column(String(40), nullable=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    exam = relationship("Exam", back_populates="schedules")
    subject = relationship("Subject")
    teacher = relationship("Teacher")


class Mark(Base):
    __tablename__ = "marks"

    id = Column(Integer, primary_key=True, index=True)
    exam_id = Column(Integer, ForeignKey("exams.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    total_marks = Column(Numeric(8, 2), nullable=False)
    obtained_marks = Column(Numeric(8, 2), nullable=False)
    grade = Column(String(5), nullable=True)
    remarks = Column(String(200), nullable=True)
    entered_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    exam = relationship("Exam", back_populates="marks")
    student = relationship("Student", back_populates="marks")
    subject = relationship("Subject")

    __table_args__ = (
        UniqueConstraint("exam_id", "student_id", "subject_id"),
    )

from sqlalchemy import (
    Boolean, Column, Date, DateTime, ForeignKey, Integer, Numeric, SmallInteger,
    String, Text, Time, func
)
from sqlalchemy.orm import relationship

from app.database import Base


class Leave(Base):
    __tablename__ = "leaves"

    id = Column(Integer, primary_key=True, index=True)
    applicant_type = Column(String(20), default="student")  # student | teacher | parent
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="CASCADE"), nullable=True)
    leave_type = Column(String(50), nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    reason = Column(Text, nullable=False)
    document_path = Column(String(255), nullable=True)
    status = Column(String(30), default="pending")  # pending|approved|rejected
    days = Column(SmallInteger, default=1)
    rejection_reason = Column(String(300), nullable=True)
    approved_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reviewed_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    student = relationship("Student", back_populates="leaves")
    teacher = relationship("Teacher")
    reviewer = relationship("User", foreign_keys=[reviewed_by])


class TimetableSlot(Base):
    __tablename__ = "timetable_slots"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True)
    room = Column(String(40), nullable=True)
    day_of_week = Column(Integer, nullable=False)  # 1=Mon ... 7=Sun
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    school_class = relationship("SchoolClass")
    section = relationship("Section")
    subject = relationship("Subject")
    teacher = relationship("Teacher")


class Homework(Base):
    __tablename__ = "homeworks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    description = Column(Text, nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="SET NULL"), nullable=True)
    due_date = Column(Date, nullable=True)
    file_path = Column(String(255), nullable=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    subject = relationship("Subject")
    school_class = relationship("SchoolClass")
    section = relationship("Section")
    teacher = relationship("Teacher")


class Assignment(Base):
    __tablename__ = "assignments"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    description = Column(Text, nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="SET NULL"), nullable=True)
    due_date = Column(Date, nullable=True)
    file_path = Column(String(255), nullable=True)
    total_marks = Column(Numeric(8, 2), default=100)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    subject = relationship("Subject")
    school_class = relationship("SchoolClass")
    section = relationship("Section")
    teacher = relationship("Teacher")
    submissions = relationship("AssignmentSubmission", back_populates="assignment")


class AssignmentSubmission(Base):
    __tablename__ = "assignment_submissions"

    id = Column(Integer, primary_key=True, index=True)
    assignment_id = Column(Integer, ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    file_path = Column(String(255), nullable=True)
    note = Column(Text, nullable=True)
    submitted_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    assignment = relationship("Assignment", back_populates="submissions")
    student = relationship("Student")


class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    audience = Column(String(30), default="all")  # all|class|section|parents|teachers
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="SET NULL"), nullable=True)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="SET NULL"), nullable=True)
    published = Column(Boolean, default=True)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    author = relationship("User", foreign_keys=[created_by])
    school_class = relationship("SchoolClass")
    section = relationship("Section")

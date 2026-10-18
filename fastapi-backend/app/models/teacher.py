from sqlalchemy import Column, Date, ForeignKey, Integer, Numeric, String, DateTime, func
from sqlalchemy.orm import relationship

from app.database import Base


class Teacher(Base):
    __tablename__ = "teachers"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    employee_code = Column(String(50), unique=True, nullable=False)
    gender = Column(String(20), nullable=True)
    qualification = Column(String(120), nullable=True)
    designation = Column(String(120), nullable=True)
    monthly_salary = Column(Numeric(12, 2), nullable=True)
    phone = Column(String(30), nullable=True)
    joining_date = Column(Date, nullable=True)
    status = Column(String(30), default="active")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="teacher")
    assignments = relationship("TeacherAssignment", back_populates="teacher")
    face_template = relationship(
        "FaceTemplate",
        primaryjoin="and_(FaceTemplate.person_type=='teacher', foreign(FaceTemplate.person_id)==Teacher.id)",
        uselist=False,
    )


class TeacherAssignment(Base):
    __tablename__ = "teacher_assignments"

    id = Column(Integer, primary_key=True, index=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="SET NULL"), nullable=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    teacher = relationship("Teacher", back_populates="assignments")
    school_class = relationship("SchoolClass")
    section = relationship("Section")
    subject = relationship("Subject")

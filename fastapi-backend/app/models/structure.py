from sqlalchemy import (
    Boolean, Column, Date, ForeignKey, Integer, SmallInteger,
    String, Text, DateTime, Numeric, func
)
from sqlalchemy.orm import relationship

from app.database import Base


class AcademicSession(Base):
    __tablename__ = "academic_sessions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    year = Column(Integer, nullable=True)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    is_current = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class SchoolClass(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    code = Column(String(30), nullable=True)
    numeric_grade = Column(Integer, default=1)
    display_order = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    sections = relationship("Section", back_populates="school_class", cascade="all, delete-orphan")
    students = relationship("Student", back_populates="school_class")


class Section(Base):
    __tablename__ = "sections"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(120), nullable=False)
    room_no = Column(String(30), nullable=True)
    capacity = Column(Integer, default=40)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    school_class = relationship("SchoolClass", back_populates="sections")
    students = relationship("Student", back_populates="section")


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    code = Column(String(30), nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="SET NULL"), nullable=True)
    type = Column(String(30), default="theory")      # theory | practical | elective
    passing_marks = Column(Numeric(8, 2), default=40)
    total_marks = Column(Numeric(8, 2), default=100)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

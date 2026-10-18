from sqlalchemy import Boolean, Column, Integer, String, DateTime, func
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    email = Column(String(191), unique=True, nullable=False, index=True)
    password = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default="admin")
    phone = Column(String(30), nullable=True)
    photo_path = Column(String(255), nullable=True)
    locale = Column(String(10), nullable=True)
    is_active = Column(Boolean, default=True)
    email_verified_at = Column(DateTime, nullable=True)
    remember_token = Column(String(100), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # Relationships
    student = relationship("Student", back_populates="user", uselist=False)
    teacher = relationship("Teacher", back_populates="user", uselist=False)
    guardian = relationship("Guardian", back_populates="user", uselist=False)
    alerts = relationship("CollegeNotification", back_populates="user")

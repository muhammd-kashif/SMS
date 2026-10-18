from app.database import engine, Base, SessionLocal
from app.models.user import User
from app.models.student import Student
from app.models.academic import *
from app.models.attendance import *
from app.models.exam import *
from app.models.fee import *
from app.models.structure import *
from app.core.security import get_password_hash

# Create tables
Base.metadata.create_all(bind=engine)

db = SessionLocal()

# Seed admin user if not exists
if not db.query(User).filter(User.email == "admin@smartcollege.test").first():
    admin = User(
        email="admin@smartcollege.test",
        password=get_password_hash("College@123"),
        name="Admin",
        role="admin",
        is_active=True
    )
    db.add(admin)

if not db.query(User).filter(User.email == "kashif@123gmail.com").first():
    kashif = User(
        email="kashif@123gmail.com",
        password=get_password_hash("College@123"),
        name="Kashif",
        role="admin",
        is_active=True
    )
    db.add(kashif)

db.commit()
db.close()

print("Database seeded with SQLite successfully!")

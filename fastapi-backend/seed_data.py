import random
from datetime import date, timedelta

from app.database import SessionLocal, Base, engine
from app.models.user import User
from app.models.structure import AcademicSession, SchoolClass, Section, Subject
from app.models.student import Guardian, Student
from app.models.teacher import Teacher, TeacherAssignment
from app.models.attendance import Attendance
from app.models.fee import FeeItem, Payment
from app.models.exam import Exam, ExamSchedule, Mark
from app.models.academic import Announcement
from app.models.misc import CollegeNotification
from app.core.security import get_password_hash

random.seed(42)
Base.metadata.create_all(bind=engine)
db = SessionLocal()

# clear rows
for model in [Payment, FeeItem, Mark, ExamSchedule, Exam, Attendance, CollegeNotification, Announcement,
              TeacherAssignment, Student, Guardian, Teacher, Subject, Section, SchoolClass, AcademicSession]:
    db.query(model).delete()
db.query(User).filter(User.email != "admin@smartcollege.test").filter(User.email != "kashif@123gmail.com").delete(synchronize_session=False)
db.commit()

# session
session = AcademicSession(name="2026-2027", year=2026, is_current=True)
db.add(session)
db.commit()

# classes
classes = []
for i in range(1, 11):
    c = SchoolClass(name=f"Class {i}", code=f"C{i}", numeric_grade=i, display_order=i)
    db.add(c)
    classes.append(c)
db.commit()
for c in classes:
    db.add(Section(class_id=c.id, name="A"))
    db.add(Section(class_id=c.id, name="B"))
db.commit()

sections = db.query(Section).all()
sections_by_class = {}
for s in sections:
    sections_by_class.setdefault(s.class_id, []).append(s)

# subjects
subject_names = ["English", "Mathematics", "Urdu", "Science", "Social Studies"]
subjects_by_class = {}
for c in classes:
    sl = []
    for nm in subject_names:
        sub = Subject(name=nm, code=nm[:3].upper(), class_id=c.id, type="theory", passing_marks=40, total_marks=100)
        db.add(sub)
        sl.append(sub)
    subjects_by_class[c.id] = sl
db.commit()

H = get_password_hash("College@123")

# teachers
teacher_names = ["Ayesha", "Bilal", "Chandra", "Daniyal", "Eman", "Faisal", "Ghazal", "Hamza",
                 "Iqra", "Junaid", "Kiran", "Laiba", "Muneeb", "Nida", "Omar"]
teachers = []
for i, nm in enumerate(teacher_names, start=1):
    user = User(name=nm + " Teacher", email=f"teacher{i}@smartcollege.test", password=H, role="teacher", phone=f"0300{i:07d}", is_active=(i != 5))
    db.add(user)
    db.flush()
    teacher = Teacher(
        user_id=user.id,
        employee_code=f"TCH-{i:04d}",
        gender=random.choice(["male", "female"]),
        qualification=random.choice(["M.A.", "M.Sc", "B.Ed", "M.Ed"]),
        designation="Teacher",
        monthly_salary=random.choice([45000, 52000, 60000]),
        phone=user.phone,
        joining_date=date(2025, random.randint(1, 12), random.randint(1, 28)),
        status="active" if i != 5 else "inactive",
    )
    db.add(teacher)
    db.flush()
    # assignment
    cls = random.choice(classes)
    sec = random.choice(sections_by_class[cls.id])
    sub = random.choice(subjects_by_class[cls.id])
    db.add(TeacherAssignment(teacher_id=teacher.id, class_id=cls.id, section_id=sec.id, subject_id=sub.id))
    teachers.append(teacher)
db.commit()

# students
students = []
first_names = ["Ali", "Sara", "Ahmed", "Fatima", "Usman", "Ayesha", "Hassan", "Zainab", "Bilal", "Noor"]
last_names = ["Khan", "Malik", "Ahmed", "Raza", "Sheikh", "Qureshi", "Butt", "Chaudhry"]
for i in range(1, 201):
    cls = classes[(i - 1) // 20] if (i - 1) // 20 < 10 else classes[-1]
    # distribute sections A/B alternating
    sec = sections_by_class[cls.id][(i % 2)]
    gender = random.choice(["male", "female"])
    fn = random.choice(first_names)
    ln = random.choice(last_names)
    name = f"{fn} {ln}"
    user = User(name=name, email=f"student{i}@smartcollege.test", password=H, role="student", phone=f"0311{i:07d}", is_active=True)
    db.add(user)
    db.flush()
    guardian = Guardian(name=f"Parent of {name}", phone=f"0321{i:07d}", email=f"guardian{i}@smartcollege.test")
    db.add(guardian)
    db.flush()
    student = Student(
        user_id=user.id,
        guardian_id=guardian.id,
        student_code=f"STU-{i:05d}",
        roll_number=f"{cls.numeric_grade:02d}{sec.name}-{(i % 40) + 1:02d}",
        class_id=cls.id,
        section_id=sec.id,
        session_id=session.id,
        father_name=random.choice(first_names) + " " + ln,
        dob=date(2013 + (i % 6), random.randint(1, 12), random.randint(1, 28)),
        gender=gender,
        phone=user.phone,
        parent_phone=guardian.phone,
        address=random.choice(["Street 1", "Model Town", "Gulberg", "DHA", "Johar Town"]),
        admission_date=date(2026, 8, 17),
        leave_allowance=20,
        status="active",
    )
    db.add(student)
    db.flush()
    students.append(student)
db.commit()

# fees
for student in students:
    db.add(FeeItem(student_id=student.id, fee_type="admission", title="Admission Fee", amount=random.choice([5000, 8000]), due_date=date(2026, 9, 1), status="paid", paid_amount=0))
    db.add(FeeItem(student_id=student.id, fee_type="monthly", title="Monthly Tuition", amount=random.choice([2000, 2500, 3000]), due_date=date(2026, 10, 5), status="pending", paid_amount=0))
db.commit()
# post some payments
all_fees = db.query(FeeItem).all()
for fee in all_fees:
    if random.random() < 0.6:
        amt = float(fee.amount)
        if random.random() < 0.3:
            amt = round(amt / 2, 2)
        p = Payment(student_id=fee.student_id, fee_item_id=fee.id, receipt_no=f"RCP-{fee.id:05d}", amount=amt, method=random.choice(["cash", "bank", "online"]), paid_at=date.today() - timedelta(days=random.randint(0, 10)), status="posted")
        db.add(p)
        fee.paid_amount = amt
        fee.refresh_status()
db.commit()

# attendance
today = date.today()
for i in range(7):
    day = today - timedelta(days=6 - i)
    if day.weekday() == 6:
        continue
    for student in students:
        r = random.random()
        if r < 0.85:
            status = "present"
        elif r < 0.93:
            status = "late"
        elif r < 0.96:
            status = "absent"
        else:
            status = "leave"
        check_time = "08:05" if status == "present" else "08:25"
        att = Attendance(person_type="student", person_id=student.id, attendance_date=day, check_in_time=__import__("datetime").time.fromisoformat(check_time), status=status, source="seed")
        db.add(att)
db.commit()

# exams
exam = Exam(name="Mid-Term 2026", exam_type="mid_term", class_id=classes[4].id, section_id=None, start_date=today + timedelta(days=10), end_date=today + timedelta(days=15), published=True)
db.add(exam)
db.commit()
db.refresh(exam)
for sub in subjects_by_class[classes[4].id]:
    db.add(ExamSchedule(exam_id=exam.id, subject_id=sub.id, exam_date=exam.start_date, start_time=__import__("datetime").time.fromisoformat("09:00"), end_time=__import__("datetime").time.fromisoformat("11:00"), room="Hall"))
db.commit()
# marks
for student in [s for s in students if s.class_id == classes[4].id]:
    for sub in subjects_by_class[classes[4].id]:
        obt = random.randint(40, 100)
        db.add(Mark(exam_id=exam.id, student_id=student.id, subject_id=sub.id, total_marks=100, obtained_marks=obt, grade="A" if obt >= 80 else "B" if obt >= 60 else "C" if obt >= 40 else "F"))
db.commit()

# announcements
db.add(Announcement(title="Welcome Back", body="School reopens with new session.", audience="all", published=True, created_by=1))
db.add(Announcement(title="Exam Schedule", body="Mid-term exams start soon.", audience="all", published=True, created_by=1))
db.commit()

# notifications
for s in students[:5]:
    db.add(CollegeNotification(user_id=s.user_id, title="Fee Due", body="Your fee voucher is pending.", type="fee"))
db.commit()

print("dummy data seeded: students", len(students), "teachers", len(teachers), "classes", len(classes))
db.close()
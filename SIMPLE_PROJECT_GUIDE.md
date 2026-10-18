# Smart College Management System - Simple Guide
# (Smart College Management System - Asaan Guide)

## 1. Project is kis chez ka? / What is this project?

**English:**
This project is a complete school/college management software. It helps a school manage students, teachers, classes, attendance, fees, exams, results, leaves, homework, assignments, announcements, notifications, reports, settings, and face attendance.

**Roman Urdu:**
Yeh project ek complete school/college management software hai. Yeh ek school ko students, teachers, classes, attendance, fees, exams, results, leaves, homework, assignments, announcements, notifications, reports, settings aur face attendance manage karne mein help karta hai.

---

## 2. Parts of the project (4 main parts)

**English:**
1. Frontend (React website) - screen users see
2. Backend (FastAPI Python API) - business logic and database handling
3. Database (SQLite/MySQL) - data storage
4. Face service (Python/OpenCV) - face recognition for attendance

**Roman Urdu:**
1. Frontend (React website) - woh screen jo user dekhta hai
2. Backend (FastAPI Python API) - business logic aur database handling
3. Database (SQLite/MySQL) - data save karne ke liye
4. Face service (Python/OpenCV) - attendance ke liye face recognition

---

## 3. Simple 10-year-old explanation

**English:**
Think of this app like a smart school office. Admin and teachers can add students, mark attendance, collect fees, upload homework, make exam schedules, and publish results. Students and parents can open their portal to see their own attendance, fees, exams, homework, leaves, timetable, and announcements. The scanner recognizes a face and marks attendance automatically.

**Roman Urdu:**
Soch ke yeh app ek smart school office hai. Admin aur teachers students add kar sakte hain, attendance mark kar sakte hain, fees collect kar sakte hain, homework upload kar sakte hain, exam schedule bana sakte hain, aur results publish kar sakte hain. Students aur parents apna portal khol kar apni attendance, fees, exams, homework, leaves, timetable, aur announcements dekh sakte hain. Scanner face recognize karta hai aur attendance automatically mark karta hai.

---

## 4. What work does it do? / Kaun kaam karta hai?

**English:**
- Admin: full control, users, settings, backups, audit logs
- Accountant: fees, reports, notifications
- Teacher: classes, attendance, exams/marks, leaves, timetable, homework, assignments, announcements
- Student: own portal and profile
- Parent: portals of linked children
- Face registration and face attendance with present/late/absent logic
- Reports as CSV/PDF

**Roman Urdu:**
- Admin: full control, users, settings, backups, audit logs
- Accountant: fees, reports, notifications
- Teacher: classes, attendance, exams/marks, leaves, timetable, homework, assignments, announcements
- Student: apna portal aur profile
- Parent: linked children ka portal
- Face registration aur face attendance with Present/Late/Absent logic
- Reports CSV/PDF form mein

---

## 5. Languages / Technologies used

**English:**
- Frontend: React, JavaScript, Vite, CSS
- Backend: Python, FastAPI, SQLAlchemy
- Database: SQLite (local) / MySQL (production)
- Face service: Python, OpenCV, YuNet, SFace
- Mobile (optional): Flutter
- Others: JWT auth, ReportLab, Pillow, httpx

**Roman Urdu:**
- Frontend: React, JavaScript, Vite, CSS
- Backend: Python, FastAPI, SQLAlchemy
- Database: SQLite (local) / MySQL (production)
- Face service: Python, OpenCV, YuNet, SFace
- Mobile (optional): Flutter
- Others: JWT auth, ReportLab, Pillow, httpx

---

## 6. How to run? / Kaise run hota hai?

**English:**
Start 3 services:
1. Backend:
   cd fastapi-backend
   venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
2. Frontend:
   cd frontend
   npm run dev
3. Face service:
   cd face-service
   python -m uvicorn app:app --host 127.0.0.1 --port 8001

Open http://127.0.0.1:5173 in browser.

**Roman Urdu:**
3 services start karo:
1. Backend:
   cd fastapi-backend
   venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
2. Frontend:
   cd frontend
   npm run dev
3. Face service:
   cd face-service
   python -m uvicorn app:app --host 127.0.0.1 --port 8001

Browser mein http://127.0.0.1:5173 open karo.

---

## 7. Demo logins

Password for all: College@123

- Admin: admin@smartcollege.test
- Teacher: teacher@smartcollege.test
- Accountant: accountant@smartcollege.test
- Student: student@smartcollege.test
- Parent: parent@smartcollege.test

**Roman Urdu:**
Sab ka password: College@123

- Admin: admin@smartcollege.test
- Teacher: teacher@smartcollege.test
- Accountant: accountant@smartcollege.test
- Student: student@smartcollege.test
- Parent: parent@smartcollege.test

---

## 8. Important URLs

- Frontend: http://127.0.0.1:5173
- Backend: http://127.0.0.1:8000
- API docs: http://127.0.0.1:8000/docs
- Face service: http://127.0.0.1:8001

---

## 9. What has been fixed in this completed version?

**English:**
- Missing backend endpoints completed
- Settings save (light/dark mode, colors) fixed
- User management added
- Face registration/scan connected
- Language persistence (English/Urdu) fixed
- Student and teacher edit/save fixed
- Database seeded with dummy school data

**Roman Urdu:**
- Missing backend endpoints complete kiye
- Settings save (light/dark mode, colors) fix kiya
- User management add kiya
- Face registration/scan connect kiya
- Language persistence (English/Urdu) fix kiya
- Student aur teacher edit/save fix kiya
- Database mein dummy school data seed kiya

---

## 10. In one line

**English:** Smart College is a full college management portal with dashboards, portals, fees, exams, attendance, face recognition, reports, and settings.

**Roman Urdu:** Smart College ek full college management portal hai jisme dashboards, portals, fees, exams, attendance, face recognition, reports, aur settings hain.

# Smart College Management System

React admin, student, teacher, and parent portals, a Laravel API, MySQL, and a Python face-recognition service.

## Development Progress

- **June 2026** — Project planning, database schema design, and initial module setup.
- **July 2026** — Frontend React portals and Laravel API development.
- **August 2026** — Face recognition service and Flutter mobile app integration.
- **September 2026** — Testing, bug fixes, and deployment configuration.
- **October 2026** — Final build, documentation, and GitHub upload.

This machine has PHP 8.2, so the API is Laravel 12 with Sanctum. Laravel 13 needs PHP 8.3 or newer. The same application structure moves to Laravel 13 after that PHP upgrade. Local XAMPP provides MariaDB 10.4, which is compatible with the MySQL 8 schema used in production.

## Run locally

Start MySQL from XAMPP, then in three terminals:

```powershell
cd E:\Mernprojects\SMS\backend
php artisan serve --host=127.0.0.1 --port=8000
```

```powershell
cd E:\Mernprojects\SMS\frontend
npm run dev
```

```powershell
cd E:\Mernprojects\SMS\face-service
C:\Users\FARHAN\AppData\Local\Programs\Python\Python312\python.exe -m uvicorn app:app --host 127.0.0.1 --port 8001
```

Open http://127.0.0.1:5173

The first face-service start downloads the YuNet and SFace models into `face-service/models`.

## Demo accounts

Password for every account: `College@123`

| Role | Email |
| --- | --- |
| Admin | admin@smartcollege.test |
| Teacher | teacher@smartcollege.test |
| Accountant | accountant@smartcollege.test |
| Student | student@smartcollege.test |
| Parent | parent@smartcollege.test |

The student account is Ayesha Malik, Class 5 A, roll `05A-01`. Her father, Tariq Malik, can also open her brother Hassan Malik in Class 3 A.

## Reset demo data

`php artisan db:seed --force` removes the previous school records and loads Crescent Model School for session 2026-2027. Settings such as the logo are kept. Staff, teacher, student, and parent logins are recreated, so existing API tokens stop working.

Seed order: clear rows, academic session, classes and sections, subjects, teachers, students, teacher assignments, timetable, attendance, fee vouchers and receipts, exams and marks, then leaves, homework, assignments, announcements, and face rows.

| Data | What is loaded |
| --- | --- |
| Students | 200 across Class 1–10, sections A and B. Each has a student ID, roll number, guardian, contact, address, date of birth, admission date, and status. |
| Teachers | 15, with employee ID, gender, qualification, designation, monthly salary, subject, and class assignment. One teacher is inactive. |
| Attendance | 17 Aug 2026 through the last school day, Monday–Saturday. Present rates sit between 75% and 98%. Check-in times fall before 08:15 for Present and after it for Late. |
| Fees | Admission plus monthly tuition. Vouchers are paid, partial, pending, or overdue, with receipt numbers on posted payments. |
| Exams | Mid-term and September monthly results, plus the February 2027 date sheet. |
| Other | Leave requests, timetable, homework, assignments, announcements, notifications, and fee defaulters from overdue vouchers. |

The first student in each section, and every teacher, has one face row. Embeddings are unique. They are placeholders, not camera photos, so a live scan will not match them. Register a real face from the Face page to replace a row. This project has no library module, so books are not seeded.

## Attendance rules

Arrival at or before `present_until` (default 08:15) is Present. A later arrival is Late. Closing the day marks everyone else Absent, or Leave when an approved leave covers that date. A second face scan on the same day does not create another record.

Face data is stored as an embedding, not the camera frame. Offline scans stay in the browser and sync when the API is reachable. The sync uses the original capture time and a client id so the same scan is not inserted twice.

## Production

See `deploy/nginx.conf`. On Ubuntu, run PHP-FPM or `php artisan serve` behind Nginx, MySQL 8, the built React app, and the Python service. Point `FACE_SERVICE_URL` at that service. Schedule `php artisan schedule:run` every minute so fee reminders and late fees run at 07:00.

Backups are created from Settings and stored in `backend/storage/app/backups`.

Smart College Flutter app
=========================

This app follows the Figma frames in design/smart-college-figma.html.
It is a separate folder from the React website.

Run it from this folder:

  E:\flutter_windows_3.35.1-stable\flutter\bin\flutter.bat pub get
  E:\flutter_windows_3.35.1-stable\flutter\bin\flutter.bat run -d chrome

Or on a phone:

  flutter run

Sign in
  Admin     admin@smartcollege.test
  Student   student@smartcollege.test
  Password  College@123

Sign-in calls POST /api/login on the Laravel server at
http://127.0.0.1:8000. Start that server before opening the app.
An Android emulator uses http://10.0.2.2:8000/api.

Lists and save actions use the same API: students, teachers, classes,
timetable, attendance, fees, payments, exams, results, leaves, homework,
assignments, announcements, notifications, reports, portal, and settings.
A student or parent account opens the portal and reads those records
from GET /api/portal. Face capture stays on the web desk; this app
checks GET /api/face/health and does not pretend a face was saved.

import { useEffect, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth';
import { I18nProvider } from './i18n';
import Shell from './Shell';
import { FeedbackProvider, Loader } from './ui';
import Academics from './pages/Academics';
import { AttendanceList, FaceRegister, MyAttendance, Scan } from './pages/Attendance';
import Classes from './pages/Classes';
import { Announcements, Notifications } from './pages/Communication';
import Dashboard from './pages/Dashboard';
import Exams from './pages/Exams';
import Fees from './pages/Fees';
import Leaves from './pages/Leaves';
import Login from './pages/Login';
import Portal from './pages/Portal';
import Reports from './pages/Reports';
import Profile from './pages/Profile';
import Settings from './pages/Settings';
import { StudentForm, StudentProfile, Students } from './pages/Students';
import Teachers from './pages/Teachers';

function Guard() {
  const { user, ready } = useAuth();
  if (!ready) return <Loader full />;
  if (!user) return <Navigate to="/login" replace />;
  return <Shell />;
}

function Home() {
  const { user } = useAuth();
  if (user?.role === 'student' || user?.role === 'parent') return <Navigate to="/portal" replace />;
  return <Dashboard />;
}

function AppRoutes() {
  const { user } = useAuth();
  const [locale, setLocale] = useState(localStorage.getItem('sms_locale') || 'en');
  useEffect(() => {
    if (user?.locale) setLocale(user.locale);
  }, [user]);
  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = locale === 'ur' ? 'rtl' : 'ltr';
    document.title = locale === 'ur' ? 'سمارٹ کالج' : 'Smart College';
    localStorage.setItem('sms_locale', locale);
  }, [locale]);

  return (
    <I18nProvider locale={locale} setLocale={setLocale}>
      <FeedbackProvider>
      <Routes>
        <Route path="/login" element={user ? <Navigate to="/" replace /> : <Login />} />
        <Route element={<Guard />}>
          <Route index element={<Home />} />
          <Route path="profile" element={<Profile />} />
          <Route path="students" element={<Students />} />
          <Route path="students/new" element={<StudentForm />} />
          <Route path="students/:id/edit" element={<StudentForm />} />
          <Route path="students/:id" element={<StudentProfile />} />
          <Route path="teachers" element={<Teachers />} />
          <Route path="classes" element={<Classes />} />
          <Route path="attendance/scan" element={<Scan />} />
          <Route path="attendance" element={<AttendanceList />} />
          <Route path="my-attendance" element={<MyAttendance />} />
          <Route path="face/register" element={<FaceRegister />} />
          <Route path="fees" element={<Fees />} />
          <Route path="exams" element={<Exams />} />
          <Route path="leaves" element={<Leaves />} />
          <Route path="academics" element={<Academics />} />
          <Route path="announcements" element={<Announcements />} />
          <Route path="notifications" element={<Notifications />} />
          <Route path="reports" element={<Reports />} />
          <Route path="settings" element={<Settings />} />
          <Route path="portal" element={<Portal />} />
        </Route>
      </Routes>
      </FeedbackProvider>
    </I18nProvider>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}

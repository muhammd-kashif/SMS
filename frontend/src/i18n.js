import { createContext, createElement, useContext, useMemo } from 'react';
import { phrases, terms } from './phrases';
import { toUrduScript } from './urduScript';

const dictionary = {
  en: {
    college: 'Smart College',
    signIn: 'Sign in',
    signOut: 'Sign out',
    viewProfile: 'View profile',
    editProfile: 'Edit profile',
    changePassword: 'Change password',
    email: 'Email',
    password: 'Password',
    dashboard: 'Dashboard',
    students: 'Students',
    allStudents: 'All students',
    addStudent: 'Add student',
    faceRegistration: 'Face registration',
    teachers: 'Teachers',
    classes: 'Classes & sections',
    attendance: 'Attendance',
    faceAttendance: 'Attendance scanner',
    studentAttendance: 'Student attendance',
    teacherAttendance: 'Teacher attendance',
    myAttendance: 'My attendance',
    fees: 'Fees',
    feeManagement: 'Fee management',
    payments: 'Payments',
    pendingFees: 'Pending fees',
    receipts: 'Receipts',
    examinations: 'Examinations',
    exams: 'Exams',
    schedule: 'Schedule',
    marks: 'Marks',
    results: 'Results',
    leaves: 'Leaves',
    academics: 'Academics',
    timetable: 'Timetable',
    homework: 'Homework',
    assignments: 'Assignments',
    communication: 'Communication',
    notifications: 'Notifications',
    announcements: 'Announcements',
    reports: 'Reports',
    settings: 'Settings',
    structure: 'Fee structure',
    studentFees: 'Student fees',
    collectFee: 'Collect fee',
    voucher: 'Fee voucher',
    defaulters: 'Defaulters',
    myClasses: 'My classes',
    myChildren: 'My children',
    portal: 'My portal',
    profile: 'Profile',
    save: 'Save',
    cancel: 'Cancel',
    search: 'Search',
    create: 'Create',
    update: 'Update',
    download: 'Download',
    print: 'Print',
    share: 'Share',
    present: 'Present',
    absent: 'Absent',
    late: 'Late',
    leave: 'Leave',
    language: 'Language',
    english: 'English',
    urdu: 'Urdu',
    loading: 'Loading…',
    empty: 'Nothing to show yet.',
    confirm: 'Please confirm',
    yes: 'Yes',
    no: 'No',
    overview: 'Overview',
    academic: 'Academic',
    finance: 'Finance',
    studentServices: 'Student services',
    resources: 'Resources',
    navCollege: 'College',
    study: 'Study',
    work: 'Work',
    admin: 'Admin',
    teacher: 'Teacher',
    student: 'Student',
    parent: 'Parent',
    accountant: 'Accountant',
    markAllRead: 'Mark all as read',
    dashboardText: 'Students, attendance, fees, and the work waiting today.',
    quickActions: 'Quick actions',
    sendAnnouncement: 'Send announcement',
    createExam: 'Create exam',
    startAttendance: 'Start attendance',
    registerFace: 'Register face',
    presentToday: 'Present today',
    totalTeachers: 'Total teachers',
    totalStudents: 'Total students',
    upcomingExams: 'Upcoming exams',
    feePending: 'Fee pending',
    lateToday: 'Late today',
    postedPayments: 'Posted payments',
    feeCollection: 'Fee collection',
    presentAndLate: 'Present and late',
    attendanceTrend: 'Attendance trend',
    classWiseToday: 'Class-wise attendance today',
    noClassesYet: 'No classes yet.',
    noUpcomingExams: 'No upcoming exams.',
    dashboardLoadError: 'Unable to load the dashboard.',
  },
  ur: {
    college: 'سمارٹ کالج',
    signIn: 'داخل ہوں',
    signOut: 'خارج ہوں',
    viewProfile: 'پروفائل دیکھیں',
    editProfile: 'پروفائل میں ترمیم',
    changePassword: 'پاس ورڈ تبدیل کریں',
    email: 'ای میل',
    password: 'پاس ورڈ',
    dashboard: 'ڈیش بورڈ',
    students: 'طلبہ',
    allStudents: 'تمام طلبہ',
    addStudent: 'طالب علم شامل کریں',
    faceRegistration: 'چہرہ رجسٹر کریں',
    teachers: 'اساتذہ اور عملہ',
    classes: 'کلاسز',
    attendance: 'حاضری',
    faceAttendance: 'چہرے سے حاضری',
    studentAttendance: 'طلبہ کی حاضری',
    teacherAttendance: 'اساتذہ کی حاضری',
    myAttendance: 'میری حاضری',
    fees: 'فیس',
    feeManagement: 'فیس مینجمنٹ',
    payments: 'ادائیگیاں',
    pendingFees: 'باقی فیس',
    receipts: 'رسیدیں',
    examinations: 'امتحانات',
    exams: 'امتحانات',
    schedule: 'شیڈول',
    marks: 'نمبر',
    results: 'نتائج',
    leaves: 'چھٹیاں',
    academics: 'تعلیم',
    timetable: 'ٹائم ٹیبل',
    homework: 'ہوم ورک',
    assignments: 'اسائنمنٹس',
    communication: 'رابطہ',
    notifications: 'اطلاعات',
    announcements: 'اعلانات',
    reports: 'رپورٹس',
    settings: 'ترتیبات',
    structure: 'فیس کا ڈھانچہ',
    studentFees: 'طلبہ کی فیس',
    collectFee: 'فیس وصول کریں',
    voucher: 'فیس واؤچر',
    defaulters: 'بقایا جات',
    myClasses: 'میری کلاسیں',
    myChildren: 'میرے بچے',
    portal: 'میرا پورٹل',
    profile: 'پروفائل',
    save: 'محفوظ کریں',
    cancel: 'منسوخ',
    search: 'تلاش',
    create: 'بنائیں',
    update: 'تبدیل کریں',
    download: 'ڈاؤن لوڈ',
    print: 'پرنٹ',
    share: 'شیئر',
    present: 'حاضر',
    absent: 'غیر حاضر',
    late: 'دیر',
    leave: 'چھٹی',
    language: 'زبان',
    english: 'انگریزی',
    urdu: 'اردو',
    loading: 'لوڈ ہو رہا ہے…',
    empty: 'ابھی کوئی ریکارڈ نہیں۔',
    confirm: 'تصدیق کریں',
    yes: 'ہاں',
    no: 'نہیں',
    overview: 'جائزہ',
    academic: 'تعلیمی',
    finance: 'مالیات',
    studentServices: 'طلبہ کی خدمات',
    resources: 'وسائل',
    navCollege: 'کالج',
    study: 'تعلیم',
    work: 'کام',
    admin: 'ایڈمن',
    teacher: 'استاد',
    student: 'طالب علم',
    parent: 'والدین',
    accountant: 'اکاؤنٹنٹ',
    markAllRead: 'سب کو پڑھا ہوا نشان زد کریں',
    dashboardText: 'طلبہ، حاضری، فیس، اور آج کا باقی کام۔',
    quickActions: 'فوری کام',
    sendAnnouncement: 'اعلان بھیجیں',
    createExam: 'امتحان بنائیں',
    startAttendance: 'حاضری شروع کریں',
    registerFace: 'چہرہ رجسٹر کریں',
    presentToday: 'آج حاضر',
    totalTeachers: 'کل اساتذہ',
    totalStudents: 'کل طلبہ',
    upcomingExams: 'آنے والے امتحانات',
    feePending: 'باقی فیس',
    lateToday: 'آج دیر سے',
    postedPayments: 'درج شدہ ادائیگیاں',
    feeCollection: 'فیس وصولی',
    presentAndLate: 'حاضر اور دیر',
    attendanceTrend: 'حاضری کا رجحان',
    classWiseToday: 'آج کلاس کے لحاظ سے حاضری',
    noClassesYet: 'ابھی کوئی کلاس نہیں۔',
    noUpcomingExams: 'کوئی آنے والا امتحان نہیں۔',
    dashboardLoadError: 'ڈیش بورڈ لوڈ نہیں ہو سکا۔',
  },
};

const I18nContext = createContext(null);

const termList = [...terms].sort((a, b) => b.length - a.length);

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function translateText(locale, value) {
  if (value == null || typeof value === 'number' || typeof value === 'boolean') return value;
  const text = String(value);
  if (!text.trim() || locale !== 'ur') return text;
  const exact = lookup(text);
  if (exact) return exact;
  let next = text;
  next = next.replace(/\bClass (\d+)\b/g, 'کلاس $1');
  next = next.replace(/\bRoom (\d+[A-Za-z]?)\b/g, 'کمرہ $1');
  next = next.replace(/\bHall (\d+)\b/g, 'ہال $1');
  next = next.replace(/\bSample (\d+) saved\./g, 'نمونہ $1 محفوظ ہو گیا۔');
  next = next.replace(/\bSample (\d+) of (\d+)/g, 'نمونہ $1 از $2');
  for (const key of termList) {
    const urdu = phrases[key];
    if (!urdu || !next.includes(key)) continue;
    const pattern = new RegExp(`(?<![A-Za-z0-9])${escapeRegExp(key)}(?![A-Za-z0-9])`, 'g');
    next = next.replace(pattern, urdu);
  }
  return toUrduScript(next);
}

function lookup(text) {
  if (phrases[text]) return phrases[text];
  const trimmed = text.trim();
  if (phrases[trimmed]) return phrases[trimmed];
  const lower = trimmed.toLowerCase();
  if (phrases[lower]) return phrases[lower];
  const human = trimmed.replaceAll('_', ' ');
  if (phrases[human]) return phrases[human];
  const titled = human.replace(/\b[a-z]/g, (letter) => letter.toUpperCase());
  if (phrases[titled]) return phrases[titled];
  return '';
}

export function I18nProvider({ locale, setLocale, children }) {
  const value = useMemo(() => ({
    locale,
    setLocale,
    dir: locale === 'ur' ? 'rtl' : 'ltr',
    t: (key) => dictionary[locale]?.[key] || dictionary.en[key] || translateText(locale, key),
    tx: (value) => translateText(locale, value),
  }), [locale, setLocale]);
  return createElement(I18nContext.Provider, { value }, children);
}

export function useI18n() {
  return useContext(I18nContext);
}

import {Input,  Tr } from './ui';
import { useEffect, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { api } from './api';
import { can, useAuth } from './auth';
import { useI18n } from './i18n';

const adminGroups = [
  { section: 'Overview', label: 'dashboard', to: '/', module: 'dashboard' },
  { section: 'Academic', label: 'students', to: '/students', module: 'students' },
  { section: 'Academic', label: 'teachers', to: '/teachers', module: 'students' },
  { section: 'Academic', label: 'classes', to: '/classes', module: 'settings' },
  { section: 'Academic', label: 'timetable', to: '/academics?tab=timetable', module: 'academics' },
  {
    section: 'Attendance', label: 'attendance', module: 'attendance', children: [
      { label: 'faceAttendance', to: '/attendance/scan' },
      { label: 'faceRegistration', to: '/face/register', face: true },
      { label: 'studentAttendance', to: '/attendance' },
      { label: 'teacherAttendance', to: '/attendance?type=teacher' },
    ],
  },
  {
    section: 'Finance', label: 'fees', module: 'fees', children: [
      { label: 'structure', to: '/fees?tab=structure' },
      { label: 'collectFee', to: '/fees?tab=collect' },
      { label: 'studentFees', to: '/fees' },
      { label: 'voucher', to: '/fees?tab=voucher' },
      { label: 'payments', to: '/fees?tab=payments' },
      { label: 'defaulters', to: '/fees?tab=defaulters' },
    ],
  },
  {
    section: 'Examination', label: 'examinations', module: 'exams', children: [
      { label: 'schedule', to: '/exams?tab=schedule' },
      { label: 'exams', to: '/exams' },
      { label: 'marks', to: '/exams?tab=marks' },
      { label: 'results', to: '/exams?tab=results' },
    ],
  },
  { section: 'Student Services', label: 'leaves', to: '/leaves', module: 'leaves' },
  { section: 'Student Services', label: 'homework', to: '/academics?tab=homework', module: 'academics' },
  { section: 'Student Services', label: 'assignments', to: '/academics?tab=assignments', module: 'academics' },
  { section: 'Student Services', label: 'announcements', to: '/announcements', module: 'communication' },
  { section: 'Resources', label: 'reports', to: '/reports', module: 'reports' },
  { section: 'Resources', label: 'settings', to: '/settings', module: 'settings' },
];

const accountantGroups = [
  { section: 'Overview', label: 'dashboard', to: '/' },
  {
    section: 'Finance', label: 'fees', children: [
      { label: 'structure', to: '/fees?tab=structure' },
      { label: 'studentFees', to: '/fees' },
      { label: 'collectFee', to: '/fees?tab=collect' },
      { label: 'voucher', to: '/fees?tab=voucher' },
      { label: 'payments', to: '/fees?tab=payments' },
      { label: 'receipts', to: '/fees?tab=receipts' },
      { label: 'pendingFees', to: '/fees?tab=pending' },
      { label: 'defaulters', to: '/fees?tab=defaulters' },
    ],
  },
  { section: 'College', label: 'reports', to: '/reports' },
  { section: 'College', label: 'notifications', to: '/notifications' },
  { section: 'College', label: 'profile', to: '/profile' },
];

const teacherGroups = [
  { section: 'Overview', label: 'dashboard', to: '/' },
  { section: 'Academic', label: 'students', to: '/students' },
  { section: 'Academic', label: 'timetable', to: '/academics?tab=timetable' },
  { section: 'Attendance', label: 'studentAttendance', to: '/attendance' },
  { section: 'Attendance', label: 'myAttendance', to: '/my-attendance' },
  { section: 'Examination', label: 'exams', to: '/exams' },
  { section: 'Examination', label: 'marks', to: '/exams?tab=marks' },
  { section: 'Student Services', label: 'homework', to: '/academics?tab=homework' },
  { section: 'Student Services', label: 'assignments', to: '/academics?tab=assignments' },
  { section: 'Student Services', label: 'announcements', to: '/announcements' },
];

const sectionKeys = {
  Overview: 'overview',
  Academic: 'academic',
  Attendance: 'attendance',
  Finance: 'finance',
  Examination: 'examinations',
  'Student Services': 'studentServices',
  Resources: 'resources',
  College: 'navCollege',
  Study: 'study',
  Work: 'work',
};

function linkMatches(to, pathname, search) {
  if (!to) return false;
  const [path, query = ''] = to.split('?');
  const wanted = new URLSearchParams(query);
  const current = new URLSearchParams(search);
  const exactPath = pathname === path;
  const nested = path !== '/' && pathname.startsWith(`${path}/`);
  if (!exactPath && !nested) return false;
  if ([...wanted.keys()].length) {
    return exactPath && [...wanted.entries()].every(([key, value]) => current.get(key) === value);
  }
  if (current.get('tab') || current.get('type')) return false;
  return true;
}

function activeTo(links, pathname, search) {
  return links.filter((to) => linkMatches(to, pathname, search)).sort((a, b) => b.length - a.length)[0] || '';
}

function NavIcon({ name }) {
  const shapes = {
    dashboard: <path d="M4 11 12 4l8 7v8a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1z" />,
    students: <><path d="M16 20v-1.2A3.8 3.8 0 0 0 12.2 15H7.8A3.8 3.8 0 0 0 4 18.8V20" /><circle cx="10" cy="8" r="3" /><path d="M20 20v-1.1A3.2 3.2 0 0 0 17.2 16M15 5.2a3 3 0 0 1 0 5.6" /></>,
    teachers: <><path d="M3 10 12 5l9 5-9 5-9-5z" /><path d="M7 12v4.5c0 .8 2.2 2.5 5 2.5s5-1.7 5-2.5V12" /></>,
    classes: <><rect x="4" y="4" width="7" height="7" rx="1.5" /><rect x="13" y="4" width="7" height="7" rx="1.5" /><rect x="4" y="13" width="7" height="7" rx="1.5" /><rect x="13" y="13" width="7" height="7" rx="1.5" /></>,
    attendance: <><circle cx="12" cy="12" r="8" /><path d="M12 8v5l3 2" /></>,
    fees: <><rect x="3" y="6" width="18" height="12" rx="2" /><path d="M3 10h18M7 15h4" /></>,
    examinations: <><path d="M7 3h8l4 4v14H7z" /><path d="M15 3v4h4M9 13h6M9 17h4" /></>,
    leaves: <path d="M12 21s-7-4.4-7-10a4 4 0 0 1 7-2 4 4 0 0 1 7 2c0 5.6-7 10-7 10z" />,
    academics: <><path d="M4 19V6l8-3 8 3v13" /><path d="M12 3v16" /></>,
    communication: <path d="M5 6h14v9H8l-3 3z" />,
    reports: <><path d="M5 19V5h14v14z" /><path d="M8 15v-3M12 15V8M16 15v-5" /></>,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4" /></>,
    profile: <><circle cx="12" cy="8" r="3" /><path d="M6 19a6 6 0 0 1 12 0" /></>,
    notifications: <><path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15z" /><path d="M10 19a2 2 0 0 0 4 0" /></>,
  };
  const aliases = { myClasses: 'classes', homework: 'examinations', assignments: 'examinations', exams: 'examinations', marks: 'reports', announcements: 'communication', timetable: 'attendance', results: 'reports', myChildren: 'students' };
  return (
    <svg className="nav-ico" viewBox="0 0 24 24" aria-hidden="true">
      {shapes[name] || shapes[aliases[name]] || shapes.dashboard}
    </svg>
  );
}

function NavGroup({ item, onNavigate }) {
  const { t } = useI18n();
  const { user } = useAuth();
  const location = useLocation();
  const children = (item.children || []).filter((child) => (!child.admin || user?.role === 'admin') && (!child.face || can(user, 'face')));
  const current = activeTo(children.length ? children.map((child) => child.to) : [item.to], location.pathname, location.search);
  const childActive = Boolean(current);
  const [open, setOpen] = useState(childActive);
  useEffect(() => { if (childActive) setOpen(true); }, [childActive]);

  if (!children.length) {
    return (
      <NavLink to={item.to} className={() => `nav-link${current === item.to ? ' active' : ''}`} onClick={onNavigate}>
        <span className="nav-text"><NavIcon name={item.label} />{t(item.label)}</span>
      </NavLink>
    );
  }

  return (
    <div className={open ? 'nav-group open' : 'nav-group'}>
      <button type="button" className={childActive ? 'nav-link active' : 'nav-link'} onClick={() => setOpen((value) => !value)}>
        <span className="nav-text"><NavIcon name={item.label} />{t(item.label)}</span>
        <span className="chev" aria-hidden="true" />
      </button>
      {open ? (
        <div className="sub">
          {children.map((child) => (
            <NavLink key={child.to} to={child.to} className={() => (current === child.to ? 'active' : undefined)} onClick={onNavigate}>{t(child.label)}</NavLink>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function portalGroups(role) {
  const items = [
    { section: 'Overview', label: 'dashboard', to: '/portal' },
    { section: 'Study', label: 'attendance', to: '/portal?tab=attendance' },
    { section: 'Study', label: 'fees', to: '/portal?tab=fees' },
    { section: 'Study', label: 'exams', to: '/portal?tab=exams' },
    { section: 'Study', label: 'results', to: '/portal?tab=results' },
    { section: 'Study', label: 'leaves', to: '/portal?tab=leaves' },
    { section: 'Work', label: 'timetable', to: '/portal?tab=timetable' },
    { section: 'Work', label: 'homework', to: '/portal?tab=homework' },
    { section: 'Work', label: 'assignments', to: '/portal?tab=assignments' },
    { section: 'College', label: 'announcements', to: '/portal?tab=announcements' },
    { section: 'College', label: 'notifications', to: '/notifications' },
    { section: 'College', label: 'profile', to: '/profile' },
  ];
  if (role === 'parent') items.splice(1, 0, { section: 'Overview', label: 'myChildren', to: '/portal?tab=children' });
  return items;
}

export default function Shell() {
  const { user, logout, updateUser } = useAuth();
  const { t, tx, locale, setLocale } = useI18n();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [notesOpen, setNotesOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [notes, setNotes] = useState([]);
  const [unread, setUnread] = useState(0);
  const [query, setQuery] = useState('');
  const localeRequest = useRef(locale);
  const college = user?.college || {};

  function loadNotes() {
    api('/api/notifications').then((data) => {
      setUnread(data.unread || 0);
      setNotes((data.data || []).slice(0, 6));
    }).catch(() => {});
  }

  useEffect(() => { loadNotes(); }, [user]);

  async function changeLanguage(next) {
    localeRequest.current = next;
    setLocale(next);
    if (!user) return;
    try {
      const profile = await api('/api/me', { method: 'PUT', body: { locale: next } });
      if (localeRequest.current === next) updateUser(profile);
    } catch {
      if (localeRequest.current === next) setLocale(locale);
    }
  }

  const visible = user?.role === 'accountant'
    ? accountantGroups
    : user?.role === 'teacher'
    ? teacherGroups
    : user?.role === 'student' || user?.role === 'parent'
      ? portalGroups(user.role)
      : adminGroups.filter((item) => can(user, item.module));

  function search(event) {
    event.preventDefault();
    const term = query.trim();
    if (!term) return;
    if (user?.role === 'accountant') navigate(`/fees?search=${encodeURIComponent(term)}`);
    else if (user?.role === 'student' || user?.role === 'parent') navigate(`/portal?tab=attendance`);
    else navigate(`/students?search=${encodeURIComponent(term)}`);
    setOpen(false);
  }

  return (
    <div className="shell">
      {open ? <button className="drawer-back" aria-label="Close menu" onClick={() => setOpen(false)} /> : null}
      <aside className={open ? 'sidebar open' : 'sidebar'}>
        <div className="brand brand-block">
          <img className="brand-logo" src={college.logo_url || '/logo.png'} alt="" />
        </div>
        <nav>
          {visible.map((item, index) => {
            const showSection = item.section && item.section !== visible[index - 1]?.section;
            return (
              <div key={item.label + (item.to || '')}>
                {showSection ? <div className="nav-label">{t(sectionKeys[item.section] || item.section)}</div> : null}
                <NavGroup item={item} onNavigate={() => setOpen(false)} />
              </div>
            );
          })}
        </nav>
      </aside>
      <div className="main">
        <header className="topbar">
          <button className="menu-btn" onClick={() => setOpen((value) => !value)} aria-label="Open menu">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>
          </button>
          <form className="search-box" onSubmit={search}>
            <svg className="search-ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="M20 20l-3.5-3.5" /></svg>
            <Input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={t('search')} aria-label={t('search')} />
          </form>
          <div className="top-actions">
            <div className="lang-switch" role="group" aria-label={t('language')}>
              <button type="button" lang="en" className={locale === 'en' ? 'active' : 'urdu-label'} aria-pressed={locale === 'en'} onClick={() => changeLanguage('en')}>{locale === 'ur' ? 'انگریزی' : 'English'}</button>
              <button type="button" lang="ur" className={locale === 'ur' ? 'active' : ''} aria-pressed={locale === 'ur'} onClick={() => changeLanguage('ur')}>اردو</button>
            </div>
            <div className="user-menu">
              <button className="icon-btn" aria-label={t('notifications')} onClick={() => { setNotesOpen((value) => !value); setProfileOpen(false); }}>
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15z" /><path d="M10 19a2 2 0 0 0 4 0" /></svg>
                {unread > 0 ? <span className="badge-count">{unread}</span> : null}
              </button>
              {notesOpen ? (
                <div className="notice-panel">
                  <strong>{t('notifications')}</strong>
                  {notes.length === 0 ? <p>{t('empty')}</p> : notes.map((note) => (
                    <button key={note.id} className={note.read_at ? 'notice-item' : 'notice-item unread'} onClick={async () => {
                      await api(`/api/notifications/${note.id}/read`, { method: 'POST' });
                      setNotesOpen(false);
                      navigate('/notifications');
                    }}>
                      <strong>{tx(note.title)}</strong>
                      <span>{tx(note.body)}</span>
                    </button>
                  ))}
                  <button className="btn ghost" onClick={async () => { await api('/api/notifications/read-all', { method: 'POST' }); loadNotes(); }}>{t('markAllRead')}</button>
                </div>
              ) : null}
            </div>
            <div className="user-menu">
              <button className="user-chip" onClick={() => { setProfileOpen((value) => !value); setNotesOpen(false); }}>
                {user?.face_photo_url || user?.photo_url
                  ? <img className="avatar-sm" src={user.face_photo_url || user.photo_url} alt="" />
                  : <span className="avatar-sm">{(user?.name || 'U').trim().charAt(0).toUpperCase()}</span>}
                <span className="user-meta">
                  <strong>{tx(user?.name)}</strong>
                  <span>{t(user?.role)}</span>
                </span>
              </button>
              {profileOpen ? (
                <div className="menu-panel profile-menu">
                  <div className="profile-menu-head">
                    {user?.face_photo_url || user?.photo_url
                      ? <img className="avatar-sm" src={user.face_photo_url || user.photo_url} alt="" />
                      : <span className="avatar-sm">{(user?.name || 'U').trim().charAt(0).toUpperCase()}</span>}
                    <span>
                      <strong>{tx(user?.name)}</strong>
                      <span>{t(user?.role)}</span>
                    </span>
                  </div>
                  <button className="menu-item" type="button" onClick={() => { setProfileOpen(false); navigate('/profile'); }}>
                    <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="3" /><path d="M6 19a6 6 0 0 1 12 0" /></svg>
                    <span>{t('viewProfile')}</span>
                  </button>
                  <button className="menu-item" type="button" onClick={() => { setProfileOpen(false); navigate('/profile?tab=edit'); }}>
                    <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h4l10-10-4-4L4 16z" /><path d="M13 7l4 4" /></svg>
                    <span>{t('editProfile')}</span>
                  </button>
                  <button className="menu-item" type="button" onClick={() => { setProfileOpen(false); navigate('/profile?tab=password'); }}>
                    <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="9" rx="2" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></svg>
                    <span>{t('changePassword')}</span>
                  </button>
                  <button className="menu-item danger" type="button" onClick={logout}>
                    <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M10 7V5H5v14h5v-2" /><path d="M10 12h9M16 9l3 3-3 3" /></svg>
                    <span>{t('signOut')}</span>
                  </button>
                </div>
              ) : null}
            </div>
          </div>
        </header>
        <Outlet />
      </div>
    </div>
  );
}

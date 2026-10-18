import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { can, useAuth } from '../auth';
import { useI18n } from '../i18n';
import { Loader, money, Page } from '../ui';

const urduMonths = {
  Jan: 'جن', Feb: 'فر', Mar: 'مار', Apr: 'اپر', May: 'مئی', Jun: 'جون',
  Jul: 'جول', Aug: 'اگ', Sep: 'ست', Oct: 'اکت', Nov: 'نو', Dec: 'دس',
};

export default function Dashboard() {
  const { user } = useAuth();
  const { t, tx, locale } = useI18n();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  useEffect(() => {
    api('/api/dashboard').then(setData).catch(() => setError('dashboardLoadError'));
  }, []);
  if (!data) return <Page title={t('dashboard')}>{error ? <p className="error">{t(error)}</p> : <Loader />}</Page>;
  const max = Math.max(1, ...data.trend.map((day) => day.present + day.absent + day.late));
  const feeMax = Math.max(1, ...(data.fee_trend || []).map((item) => item.amount));
  return (
    <Page title={t('dashboard')} text={t('dashboardText')}>
      <article className="card quick-card">
        <h3>{t('quickActions')}</h3>
        <div className="quick-actions">
          {can(user, 'students') ? <Link className="btn" to="/students/new">{t('addStudent')}</Link> : null}
          {can(user, 'face') ? <Link className="btn ghost" to="/face/register">{t('registerFace')}</Link> : null}
          {can(user, 'attendance') ? <Link className="btn ghost" to="/attendance/scan">{t('startAttendance')}</Link> : null}
          {can(user, 'fees') ? <Link className="btn" to="/fees?tab=collect">{t('collectFee')}</Link> : null}
          {can(user, 'exams') ? <Link className="btn ghost" to="/exams">{t('createExam')}</Link> : null}
          {can(user, 'communication') ? <Link className="btn ghost" to="/announcements">{t('sendAnnouncement')}</Link> : null}
        </div>
      </article>
      <div className="grid stats">
        <article className="card stat students"><span>{t('totalStudents')}</span><strong>{data.students}</strong></article>
        <article className="card stat teachers"><span>{t('totalTeachers')}</span><strong>{data.teachers}</strong></article>
        <article className="card stat present"><span>{t('presentToday')}</span><strong>{data.attendance.present}</strong></article>
        <article className="card stat late"><span>{t('lateToday')}</span><strong>{data.attendance.late}</strong></article>
        <article className="card stat fees"><span>{t('feePending')}</span><strong>{money(data.fees.pending, locale)}</strong></article>
        <article className="card stat exams"><span>{t('upcomingExams')}</span><strong>{data.upcoming_exams.length}</strong></article>
      </div>
      <div className="grid two">
        <article className="card chart-card">
          <div className="card-head"><h3>{t('attendanceTrend')}</h3><span className="hint">{t('presentAndLate')}</span></div>
          <div className="bars">
            {data.trend.map((day) => (
              <div key={day.date} className="bar" style={{ height: `${((day.present + day.late) / max) * 100}%`, background: 'color-mix(in srgb, var(--primary) 55%, white)' }} title={`${day.present} ${t('present')}`}>
                <span>{day.date.slice(8)}</span>
              </div>
            ))}
          </div>
        </article>
        <article className="card chart-card">
          <div className="card-head"><h3>{t('feeCollection')}</h3><span className="hint">{t('postedPayments')}</span></div>
          <div className="bars">
            {(data.fee_trend || []).map((item) => (
              <div key={item.label} className="bar" style={{ height: `${(item.amount / feeMax) * 100}%`, background: 'color-mix(in srgb, var(--secondary) 70%, white)' }} title={money(item.amount, locale)}>
                <span>{locale === 'ur' ? (urduMonths[item.label] || item.label) : item.label}</span>
              </div>
            ))}
          </div>
        </article>
      </div>
      <div className="grid two">
        <article className="card">
          <h3>{t('classWiseToday')}</h3>
          {(data.class_attendance || []).length === 0 ? <p className="hint">{t('noClassesYet')}</p> : (
            <div className="stack">
              {data.class_attendance.map((row) => (
                <div className="stack-row" key={row.name}>
                  <strong>{tx(row.name)}</strong>
                  <span>{row.present} {t('present')} · {row.absent} {t('absent')} · {row.late} {t('late')} · {row.leave} {t('leave')}</span>
                </div>
              ))}
            </div>
          )}
        </article>
        <article className="card">
          <h3>{t('upcomingExams')}</h3>
          {data.upcoming_exams.length === 0 ? <p className="hint">{t('noUpcomingExams')}</p> : (
            <div className="stack">
              {data.upcoming_exams.map((exam) => (
                <div className="stack-row" key={exam.id}>
                  <strong>{tx(exam.name)}</strong>
                  <span>{tx(exam.class_name)} · {exam.start_date}</span>
                </div>
              ))}
            </div>
          )}
        </article>
      </div>
    </Page>
  );
}

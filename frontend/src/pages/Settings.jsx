import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, download, errorText } from '../api';
import { applyTheme } from '../theme';
import { useAuth } from '../auth';
import { useI18n } from '../i18n';
import {FilePick, Input,  Tr, DataTable, Field, Loader, Modal, Page, StatusSwitch, Tabs, useFeedback } from '../ui';

const sections = [
  { id: 'general', label: 'General' },
  { id: 'appearance', label: 'Appearance' },
  { id: 'academic', label: 'Academic' },
  { id: 'attendance', label: 'Attendance' },
  { id: 'fees', label: 'Fees' },
  { id: 'notifications', label: 'Notifications' },
  { id: 'language', label: 'Language' },
  { id: 'security', label: 'Security' },
  { id: 'backup', label: 'Backup' },
  { id: 'audit', label: 'Audit' },
];

const days = [['mon', 'Mon'], ['tue', 'Tue'], ['wed', 'Wed'], ['thu', 'Thu'], ['fri', 'Fri'], ['sat', 'Sat'], ['sun', 'Sun']];
const methodOptions = ['cash', 'bank', 'online', 'other'];
const palettes = [
  { id: 'navy', name: 'College navy', primary_color: '#1B4F9C', secondary_color: '#F39200', accent_color: '#F5A623', sidebar_color: '#0E2A4A', header_color: '#FFFDF8' },
  { id: 'emerald', name: 'Emerald', primary_color: '#0F766E', secondary_color: '#D97706', accent_color: '#14B8A6', sidebar_color: '#042F2E', header_color: '#F0FDFA' },
  { id: 'royal', name: 'Royal', primary_color: '#5B21B6', secondary_color: '#DB2777', accent_color: '#A78BFA', sidebar_color: '#2E1065', header_color: '#FAF5FF' },
  { id: 'ocean', name: 'Ocean', primary_color: '#0369A1', secondary_color: '#0284C7', accent_color: '#38BDF8', sidebar_color: '#0C4A6E', header_color: '#F0F9FF' },
  { id: 'crimson', name: 'Crimson', primary_color: '#9F1239', secondary_color: '#E11D48', accent_color: '#FB7185', sidebar_color: '#4C0519', header_color: '#FFF1F2' },
  { id: 'slate', name: 'Slate', primary_color: '#334155', secondary_color: '#0F766E', accent_color: '#64748B', sidebar_color: '#0F172A', header_color: '#F8FAFC' },
  { id: 'sunset', name: 'Sunset', primary_color: '#C2410C', secondary_color: '#F59E0B', accent_color: '#FB923C', sidebar_color: '#431407', header_color: '#FFF7ED' },
  { id: 'forest', name: 'Forest', primary_color: '#166534', secondary_color: '#CA8A04', accent_color: '#4ADE80', sidebar_color: '#052E16', header_color: '#F0FDF4' },
];
const buttonStyles = [
  { id: 'square', label: 'Square' },
  { id: 'rounded', label: 'Rounded' },
  { id: 'pill', label: 'Pill' },
];

function UrduValue({ name, value, ...props }) {
  const { locale, tx } = useI18n();
  const source = value || '';
  const shown = locale === 'ur' ? tx(source) : source;
  const [text, setText] = useState(shown);
  const [touched, setTouched] = useState(false);
  useEffect(() => {
    setText(locale === 'ur' ? tx(source) : source);
    setTouched(false);
  }, [source, locale]);
  return (
    <>
      <Input {...props} value={text} onChange={(event) => { setTouched(true); setText(event.target.value); }} />
      <input type="hidden" name={name} value={touched ? text : source} />
    </>
  );
}

function sameColor(left, right) {
  return String(left || '').toLowerCase() === String(right || '').toLowerCase();
}

export default function Settings() {
  const { user, updateUser } = useAuth();
  const { toast, confirm } = useFeedback();
  const [tab, setTab] = useState('general');
  const [settings, setSettings] = useState(null);
  const [users, setUsers] = useState([]);
  const [backups, setBackups] = useState([]);
  const [audit, setAudit] = useState({ rows: [], page: 1, last: 1, total: 0, from: 0, to: 0 });
  const [loading, setLoading] = useState(true);
  const [userForm, setUserForm] = useState(false);
  const [look, setLook] = useState(null);

  function load() {
    setLoading(true);
    Promise.all([
      api('/api/settings'),
      api('/api/users'),
      api('/api/backups'),
      api('/api/audit-logs'),
    ]).then(([settingsData, userRows, backupRows, auditRows]) => {
      setSettings(settingsData.settings);
      setLook({
        primary_color: settingsData.settings.primary_color,
        secondary_color: settingsData.settings.secondary_color,
        accent_color: settingsData.settings.accent_color,
        sidebar_color: settingsData.settings.sidebar_color,
        header_color: settingsData.settings.header_color,
        button_style: settingsData.settings.button_style || 'rounded',
        theme: settingsData.settings.theme || 'light',
      });
      setUsers(userRows);
      setBackups(backupRows);
      setAudit({
        rows: auditRows.data || [],
        page: auditRows.current_page || 1,
        last: auditRows.last_page || 1,
        total: auditRows.total || 0,
        from: auditRows.from || 0,
        to: auditRows.to || 0,
      });
      applyTheme(settingsData.branding);
    }).catch((err) => toast(errorText(err), 'err')).finally(() => setLoading(false));
  }
  useEffect(() => { load(); }, []);

  async function save(event) {
    event.preventDefault();
    const form = new FormData(event.target);
    if (tab === 'attendance') {
      const daysSelected = days.filter(([key]) => form.get(`day_${key}`)).map(([key]) => key);
      form.set('working_days', JSON.stringify(daysSelected));
    }
    if (tab === 'fees') {
      const selected = methodOptions.filter((method) => form.get(`method_${method}`));
      form.set('payment_methods', JSON.stringify(selected.length ? selected : ['cash']));
    }
    days.forEach(([key]) => form.delete(`day_${key}`));
    methodOptions.forEach((method) => form.delete(`method_${method}`));
    try {
      const data = await api('/api/settings', { method: 'POST', form });
      setSettings(data.settings);
      applyTheme(data.branding);
      const profile = await api('/api/me');
      updateUser(profile);
      toast('Settings saved. The color scheme is now applied.');
    } catch (err) { toast(errorText(err), 'err'); }
  }

  function preview(next) {
    setLook(next);
    applyTheme({ ...next, name: settings?.college_name });
  }

  if (!settings || !look) return <Page title="Settings">{loading ? <Loader /> : <p><Tr>Unable to load settings.</Tr></p>}</Page>;
  const matched = palettes.find((item) => ['primary_color', 'secondary_color', 'accent_color', 'sidebar_color', 'header_color'].every((key) => sameColor(item[key], look[key])));
  const working = settings.working_days || [];
  const methods = settings.payment_methods || methodOptions;

  return (
    <Page title="Settings" text="College profile, appearance, academic rules, security, and backups.">
      <Tabs tabs={sections} value={tab} onChange={setTab} />
      <form className="card form-grid" onSubmit={save}>
        {tab === 'general' ? (
          <>
            <Field label="College name"><UrduValue name="college_name" value={settings.college_name} required /></Field>
            <Field label="Short name"><UrduValue name="short_name" value={settings.short_name || 'SC'} maxLength={12} /></Field>
            <Field label="Phone"><Input name="college_phone" defaultValue={settings.college_phone || ''} /></Field>
            <Field label="Email"><Input name="college_email" type="email" defaultValue={settings.college_email || ''} /></Field>
            <Field label="Website"><Input name="college_website" defaultValue={settings.college_website || ''} /></Field>
            <Field label="Address" wide><UrduValue name="college_address" value={settings.college_address || ''} /></Field>
            <Field label="College logo"><FilePick name="logo" accept="image/*" /></Field>
            <Field label="Favicon"><FilePick name="favicon" accept="image/*" /></Field>
          </>
        ) : null}
        {tab === 'appearance' ? (
          <>
            <Input type="hidden" name="primary_color" value={look.primary_color} />
            <Input type="hidden" name="secondary_color" value={look.secondary_color} />
            <Input type="hidden" name="accent_color" value={look.accent_color} />
            <Input type="hidden" name="sidebar_color" value={look.sidebar_color} />
            <Input type="hidden" name="header_color" value={look.header_color} />
            <Input type="hidden" name="button_style" value={look.button_style} />
            <Input type="hidden" name="theme" value={look.theme} />
            <div className="wide look-block">
              <span className="look-title"><Tr>Color combination</Tr></span>
              <p className="hint"><Tr>Choose one set. Primary is used for buttons, links, active menu items, and focus. Secondary and accent mark highlights. Sidebar and header follow the same set.</Tr></p>
              <div className="palette-grid">
                {palettes.map((item) => (
                  <button key={item.id} type="button" className={matched?.id === item.id ? 'palette on' : 'palette'} onClick={() => preview({ ...look, ...item })}>
                    <span className="swatches" aria-hidden="true">
                      <i style={{ background: item.primary_color }} />
                      <i style={{ background: item.secondary_color }} />
                      <i style={{ background: item.accent_color }} />
                      <i style={{ background: item.sidebar_color }} />
                      <i style={{ background: item.header_color }} />
                    </span>
                    <strong><Tr>{item.name}</Tr></strong>
                  </button>
                ))}
              </div>
              {matched ? null : <p className="hint"><Tr>The saved colors are a custom mix. Pick a combination above to replace them.</Tr></p>}
            </div>
            <div className="wide look-block">
              <span className="look-title"><Tr>Button style</Tr></span>
              <div className="choice-row">
                {buttonStyles.map((item) => (
                  <button key={item.id} type="button" className={look.button_style === item.id ? `choice on shape-${item.id}` : `choice shape-${item.id}`} onClick={() => preview({ ...look, button_style: item.id })}><Tr>{item.label}</Tr></button>
                ))}
              </div>
            </div>
            <div className="wide look-block">
              <span className="look-title"><Tr>Theme</Tr></span>
              <div className="choice-row">
                {['light', 'dark'].map((item) => (
                  <button key={item} type="button" className={look.theme === item ? 'choice on' : 'choice'} onClick={() => preview({ ...look, theme: item })}>{item === 'light' ? <Tr>Light</Tr> : <Tr>Dark</Tr>}</button>
                ))}
              </div>
            </div>
            <div className="wide preview-bar" aria-hidden="true">
              <span className="preview-side" style={{ background: look.sidebar_color }} />
              <span className="preview-main" style={{ background: look.header_color }}>
                <span className="preview-btn" style={{ background: look.primary_color }}><Tr>Button</Tr></span>
                <span className="preview-dot" style={{ background: look.secondary_color }} />
                <span className="preview-dot" style={{ background: look.accent_color }} />
              </span>
            </div>
          </>
        ) : null}
        {tab === 'academic' ? (
          <div className="wide">
            <p><Tr>Classes, sections, subjects, and the academic session are managed together.</Tr></p>
            <Link className="btn" to="/classes"><Tr>Open academic structure</Tr></Link>
            <p><Tr>Grades are calculated from percentage: A, B, C, D, and F. Pass mark follows the grading rules already used on report cards.</Tr></p>
          </div>
        ) : null}
        {tab === 'attendance' ? (
          <>
            <Field label="Face match threshold" hint="Higher is stricter. 0.363 is the default for this camera model."><Input name="face_match_threshold" type="number" min="0.2" max="0.9" step="0.001" defaultValue={settings.face_match_threshold ?? 0.363} /></Field>
            <Field label="Present until"><Input name="present_until" type="time" defaultValue={settings.present_until} /></Field>
            <Field label="Late until"><Input name="late_until" type="time" defaultValue={settings.late_until} /></Field>
            <Field label="Default leave allowance"><Input name="default_leave_allowance" type="number" defaultValue={settings.default_leave_allowance} /></Field>
            <div className="wide">
              <span><Tr>Working days</Tr></span>
              <div className="toolbar">
                {days.map(([key, label]) => (
                  <label key={key}><Input type="checkbox" name={`day_${key}`} defaultChecked={working.includes(key)} /> <Tr>{label}</Tr></label>
                ))}
              </div>
            </div>
          </>
        ) : null}
        {tab === 'fees' ? (
          <>
            <Field label="Grace days"><Input name="grace_days" type="number" defaultValue={settings.grace_days} /></Field>
            <Field label="Late fee"><Input name="late_fee_amount" type="number" defaultValue={settings.late_fee_amount} /></Field>
            <Field label="Bank name" hint="Printed on the fee voucher payment box."><UrduValue name="bank_name" value={settings.bank_name || ''} /></Field>
            <Field label="Bank account"><Input name="bank_account" defaultValue={settings.bank_account || ''} /></Field>
            <Field label="Reminder days"><Input name="reminder_days" type="number" defaultValue={settings.reminder_days} /></Field>
            <div className="wide">
              <span><Tr>Payment methods</Tr></span>
              <div className="toolbar">
                {methodOptions.map((method) => (
                  <label key={method}><Input type="checkbox" name={`method_${method}`} defaultChecked={methods.includes(method)} /> <Tr>{method}</Tr></label>
                ))}
              </div>
            </div>
          </>
        ) : null}
        {tab === 'notifications' ? (
          <>
            <Field label="Email notifications"><select name="email_notifications" defaultValue={settings.email_notifications ? '1' : '0'}><option value="1"><Tr>On</Tr></option><option value="0"><Tr>Off</Tr></option></select></Field>
            <Field label="Push notifications"><select name="push_notifications" defaultValue={settings.push_notifications ? '1' : '0'}><option value="1"><Tr>On</Tr></option><option value="0"><Tr>Off</Tr></option></select></Field>
            <Field label="SMS webhook"><Input name="sms_webhook" defaultValue={settings.sms_webhook || ''} /></Field>
            <Field label="WhatsApp webhook"><Input name="whatsapp_webhook" defaultValue={settings.whatsapp_webhook || ''} /></Field>
          </>
        ) : null}
        {tab === 'language' ? (
          <Field label="Default language">
            <select name="default_locale" defaultValue={settings.default_locale}><option value="en"><Tr>English</Tr></option><option value="ur"><Tr>Urdu</Tr></option></select>
          </Field>
        ) : null}
        {tab === 'security' ? (
          <>
            <Field label="Minimum password length">
              <select name="password_min" defaultValue={String(settings.password_min || 8)}><option value="8"><Tr>8 characters</Tr></option><option value="12"><Tr>12 characters</Tr></option></select>
            </Field>
            <p className="wide"><Tr>Sign-in uses a bearer token. Failed logins are throttled. Passwords are stored hashed. Two-factor authentication can be added when an authenticator provider is connected; the current sign-in remains email and password.</Tr></p>
          </>
        ) : null}
        {tab === 'backup' ? (
          <Field label="Scheduled backup">
            <select name="backup_schedule" defaultValue={settings.backup_schedule || 'off'}>
              <option value="off"><Tr>Manual only</Tr></option>
              <option value="daily"><Tr>Daily at 02:00</Tr></option>
              <option value="weekly"><Tr>Weekly on Monday</Tr></option>
            </select>
          </Field>
        ) : null}
        {tab !== 'audit' && tab !== 'academic' ? <button className="btn" type="submit"><Tr>Save changes</Tr></button> : null}
      </form>
      {tab === 'security' ? (
        <article className="card">
          <h3><Tr>Users</Tr></h3>
          <div className="toolbar"><button className="btn" type="button" onClick={() => setUserForm(true)}><Tr>Add user</Tr></button></div>
          {users.map((person) => (
            <div className="stack-row" key={person.id}>
              <div>
                <strong><Tr>{person.name}</Tr></strong>
                <div>{person.email} · <Tr>{person.role}</Tr></div>
              </div>
              <StatusSwitch
                active={Boolean(person.is_active)}
                disabled={person.id === user?.id}
                onChange={async (next) => {
                  if (!next) {
                    const ok = await confirm({ title: 'Set user inactive?', body: 'This person stays on record and cannot sign in until you turn them active again.', confirmLabel: 'Set inactive', danger: true });
                    if (!ok) return;
                  }
                  try {
                    await api(`/api/users/${person.id}`, { method: 'PUT', body: { is_active: next } });
                    toast(next ? 'User is active.' : 'User is inactive.');
                    load();
                  } catch (err) { toast(errorText(err), 'err'); }
                }}
              />
            </div>
          ))}
        </article>
      ) : null}
      <Modal title={userForm ? 'Add user' : ''} onClose={() => setUserForm(false)}>
        {userForm ? (
          <form className="form-grid" onSubmit={async (event) => {
            event.preventDefault();
            try {
              await api('/api/users', { method: 'POST', body: Object.fromEntries(new FormData(event.target).entries()) });
              toast('User added.');
              setUserForm(false);
              load();
            } catch (err) { toast(errorText(err), 'err'); }
          }}>
            <Field label="Name"><Input name="name" required /></Field>
            <Field label="Email"><Input name="email" type="email" required /></Field>
            <Field label="Password"><Input name="password" type="password" required minLength={8} /></Field>
            <Field label="Role">
              <select name="role"><option value="admin"><Tr>Admin</Tr></option><option value="teacher"><Tr>Teacher</Tr></option><option value="accountant"><Tr>Accountant</Tr></option></select>
            </Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      {tab === 'backup' ? (
        <article className="card">
          <button className="btn" onClick={async () => { await api('/api/backups', { method: 'POST' }); toast('Backup created.'); load(); }}><Tr>Create backup</Tr></button>
          {backups.map((backup) => (
            <p key={backup.id}>{backup.filename} · {backup.created_at} · {backup.created_by}
              <button className="btn ghost" onClick={() => download(`/api/backups/${backup.id}/download`, backup.filename)}><Tr>Download</Tr></button>
              <button className="btn ghost" onClick={async () => {
                const ok = await confirm({ title: 'Restore backup?', body: 'This replaces the current database with the backup. Type confirmation in the next step.', confirmLabel: 'Continue', danger: true });
                if (!ok) return;
                const typed = window.prompt('Type RESTORE to confirm');
                if (typed !== 'RESTORE') return;
                await api(`/api/backups/${backup.id}/restore`, { method: 'POST', body: { confirm: 'RESTORE' } });
                toast('Database restored.');
              }}><Tr>Restore</Tr></button>
            </p>
          ))}
        </article>
      ) : null}
      {tab === 'audit' ? (
        <DataTable
          columns={[
            { key: 'user', label: 'User' },
            { key: 'action', label: 'Action' },
            { key: 'record', label: 'Record' },
            { key: 'module', label: 'Module' },
            { key: 'at', label: 'When' },
          ]}
          rows={audit.rows}
          loading={loading}
          emptyTitle="No audit records"
          emptyText="Sensitive changes will be listed here."
          page={audit.page}
          lastPage={audit.last}
          from={audit.from}
          to={audit.to}
          total={audit.total}
          noun="events"
          onPage={async (page) => {
            const data = await api(`/api/audit-logs?page=${page}`);
            setAudit({ rows: data.data || [], page: data.current_page, last: data.last_page, total: data.total, from: data.from || 0, to: data.to || 0 });
          }}
        />
      ) : null}
    </Page>
  );
}

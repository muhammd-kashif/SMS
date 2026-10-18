import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api, apiForm, download, errorText, exportCsv, fieldErrors, openPdf, withQuery } from '../api';
import { useAuth } from '../auth';
import { useList } from '../list';
import { MonthAttendance } from './MonthAttendance';
import {Textarea, Input, FilePick, Tr, ActionMenu, Badge, DataTable, EmptyState, Field, Loader, money, Page, StatusSwitch, Tabs, useFeedback } from '../ui';

function useStructure() {
  const [structure, setStructure] = useState({ classes: [], sessions: [] });
  useEffect(() => { api('/api/structure').then(setStructure).catch(() => {}); }, []);
  return structure;
}

export function Students() {
  const { user } = useAuth();
  const { confirm, toast } = useFeedback();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const structure = useStructure();
  const [filters, setFilters] = useState({
    search: params.get('search') || '',
    class_id: '',
    section_id: '',
    gender: '',
    status: '',
    session_id: '',
    face: '',
  });
  const list = useList('/api/students', filters);
  const sections = structure.classes.find((item) => String(item.id) === String(filters.class_id))?.sections || [];
  const admin = user?.role === 'admin';

  function setFilter(key, value) {
    setFilters((current) => ({ ...current, [key]: value, ...(key === 'class_id' ? { section_id: '' } : {}) }));
  }

  async function setStatus(row, active) {
    if (!active) {
      const ok = await confirm({
        title: 'Set student inactive?',
        body: 'This person stays on record and cannot sign in until you turn them active again.',
        confirmLabel: 'Set inactive',
        danger: true,
      });
      if (!ok) return;
    }
    try {
      await api(`/api/students/${row.id}/status`, { method: 'PUT', body: { status: active ? 'active' : 'inactive' } });
      toast(active ? 'Student is active.' : 'Student is inactive.');
      list.reload();
    } catch (err) {
      toast(errorText(err), 'err');
    }
  }

  return (
    <Page title="Students" text="Search, filter, and manage student records." actions={
      <div className="toolbar">
        {admin ? <Link className="btn" to="/students/new"><Tr>Add student</Tr></Link> : null}
        <button className="btn ghost" onClick={() => exportCsv('students.csv', list.rows.map((row) => ({
          Name: row.name, ID: row.student_code, Roll: row.roll_number, Class: row.class_name, Section: row.section_name, Status: row.status,
        })))}><Tr>Export Excel</Tr></button>
        <button className="btn ghost" onClick={() => openPdf(withQuery('/api/students', { ...filters, format: 'pdf' })).catch(() => toast('Could not open the PDF.', 'err'))}><Tr>Print PDF</Tr></button>
      </div>
    }>
      <div className="card filters">
        <Field label="Search"><Input value={filters.search} placeholder="Search student by name, ID or roll number" onChange={(event) => setFilter('search', event.target.value)} /></Field>
        <Field label="Class">
          <select value={filters.class_id} onChange={(event) => setFilter('class_id', event.target.value)}>
            <option value=""><Tr>All</Tr></option>
            {structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
        <Field label="Section">
          <select value={filters.section_id} onChange={(event) => setFilter('section_id', event.target.value)}>
            <option value=""><Tr>All</Tr></option>
            {sections.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
        <Field label="Gender">
          <select value={filters.gender} onChange={(event) => setFilter('gender', event.target.value)}>
            <option value=""><Tr>All</Tr></option><option value="male"><Tr>Male</Tr></option><option value="female"><Tr>Female</Tr></option><option value="other"><Tr>Other</Tr></option>
          </select>
        </Field>
        <Field label="Status">
          <select value={filters.status} onChange={(event) => setFilter('status', event.target.value)}>
            <option value=""><Tr>All</Tr></option><option value="active"><Tr>Active</Tr></option><option value="inactive"><Tr>Inactive</Tr></option><option value="withdrawn"><Tr>Withdrawn</Tr></option>
          </select>
        </Field>
        <Field label="Face">
          <select value={filters.face} onChange={(event) => setFilter('face', event.target.value)}>
            <option value=""><Tr>All</Tr></option>
            <option value="registered"><Tr>Registered</Tr></option>
            <option value="missing"><Tr>Not registered</Tr></option>
          </select>
        </Field>
        <Field label="Admission session">
          <select value={filters.session_id} onChange={(event) => setFilter('session_id', event.target.value)}>
            <option value=""><Tr>All</Tr></option>
            {structure.sessions.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
      </div>
      <DataTable
        columns={[
          { key: 'photo', label: 'Photo', render: (row) => (row.face_photo_url || row.photo_url) ? <img src={row.face_photo_url || row.photo_url} alt="" style={{ width: 36, height: 36, borderRadius: 8, objectFit: 'cover' }} /> : <span className="avatar" style={{ width: 36, height: 36, fontSize: 14 }}>{row.name?.slice(0, 1)}</span> },
          { key: 'name', label: 'Student', sort: true, render: (row) => <Link to={`/students/${row.id}`}><Tr>{row.name}</Tr></Link> },
          { key: 'student_code', label: 'ID', sort: true },
          { key: 'roll_number', label: 'Roll', sort: true },
          { key: 'class_name', label: 'Class', render: (row) => <Tr>{row.class_name || '—'}</Tr> },
          { key: 'section_name', label: 'Section', render: (row) => <Tr>{row.section_name || '—'}</Tr> },
          { key: 'phone', label: 'Contact', render: (row) => row.phone || row.parent_phone || '—' },
          { key: 'face', label: 'Face', render: (row) => <Badge value={row.face_registered ? 'registered' : 'missing'} /> },
          { key: 'status', label: 'Status', sort: true, render: (row) => (
            <StatusSwitch active={row.status === 'active'} disabled={!admin} onChange={(next) => setStatus(row, next)} />
          ) },
          { key: 'actions', label: '', render: (row) => (
            <ActionMenu items={[
              { label: 'View', onClick: () => navigate(`/students/${row.id}`) },
              { label: 'Edit', show: admin, onClick: () => navigate(`/students/${row.id}/edit`) },
              { label: 'Attendance', onClick: () => navigate(`/students/${row.id}?tab=attendance`) },
              { label: 'Fees', onClick: () => navigate(`/students/${row.id}?tab=fees`) },
            ]} />
          ) },
        ]}
        rows={list.rows}
        loading={list.loading}
        sort={list.sort}
        onSort={list.toggleSort}
        emptyTitle="No students found"
        emptyText="There are currently no students matching your filters."
        emptyAction={admin ? <Link className="btn" to="/students/new"><Tr>Add student</Tr></Link> : null}
        page={list.page}
        lastPage={list.last}
        from={list.from}
        to={list.to}
        total={list.total}
        noun="students"
        onPage={list.setPage}
      />
    </Page>
  );
}

const emptyForm = {
  name: '', email: '', password: '', father_name: '', dob: '', gender: 'male', phone: '',
  parent_phone: '', parent_name: '', parent_email: '', address: '', roll_number: '',
  class_id: '', section_id: '', session_id: '', admission_date: '', leave_allowance: 20, status: 'active',
};

export function StudentForm() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { toast } = useFeedback();
  const structure = useStructure();
  const [errors, setErrors] = useState({});
  const [form, setForm] = useState(emptyForm);
  const sections = structure.classes.find((item) => String(item.id) === String(form.class_id))?.sections || [];

  useEffect(() => {
    if (!id) return;
    api(`/api/students/${id}`).then((student) => setForm((current) => ({
      ...current,
      ...student,
      password: '',
      parent_name: student.guardian?.name || '',
      parent_email: student.guardian?.email || '',
    })));
  }, [id]);

  function set(key, value) { setForm((current) => ({ ...current, [key]: value })); }

  function localErrors() {
    const next = {};
    if (form.phone && !/^[0-9+\-\s]{7,20}$/.test(form.phone)) next.phone = 'Please enter a valid phone number.';
    if (form.parent_phone && !/^[0-9+\-\s]{7,20}$/.test(form.parent_phone)) next.parent_phone = 'Please enter a valid phone number.';
    if (form.email && !/^\S+@\S+\.\S+$/.test(form.email)) next.email = 'Please enter a valid email.';
    return next;
  }

  async function submit(event) {
    event.preventDefault();
    const local = localErrors();
    if (Object.keys(local).length) {
      setErrors(local);
      toast('Unable to save student. Please check the required fields.', 'err');
      return;
    }
    const data = new FormData(event.target);
    for (const [key, value] of [...data.entries()]) {
      if (value === '' || (value instanceof File && value.size === 0)) data.delete(key);
    }
    try {
      const saved = id ? await apiForm(`/api/students/${id}`, data) : await apiForm('/api/students', data);
      toast(id ? 'Student updated successfully.' : 'Student added successfully.');
      navigate(`/students/${saved.id || id}`);
    } catch (err) {
      setErrors(fieldErrors(err));
      toast(errorText(err), 'err');
    }
  }

  return (
    <Page title={id ? 'Edit student' : 'Add student'} text="Complete the student record. Required fields are marked by the browser.">
      <form className="card form-grid" onSubmit={submit}>
        <Field label="Name" error={errors.name}><Input name="name" value={form.name} onChange={(event) => set('name', event.target.value)} required /></Field>
        <Field label="Email" error={errors.email}><Input name="email" type="email" value={form.email} onChange={(event) => set('email', event.target.value)} required /></Field>
        <Field label="Password" error={errors.password}><Input name="password" type="password" value={form.password} onChange={(event) => set('password', event.target.value)} required={!id} minLength={8} /></Field>
        <Field label="Father / guardian"><Input name="father_name" value={form.father_name || ''} onChange={(event) => set('father_name', event.target.value)} /></Field>
        <Field label="Date of birth"><Input name="dob" type="date" value={form.dob || ''} onChange={(event) => set('dob', event.target.value)} /></Field>
        <Field label="Gender">
          <select name="gender" value={form.gender || ''} onChange={(event) => set('gender', event.target.value)}>
            <option value="male"><Tr>Male</Tr></option><option value="female"><Tr>Female</Tr></option><option value="other"><Tr>Other</Tr></option>
          </select>
        </Field>
        <Field label="Phone" error={errors.phone}><Input name="phone" value={form.phone || ''} onChange={(event) => set('phone', event.target.value)} /></Field>
        <Field label="Parent phone" error={errors.parent_phone}><Input name="parent_phone" value={form.parent_phone || ''} onChange={(event) => set('parent_phone', event.target.value)} /></Field>
        <Field label="Parent name"><Input name="parent_name" value={form.parent_name || ''} onChange={(event) => set('parent_name', event.target.value)} /></Field>
        <Field label="Parent email" error={errors.parent_email}><Input name="parent_email" type="email" value={form.parent_email || ''} onChange={(event) => set('parent_email', event.target.value)} /></Field>
        <Field label="Roll number" error={errors.roll_number}><Input name="roll_number" value={form.roll_number || ''} onChange={(event) => set('roll_number', event.target.value)} required /></Field>
        <Field label="Admission date"><Input name="admission_date" type="date" value={form.admission_date || ''} onChange={(event) => set('admission_date', event.target.value)} /></Field>
        <Field label="Class" error={errors.class_id}>
          <select name="class_id" value={form.class_id || ''} onChange={(event) => set('class_id', event.target.value)} required>
            <option value=""><Tr>Select</Tr></option>
            {structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
        <Field label="Section" error={errors.section_id}>
          <select name="section_id" value={form.section_id || ''} onChange={(event) => set('section_id', event.target.value)} required>
            <option value=""><Tr>Select</Tr></option>
            {sections.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
        <Field label="Session">
          <select name="session_id" value={form.session_id || ''} onChange={(event) => set('session_id', event.target.value)}>
            <option value=""><Tr>Select</Tr></option>
            {structure.sessions.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
        <Field label="Status">
          <Input type="hidden" name="status" value={form.status === 'active' ? 'active' : 'inactive'} />
          <StatusSwitch active={form.status === 'active'} onChange={(next) => set('status', next ? 'active' : 'inactive')} />
        </Field>
        <Field label="Leave allowance"><Input name="leave_allowance" type="number" value={form.leave_allowance} onChange={(event) => set('leave_allowance', event.target.value)} /></Field>
        <Field label="Address" wide><Textarea name="address" value={form.address || ''} onChange={(event) => set('address', event.target.value)} /></Field>
        <Field label="Profile photo" error={errors.photo} hint="JPG or PNG, up to 4 MB."><FilePick name="photo" accept="image/png,image/jpeg,image/webp" /></Field>
        <div className="toolbar wide">
          <button className="btn" type="submit"><Tr>Save</Tr></button>
          <Link className="btn ghost" to={id ? `/students/${id}` : '/students'}><Tr>Cancel</Tr></Link>
        </div>
      </form>
    </Page>
  );
}

export function StudentProfile() {
  const { id } = useParams();
  const [params, setParams] = useSearchParams();
  const { user } = useAuth();
  const { toast, confirm } = useFeedback();
  const [student, setStudent] = useState(null);
  const [history, setHistory] = useState([]);
  const [attendanceLoading, setAttendanceLoading] = useState(true);
  const tab = params.get('tab') || 'overview';
  useEffect(() => { api(`/api/students/${id}`).then(setStudent); }, [id]);
  useEffect(() => {
    setAttendanceLoading(true);
    api(`/api/attendance?student_id=${id}&all=1`).then((data) => setHistory(data.data || [])).catch(() => setHistory([])).finally(() => setAttendanceLoading(false));
  }, [id]);
  if (!student) return <Page title="Student"><Loader /></Page>;
  const attendance = student.attendance || {};
  return (
    <Page title={student.name} text={`${student.student_code || ''} · ${student.class_name || ''} ${student.section_name || ''}`.trim()} actions={
      <div className="toolbar">
        <Link className="btn" to={`/students/${student.id}/edit`}><Tr>Edit</Tr></Link>
        <button className="btn ghost" onClick={() => openPdf(`/api/students?search=${encodeURIComponent(student.student_code || student.name)}&format=pdf`).catch(() => toast('Could not open the profile PDF.', 'err'))}><Tr>Print profile</Tr></button>
      </div>
    }>
      <article className="card profile-hero">
        {(student.face_photo_url || student.photo_url) ? <img src={student.face_photo_url || student.photo_url} alt="" /> : <div className="avatar">{student.name.slice(0, 1)}</div>}
        <div>
          <h2><Tr>{student.name}</Tr></h2>
          <p>{student.student_code} · <Tr>{student.class_name}</Tr> — <Tr>{student.section_name}</Tr></p>
          <p><Badge value={student.status} /> <Badge value={student.face_registered ? 'registered' : 'missing'} /></p>
          <StatusSwitch active={student.status === 'active'} disabled={user?.role !== 'admin'} onChange={async (next) => {
            if (!next) {
              const ok = await confirm({ title: 'Set student inactive?', body: 'This person stays on record and cannot sign in until you turn them active again.', confirmLabel: 'Set inactive', danger: true });
              if (!ok) return;
            }
            try {
              const saved = await api(`/api/students/${student.id}/status`, { method: 'PUT', body: { status: next ? 'active' : 'inactive' } });
              setStudent({ ...student, ...saved });
              toast(next ? 'Student is active.' : 'Student is inactive.');
            } catch (err) { toast(errorText(err), 'err'); }
          }} />
        </div>
      </article>
      <Tabs value={tab} onChange={(next) => setParams({ tab: next })} tabs={[
        { id: 'overview', label: 'Overview' },
        { id: 'attendance', label: 'Attendance' },
        { id: 'fees', label: 'Fees' },
        { id: 'exams', label: 'Exams' },
        { id: 'leaves', label: 'Leave' },
        { id: 'documents', label: 'Documents' },
      ]} />
      {tab === 'overview' ? (
        <div className="profile-grid">
          <article className="card">
            <h3><Tr>Personal information</Tr></h3>
            <dl className="meta-list">
              <div><dt><Tr>Full name</Tr></dt><dd><Tr>{student.name}</Tr></dd></div>
              <div><dt><Tr>Student ID</Tr></dt><dd>{student.student_code || '—'}</dd></div>
              <div><dt><Tr>Date of birth</Tr></dt><dd>{student.dob ? String(student.dob).slice(0, 10) : '—'}</dd></div>
              <div><dt><Tr>Gender</Tr></dt><dd><Tr>{student.gender || '—'}</Tr></dd></div>
              <div><dt><Tr>Contact</Tr></dt><dd>{student.phone || '—'}</dd></div>
              <div><dt><Tr>Address</Tr></dt><dd><Tr>{student.address || '—'}</Tr></dd></div>
            </dl>
          </article>
          <article className="card">
            <h3><Tr>Academic information</Tr></h3>
            <dl className="meta-list">
              <div><dt><Tr>Class</Tr></dt><dd><Tr>{student.class_name || '—'}</Tr></dd></div>
              <div><dt><Tr>Section</Tr></dt><dd><Tr>{student.section_name || '—'}</Tr></dd></div>
              <div><dt><Tr>Roll number</Tr></dt><dd>{student.roll_number || '—'}</dd></div>
              <div><dt><Tr>Admission date</Tr></dt><dd>{student.admission_date ? String(student.admission_date).slice(0, 10) : '—'}</dd></div>
              <div><dt><Tr>Session</Tr></dt><dd>{student.session_name || '—'}</dd></div>
              <div><dt><Tr>Attendance</Tr></dt><dd>{attendance.percentage ?? 0}%</dd></div>
            </dl>
          </article>
          <article className="card">
            <h3><Tr>Guardian</Tr></h3>
            <dl className="meta-list">
              <div><dt><Tr>Name</Tr></dt><dd><Tr>{student.father_name || '—'}</Tr></dd></div>
              <div><dt><Tr>Contact</Tr></dt><dd>{student.parent_phone || '—'}</dd></div>
              <div><dt><Tr>Email</Tr></dt><dd>{student.email || '—'}</dd></div>
            </dl>
          </article>
          <article className="card">
            <h3><Tr>Status</Tr></h3>
            <dl className="meta-list">
              <div><dt><Tr>Account</Tr></dt><dd><Badge value={student.status} /></dd></div>
              <div><dt><Tr>Face</Tr></dt><dd><Badge value={student.face_registered ? 'registered' : 'missing'} /></dd></div>
              <div><dt><Tr>Fee pending</Tr></dt><dd>{money(student.fees?.pending)}</dd></div>
            </dl>
            <Link className="btn ghost" to={`/face/register?type=student&id=${student.id}`}>{student.face_registered ? 'Update face' : 'Register face'}</Link>
          </article>
        </div>
      ) : null}
      {tab === 'attendance' ? (
        <>
          <div className="toolbar">
            <button className="btn" onClick={() => download(`/api/attendance?student_id=${student.id}&format=pdf`, `${student.student_code || 'student'}-attendance.pdf`).catch(() => toast('Could not download the attendance PDF.', 'err'))}><Tr>Download PDF</Tr></button>
            <button className="btn ghost" onClick={() => openPdf(`/api/attendance?student_id=${student.id}&format=pdf`).catch(() => toast('Could not open the attendance PDF.', 'err'))}><Tr>Print</Tr></button>
          </div>
          <MonthAttendance name={student.name} code={`${student.student_code || ''} · Roll ${student.roll_number || ''}`} rows={history} loading={attendanceLoading} />
        </>
      ) : null}
      {tab === 'fees' ? (
        <>
          <div className="kpis">
            <div className="kpi"><span><Tr>Total fee</Tr></span><strong>{money(student.fees?.total)}</strong></div>
            <div className="kpi present"><span><Tr>Paid</Tr></span><strong>{money(student.fees?.paid)}</strong></div>
            <div className="kpi late"><span><Tr>Pending</Tr></span><strong>{money(student.fees?.pending)}</strong></div>
          </div>
          <DataTable
            columns={[
              { key: 'title', label: 'Fee' },
              { key: 'due_date', label: 'Due', render: (row) => String(row.due_date || '').slice(0, 10) },
              { key: 'amount', label: 'Amount', render: (row) => money(row.amount) },
              { key: 'paid_amount', label: 'Paid', render: (row) => money(row.paid_amount) },
              { key: 'pending_amount', label: 'Pending', render: (row) => money(row.pending_amount) },
              { key: 'status', label: 'Status', render: (row) => <Badge value={row.status} /> },
            ]}
            rows={student.fees?.items || []}
            emptyTitle="No fee records found"
            emptyText="Fee vouchers for this student will appear here."
            page={1}
            lastPage={1}
            from={(student.fees?.items || []).length ? 1 : 0}
            to={(student.fees?.items || []).length}
            total={(student.fees?.items || []).length}
            noun="fees"
            onPage={() => {}}
          />
        </>
      ) : null}
      {tab === 'exams' ? (
        <article className="card">
          {(student.marks || []).length === 0 ? <EmptyState title="No results" text="Examination marks will appear after entry." /> : student.marks.map((mark) => (
            <p key={mark.id}><Tr>{mark.subject?.name || 'Subject'}</Tr>: {mark.obtained_marks}/{mark.total_marks} · {mark.grade}</p>
          ))}
        </article>
      ) : null}
      {tab === 'documents' ? (
        <article className="card">
          {(student.face_photo_url || student.photo_url) ? <img className="photo" src={student.face_photo_url || student.photo_url} alt="" /> : <EmptyState title="No documents found" text="The student photo and uploaded documents will appear here." />}
        </article>
      ) : null}
      {tab === 'leaves' ? (
        <article className="card">
          <p>Leave balance: {attendance.remaining_leave} of {attendance.total_leave}</p>
          {(student.leaves || []).length === 0 ? <EmptyState title="No leave requests" text="Approved and pending leaves are listed here." /> : student.leaves.map((leave) => (
            <p key={leave.id}>{leave.leave_type} · {String(leave.start_date).slice(0, 10)} → {String(leave.end_date).slice(0, 10)} · <Badge value={leave.status} /></p>
          ))}
        </article>
      ) : null}
    </Page>
  );
}

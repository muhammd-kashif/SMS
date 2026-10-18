import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, apiForm, download, errorText } from '../api';
import { useAuth } from '../auth';
import { useI18n } from '../i18n';
import {Input, FilePick, Tr, Badge, DataTable, EmptyState, Field, Loader, Modal, Page, Tabs, money, useFeedback } from '../ui';
import { MonthAttendance } from './MonthAttendance';

const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

function once(rows) {
  const total = rows.length;
  return { page: 1, lastPage: 1, from: total ? 1 : 0, to: total, total, noun: 'records', onPage: () => {} };
}

export default function Portal() {
  const { user } = useAuth();
  const { tx } = useI18n();
  const [data, setData] = useState(null);
  const [params, setParams] = useSearchParams();
  const tab = params.get('tab') || 'overview';
  const [child, setChild] = useState('');
  const [submitItem, setSubmitItem] = useState(null);
  const { toast } = useFeedback();

  useEffect(() => {
    setData(null);
    api(`/api/portal${child ? `?student_id=${child}` : ''}`).then(setData).catch(() => setData(null));
  }, [child]);

  if (!data) return <Page title="Portal"><Loader /></Page>;
  const student = data.student;
  const attendance = data.attendance;
  const fees = data.fees?.items || [];
  const payments = data.payments || [];
  const exams = data.exams || [];
  const results = data.results || [];
  const timetable = data.timetable || [];
  const homework = data.homework || [];
  const assignments = data.assignments || [];
  const announcements = data.announcements || [];
  const leaves = data.leaves || [];

  return (
    <Page title={student.name} text={`${student.student_code} · ${tx('Roll')} ${student.roll_number} · ${student.class_name} ${student.section_name}`}>
      {user.role === 'parent' && data.children.length > 1 ? (
        <div className="card filters">
          <Field label="Child">
            <select value={child || student.id} onChange={(event) => setChild(event.target.value)}>
              {data.children.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr> · <Tr>{`${item.class_name || ''} ${item.section_name || ''}`}</Tr></option>)}
            </select>
          </Field>
        </div>
      ) : null}
      <article className="card profile-hero">
        {(student.face_photo_url || student.photo_url) ? <img src={student.face_photo_url || student.photo_url} alt="" /> : <div className="avatar">{student.name?.slice(0, 1)}</div>}
        <div>
          <h2><Tr>{student.name}</Tr></h2>
          <p>{student.student_code} · <Tr>{student.class_name}</Tr> — <Tr>{student.section_name}</Tr></p>
        </div>
      </article>
      <Tabs value={tab} onChange={(id) => setParams(id === 'overview' ? {} : { tab: id })} tabs={[
        { id: 'overview', label: 'Dashboard' },
        ...(user.role === 'parent' ? [{ id: 'children', label: 'My children' }] : []),
        { id: 'attendance', label: 'Attendance' },
        { id: 'fees', label: 'Fees' },
        { id: 'exams', label: 'Exams' },
        { id: 'results', label: 'Results' },
        { id: 'leaves', label: 'Leaves' },
        { id: 'timetable', label: 'Timetable' },
        { id: 'homework', label: 'Homework' },
        { id: 'assignments', label: 'Assignments' },
        { id: 'announcements', label: 'Announcements' },
      ]} />
      {tab === 'overview' ? (
        <div className="kpis">
          <div className="kpi percent"><span><Tr>Attendance</Tr></span><strong>{attendance.percentage}%</strong></div>
          <div className="kpi present"><span><Tr>Present</Tr></span><strong>{attendance.present}</strong></div>
          <div className="kpi absent"><span><Tr>Absent</Tr></span><strong>{attendance.absent}</strong></div>
          <div className="kpi late"><span><Tr>Late</Tr></span><strong>{attendance.late}</strong></div>
          <div className="kpi leave"><span><Tr>Leave</Tr></span><strong>{attendance.leave}</strong></div>
        </div>
      ) : null}
      {tab === 'children' ? (
        <DataTable
          columns={[
            { key: 'name', label: 'Student' },
            { key: 'class_name', label: 'Class' },
            { key: 'section_name', label: 'Section' },
            { key: 'open', label: '', render: (row) => <button className="btn ghost" type="button" onClick={() => { setChild(row.id); setParams({}); }}><Tr>Open</Tr></button> },
          ]}
          rows={data.children}
          emptyTitle="No children linked"
          emptyText="Students linked to this parent account will appear here."
          {...once(data.children)}
          noun="children"
        />
      ) : null}
      {tab === 'attendance' ? (
        <MonthAttendance key={student.id} name={student.name} code={`${student.student_code || ''} · Roll ${student.roll_number || ''}`} rows={data.attendance_history || []} />
      ) : null}
      {tab === 'fees' ? (
        <>
          <div className="kpis">
            <div className="kpi"><span><Tr>Total fee</Tr></span><strong>{money(data.fees.total)}</strong></div>
            <div className="kpi present"><span><Tr>Paid</Tr></span><strong>{money(data.fees.paid)}</strong></div>
            <div className="kpi late"><span><Tr>Pending</Tr></span><strong>{money(data.fees.pending)}</strong></div>
          </div>
          <DataTable
            columns={[
              { key: 'title', label: 'Fee' },
              { key: 'due_date', label: 'Due', render: (row) => String(row.due_date || '').slice(0, 10) },
              { key: 'amount', label: 'Amount', render: (row) => money(row.total_due ?? row.amount) },
              { key: 'paid_amount', label: 'Paid', render: (row) => money(row.paid_amount) },
              { key: 'pending_amount', label: 'Pending', render: (row) => money(row.pending_amount) },
              { key: 'status', label: 'Status', render: (row) => <Badge value={row.status} /> },
            ]}
            rows={fees}
            emptyTitle="No fee records"
            emptyText="Fee vouchers for this student will appear here."
            {...once(fees)}
            noun="fees"
          />
          <DataTable
            columns={[
              { key: 'receipt_no', label: 'Receipt' },
              { key: 'amount', label: 'Amount', render: (row) => money(row.amount) },
              { key: 'paid_at', label: 'Date', render: (row) => String(row.paid_at || row.created_at || '').slice(0, 10) },
              { key: 'download', label: '', render: (row) => <button className="btn ghost" type="button" onClick={() => download(`/api/payments/${row.id}/receipt`, `${row.receipt_no}.pdf`)}><Tr>Receipt</Tr></button> },
            ]}
            rows={payments}
            emptyTitle="No payments"
            emptyText="Receipts appear after a fee is collected."
            {...once(payments)}
            noun="payments"
          />
        </>
      ) : null}
      {tab === 'exams' ? (
        <DataTable
          columns={[
            { key: 'name', label: 'Exam' },
            { key: 'start_date', label: 'Starts', render: (row) => String(row.start_date || '').slice(0, 10) },
            { key: 'end_date', label: 'Ends', render: (row) => String(row.end_date || '').slice(0, 10) },
          ]}
          rows={exams}
          emptyTitle="No exams"
          emptyText="Published exams for this class will appear here."
          {...once(exams)}
          noun="exams"
        />
      ) : null}
      {tab === 'results' ? (
        <DataTable
          columns={[
            { key: 'exam', label: 'Exam' },
            { key: 'obtained', label: 'Obtained' },
            { key: 'total', label: 'Total' },
            { key: 'percentage', label: '%', render: (row) => `${row.percentage}%` },
            { key: 'grade', label: 'Grade' },
            { key: 'result', label: 'Result', render: (row) => <Badge value={row.result} /> },
            { key: 'pdf', label: '', render: (row) => <button className="btn ghost" type="button" onClick={() => download(`/api/report-cards?student_id=${student.id}&exam_id=${row.exam_id}`, 'report-card.pdf')}><Tr>PDF</Tr></button> },
          ]}
          rows={results}
          emptyTitle="No results"
          emptyText="Results appear after marks are published."
          {...once(results)}
          noun="results"
        />
      ) : null}
      {tab === 'timetable' ? (
        <DataTable
          columns={[
            { key: 'day_of_week', label: 'Day', render: (row) => <Tr>{days[row.day_of_week] || '—'}</Tr> },
            { key: 'start_time', label: 'Time', render: (row) => `${String(row.start_time || '').slice(0, 5)} – ${String(row.end_time || '').slice(0, 5)}` },
            { key: 'subject', label: 'Subject', render: (row) => <Tr>{row.subject?.name || '—'}</Tr> },
            { key: 'room', label: 'Room' },
          ]}
          rows={timetable}
          emptyTitle="No timetable"
          emptyText="The class timetable will appear here."
          {...once(timetable)}
          noun="periods"
        />
      ) : null}
      {tab === 'homework' ? (
        <DataTable
          columns={[
            { key: 'title', label: 'Homework' },
            { key: 'subject', label: 'Subject', render: (row) => <Tr>{row.subject?.name || '—'}</Tr> },
            { key: 'due_date', label: 'Due', render: (row) => String(row.due_date || '').slice(0, 10) || '—' },
          ]}
          rows={homework}
          emptyTitle="No homework"
          emptyText="New homework for this class will appear here."
          {...once(homework)}
          noun="homework"
        />
      ) : null}
      {tab === 'assignments' ? (
        <DataTable
          columns={[
            { key: 'title', label: 'Assignment' },
            { key: 'subject', label: 'Subject', render: (row) => <Tr>{row.subject?.name || '—'}</Tr> },
            { key: 'due_date', label: 'Due', render: (row) => String(row.due_date || '').slice(0, 10) || '—' },
            { key: 'submit', label: '', render: (row) => <button className="btn ghost" type="button" onClick={() => setSubmitItem(row)}><Tr>Submit</Tr></button> },
          ]}
          rows={assignments}
          emptyTitle="No assignments"
          emptyText="Assignments for this class will appear here."
          {...once(assignments)}
          noun="assignments"
        />
      ) : null}
      <Modal title={submitItem ? `Submit · ${submitItem.title}` : ''} onClose={() => setSubmitItem(null)}>
        {submitItem ? (
          <form className="form-grid" onSubmit={async (event) => {
            event.preventDefault();
            const form = new FormData(event.target);
            form.append('student_id', student.id);
            try {
              await apiForm(`/api/assignments/${submitItem.id}/submit`, form);
              toast('Assignment submitted.');
              setSubmitItem(null);
            } catch (err) { toast(errorText(err), 'err'); }
          }}>
            <Field label="File" wide><FilePick name="file" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      {tab === 'announcements' ? (
        announcements.length === 0 ? <EmptyState title="No announcements" text="College notices for this class will appear here." /> : (
          <div className="notice-list">
            {announcements.map((item) => (
              <article className="card" key={item.id}>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
          </div>
        )
      ) : null}
      {tab === 'leaves' ? (
        <>
          <div className="kpis">
            <div className="kpi leave"><span><Tr>Leave balance</Tr></span><strong>{attendance.remaining_leave}</strong></div>
          </div>
          <DataTable
            columns={[
              { key: 'leave_type', label: 'Type' },
              { key: 'start_date', label: 'From', render: (row) => String(row.start_date || '').slice(0, 10) },
              { key: 'end_date', label: 'To', render: (row) => String(row.end_date || '').slice(0, 10) },
              { key: 'status', label: 'Status', render: (row) => <Badge value={row.status} /> },
            ]}
            rows={leaves}
            emptyTitle="No leave requests"
            emptyText="Approved and pending leaves are listed here."
            {...once(leaves)}
            noun="leaves"
          />
        </>
      ) : null}
    </Page>
  );
}

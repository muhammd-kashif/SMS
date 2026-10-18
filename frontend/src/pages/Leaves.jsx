import { useEffect, useState } from 'react';
import { api, errorText, exportCsv } from '../api';
import { useAuth } from '../auth';
import { useList } from '../list';
import {Textarea, Input, FilePick, Tr, Badge, DataTable, Field, Modal, Page, RowActions, useFeedback } from '../ui';

export default function Leaves() {
  const { user } = useAuth();
  const { toast } = useFeedback();
  const [filters, setFilters] = useState({ search: '', class_id: '', section_id: '', status: '', leave_type: '', from: '', to: '' });
  const [students, setStudents] = useState([]);
  const [classes, setClasses] = useState([]);
  const [view, setView] = useState(null);
  const [apply, setApply] = useState(false);
  const list = useList('/api/leaves', filters);
  const staff = user.role === 'admin' || user.role === 'teacher';
  const sections = classes.find((item) => String(item.id) === String(filters.class_id))?.sections || [];

  useEffect(() => {
    if (staff) {
      api('/api/students?all=1').then((data) => setStudents(data.data || [])).catch(() => {});
      api('/api/structure').then((data) => setClasses(data.classes || [])).catch(() => {});
    } else {
      api('/api/portal').then((data) => setStudents(data.children || [])).catch(() => {});
    }
  }, [staff]);

  async function review(row, status) {
    try {
      await api(`/api/leaves/${row.id}/review`, { method: 'POST', body: { status } });
      toast(status === 'approved' ? 'Leave approved.' : 'Leave rejected.');
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  return (
    <Page title="Leaves" text="Submit a request from the popup. Open a row to view it." actions={
      <div className="toolbar">
        <button className="btn" onClick={() => setApply(true)}><Tr>Request leave</Tr></button>
        <button className="btn ghost" onClick={() => exportCsv('leaves.csv', list.rows.map((row) => ({ Student: row.student?.user?.name, Type: row.leave_type, Status: row.status })))}><Tr>Export</Tr></button>
      </div>
    }>
      {staff ? (
        <div className="card filters">
          <Field label="Class"><select value={filters.class_id} onChange={(event) => setFilters({ ...filters, class_id: event.target.value, section_id: '' })}><option value=""><Tr>All</Tr></option>{classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}</select></Field>
          <Field label="Section"><select value={filters.section_id} onChange={(event) => setFilters({ ...filters, section_id: event.target.value })}><option value=""><Tr>All</Tr></option>{sections.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}</select></Field>
          <Field label="Type"><select value={filters.leave_type} onChange={(event) => setFilters({ ...filters, leave_type: event.target.value })}><option value=""><Tr>All</Tr></option><option value="sick"><Tr>Sick</Tr></option><option value="casual"><Tr>Casual</Tr></option><option value="emergency"><Tr>Emergency</Tr></option><option value="other"><Tr>Other</Tr></option></select></Field>
          <Field label="Status"><select value={filters.status} onChange={(event) => setFilters({ ...filters, status: event.target.value })}><option value=""><Tr>All</Tr></option><option value="pending"><Tr>Pending</Tr></option><option value="approved"><Tr>Approved</Tr></option><option value="rejected"><Tr>Rejected</Tr></option></select></Field>
          <Field label="From"><Input type="date" value={filters.from} onChange={(event) => setFilters({ ...filters, from: event.target.value })} /></Field>
          <Field label="To"><Input type="date" value={filters.to} onChange={(event) => setFilters({ ...filters, to: event.target.value })} /></Field>
        </div>
      ) : null}
      <DataTable
        columns={[
          { key: 'student', label: 'Student', render: (row) => <Tr>{row.student?.user?.name}</Tr> },
          { key: 'class', label: 'Class', render: (row) => <Tr>{`${row.student?.school_class?.name || ''} ${row.student?.section?.name || ''}`}</Tr> },
          { key: 'from', label: 'From', render: (row) => String(row.start_date).slice(0, 10) },
          { key: 'to', label: 'To', render: (row) => String(row.end_date).slice(0, 10) },
          { key: 'reason', label: 'Reason' },
          { key: 'status', label: 'Status', render: (row) => <Badge value={row.status} /> },
          { key: 'actions', label: 'Actions', render: (row) => (
            <div className="toolbar">
              <RowActions onView={() => setView(row)} />
              {staff && row.status === 'pending' ? (
                <>
                  <button className="btn" onClick={() => review(row, 'approved')}><Tr>Approve</Tr></button>
                  <button className="btn ghost" onClick={() => review(row, 'rejected')}><Tr>Reject</Tr></button>
                </>
              ) : null}
            </div>
          ) },
        ]}
        rows={list.rows}
        loading={list.loading}
        emptyTitle="No leave requests"
        emptyText="Requests that match these filters will appear here."
        page={list.page}
        lastPage={list.last}
        from={list.from}
        to={list.to}
        total={list.total}
        noun="leaves"
        onPage={list.setPage}
      />
      <Modal title={apply ? 'Request leave' : ''} onClose={() => setApply(false)}>
        {apply ? (
          <form className="form-grid" onSubmit={async (event) => {
            event.preventDefault();
            try {
              await api('/api/leaves', { method: 'POST', form: new FormData(event.target) });
              toast('Leave request submitted.');
              setApply(false);
              list.reload();
            } catch (err) { toast(errorText(err), 'err'); }
          }}>
            <Field label="Student"><select name="student_id" required>{students.map((student) => <option key={student.id} value={student.id}><Tr>{student.name || student.user?.name}</Tr></option>)}</select></Field>
            <Field label="Type"><select name="leave_type"><option value="sick"><Tr>Sick</Tr></option><option value="casual"><Tr>Casual</Tr></option><option value="emergency"><Tr>Emergency</Tr></option><option value="other"><Tr>Other</Tr></option></select></Field>
            <Field label="From"><Input name="start_date" type="date" required /></Field>
            <Field label="To"><Input name="end_date" type="date" required /></Field>
            <Field label="Reason" wide><Textarea name="reason" required /></Field>
            <Field label="Document" hint="JPG, PNG, or PDF up to 5 MB."><FilePick name="document" accept="image/png,image/jpeg,application/pdf" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      <Modal title={view ? 'Leave request' : ''} onClose={() => setView(null)}>
        {view ? (
          <dl className="meta-list">
            <div><dt><Tr>Student</Tr></dt><dd><Tr>{view.student?.user?.name}</Tr></dd></div>
            <div><dt><Tr>Type</Tr></dt><dd><Tr>{view.leave_type}</Tr></dd></div>
            <div><dt><Tr>Dates</Tr></dt><dd>{String(view.start_date).slice(0, 10)} → {String(view.end_date).slice(0, 10)}</dd></div>
            <div><dt><Tr>Days</Tr></dt><dd>{view.days}</dd></div>
            <div><dt><Tr>Status</Tr></dt><dd><Badge value={view.status} /></dd></div>
            <div><dt><Tr>Reason</Tr></dt><dd><Tr>{view.reason}</Tr></dd></div>
          </dl>
        ) : null}
      </Modal>
    </Page>
  );
}

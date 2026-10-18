import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorText } from '../api';
import { useAuth } from '../auth';
import { useList } from '../list';
import {Input,  Tr, Badge, DataTable, Field, Modal, Page, RowActions, StatusSwitch, money, useFeedback } from '../ui';

const empty = { name: '', email: '', password: '', phone: '', gender: '', qualification: '', designation: 'Teacher', salary: '', joining_date: '', status: 'active', assignments: [] };

export default function Teachers() {
  const { user } = useAuth();
  const { toast, confirm } = useFeedback();
  const [filters, setFilters] = useState({ search: '', status: '', designation: '', subject_id: '' });
  const [structure, setStructure] = useState({ classes: [], subjects: [] });
  const [form, setForm] = useState(null);
  const [view, setView] = useState(null);
  const list = useList('/api/teachers', filters);
  const admin = user.role === 'admin';

  useEffect(() => { api('/api/structure').then(setStructure).catch(() => {}); }, []);

  async function save(event) {
    event.preventDefault();
    try {
      const body = { ...form };
      if (!body.assignments?.[0]?.class_id) delete body.assignments;
      if (!body.password) delete body.password;
      if (!body.salary) body.salary = null;
      if (!body.gender) body.gender = null;
      if (form.id) await api(`/api/teachers/${form.id}`, { method: 'PUT', body });
      else await api('/api/teachers', { method: 'POST', body });
      toast(form.id ? 'Teacher updated successfully.' : 'Teacher added successfully.');
      setForm(null);
      list.reload();
    } catch (err) {
      toast(errorText(err), 'err');
    }
  }

  async function setStatus(row, active) {
    if (!active) {
      const ok = await confirm({
        title: 'Set teacher inactive?',
        body: 'This person stays on record and cannot sign in until you turn them active again.',
        confirmLabel: 'Set inactive',
        danger: true,
      });
      if (!ok) return;
    }
    try {
      await api(`/api/teachers/${row.id}/status`, { method: 'PUT', body: { status: active ? 'active' : 'inactive' } });
      toast(active ? 'Teacher is active.' : 'Teacher is inactive.');
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  return (
    <Page title="Teachers" text="Search by name or code. Use the switch to set a teacher active or inactive." actions={admin ? <button className="btn" onClick={() => setForm(empty)}><Tr>Add teacher</Tr></button> : null}>
      <div className="card filters">
        <Field label="Search"><Input value={filters.search} onChange={(event) => setFilters({ ...filters, search: event.target.value })} placeholder="Name, code, phone" /></Field>
        <Field label="Role / designation"><Input value={filters.designation} onChange={(event) => setFilters({ ...filters, designation: event.target.value })} placeholder="Teacher" /></Field>
        <Field label="Status">
          <select value={filters.status} onChange={(event) => setFilters({ ...filters, status: event.target.value })}>
            <option value=""><Tr>All</Tr></option><option value="active"><Tr>Active</Tr></option><option value="inactive"><Tr>Inactive</Tr></option>
          </select>
        </Field>
        <Field label="Subject">
          <select value={filters.subject_id} onChange={(event) => setFilters({ ...filters, subject_id: event.target.value })}>
            <option value=""><Tr>All</Tr></option>
            {structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
          </select>
        </Field>
      </div>
      <DataTable
        columns={[
          { key: 'photo', label: 'Photo', render: (row) => row.face_photo_url ? <img src={row.face_photo_url} alt="" style={{ width: 36, height: 36, borderRadius: 8, objectFit: 'cover' }} /> : <span className="avatar" style={{ width: 36, height: 36, fontSize: 14 }}>{row.name?.slice(0, 1)}</span> },
          { key: 'name', label: 'Name' },
          { key: 'employee_code', label: 'Code' },
          { key: 'designation', label: 'Role' },
          { key: 'classes', label: 'Classes', render: (row) => <Tr>{(row.assignments || []).map((item) => `${item.class_name || ''} ${item.subject_name || ''}`).join(', ')}</Tr> },
          { key: 'status', label: 'Status', render: (row) => <StatusSwitch active={row.status === 'active'} disabled={!admin} onChange={(next) => setStatus(row, next)} /> },
          { key: 'face', label: 'Face', render: (row) => <Badge value={row.face_registered ? 'registered' : 'missing'} /> },
          { key: 'actions', label: 'Actions', render: (row) => (
            <div className="row-actions">
              <RowActions onView={() => setView(row)} onEdit={admin ? () => setForm({ ...row, password: '' }) : null} />
              {admin ? <Link className="btn ghost" to={`/face/register?type=teacher&id=${row.id}`}><Tr>Face</Tr></Link> : null}
            </div>
          ) },
        ]}
        rows={list.rows}
        loading={list.loading}
        emptyTitle="No teachers found"
        emptyText="Add a teacher or clear the filters."
        emptyAction={admin ? <button className="btn" onClick={() => setForm(empty)}><Tr>Add teacher</Tr></button> : null}
        page={list.page}
        lastPage={list.last}
        from={list.from}
        to={list.to}
        total={list.total}
        noun="teachers"
        onPage={list.setPage}
      />
      <Modal title={view ? view.name : ''} onClose={() => setView(null)}>
        {view ? (
          <div>
            {view.face_photo_url ? <img src={view.face_photo_url} alt="" style={{ width: 96, height: 96, borderRadius: 18, objectFit: 'cover' }} /> : <div className="avatar">{view.name?.slice(0, 1)}</div>}
            <p>{view.email}</p>
            <p><Tr>{view.phone || 'No phone'}</Tr> · <Tr>{view.designation}</Tr></p>
            <p><Tr>{view.gender || '—'}</Tr> · <Tr>{view.qualification || '—'}</Tr></p>
            <p><Tr>Monthly salary:</Tr> {view.salary ? money(view.salary) : '—'}</p>
            <p><Tr>Joined</Tr> {view.joining_date || '—'}</p>
            <p><Tr>Status:</Tr> <StatusSwitch active={view.status === 'active'} disabled={!admin} onChange={(next) => setStatus(view, next)} /></p>
            <p><Tr>{(view.assignments || []).map((item) => `${item.class_name} ${item.section_name || ''} · ${item.subject_name || ''}`).join(', ') || 'No assignments'}</Tr></p>
          </div>
        ) : null}
      </Modal>
      <Modal title={form ? (form.id ? 'Edit teacher' : 'Add teacher') : ''} onClose={() => setForm(null)}>
        {form ? (
          <form className="form-grid" onSubmit={save}>
            <Field label="Name"><Input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} required /></Field>
            <Field label="Email"><Input type="email" value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} required /></Field>
            <Field label="Password"><Input type="password" value={form.password || ''} onChange={(event) => setForm({ ...form, password: event.target.value })} required={!form.id} minLength={8} /></Field>
            <Field label="Phone"><Input value={form.phone || ''} onChange={(event) => setForm({ ...form, phone: event.target.value })} /></Field>
            <Field label="Gender">
              <select value={form.gender || ''} onChange={(event) => setForm({ ...form, gender: event.target.value })}>
                <option value=""><Tr>Select</Tr></option>
                <option value="male"><Tr>Male</Tr></option>
                <option value="female"><Tr>Female</Tr></option>
              </select>
            </Field>
            <Field label="Qualification"><Input value={form.qualification || ''} onChange={(event) => setForm({ ...form, qualification: event.target.value })} /></Field>
            <Field label="Designation"><Input value={form.designation || ''} onChange={(event) => setForm({ ...form, designation: event.target.value })} /></Field>
            <Field label="Monthly salary"><Input type="number" min="0" step="1" value={form.salary ?? ''} onChange={(event) => setForm({ ...form, salary: event.target.value })} /></Field>
            <Field label="Status">
              <StatusSwitch active={(form.status || 'active') === 'active'} onChange={(next) => setForm({ ...form, status: next ? 'active' : 'inactive' })} />
            </Field>
            <Field label="Joining date"><Input type="date" value={form.joining_date || ''} onChange={(event) => setForm({ ...form, joining_date: event.target.value })} /></Field>
            <Field label="Class">
              <select value={form.assignments[0]?.class_id || ''} onChange={(event) => setForm({ ...form, assignments: [{ class_id: Number(event.target.value), section_id: form.assignments[0]?.section_id, subject_id: form.assignments[0]?.subject_id }] })}>
                <option value=""><Tr>Select</Tr></option>
                {structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Subject">
              <select value={form.assignments[0]?.subject_id || ''} onChange={(event) => setForm({ ...form, assignments: [{ ...(form.assignments[0] || {}), subject_id: Number(event.target.value) }] })}>
                <option value=""><Tr>Select</Tr></option>
                {structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}

import { useEffect, useState } from 'react';
import { api, errorText } from '../api';
import { useAuth } from '../auth';
import { useList } from '../list';
import {Textarea, Input,  Tr, Badge, DataTable, Field, Modal, Page, RowActions, StatusSwitch, useFeedback } from '../ui';

export function Announcements() {
  const { user } = useAuth();
  const { toast, confirm } = useFeedback();
  const [filters, setFilters] = useState({ audience: '', class_id: '', status: '', date: '' });
  const [structure, setStructure] = useState({ classes: [] });
  const [editing, setEditing] = useState(null);
  const [view, setView] = useState(null);
  const list = useList('/api/announcements', filters);
  const staff = user.role === 'admin' || user.role === 'teacher';

  useEffect(() => { api('/api/structure').then(setStructure).catch(() => {}); }, []);

  async function setPublished(row, next) {
    try {
      await api(`/api/announcements/${row.id}`, { method: 'PUT', body: { published: next } });
      toast(next ? 'Announcement is active.' : 'Announcement is inactive.');
      setView((current) => (current?.id === row.id ? { ...current, published: next } : current));
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function save(event) {
    event.preventDefault();
    const body = Object.fromEntries(new FormData(event.target).entries());
    body.published = body.published === '1';
    try {
      if (editing?.id) await api(`/api/announcements/${editing.id}`, { method: 'PUT', body });
      else await api('/api/announcements', { method: 'POST', body });
      toast(editing?.id ? 'Announcement updated.' : 'Announcement published.');
      setEditing(null);
      event.target.reset();
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  return (
    <Page title="Announcements" text="Publish a notice from the popup. View and edit use the same window." actions={staff ? <button className="btn" onClick={() => setEditing({})}><Tr>New announcement</Tr></button> : null}>
      <div className="card filters">
        <Field label="Audience"><select value={filters.audience} onChange={(event) => setFilters({ ...filters, audience: event.target.value })}><option value=""><Tr>All</Tr></option><option value="all"><Tr>Everyone</Tr></option><option value="class"><Tr>Class</Tr></option><option value="parents"><Tr>Parents</Tr></option><option value="teachers"><Tr>Teachers</Tr></option></select></Field>
        <Field label="Class"><select value={filters.class_id} onChange={(event) => setFilters({ ...filters, class_id: event.target.value })}><option value=""><Tr>All</Tr></option>{structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}</select></Field>
        <Field label="Status"><select value={filters.status} onChange={(event) => setFilters({ ...filters, status: event.target.value })}><option value=""><Tr>All</Tr></option><option value="published"><Tr>Published</Tr></option><option value="unpublished"><Tr>Unpublished</Tr></option></select></Field>
        <Field label="Date"><Input type="date" value={filters.date} onChange={(event) => setFilters({ ...filters, date: event.target.value })} /></Field>
      </div>
      <DataTable
        columns={[
          { key: 'title', label: 'Title' },
          { key: 'audience', label: 'Audience' },
          { key: 'class', label: 'Class', render: (row) => <Tr>{row.school_class?.name || '—'}</Tr> },
          { key: 'status', label: 'Status', render: (row) => <StatusSwitch active={Boolean(row.published)} disabled={!staff} onChange={(next) => setPublished(row, next)} /> },
          { key: 'actions', label: 'Actions', render: (row) => (
            <RowActions
              onView={() => setView(row)}
              onEdit={staff ? () => setEditing(row) : null}
              onDelete={user.role === 'admin' ? async () => {
                const ok = await confirm({ title: 'Delete announcement?', body: row.title, confirmLabel: 'Delete', danger: true });
                if (!ok) return;
                await api(`/api/announcements/${row.id}`, { method: 'DELETE' });
                toast('Announcement deleted.');
                list.reload();
              } : null}
            />
          ) },
        ]}
        rows={list.rows}
        loading={list.loading}
        emptyTitle="No announcements"
        emptyText="Published notices will show here."
        page={list.page}
        lastPage={list.last}
        from={list.from}
        to={list.to}
        total={list.total}
        noun="announcements"
        onPage={list.setPage}
      />
      <Modal title={editing ? (editing.id ? 'Edit announcement' : 'New announcement') : ''} onClose={() => setEditing(null)}>
        {editing ? (
          <form key={editing.id || 'new'} className="form-grid" onSubmit={save}>
            <Field label="Title" wide><Input name="title" defaultValue={editing.title || ''} required /></Field>
            <Field label="Audience">
              <select name="audience" defaultValue={editing.audience || 'all'}><option value="all"><Tr>All</Tr></option><option value="class"><Tr>Class</Tr></option><option value="section"><Tr>Section</Tr></option><option value="parents"><Tr>Parents</Tr></option><option value="teachers"><Tr>Teachers</Tr></option></select>
            </Field>
            <Field label="Class"><select name="class_id" defaultValue={editing.class_id || ''}><option value=""><Tr>Optional</Tr></option>{structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}</select></Field>
            <Field label="Publish"><select name="published" defaultValue={editing.published === false ? '0' : '1'}><option value="1"><Tr>Published</Tr></option><option value="0"><Tr>Unpublished</Tr></option></select></Field>
            <Field label="Message" wide><Textarea name="body" defaultValue={editing.body || ''} required /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      <Modal title={view?.title || ''} onClose={() => setView(null)}>
        {view ? (
          <dl className="meta-list">
            <div><dt><Tr>Audience</Tr></dt><dd><Tr>{view.audience}</Tr></dd></div>
            <div><dt><Tr>Class</Tr></dt><dd><Tr>{view.school_class?.name || '—'}</Tr></dd></div>
            <div><dt><Tr>Status</Tr></dt><dd><StatusSwitch active={Boolean(view.published)} disabled={!staff} onChange={(next) => setPublished(view, next)} /></dd></div>
            <div><dt><Tr>Message</Tr></dt><dd><Tr>{view.body}</Tr></dd></div>
          </dl>
        ) : null}
      </Modal>
    </Page>
  );
}

export function Notifications() {
  const { toast, confirm } = useFeedback();
  const [page, setPage] = useState(1);
  const [pack, setPack] = useState({ rows: [], last: 1, total: 0, from: 0, to: 0 });
  const [loading, setLoading] = useState(true);
  const [view, setView] = useState(null);

  function load(next = page) {
    setLoading(true);
    api(`/api/notifications?page=${next}`).then((data) => setPack({
      rows: data.data || [],
      last: data.last_page || 1,
      total: data.total || (data.data || []).length,
      from: data.from || 0,
      to: data.to || 0,
    })).finally(() => setLoading(false));
  }
  useEffect(() => { load(page); }, [page]);

  return (
    <Page title="Notifications" actions={<button className="btn ghost" onClick={async () => { await api('/api/notifications/read-all', { method: 'POST' }); toast('All notifications marked as read.'); load(); }}><Tr>Mark all as read</Tr></button>}>
      <DataTable
        columns={[
          { key: 'title', label: 'Notification', render: (row) => <strong><Tr>{row.title}</Tr></strong> },
          { key: 'body', label: 'Message' },
          { key: 'state', label: 'Status', render: (row) => <Badge value={row.read_at ? 'read' : 'unread'} /> },
          { key: 'actions', label: 'Actions', render: (row) => (
            <RowActions
              onView={async () => {
                setView(row);
                if (!row.read_at) {
                  await api(`/api/notifications/${row.id}/read`, { method: 'POST' });
                  load();
                }
              }}
              onDelete={async () => {
                const ok = await confirm({ title: 'Delete notification?', body: row.title, confirmLabel: 'Delete', danger: true });
                if (!ok) return;
                await api(`/api/notifications/${row.id}`, { method: 'DELETE' });
                toast('Notification deleted.');
                load();
              }}
            />
          ) },
        ]}
        rows={pack.rows}
        loading={loading}
        emptyTitle="No notifications"
        emptyText="New alerts for fees, exams, leave, and homework appear here."
        page={page}
        lastPage={pack.last}
        from={pack.from}
        to={pack.to}
        total={pack.total}
        noun="notifications"
        onPage={setPage}
      />
      <Modal title={view?.title || ''} onClose={() => setView(null)}>
        {view ? (
          <dl className="meta-list">
            <div><dt><Tr>Status</Tr></dt><dd><Badge value={view.read_at ? 'read' : 'unread'} /></dd></div>
            <div><dt><Tr>Message</Tr></dt><dd><Tr>{view.body}</Tr></dd></div>
          </dl>
        ) : null}
      </Modal>
    </Page>
  );
}

import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, errorText } from '../api';
import {Input,  Tr, DataTable, Field, Modal, Page, RowActions, StatusSwitch, Tabs, useFeedback } from '../ui';

const tabs = [
  { id: 'classes', label: 'Classes' },
  { id: 'sections', label: 'Sections' },
  { id: 'subjects', label: 'Subjects' },
  { id: 'sessions', label: 'Sessions' },
];

const blanks = {
  class: { kind: 'class', name: '', code: '' },
  section: { kind: 'section', class_id: '', name: '' },
  subject: { kind: 'subject', name: '', code: '' },
  session: { kind: 'session', name: '', start_date: '', end_date: '', is_current: true },
};

function day(value) {
  return value ? String(value).slice(0, 10) : '';
}

export default function Classes() {
  const { confirm, toast } = useFeedback();
  const [params, setParams] = useSearchParams();
  const tab = tabs.some((item) => item.id === params.get('tab')) ? params.get('tab') : 'classes';
  const [data, setData] = useState({ classes: [], subjects: [], sessions: [] });
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState(null);
  const [view, setView] = useState(null);

  async function setSessionStatus(row, active) {
    try {
      await api(`/api/sessions/${row.id}`, {
        method: 'PUT',
        body: { name: row.name, start_date: day(row.start_date), end_date: day(row.end_date), is_current: active },
      });
      toast(active ? 'Session is active.' : 'Session is inactive.');
      setView((current) => (current?.id === row.id ? { ...current, is_current: active } : current));
      load();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  function load() {
    api('/api/structure').then(setData).catch((err) => toast(errorText(err), 'err')).finally(() => setLoading(false));
  }
  useEffect(() => { load(); }, []);

  const query = search.trim().toLowerCase();
  const classes = data.classes.filter((item) => !query || `${item.name} ${item.code || ''}`.toLowerCase().includes(query));
  const sections = data.classes.flatMap((item) => (item.sections || []).map((section) => ({
    ...section,
    class_id: item.id,
    class_name: item.name,
  }))).filter((item) => !query || `${item.name} ${item.class_name}`.toLowerCase().includes(query));
  const subjects = data.subjects.filter((item) => !query || `${item.name} ${item.code || ''}`.toLowerCase().includes(query));
  const sessions = data.sessions.filter((item) => !query || item.name.toLowerCase().includes(query));

  async function save(event) {
    event.preventDefault();
    const path = { class: '/api/classes', section: '/api/sections', subject: '/api/subjects', session: '/api/sessions' }[form.kind];
    const body = { ...form };
    delete body.kind;
    delete body.id;
    delete body.class_name;
    delete body.sections;
    try {
      if (form.id) await api(`${path}/${form.id}`, { method: 'PUT', body });
      else await api(path, { method: 'POST', body });
      toast(form.id ? 'Saved.' : 'Added.');
      setForm(null);
      load();
    } catch (err) {
      toast(errorText(err), 'err');
    }
  }

  async function remove(kind, row) {
    const labels = { class: 'class', section: 'section', subject: 'subject', session: 'session' };
    const ok = await confirm({
      title: `Delete ${labels[kind]}?`,
      body: row.name,
      confirmLabel: 'Delete',
      danger: true,
    });
    if (!ok) return;
    const path = { class: '/api/classes', section: '/api/sections', subject: '/api/subjects', session: '/api/sessions' }[kind];
    try {
      await api(`${path}/${row.id}`, { method: 'DELETE' });
      toast('Removed.');
      load();
    } catch (err) {
      toast(errorText(err), 'err');
    }
  }

  const rows = { classes, sections, subjects, sessions }[tab];
  const columns = {
    classes: [
      { key: 'name', label: 'Class' },
      { key: 'code', label: 'Code', render: (row) => row.code || '—' },
      { key: 'sections', label: 'Sections', render: (row) => <Tr>{(row.sections || []).map((section) => section.name).join(', ') || '—'}</Tr> },
    ],
    sections: [
      { key: 'name', label: 'Section' },
      { key: 'class_name', label: 'Class' },
    ],
    subjects: [
      { key: 'name', label: 'Subject' },
      { key: 'code', label: 'Code', render: (row) => row.code || '—' },
    ],
    sessions: [
      { key: 'name', label: 'Session' },
      { key: 'start_date', label: 'Starts', render: (row) => day(row.start_date) },
      { key: 'end_date', label: 'Ends', render: (row) => day(row.end_date) },
      { key: 'is_current', label: 'Status', render: (row) => (
        <StatusSwitch active={Boolean(row.is_current)} onChange={(next) => setSessionStatus(row, next)} />
      ) },
    ],
  }[tab];

  return (
    <Page title="Academic structure" text="Classes, sections, subjects, and sessions. Add, view, and edit from the popup." actions={
      <button className="btn" onClick={() => setForm(blanks[tab === 'classes' ? 'class' : tab.slice(0, -1)])}>
        <Tr>{tab === 'classes' ? 'Add class' : tab === 'sections' ? 'Add section' : tab === 'subjects' ? 'Add subject' : 'Add session'}</Tr>
      </button>
    }>
      <Tabs tabs={tabs} value={tab} onChange={(id) => { setParams(id === 'classes' ? {} : { tab: id }); setSearch(''); }} />
      <div className="card filters one">
        <Field label="Search"><Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Name or code" /></Field>
      </div>
      <DataTable
        columns={[
          ...columns,
          { key: 'actions', label: 'Actions', render: (row) => (
            <RowActions
              onView={() => setView({ ...row, kind: tab === 'classes' ? 'class' : tab.slice(0, -1) })}
              onEdit={() => setForm({
                ...row,
                kind: tab === 'classes' ? 'class' : tab.slice(0, -1),
                start_date: day(row.start_date),
                end_date: day(row.end_date),
                class_id: row.class_id || '',
              })}
              onDelete={() => remove(tab === 'classes' ? 'class' : tab.slice(0, -1), row)}
            />
          ) },
        ]}
        rows={rows}
        loading={loading}
        emptyTitle="Nothing here yet"
        emptyText="Use the add button to create the first record."
        page={1}
        lastPage={1}
        from={rows.length ? 1 : 0}
        to={rows.length}
        total={rows.length}
        noun={tab}
        onPage={() => {}}
      />

      <Modal title={view ? view.name : ''} onClose={() => setView(null)}>
        {view?.kind === 'class' ? (
          <dl className="meta-list">
            <div><dt><Tr>Class</Tr></dt><dd><Tr>{view.name}</Tr></dd></div>
            <div><dt><Tr>Code</Tr></dt><dd>{view.code || '—'}</dd></div>
            <div><dt><Tr>Sections</Tr></dt><dd><Tr>{(view.sections || []).map((section) => section.name).join(', ') || '—'}</Tr></dd></div>
          </dl>
        ) : null}
        {view?.kind === 'section' ? (
          <dl className="meta-list">
            <div><dt><Tr>Section</Tr></dt><dd><Tr>{view.name}</Tr></dd></div>
            <div><dt><Tr>Class</Tr></dt><dd><Tr>{view.class_name}</Tr></dd></div>
          </dl>
        ) : null}
        {view?.kind === 'subject' ? (
          <dl className="meta-list">
            <div><dt><Tr>Subject</Tr></dt><dd><Tr>{view.name}</Tr></dd></div>
            <div><dt><Tr>Code</Tr></dt><dd>{view.code || '—'}</dd></div>
          </dl>
        ) : null}
        {view?.kind === 'session' ? (
          <dl className="meta-list">
            <div><dt><Tr>Session</Tr></dt><dd>{view.name}</dd></div>
            <div><dt><Tr>Starts</Tr></dt><dd>{day(view.start_date)}</dd></div>
            <div><dt><Tr>Ends</Tr></dt><dd>{day(view.end_date)}</dd></div>
            <div><dt><Tr>Status</Tr></dt><dd><StatusSwitch active={Boolean(view.is_current)} onChange={(next) => setSessionStatus(view, next)} /></dd></div>
          </dl>
        ) : null}
      </Modal>

      <Modal title={form ? (form.id ? `Edit ${form.kind}` : `Add ${form.kind}`) : ''} onClose={() => setForm(null)}>
        {form ? (
          <form className="form-grid" onSubmit={save}>
            {form.kind === 'section' ? (
              <Field label="Class" wide>
                <select value={form.class_id} onChange={(event) => setForm({ ...form, class_id: event.target.value })} required>
                  <option value=""><Tr>Select</Tr></option>
                  {data.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
                </select>
              </Field>
            ) : null}
            <Field label="Name" wide><Input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} required /></Field>
            {form.kind === 'class' || form.kind === 'subject' ? (
              <Field label="Code"><Input value={form.code || ''} onChange={(event) => setForm({ ...form, code: event.target.value })} /></Field>
            ) : null}
            {form.kind === 'session' ? (
              <>
                <Field label="Starts"><Input type="date" value={form.start_date || ''} onChange={(event) => setForm({ ...form, start_date: event.target.value })} required /></Field>
                <Field label="Ends"><Input type="date" value={form.end_date || ''} onChange={(event) => setForm({ ...form, end_date: event.target.value })} required /></Field>
                <Field label="Status"><StatusSwitch active={!!form.is_current} onChange={(next) => setForm({ ...form, is_current: next })} /></Field>
              </>
            ) : null}
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}

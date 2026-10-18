import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, apiForm, errorText } from '../api';
import { useAuth } from '../auth';
import {Textarea, Input, FilePick, Tr, DataTable, Field, Modal, Page, RowActions, Tabs, useFeedback } from '../ui';

const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const tabs = [
  { id: 'timetable', label: 'Timetable' },
  { id: 'homework', label: 'Homework' },
  { id: 'assignments', label: 'Assignments' },
];

function day(value) {
  return value ? String(value).slice(0, 10) : '';
}
function clock(value) {
  return value ? String(value).slice(0, 5) : '';
}

export default function Academics() {
  const { user } = useAuth();
  const { confirm, toast } = useFeedback();
  const [params, setParams] = useSearchParams();
  const tab = tabs.some((item) => item.id === params.get('tab')) ? params.get('tab') : 'timetable';
  const [slots, setSlots] = useState([]);
  const [homework, setHomework] = useState([]);
  const [assignments, setAssignments] = useState([]);
  const [structure, setStructure] = useState({ classes: [], subjects: [] });
  const [loading, setLoading] = useState(true);
  const [slotForm, setSlotForm] = useState(null);
  const [workForm, setWorkForm] = useState(null);
  const [view, setView] = useState(null);
  const staff = user.role === 'admin' || user.role === 'teacher';

  function load() {
    setLoading(true);
    Promise.all([
      api('/api/timetable'),
      api('/api/homework'),
      api('/api/assignments'),
      api('/api/structure'),
    ]).then(([nextSlots, nextHomework, nextAssignments, nextStructure]) => {
      setSlots(nextSlots || []);
      setHomework(nextHomework || []);
      setAssignments(nextAssignments || []);
      setStructure(nextStructure || { classes: [], subjects: [] });
    }).catch((err) => toast(errorText(err), 'err')).finally(() => setLoading(false));
  }
  useEffect(() => { load(); }, []);

  const work = tab === 'homework' ? homework : assignments;

  async function saveSlot(event) {
    event.preventDefault();
    const body = Object.fromEntries(new FormData(event.target).entries());
    body.start_time = clock(body.start_time);
    body.end_time = clock(body.end_time);
    if (!body.room) delete body.room;
    try {
      if (slotForm?.id) await api(`/api/timetable/${slotForm.id}`, { method: 'PUT', body });
      else await api('/api/timetable', { method: 'POST', body });
      toast(slotForm?.id ? 'Period updated.' : 'Period added.');
      setSlotForm(null);
      load();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function saveWork(event) {
    event.preventDefault();
    const path = tab === 'homework' ? '/api/homework' : '/api/assignments';
    try {
      if (workForm?.id) await apiForm(`${path}/${workForm.id}`, new FormData(event.target));
      else await apiForm(path, new FormData(event.target));
      toast(workForm?.id ? 'Updated.' : 'Published.');
      setWorkForm(null);
      load();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function remove(row) {
    const ok = await confirm({
      title: tab === 'timetable' ? 'Remove period?' : 'Delete this item?',
      body: row.subject?.name || row.title || 'This record',
      confirmLabel: 'Delete',
      danger: true,
    });
    if (!ok) return;
    const path = tab === 'timetable' ? `/api/timetable/${row.id}` : tab === 'homework' ? `/api/homework/${row.id}` : `/api/assignments/${row.id}`;
    try {
      await api(path, { method: 'DELETE' });
      toast('Removed.');
      load();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  return (
    <Page title="Academics" text="Timetable, homework, and assignments open in a popup to add, view, or edit." actions={staff ? (
      <button className="btn" onClick={() => (tab === 'timetable' ? setSlotForm({}) : setWorkForm({}))}>
        <Tr>{tab === 'timetable' ? 'Add period' : tab === 'homework' ? 'Add homework' : 'Add assignment'}</Tr>
      </button>
    ) : null}>
      <Tabs tabs={tabs} value={tab} onChange={(id) => setParams({ tab: id })} />
      {tab === 'timetable' ? (
        <DataTable
          columns={[
            { key: 'day', label: 'Day', render: (row) => <Tr>{days[row.day_of_week]}</Tr> },
            { key: 'time', label: 'Time', render: (row) => `${clock(row.start_time)}–${clock(row.end_time)}` },
            { key: 'subject', label: 'Subject', render: (row) => <Tr>{row.subject?.name || '—'}</Tr> },
            { key: 'class', label: 'Class', render: (row) => <Tr>{`${row.school_class?.name || ''} ${row.section?.name || ''}`}</Tr> },
            { key: 'room', label: 'Room', render: (row) => <Tr>{row.room || '—'}</Tr> },
            { key: 'actions', label: 'Actions', render: (row) => (
              <RowActions
                onView={() => setView({ kind: 'slot', ...row })}
                onEdit={staff ? () => setSlotForm(row) : null}
                onDelete={staff ? () => remove(row) : null}
              />
            ) },
          ]}
          rows={slots}
          loading={loading}
          emptyTitle="No periods"
          emptyText="Add a period to build the timetable."
          page={1}
          lastPage={1}
          from={slots.length ? 1 : 0}
          to={slots.length}
          total={slots.length}
          noun="periods"
          onPage={() => {}}
        />
      ) : (
        <DataTable
          columns={[
            { key: 'title', label: 'Title' },
            { key: 'subject', label: 'Subject', render: (row) => <Tr>{row.subject?.name || '—'}</Tr> },
            { key: 'class', label: 'Class', render: (row) => <Tr>{row.school_class?.name || '—'}</Tr> },
            { key: 'due', label: 'Due', render: (row) => day(row.due_date) || '—' },
            { key: 'actions', label: 'Actions', render: (row) => (
              <RowActions
                onView={() => setView({ kind: 'work', ...row })}
                onEdit={staff ? () => setWorkForm(row) : null}
                onDelete={staff ? () => remove(row) : null}
              />
            ) },
          ]}
          rows={work}
          loading={loading}
          emptyTitle={`No ${tab}`}
          emptyText="Published work will appear here."
          page={1}
          lastPage={1}
          from={work.length ? 1 : 0}
          to={work.length}
          total={work.length}
          noun={tab}
          onPage={() => {}}
        />
      )}

      <Modal title={view?.kind === 'slot' ? (view.subject?.name || 'Period') : view?.title || ''} onClose={() => setView(null)}>
        {view?.kind === 'slot' ? (
          <dl className="meta-list">
            <div><dt><Tr>Day</Tr></dt><dd><Tr>{days[view.day_of_week]}</Tr></dd></div>
            <div><dt><Tr>Time</Tr></dt><dd>{clock(view.start_time)}–{clock(view.end_time)}</dd></div>
            <div><dt><Tr>Subject</Tr></dt><dd><Tr>{view.subject?.name || '—'}</Tr></dd></div>
            <div><dt><Tr>Class</Tr></dt><dd><Tr>{`${view.school_class?.name || ''} ${view.section?.name || ''}`}</Tr></dd></div>
            <div><dt><Tr>Room</Tr></dt><dd><Tr>{view.room || '—'}</Tr></dd></div>
          </dl>
        ) : null}
        {view?.kind === 'work' ? (
          <dl className="meta-list">
            <div><dt><Tr>Title</Tr></dt><dd><Tr>{view.title}</Tr></dd></div>
            <div><dt><Tr>Subject</Tr></dt><dd><Tr>{view.subject?.name || '—'}</Tr></dd></div>
            <div><dt><Tr>Class</Tr></dt><dd><Tr>{view.school_class?.name || '—'}</Tr></dd></div>
            <div><dt><Tr>Due</Tr></dt><dd>{day(view.due_date) || '—'}</dd></div>
            <div><dt><Tr>Description</Tr></dt><dd><Tr>{view.description || '—'}</Tr></dd></div>
          </dl>
        ) : null}
      </Modal>

      <Modal title={slotForm ? (slotForm.id ? 'Edit period' : 'Add period') : ''} onClose={() => setSlotForm(null)}>
        {slotForm ? (
          <form key={slotForm.id || 'new'} className="form-grid" onSubmit={saveSlot}>
            <Field label="Class">
              <select name="class_id" defaultValue={slotForm.class_id || ''} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Section">
              <select name="section_id" defaultValue={slotForm.section_id || ''} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.classes.flatMap((item) => (item.sections || []).map((section) => <option key={section.id} value={section.id}><Tr>{`${item.name} ${section.name}`}</Tr></option>))}
              </select>
            </Field>
            <Field label="Subject">
              <select name="subject_id" defaultValue={slotForm.subject_id || ''} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Day">
              <select name="day_of_week" defaultValue={slotForm.day_of_week || 1}>
                {days.slice(1).map((label, index) => <option key={label} value={index + 1}><Tr>{label}</Tr></option>)}
              </select>
            </Field>
            <Field label="Start"><Input name="start_time" type="time" defaultValue={clock(slotForm.start_time)} required /></Field>
            <Field label="End"><Input name="end_time" type="time" defaultValue={clock(slotForm.end_time)} required /></Field>
            <Field label="Room" wide><Input name="room" defaultValue={slotForm.room || ''} /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>

      <Modal title={workForm ? (workForm.id ? `Edit ${tab === 'homework' ? 'homework' : 'assignment'}` : `Add ${tab === 'homework' ? 'homework' : 'assignment'}`) : ''} onClose={() => setWorkForm(null)}>
        {workForm ? (
          <form key={workForm.id || 'new'} className="form-grid" onSubmit={saveWork}>
            <Field label="Title" wide><Input name="title" defaultValue={workForm.title || ''} required /></Field>
            <Field label="Subject">
              <select name="subject_id" defaultValue={workForm.subject_id || ''}>
                <option value=""><Tr>Optional</Tr></option>
                {structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Class">
              <select name="class_id" defaultValue={workForm.class_id || ''} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Due"><Input name="due_date" type="date" defaultValue={day(workForm.due_date)} /></Field>
            <Field label="Description" wide><Textarea name="description" defaultValue={workForm.description || ''} /></Field>
            <Field label="File" hint="Optional. JPG, PNG, PDF, or Word."><FilePick name="file" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}

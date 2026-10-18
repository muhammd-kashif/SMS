import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, download, errorText, exportCsv, openPdf } from '../api';
import { useList } from '../list';
import {Input,  Tr, Badge, DataTable, Field, Modal, Page, RowActions, StatusSwitch, Tabs, useFeedback } from '../ui';

const tabs = [
  { id: 'exams', label: 'Exams' },
  { id: 'schedule', label: 'Schedule' },
  { id: 'marks', label: 'Marks' },
  { id: 'results', label: 'Results' },
];

const examTypes = [
  ['class_test', 'Class test'],
  ['monthly', 'Monthly'],
  ['mid_term', 'Mid-term'],
  ['final', 'Final'],
  ['practical', 'Practical'],
  ['quiz', 'Quiz'],
];

const blankExam = { name: '', exam_type: 'class_test', class_id: '', section_id: '', start_date: '', end_date: '' };
const blankPaper = { exam_id: '', subject_id: '', exam_date: '', start_time: '', end_time: '', room: '' };
const blankMark = { exam_id: '', student_id: '', subject_id: '', total_marks: '', obtained_marks: '', remarks: '' };

function day(value) {
  return value ? String(value).slice(0, 10) : '';
}
function clock(value) {
  return value ? String(value).slice(0, 5) : '';
}
function clean(body) {
  const next = { ...body };
  Object.keys(next).forEach((key) => {
    if (next[key] === '' || next[key] == null) delete next[key];
  });
  return next;
}

export default function Exams() {
  const { toast, confirm } = useFeedback();
  const [params, setParams] = useSearchParams();
  const tab = tabs.some((item) => item.id === params.get('tab')) ? params.get('tab') : 'exams';
  const [filters, setFilters] = useState({ search: '', class_id: '', section_id: '', subject_id: '', date: '' });
  const [structure, setStructure] = useState({ classes: [], subjects: [] });
  const [students, setStudents] = useState([]);
  const [results, setResults] = useState(null);
  const [resultExam, setResultExam] = useState('');
  const [examForm, setExamForm] = useState(null);
  const [paperForm, setPaperForm] = useState(null);
  const [markForm, setMarkForm] = useState(null);
  const [view, setView] = useState(null);
  const list = useList('/api/exams', filters);
  const sections = structure.classes.find((item) => String(item.id) === String(examForm?.class_id))?.sections || [];
  const markStudents = students.filter((student) => {
    const exam = list.rows.find((item) => String(item.id) === String(markForm?.exam_id));
    return !exam || String(student.class_id) === String(exam.class_id);
  });

  useEffect(() => {
    api('/api/structure').then(setStructure).catch(() => {});
    api('/api/students?all=1').then((data) => setStudents(data.data || [])).catch(() => {});
  }, []);

  const papers = list.rows.flatMap((exam) => (exam.schedules || []).map((row) => ({
    ...row,
    exam_id: exam.id,
    exam_name: exam.name,
    subject_name: row.subject?.name,
  })));

  async function saveExam(event) {
    event.preventDefault();
    const body = clean(examForm);
    try {
      if (examForm.id) await api(`/api/exams/${examForm.id}`, { method: 'PUT', body });
      else await api('/api/exams', { method: 'POST', body });
      toast(examForm.id ? 'Exam updated.' : 'Exam created.');
      setExamForm(null);
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function savePaper(event) {
    event.preventDefault();
    const body = clean({ ...paperForm, start_time: clock(paperForm.start_time), end_time: clock(paperForm.end_time) });
    try {
      if (paperForm.id) await api(`/api/exam-schedules/${paperForm.id}`, { method: 'PUT', body });
      else await api(`/api/exams/${paperForm.exam_id}/schedules`, { method: 'POST', body });
      toast(paperForm.id ? 'Paper updated.' : 'Paper added.');
      setPaperForm(null);
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function saveMark(event) {
    event.preventDefault();
    try {
      await api('/api/marks', { method: 'POST', body: clean(markForm) });
      toast('Marks saved.');
      setMarkForm(null);
      if (results?.exam?.id && String(results.exam.id) === String(markForm.exam_id)) {
        setResults(await api(`/api/results?exam_id=${markForm.exam_id}`));
      }
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function removeExam(exam) {
    const ok = await confirm({ title: 'Delete exam?', body: 'This exam and its schedule will be removed.', confirmLabel: 'Delete', danger: true });
    if (!ok) return;
    try {
      await api(`/api/exams/${exam.id}`, { method: 'DELETE' });
      toast('Exam deleted.');
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function removePaper(row) {
    const ok = await confirm({ title: 'Remove paper?', body: `${row.exam_name} · ${row.subject_name || 'Paper'}`, confirmLabel: 'Remove', danger: true });
    if (!ok) return;
    try {
      await api(`/api/exam-schedules/${row.id}`, { method: 'DELETE' });
      toast('Paper removed.');
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function publish(exam) {
    try {
      const data = await api(`/api/exams/${exam.id}/publish`, { method: 'POST' });
      toast(data.published ? 'Exam is active.' : 'Exam is inactive.');
      setView((current) => (current?.kind === 'exam' && current.id === exam.id ? { ...current, published: data.published } : current));
      list.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function loadResults(event) {
    event?.preventDefault();
    if (!resultExam) return;
    try {
      setResults(await api(`/api/results?exam_id=${resultExam}`));
    } catch (err) { toast(errorText(err), 'err'); }
  }

  const addLabel = tab === 'schedule' ? 'Add paper' : tab === 'marks' ? 'Enter marks' : 'Add exam';

  return (
    <Page title="Examinations" text="Create exams, papers, and marks from a popup. View and edit stay in the same window." actions={
      <div className="toolbar">
        {tab !== 'results' ? <button className="btn" onClick={() => {
          if (tab === 'schedule') setPaperForm(blankPaper);
          else if (tab === 'marks') setMarkForm(blankMark);
          else setExamForm(blankExam);
        }}><Tr>{addLabel}</Tr></button> : null}
        <button className="btn ghost" onClick={() => exportCsv('exams.csv', list.rows.map((exam) => ({ Name: exam.name, Type: exam.exam_type, Class: exam.school_class?.name, Start: day(exam.start_date) })))}><Tr>Export</Tr></button>
      </div>
    }>
      <Tabs tabs={tabs} value={tab} onChange={(id) => setParams(id === 'exams' ? {} : { tab: id })} />

      {tab === 'exams' ? (
        <>
          <div className="card filters">
            <Field label="Search"><Input value={filters.search} onChange={(event) => setFilters({ ...filters, search: event.target.value })} placeholder="Exam name" /></Field>
            <Field label="Class">
              <select value={filters.class_id} onChange={(event) => setFilters({ ...filters, class_id: event.target.value })}>
                <option value=""><Tr>All</Tr></option>{structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Subject">
              <select value={filters.subject_id} onChange={(event) => setFilters({ ...filters, subject_id: event.target.value })}>
                <option value=""><Tr>All</Tr></option>{structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Date"><Input type="date" value={filters.date} onChange={(event) => setFilters({ ...filters, date: event.target.value })} /></Field>
          </div>
          <DataTable
            columns={[
              { key: 'name', label: 'Exam' },
              { key: 'exam_type', label: 'Type', render: (row) => <Tr>{examTypes.find(([value]) => value === row.exam_type)?.[1] || row.exam_type}</Tr> },
              { key: 'class', label: 'Class', render: (row) => <Tr>{`${row.school_class?.name || ''} ${row.section?.name || ''}`.trim()}</Tr> },
              { key: 'start_date', label: 'Date', render: (row) => day(row.start_date) },
              { key: 'published', label: 'Status', render: (row) => <StatusSwitch active={Boolean(row.published)} onChange={() => publish(row)} /> },
              { key: 'actions', label: 'Actions', render: (row) => (
                <RowActions
                  onView={() => setView({ kind: 'exam', ...row })}
                  onEdit={() => setExamForm({ ...blankExam, ...row, class_id: row.class_id ? String(row.class_id) : '', section_id: row.section_id ? String(row.section_id) : '', start_date: day(row.start_date), end_date: day(row.end_date) })}
                  onDelete={() => removeExam(row)}
                />
              ) },
            ]}
            rows={list.rows}
            loading={list.loading}
            emptyTitle="No exams found"
            emptyText="Add an exam from the button above."
            page={list.page}
            lastPage={list.last}
            from={list.from}
            to={list.to}
            total={list.total}
            noun="exams"
            onPage={list.setPage}
          />
        </>
      ) : null}

      {tab === 'schedule' ? (
        <DataTable
          columns={[
            { key: 'exam_name', label: 'Exam' },
            { key: 'subject_name', label: 'Subject' },
            { key: 'exam_date', label: 'Date', render: (row) => day(row.exam_date) },
            { key: 'time', label: 'Time', render: (row) => `${clock(row.start_time)}–${clock(row.end_time)}` },
            { key: 'room', label: 'Room', render: (row) => row.room || '—' },
            { key: 'actions', label: 'Actions', render: (row) => (
              <RowActions
                onView={() => setView({ kind: 'paper', ...row })}
                onEdit={() => setPaperForm({ ...blankPaper, ...row, exam_id: String(row.exam_id), subject_id: String(row.subject_id || row.subject?.id || ''), exam_date: day(row.exam_date), start_time: clock(row.start_time), end_time: clock(row.end_time) })}
                onDelete={() => removePaper(row)}
              />
            ) },
          ]}
          rows={papers}
          loading={list.loading}
          emptyTitle="No papers yet"
          emptyText="Add a paper for an exam."
          page={1}
          lastPage={1}
          from={papers.length ? 1 : 0}
          to={papers.length}
          total={papers.length}
          noun="papers"
          onPage={() => {}}
        />
      ) : null}

      {tab === 'marks' ? (
        <article className="card">
          <h3><Tr>Marks</Tr></h3>
          <p className="hint"><Tr>Enter marks opens a popup. Saving the same student and subject again updates that mark.</Tr></p>
        </article>
      ) : null}

      {tab === 'results' ? (
        <>
          <form className="card filters" onSubmit={loadResults}>
            <Field label="Exam">
              <select value={resultExam} onChange={(event) => setResultExam(event.target.value)} required>
                <option value=""><Tr>Select</Tr></option>
                {list.rows.map((exam) => <option key={exam.id} value={exam.id}><Tr>{exam.name}</Tr></option>)}
              </select>
            </Field>
            <div className="toolbar">
              <button className="btn" type="submit"><Tr>Show</Tr></button>
              <button className="btn ghost" type="button" onClick={() => {
                if (!results?.exam?.id) { toast('Choose an exam and press Show first.', 'err'); return; }
                openPdf(`/api/results?exam_id=${results.exam.id}&format=pdf`).catch(() => toast('Could not open the PDF.', 'err'));
              }}><Tr>Print PDF</Tr></button>
            </div>
          </form>
          <DataTable
            columns={[
              { key: 'name', label: 'Student' },
              { key: 'roll_number', label: 'Roll' },
              { key: 'obtained', label: 'Obtained', render: (row) => `${row.obtained}/${row.total}` },
              { key: 'percentage', label: 'Percentage', render: (row) => `${row.percentage}%` },
              { key: 'grade', label: 'Grade' },
              { key: 'result', label: 'Result', render: (row) => <Badge value={row.result} /> },
              { key: 'actions', label: 'Actions', render: (row) => (
                <div className="row-actions">
                  <RowActions onView={() => setView({ kind: 'result', ...row })} onEdit={() => setMarkForm({ ...blankMark, exam_id: String(results?.exam?.id || ''), student_id: String(row.student_id) })} />
                  <button className="btn ghost" onClick={() => download(`/api/report-cards?student_id=${row.student_id}&exam_id=${results.exam.id}`, `report-${row.roll_number}.pdf`)}><Tr>PDF</Tr></button>
                </div>
              ) },
            ]}
            rows={results?.students || []}
            loading={false}
            emptyTitle="No results"
            emptyText="Choose an exam and press Show."
            page={1}
            lastPage={1}
            from={(results?.students || []).length ? 1 : 0}
            to={(results?.students || []).length}
            total={(results?.students || []).length}
            noun="students"
            onPage={() => {}}
          />
        </>
      ) : null}

      <Modal title={view?.kind === 'exam' ? view.name : view?.kind === 'paper' ? (view.subject_name || 'Paper') : view?.kind === 'result' ? view.name : ''} onClose={() => setView(null)}>
        {view?.kind === 'exam' ? (
          <dl className="meta-list">
            <div><dt><Tr>Type</Tr></dt><dd><Tr>{examTypes.find(([value]) => value === view.exam_type)?.[1] || view.exam_type}</Tr></dd></div>
            <div><dt><Tr>Class</Tr></dt><dd><Tr>{`${view.school_class?.name || ''} ${view.section?.name || ''}`.trim() || '—'}</Tr></dd></div>
            <div><dt><Tr>Starts</Tr></dt><dd>{day(view.start_date) || '—'}</dd></div>
            <div><dt><Tr>Ends</Tr></dt><dd>{day(view.end_date) || '—'}</dd></div>
            <div><dt><Tr>Status</Tr></dt><dd><StatusSwitch active={Boolean(view.published)} onChange={() => publish(view)} /></dd></div>
            <div><dt><Tr>Papers</Tr></dt><dd><Tr>{(view.schedules || []).map((row) => `${row.subject?.name || 'Paper'} ${day(row.exam_date)}`).join(', ') || '—'}</Tr></dd></div>
          </dl>
        ) : null}
        {view?.kind === 'paper' ? (
          <dl className="meta-list">
            <div><dt><Tr>Exam</Tr></dt><dd><Tr>{view.exam_name}</Tr></dd></div>
            <div><dt><Tr>Subject</Tr></dt><dd><Tr>{view.subject_name || '—'}</Tr></dd></div>
            <div><dt><Tr>Date</Tr></dt><dd>{day(view.exam_date)}</dd></div>
            <div><dt><Tr>Time</Tr></dt><dd>{clock(view.start_time)}–{clock(view.end_time)}</dd></div>
            <div><dt><Tr>Room</Tr></dt><dd><Tr>{view.room || '—'}</Tr></dd></div>
          </dl>
        ) : null}
        {view?.kind === 'result' ? (
          <dl className="meta-list">
            <div><dt><Tr>Student</Tr></dt><dd><Tr>{view.name}</Tr></dd></div>
            <div><dt><Tr>Roll</Tr></dt><dd>{view.roll_number || '—'}</dd></div>
            <div><dt><Tr>Score</Tr></dt><dd>{view.obtained}/{view.total}</dd></div>
            <div><dt><Tr>Result</Tr></dt><dd>{view.percentage}% · {view.grade} · <Tr>{view.result}</Tr></dd></div>
            <div><dt><Tr>Subjects</Tr></dt><dd>{(view.subjects || []).map((item) => `${item.subject}: ${item.obtained}/${item.total}`).join(', ') || '—'}</dd></div>
          </dl>
        ) : null}
      </Modal>

      <Modal title={examForm ? (examForm.id ? 'Edit exam' : 'Add exam') : ''} onClose={() => setExamForm(null)}>
        {examForm ? (
          <form className="form-grid" onSubmit={saveExam}>
            <Field label="Name" wide><Input value={examForm.name} onChange={(event) => setExamForm({ ...examForm, name: event.target.value })} required /></Field>
            <Field label="Type">
              <select value={examForm.exam_type} onChange={(event) => setExamForm({ ...examForm, exam_type: event.target.value })}>
                {examTypes.map(([value, label]) => <option key={value} value={value}><Tr>{label}</Tr></option>)}
              </select>
            </Field>
            <Field label="Class">
              <select value={examForm.class_id} onChange={(event) => setExamForm({ ...examForm, class_id: event.target.value, section_id: '' })} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Section">
              <select value={examForm.section_id} onChange={(event) => setExamForm({ ...examForm, section_id: event.target.value })}>
                <option value=""><Tr>All sections</Tr></option>
                {sections.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Start"><Input type="date" value={examForm.start_date} onChange={(event) => setExamForm({ ...examForm, start_date: event.target.value })} /></Field>
            <Field label="End"><Input type="date" value={examForm.end_date} onChange={(event) => setExamForm({ ...examForm, end_date: event.target.value })} /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>

      <Modal title={paperForm ? (paperForm.id ? 'Edit paper' : 'Add paper') : ''} onClose={() => setPaperForm(null)}>
        {paperForm ? (
          <form className="form-grid" onSubmit={savePaper}>
            <Field label="Exam" wide>
              <select value={paperForm.exam_id} onChange={(event) => setPaperForm({ ...paperForm, exam_id: event.target.value })} required>
                <option value=""><Tr>Select</Tr></option>
                {list.rows.map((exam) => <option key={exam.id} value={exam.id}><Tr>{exam.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Subject">
              <select value={paperForm.subject_id} onChange={(event) => setPaperForm({ ...paperForm, subject_id: event.target.value })} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Date"><Input type="date" value={paperForm.exam_date} onChange={(event) => setPaperForm({ ...paperForm, exam_date: event.target.value })} required /></Field>
            <Field label="Start"><Input type="time" value={paperForm.start_time} onChange={(event) => setPaperForm({ ...paperForm, start_time: event.target.value })} required /></Field>
            <Field label="End"><Input type="time" value={paperForm.end_time} onChange={(event) => setPaperForm({ ...paperForm, end_time: event.target.value })} required /></Field>
            <Field label="Room"><Input value={paperForm.room || ''} onChange={(event) => setPaperForm({ ...paperForm, room: event.target.value })} /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>

      <Modal title={markForm ? 'Save marks' : ''} onClose={() => setMarkForm(null)}>
        {markForm ? (
          <form className="form-grid" onSubmit={saveMark}>
            <Field label="Exam" wide>
              <select value={markForm.exam_id} onChange={(event) => setMarkForm({ ...markForm, exam_id: event.target.value, student_id: '' })} required>
                <option value=""><Tr>Select</Tr></option>
                {list.rows.map((exam) => <option key={exam.id} value={exam.id}><Tr>{exam.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Student">
              <select value={markForm.student_id} onChange={(event) => setMarkForm({ ...markForm, student_id: event.target.value })} required>
                <option value=""><Tr>Select</Tr></option>
                {markStudents.map((student) => <option key={student.id} value={student.id}><Tr>{student.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Subject">
              <select value={markForm.subject_id} onChange={(event) => setMarkForm({ ...markForm, subject_id: event.target.value })} required>
                <option value=""><Tr>Select</Tr></option>
                {structure.subjects.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Total marks"><Input type="number" min="1" value={markForm.total_marks} onChange={(event) => setMarkForm({ ...markForm, total_marks: event.target.value })} required /></Field>
            <Field label="Obtained marks"><Input type="number" min="0" value={markForm.obtained_marks} onChange={(event) => setMarkForm({ ...markForm, obtained_marks: event.target.value })} required /></Field>
            <Field label="Remarks" wide><Input value={markForm.remarks || ''} onChange={(event) => setMarkForm({ ...markForm, remarks: event.target.value })} /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}

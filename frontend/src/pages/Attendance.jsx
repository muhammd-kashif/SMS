import { useEffect, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, errorText, exportCsv, openPdf, withQuery } from '../api';
import { useAuth } from '../auth';
import { useI18n } from '../i18n';
import {Textarea, Input,  Tr, Badge, Camera, EmptyState, Field, Loader, Modal, Page, useFeedback } from '../ui';
import { MonthAttendance } from './MonthAttendance';

const QUEUE = 'sms-offline-scans';

function readQueue() {
  return JSON.parse(localStorage.getItem(QUEUE) || '[]');
}

const guidanceCopy = {
  no_face: 'Waiting for face...',
  multiple: 'Please make sure only one person is in front of the scanner.',
  too_far: 'Please move closer.',
  too_close: 'Move slightly back.',
  position: 'Please move your face inside the oval.',
  angle: 'Turn to face the camera.',
  changed: 'Only one person should be visible.',
  invalid: 'Please position your face correctly.',
};

const terminalReasons = new Set(['not_recognized', 'mismatch', 'not_registered']);

export function Scan() {
  const camera = useRef(null);
  const phase = useRef('scan');
  const seq = useRef(0);
  const holdTimer = useRef(null);
  const releaseAt = useRef(0);
  const modeRef = useRef('automatic');
  const personIdRef = useRef('');
  const personTypeRef = useRef('student');
  const [params] = useSearchParams();
  const [health, setHealth] = useState(null);
  const [summary, setSummary] = useState({ present: 0, absent: 0, late: 0, leave: 0 });
  const [mode, setMode] = useState('automatic');
  const [people, setPeople] = useState([]);
  const [personId, setPersonId] = useState('');
  const [current, setCurrent] = useState(null);
  const [failure, setFailure] = useState(null);
  const [last, setLast] = useState(null);
  const [recent, setRecent] = useState([]);
  const [status, setStatus] = useState('Scanner ready — please look at the camera');
  const [hint, setHint] = useState('Position your face inside the oval');
  const [tone, setTone] = useState('ready');
  const [queue, setQueue] = useState(readQueue());
  modeRef.current = mode;
  personIdRef.current = personId;
  personTypeRef.current = params.get('type') === 'teacher' ? 'teacher' : 'student';

  function localToday() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  }

  function loadBoard(seedRecent) {
    api(`/api/attendance?person_type=student&date=${localToday()}`)
      .then((data) => {
        setSummary(data.summary || { present: 0, absent: 0, late: 0, leave: 0 });
        if (!seedRecent) return;
        setRecent((data.data || []).slice(0, 8).map((row) => ({
          key: `${row.person_type}-${row.person_id}`,
          name: row.name,
          code: row.code,
          time: row.check_in,
          status: row.status,
          kind: 'marked',
        })));
      })
      .catch(() => {});
  }

  function remember(entry) {
    setRecent((list) => [entry, ...list.filter((item) => item.key !== entry.key)].slice(0, 8));
  }

  function finish(token) {
    if (token !== seq.current) return;
    if (holdTimer.current) clearTimeout(holdTimer.current);
    phase.current = 'hold';
    holdTimer.current = setTimeout(() => {
      setCurrent(null);
      setFailure(null);
      phase.current = 'release';
      releaseAt.current = Date.now();
      setTone('ready');
      setStatus('Waiting for the next person...');
      setHint('Position your face inside the oval');
    }, 4500);
  }

  useEffect(() => {
    api('/api/face/health').then(setHealth).catch((err) => setHealth({ ok: false, message: errorText(err) }));
    loadBoard(true);
  }, []);

  useEffect(() => {
    if (mode !== 'verify') return undefined;
    const path = personTypeRef.current === 'teacher' ? '/api/teachers?all=1' : '/api/students?all=1';
    api(path).then((data) => setPeople(data.data || [])).catch(() => {});
    return undefined;
  }, [mode]);

  useEffect(() => {
    let stopped = false;

    async function tick() {
      if (stopped) return;
      const image = camera.current?.capture();
      if (!image || phase.current === 'hold' || phase.current === 'busy') return;

      if (phase.current === 'release') {
        if (Date.now() - releaseAt.current > 12000) {
          phase.current = 'scan';
          setStatus('Waiting for face...');
          return;
        }
        try {
          const look = await api('/api/face/look', { method: 'POST', body: { image } });
          if (stopped || phase.current !== 'release') return;
          if (!look.present || look.reason === 'no_face') {
            phase.current = 'scan';
            setStatus('Waiting for face...');
            setHint('Position your face inside the oval');
          }
        } catch {
          // The timeout above resumes scanning if the camera check cannot run.
        }
        return;
      }

      if (modeRef.current === 'verify' && !personIdRef.current) {
        setStatus('Select the person to verify. A name alone does not mark attendance.');
        setTone('warn');
        return;
      }

      const token = ++seq.current;
      phase.current = 'busy';
      setCurrent(null);
      setFailure(null);
      const slow = setTimeout(() => {
        if (token === seq.current) {
          setStatus('Verifying identity...');
          setHint('Face detected. Verifying...');
          setTone('ready');
        }
      }, 350);
      const payload = { image, client_uuid: crypto.randomUUID() };
      if (modeRef.current === 'verify') {
        payload.person_type = personTypeRef.current;
        payload.expected_person_id = Number(personIdRef.current);
      }
      try {
        const data = await api('/api/face/scan', { method: 'POST', body: payload });
        clearTimeout(slow);
        if (stopped || token !== seq.current) return;
        accept(token, data);
      } catch (err) {
        clearTimeout(slow);
        if (stopped || token !== seq.current) return;
        accept(token, err.data?.reason ? err.data : { failed: true, reason: 'invalid', message: errorText(err) });
      }
    }

    function accept(token, data) {
      if (data?.verified && data.person) {
        setFailure(null);
        setCurrent(data);
        setTone('ok');
        setStatus(data.already_marked ? 'Attendance already marked' : 'Face verified');
        setHint(data.already_marked ? 'Attendance already marked' : 'Face verified');
        const person = data.person;
        const entry = {
          key: `${data.person_type}-${data.person_id}`,
          name: person.name,
          code: person.student_code || person.code,
          time: person.check_in,
          status: person.status,
          kind: data.already_marked ? 'already' : 'marked',
        };
        setLast(entry);
        remember(entry);
        if (!data.already_marked) loadBoard(false);
        finish(token);
        return;
      }

      const reason = data?.reason || 'invalid';
      if (!terminalReasons.has(reason)) {
        phase.current = 'scan';
        setCurrent(null);
        setFailure(null);
        setTone(reason === 'no_face' ? 'ready' : 'warn');
        setStatus(guidanceCopy[reason] || data?.message || 'Waiting for face...');
        setHint(reason === 'no_face' ? 'Position your face inside the oval' : (guidanceCopy[reason] || 'Position your face inside the oval'));
        return;
      }

      setCurrent(null);
      setFailure({
        reason,
        message: reason === 'not_recognized'
          ? 'No registered student or teacher was found for this face.'
          : (data.message || 'Face could not be verified.'),
      });
      setTone('bad');
      setStatus(reason === 'mismatch' ? 'Face mismatch' : (reason === 'not_registered' ? 'Face not registered' : 'Face not recognized'));
      setHint(reason === 'mismatch' ? 'Face mismatch' : 'Face not recognized');
      if (reason === 'not_recognized') {
        remember({
          key: `unknown-${Date.now()}`,
          name: 'Unknown',
          code: '',
          time: 'Now',
          status: 'Not recognized',
          kind: 'unknown',
        });
      }
      finish(token);
    }

    const timer = setInterval(() => { tick(); }, 1100);
    return () => {
      stopped = true;
      seq.current += 1;
      clearInterval(timer);
      if (holdTimer.current) clearTimeout(holdTimer.current);
    };
  }, []);

  async function sync() {
    const items = readQueue();
    if (!items.length) return;
    try {
      await api('/api/face/sync', { method: 'POST', body: { items } });
      localStorage.removeItem(QUEUE);
      setQueue([]);
      loadBoard(false);
    } catch (err) {
      setStatus(errorText(err));
      setTone('bad');
    }
  }

  const person = current?.person;
  return (
    <Page title="Face attendance scanner" text={health?.ok ? 'Scanner ready. The person in front of the camera is identified automatically.' : (health?.message || 'Checking the face service…')}>
      <div className="scan-layout scanner">
        <article className="card scanner-stage">
          <Camera ref={camera} guide hint={hint} />
          <p className={`scanner-status ${tone}`}><Tr>{status}</Tr></p>
        </article>
        <div className="scanner-side">
          <article className="card scan-hero">
            {person ? (
              <>
                <h2><Tr>{current.already_marked ? 'Attendance already marked' : 'Attendance marked'}</Tr></h2>
                {(person.face_photo_url || person.photo_url) ? <img className="avatar" src={person.face_photo_url || person.photo_url} alt="" /> : <div className="avatar">{person.name.slice(0, 1)}</div>}
                <p><Tr>{person.name}</Tr></p>
                {person.student_code ? <p><Tr>Student ID:</Tr> {person.student_code}</p> : <p>{person.code}{person.designation ? <> · <Tr>{person.designation}</Tr></> : null}</p>}
                {person.class ? <p><Tr>Class:</Tr> <Tr>{person.class}</Tr>{person.section ? ` · ${person.section}` : ''}</p> : null}
                <p><Tr>Face: verified</Tr></p>
                <p><Tr>{current.already_marked ? 'First check-in' : 'Time'}</Tr>: {person.check_in || '—'}</p>
                <h3><Badge value={person.status} /> {person.timing || current.timing}</h3>
                {current.already_marked ? <p><Tr>No duplicate attendance created.</Tr></p> : null}
                {person.late_after || current.late_after ? <p><Tr>Late after:</Tr> {person.late_after || current.late_after}</p> : null}
              </>
            ) : failure ? (
              <>
                <h2><Tr>{failure.reason === 'mismatch' ? 'Face mismatch' : 'Face not recognized'}</Tr></h2>
                <p><Tr>{failure.message}</Tr></p>
                <p><Tr>Attendance has not been marked.</Tr></p>
              </>
            ) : (
              <p><Tr>Waiting for a face. One person only, inside the oval.</Tr></p>
            )}
          </article>
          <article className="card">
            <h3><Tr>Today's attendance</Tr></h3>
            <div className="kpis">
              <div><span><Tr>Students</Tr></span><strong>{health?.students_active ?? 0}</strong></div>
              <div className="present"><span><Tr>Present</Tr></span><strong>{summary.present || 0}</strong></div>
              <div className="late"><span><Tr>Late</Tr></span><strong>{summary.late || 0}</strong></div>
              <div className="absent"><span><Tr>Absent</Tr></span><strong>{summary.absent || 0}</strong></div>
              <div className="leave"><span><Tr>Leave</Tr></span><strong>{summary.leave || 0}</strong></div>
            </div>
            <h3><Tr>Last scanned</Tr></h3>
            {last ? <p>{last.time || '—'} · <Tr>{last.name}</Tr>{last.code ? ` · ${last.code}` : ''} · <Tr>{last.status}</Tr></p> : <p className="hint"><Tr>No successful scan yet.</Tr></p>}
          </article>
          <article className="card">
            <h3><Tr>Recent scans</Tr></h3>
            {recent.length === 0 ? <p className="hint"><Tr>Scans appear here after someone steps up.</Tr></p> : recent.map((item) => (
              <div className="recent-scan" key={item.key}>
                <span>{item.time || '—'}</span>
                <strong><Tr>{item.name}</Tr></strong>
                <Badge value={item.kind === 'unknown' ? 'Not recognized' : item.status} />
              </div>
            ))}
            {queue.length ? <button className="btn ghost" type="button" onClick={sync}><Tr>Sync saved scans</Tr> ({queue.length})</button> : null}
          </article>
          <article className="card form-grid">
            <Field label="Scanner mode">
              <select value={mode} onChange={(event) => { setMode(event.target.value); setPersonId(''); setCurrent(null); setFailure(null); }}>
                <option value="automatic"><Tr>Automatic — identify whoever is present</Tr></option>
                <option value="verify"><Tr>Verify one selected person</Tr></option>
              </select>
            </Field>
            {mode === 'verify' ? (
              <Field label="Expected person">
                <select value={personId} onChange={(event) => setPersonId(event.target.value)}>
                  <option value=""><Tr>Select</Tr></option>
                  {people.map((personOption) => (
                    <option key={personOption.id} value={personOption.id}>
                      <Tr>{personOption.name}</Tr> · {personOption.student_code || personOption.employee_code}
                      {personOption.face_registered ? '' : ' · face not registered'}
                    </option>
                  ))}
                </select>
              </Field>
            ) : null}
          </article>
        </div>
      </div>
    </Page>
  );
}

const captureSteps = ['Look straight', 'Turn slightly left', 'Turn slightly right', 'Tilt slightly up', 'Tilt slightly down'];

function noseShift(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return 999;
  return Math.max(Math.abs(a[0] - b[0]), Math.abs(a[1] - b[1]));
}

export function FaceRegister() {
  const camera = useRef(null);
  const { toast } = useFeedback();
  const { user } = useAuth();
  const [params] = useSearchParams();
  const phase = useRef('scan');
  const samplesRef = useRef([]);
  const noseRef = useRef(null);
  const personRef = useRef({ type: params.get('type') || 'student', id: params.get('id') || '' });
  const blockedRef = useRef(false);
  const [people, setPeople] = useState([]);
  const [personType, setPersonType] = useState(params.get('type') || 'student');
  const [personId, setPersonId] = useState(params.get('id') || '');
  const [samples, setSamples] = useState([]);
  const [status, setStatus] = useState('Select the student or teacher. Registration starts automatically.');
  const [hint, setHint] = useState('Position your face inside the oval');
  const [tone, setTone] = useState('ready');
  const [error, setError] = useState('');
  const selected = people.find((person) => String(person.id) === String(personId));
  personRef.current = { type: personType, id: personId };
  blockedRef.current = Boolean(selected?.face_registered && user?.role !== 'admin');

  function loadPeople(type = personType) {
    const path = type === 'teacher' ? '/api/teachers?all=1' : '/api/students?all=1';
    api(path).then((data) => setPeople(data.data || data)).catch(() => {});
  }

  function clearSamples() {
    samplesRef.current = [];
    noseRef.current = null;
    setSamples([]);
  }

  useEffect(() => { loadPeople(personType); }, [personType]);

  useEffect(() => {
    let stopped = false;

    async function tick() {
      if (stopped || phase.current === 'busy' || phase.current === 'save' || phase.current === 'done' || phase.current === 'confirm') return;
      const person = personRef.current;
      if (!person.id) {
        setStatus('Select the student or teacher, then capture five views and press save.');
        setHint('Position your face inside the oval');
        setTone('ready');
        return;
      }
      if (blockedRef.current) {
        setStatus('Only an administrator can replace a face that is already registered.');
        setTone('warn');
        return;
      }
      const image = camera.current?.capture();
      if (!image) return;
      phase.current = 'busy';
      try {
        const look = await api('/api/face/look', { method: 'POST', body: { image } });
        if (stopped || personRef.current.id !== person.id || personRef.current.type !== person.type) {
          phase.current = 'scan';
          return;
        }
        if (!look.present || look.reason !== 'face') {
          phase.current = 'scan';
          const reason = look.reason || 'invalid';
          setTone(reason === 'no_face' ? 'ready' : 'warn');
          setStatus(guidanceCopy[reason] || look.message || 'Waiting for face...');
          setHint(reason === 'no_face' ? captureSteps[samplesRef.current.length] || 'Position your face inside the oval' : (guidanceCopy[reason] || 'Position your face inside the oval'));
          return;
        }
        const step = samplesRef.current.length;
        if (step > 0 && noseShift(look.nose, noseRef.current) < 14) {
          phase.current = 'scan';
          setTone('ready');
          setStatus(captureSteps[step]);
          setHint(captureSteps[step]);
          return;
        }
        const next = [...samplesRef.current, image];
        samplesRef.current = next;
        noseRef.current = look.nose;
        setSamples(next);
        setError('');
        if (next.length < captureSteps.length) {
          phase.current = 'scan';
          setTone('ok');
          setStatus(`Sample ${next.length} saved. ${captureSteps[next.length]}`);
          setHint(captureSteps[next.length]);
          return;
        }
        phase.current = 'confirm';
        setTone('ok');
        setStatus('Five samples captured. Press save to register this face.');
        setHint('Press save to register this face');
        return;
      } catch (err) {
        if (stopped) return;
        clearSamples();
        phase.current = err.status === 403 ? 'done' : 'scan';
        setTone('bad');
        setError(errorText(err));
        setStatus(errorText(err));
        setHint('Position your face inside the oval');
      }
    }

    const timer = setInterval(() => { tick(); }, 1100);
    return () => {
      stopped = true;
      clearInterval(timer);
    };
  }, [toast]);

  async function saveFace() {
    const person = personRef.current;
    const next = samplesRef.current;
    if (!person.id || next.length < captureSteps.length || phase.current !== 'confirm') return;
    phase.current = 'save';
    setError('');
    setTone('ready');
    setStatus('Checking the face and saving...');
    try {
      const data = await api('/api/face/register', {
        method: 'POST',
        body: { person_type: person.type, person_id: Number(person.id), images: next },
      });
      clearSamples();
      phase.current = 'done';
      setTone('ok');
      setStatus(data.message || 'Face registered.');
      setHint('Face registered');
      toast(data.message || 'Face registered successfully.');
      loadPeople(person.type);
    } catch (err) {
      phase.current = err.status === 403 ? 'done' : 'confirm';
      setTone('bad');
      setError(errorText(err));
      setStatus(errorText(err));
    }
  }

  function chooseType(type) {
    setPersonType(type);
    setPersonId('');
    setError('');
    clearSamples();
    phase.current = 'scan';
    setStatus('Select the student or teacher, then capture five views and press save.');
  }

  function choosePerson(id) {
    setPersonId(id);
    setError('');
    clearSamples();
    phase.current = 'scan';
    setStatus(id ? 'Scanner ready — please look at the camera' : 'Select the student or teacher, then capture five views and press save.');
    setHint(captureSteps[0]);
  }

  function startAgain() {
    setError('');
    clearSamples();
    phase.current = 'scan';
    setTone('ready');
    setStatus('Scanner ready — please look at the camera');
    setHint(captureSteps[0]);
  }

  const step = Math.min(samples.length, captureSteps.length - 1);
  return (
    <Page title="Face registration" text="Capture five views of the selected person, then press save. Attendance marks only the person whose saved face matches.">
      <div className="scan-layout scanner">
        <article className="card scanner-stage">
          <Camera ref={camera} guide hint={hint} />
          <p className={`scanner-status ${tone}`}><Tr>{status}</Tr></p>
        </article>
        <article className="card form-grid">
          <Field label="Person">
            <select value={personType} onChange={(event) => chooseType(event.target.value)}>
              <option value="student"><Tr>Student</Tr></option>
              <option value="teacher"><Tr>Teacher</Tr></option>
            </select>
          </Field>
          <Field label="Record">
            <select value={personId} onChange={(event) => choosePerson(event.target.value)}>
              <option value=""><Tr>Select</Tr></option>
              {people.map((person) => <option key={person.id} value={person.id}><Tr>{person.name}</Tr> · {person.roll_number || person.employee_code}<Tr>{person.face_registered ? ' · registered' : ' · not registered'}</Tr></option>)}
            </select>
          </Field>
          <p className="wide"><Tr>Face status:</Tr> {selected ? <Tr>{selected.face_registered ? 'Registered' : 'Not registered'}</Tr> : '—'}</p>
          <div className="sample-steps wide">
            {captureSteps.map((label, index) => (
              <span key={label} className={index < samples.length ? 'on' : index === step && personId ? 'now' : ''}>{index + 1}. <Tr>{label}</Tr></span>
            ))}
          </div>
          <p className="wide"><Tr>{`Sample ${Math.min(samples.length + 1, captureSteps.length)} of ${captureSteps.length}`}</Tr></p>
          <button className="btn" type="button" onClick={saveFace} disabled={samples.length < captureSteps.length}><Tr>Save this face</Tr></button>
          <button className="btn ghost" type="button" onClick={startAgain}><Tr>Start again</Tr></button>
          {error ? <p className="error wide"><Tr>{error}</Tr></p> : null}
          <p className="hint wide"><Tr>Keep one face inside the oval and follow the five directions. A still photo is rejected because the head must move between samples. Only an administrator can replace a registered face.</Tr></p>
        </article>
      </div>
    </Page>
  );
}

function markSymbol(status) {
  if (status === 'present') return '✓';
  if (status === 'absent') return '✕';
  if (status === 'late') return '◷';
  if (status === 'leave') return 'L';
  return '–';
}

function tallyPerson(days = {}) {
  const rows = Object.values(days);
  const present = rows.filter((row) => row.status === 'present').length;
  const absent = rows.filter((row) => row.status === 'absent').length;
  const late = rows.filter((row) => row.status === 'late').length;
  const leave = rows.filter((row) => row.status === 'leave').length;
  const marked = present + absent + late + leave;
  return { present, absent, late, leave, percent: marked ? (((present + late) / marked) * 100).toFixed(0) : '0' };
}

export function AttendanceList() {
  const { toast } = useFeedback();
  const { tx } = useI18n();
  const [params] = useSearchParams();
  const type = params.get('type') === 'teacher' ? 'teacher' : 'student';
  const today = new Date();
  const [month, setMonth] = useState(today.getMonth() + 1);
  const [year, setYear] = useState(today.getFullYear());
  const [classId, setClassId] = useState('');
  const [sectionId, setSectionId] = useState('');
  const [search, setSearch] = useState('');
  const [classes, setClasses] = useState([]);
  const [people, setPeople] = useState([]);
  const [roster, setRoster] = useState([]);
  const [marks, setMarks] = useState({});
  const [gridLoading, setGridLoading] = useState(true);
  const [revision, setRevision] = useState(0);
  const [editing, setEditing] = useState(null);
  const [adding, setAdding] = useState(false);
  const [view, setView] = useState(null);
  const sections = classes.find((item) => String(item.id) === String(classId))?.sections || [];
  const dayCount = new Date(year, month, 0).getDate();
  const monthName = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];

  useEffect(() => {
    api('/api/structure').then((data) => setClasses(data.classes || [])).catch(() => {});
    api(type === 'teacher' ? '/api/teachers?all=1' : '/api/students?all=1').then((data) => setPeople(data.data || [])).catch(() => {});
  }, [type]);

  useEffect(() => {
    let ignore = false;
    const from = `${year}-${String(month).padStart(2, '0')}-01`;
    const to = `${year}-${String(month).padStart(2, '0')}-${String(dayCount).padStart(2, '0')}`;
    const attendanceQuery = new URLSearchParams({ person_type: type, from, to, all: '1' });
    const peopleQuery = new URLSearchParams({ all: '1', status: 'active' });
    if (type === 'student' && classId) {
      attendanceQuery.set('class_id', classId);
      peopleQuery.set('class_id', classId);
    }
    if (type === 'student' && sectionId) {
      attendanceQuery.set('section_id', sectionId);
      peopleQuery.set('section_id', sectionId);
    }
    setGridLoading(true);
    Promise.all([
      api(type === 'teacher' ? '/api/teachers?all=1' : `/api/students?${peopleQuery}`),
      api(`/api/attendance?${attendanceQuery}`),
    ]).then(([peopleData, attendanceData]) => {
      if (ignore) return;
      const next = {};
      (attendanceData.data || []).forEach((row) => {
        const day = Number(String(row.date).slice(8, 10));
        if (!next[row.person_id]) next[row.person_id] = {};
        next[row.person_id][day] = row;
      });
      setRoster(peopleData.data || []);
      setMarks(next);
    }).catch(() => {
      if (!ignore) { setRoster([]); setMarks({}); }
    }).finally(() => { if (!ignore) setGridLoading(false); });
    return () => { ignore = true; };
  }, [type, month, year, dayCount, classId, sectionId, editing, adding, revision]);

  async function saveEdit(event) {
    event.preventDefault();
    const form = new FormData(event.target);
    try {
      await api('/api/attendance/manual', {
        method: 'POST',
        body: {
          person_type: type,
          person_id: Number(editing.person_id),
          date: editing.date,
          time: form.get('time') || undefined,
          status: form.get('status'),
          notes: form.get('notes'),
        },
      });
      toast('Attendance updated. The change is in the audit log.');
      setEditing(null);
    } catch (err) {
      toast(errorText(err), 'err');
    }
  }

  async function addMark(event) {
    event.preventDefault();
    const form = Object.fromEntries(new FormData(event.target).entries());
    try {
      await api('/api/attendance/manual', { method: 'POST', body: { ...form, person_type: type, person_id: Number(form.person_id) } });
      toast('Attendance saved.');
      setAdding(false);
    } catch (err) {
      toast(errorText(err), 'err');
    }
  }

  const shown = roster.filter((person) => {
    const text = `${person.name || ''} ${person.student_code || ''} ${person.roll_number || ''} ${person.employee_code || ''}`.toLowerCase();
    return text.includes(search.trim().toLowerCase());
  });
  const totals = shown.reduce((sum, person) => {
    const tally = tallyPerson(marks[person.id]);
    sum.present += tally.present;
    sum.absent += tally.absent;
    sum.late += tally.late;
    sum.leave += tally.leave;
    sum.base += tally.present + tally.absent + tally.late + tally.leave;
    return sum;
  }, { present: 0, absent: 0, late: 0, leave: 0, base: 0 });
  totals.percent = totals.base ? (((totals.present + totals.late) / totals.base) * 100).toFixed(0) : '0';

  return (
    <Page title={type === 'teacher' ? 'Teacher attendance' : 'Student attendance'} text={`${tx(monthName)} ${year}. ${tx('One record per person each day. Corrections are audited.')}`} actions={
      <div className="toolbar">
        <button className="btn" onClick={() => setAdding(true)}><Tr>Add record</Tr></button>
        <button className="btn ghost" onClick={() => exportCsv(`${type}-attendance-${year}-${month}.csv`, shown.map((person) => {
          const tally = tallyPerson(marks[person.id]);
          return { Name: person.name, ID: person.student_code || person.employee_code, Present: tally.present, Absent: tally.absent, Late: tally.late, Leave: tally.leave, 'Attendance %': tally.percent };
        }))}><Tr>Export Excel</Tr></button>
        <button className="btn ghost" onClick={() => openPdf(withQuery('/api/attendance', { person_type: type, from: `${year}-${String(month).padStart(2, '0')}-01`, to: `${year}-${String(month).padStart(2, '0')}-${String(dayCount).padStart(2, '0')}`, class_id: classId, section_id: sectionId, format: 'pdf', layout: 'month' })).catch(() => toast('Could not open the PDF.', 'err'))}><Tr>Export PDF</Tr></button>
        {type === 'student' ? <button className="btn ghost" onClick={async () => {
          const data = await api('/api/attendance/close-day', { method: 'POST', body: { date: new Date().toISOString().slice(0, 10), class_id: classId || null, section_id: sectionId || null } });
          toast(`${data.created} unmarked students recorded.`);
          setRevision((value) => value + 1);
        }}><Tr>Close day</Tr></button> : null}
      </div>
    }>
      <div className="card filters">
        <Field label="Search"><Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder={type === 'teacher' ? 'Search teacher by name or ID' : 'Search student by name, ID or roll number'} /></Field>
        {type === 'student' ? (
          <>
            <Field label="Class">
              <select value={classId} onChange={(event) => { setClassId(event.target.value); setSectionId(''); }}>
                <option value=""><Tr>All</Tr></option>{classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Section">
              <select value={sectionId} onChange={(event) => setSectionId(event.target.value)}>
                <option value=""><Tr>All</Tr></option>{sections.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
              </select>
            </Field>
          </>
        ) : null}
        <Field label="Month">
          <select value={month} onChange={(event) => setMonth(Number(event.target.value))}>
            {['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'].map((name, index) => <option key={name} value={index + 1}><Tr>{name}</Tr></option>)}
          </select>
        </Field>
        <Field label="Year"><Input type="number" min="2020" max="2100" value={year} onChange={(event) => setYear(Number(event.target.value) || year)} /></Field>
      </div>
      <div className="kpis">
        <div className="kpi present"><span><Tr>Present</Tr></span><strong>{totals.present}</strong></div>
        <div className="kpi absent"><span><Tr>Absent</Tr></span><strong>{totals.absent}</strong></div>
        <div className="kpi late"><span><Tr>Late</Tr></span><strong>{totals.late}</strong></div>
        <div className="kpi percent"><span><Tr>Attendance</Tr></span><strong>{totals.percent}%</strong></div>
      </div>
      <p className="legend"><span><Tr>✓ Present</Tr></span><span><Tr>✕ Absent</Tr></span><span><Tr>◷ Late</Tr></span><span><Tr>L Leave</Tr></span><span><Tr>– No class</Tr></span></p>
      {gridLoading ? <Loader /> : shown.length === 0 ? <EmptyState title="No attendance records found" text="Try another month, class, or section." /> : (
        <div className="month-wrap">
          <table className="month-grid">
            <thead>
              <tr>
                <th className="who">{type === 'teacher' ? 'Teacher' : 'Student'}</th>
                {Array.from({ length: dayCount }, (_, index) => <th key={index + 1}>{index + 1}</th>)}
                <th className="pct">%</th>
              </tr>
            </thead>
            <tbody>
              {shown.map((person) => {
                const tally = tallyPerson(marks[person.id]);
                return (
                  <tr key={person.id}>
                    <td className="who"><strong><Tr>{person.name}</Tr></strong><div className="hint">{person.student_code || person.employee_code}</div></td>
                    {Array.from({ length: dayCount }, (_, index) => {
                      const row = marks[person.id]?.[index + 1];
                      const symbol = markSymbol(row?.status);
                      return (
                        <td key={index + 1}>
                          <button type="button" className={row ? `mark-cell ${row.status}` : 'mark-cell empty'} onClick={() => row && setView(row)}>{symbol}</button>
                        </td>
                      );
                    })}
                    <td className={`pct ${Number(tally.percent) >= 75 ? 'good' : 'low'}`}><span>{tally.percent}%</span></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      <Modal title={adding ? 'Add attendance' : ''} onClose={() => setAdding(false)}>
        {adding ? (
          <form className="form-grid" onSubmit={addMark}>
            <Field label="Person" wide>
              <select name="person_id" required>
                <option value=""><Tr>Select</Tr></option>
                {people.map((person) => <option key={person.id} value={person.id}><Tr>{person.name}</Tr></option>)}
              </select>
            </Field>
            <Field label="Date"><Input name="date" type="date" defaultValue={new Date().toISOString().slice(0, 10)} required /></Field>
            <Field label="Status">
              <select name="status" defaultValue="present">
                <option value="present"><Tr>Present</Tr></option><option value="late"><Tr>Late</Tr></option><option value="absent"><Tr>Absent</Tr></option><option value="leave"><Tr>Leave</Tr></option>
              </select>
            </Field>
            <Field label="Time"><Input name="time" type="time" defaultValue="08:05" /></Field>
            <Field label="Reason" wide><Input name="notes" placeholder="Why this record is being added" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      <Modal title={view ? view.name : ''} onClose={() => setView(null)}>
        {view ? (
          <>
            <dl className="meta-list">
              <div><dt><Tr>Name</Tr></dt><dd><Tr>{view.name}</Tr></dd></div>
              <div><dt><Tr>Class</Tr></dt><dd>{`${view.class_name || ''} ${view.section_name || ''}`.trim() || '—'}</dd></div>
              <div><dt><Tr>Date</Tr></dt><dd>{view.date}</dd></div>
              <div><dt><Tr>Status</Tr></dt><dd><Badge value={view.status} /></dd></div>
              <div><dt><Tr>Time</Tr></dt><dd>{view.check_in || '—'}</dd></div>
              <div><dt><Tr>Source</Tr></dt><dd><Tr>{view.source || '—'}</Tr></dd></div>
              <div><dt><Tr>Notes</Tr></dt><dd>{view.notes || '—'}</dd></div>
            </dl>
            <button className="btn" type="button" onClick={() => { setEditing(view); setView(null); }}><Tr>Correct attendance</Tr></button>
          </>
        ) : null}
      </Modal>
      <Modal title={editing ? 'Change attendance' : ''} onClose={() => setEditing(null)}>
        {editing ? (
          <form className="form-grid" onSubmit={saveEdit}>
            <p className="wide">Current status: <Badge value={editing.status} /></p>
            <Field label="Change to">
              <select name="status" defaultValue={editing.status}>
                <option value="present"><Tr>Present</Tr></option><option value="absent"><Tr>Absent</Tr></option><option value="late"><Tr>Late</Tr></option><option value="leave"><Tr>Leave</Tr></option>
              </select>
            </Field>
            <Field label="Time"><Input name="time" type="time" /></Field>
            <Field label="Reason" wide><Textarea name="notes" defaultValue={editing.notes || ''} required placeholder="Medical issue with recognition device" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}

export function MyAttendance() {
  const { user } = useAuth();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api('/api/attendance?person_type=teacher&all=1&mine=1')
      .then((data) => setRows(data.data || []))
      .catch(() => setRows([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <Page title="My attendance" text="Your own monthly register.">
      <MonthAttendance personLabel="Teacher" name={user?.name} code="Teacher" rows={rows} loading={loading} />
    </Page>
  );
}

import { useMemo, useState } from 'react';
import {Input,  Tr, Badge, Field, Loader, Modal } from '../ui';

const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

function markSymbol(status) {
  if (status === 'present') return '✓';
  if (status === 'absent') return '✕';
  if (status === 'late') return '◷';
  if (status === 'leave') return 'L';
  return '–';
}

function tallyRows(rows) {
  const present = rows.filter((row) => row.status === 'present').length;
  const absent = rows.filter((row) => row.status === 'absent').length;
  const late = rows.filter((row) => row.status === 'late').length;
  const leave = rows.filter((row) => row.status === 'leave').length;
  const marked = present + absent + late + leave;
  return { present, absent, late, leave, percent: marked ? Math.round(((present + late) / marked) * 100) : 0 };
}

export function MonthAttendance({ name, code, rows = [], loading = false, personLabel = 'Student' }) {
  const today = new Date();
  const [month, setMonth] = useState(today.getMonth() + 1);
  const [year, setYear] = useState(today.getFullYear());
  const [picked, setPicked] = useState(null);
  const dayCount = new Date(year, month, 0).getDate();
  const monthKey = `${year}-${String(month).padStart(2, '0')}`;
  const monthRows = useMemo(
    () => rows.filter((row) => String(row.date || '').startsWith(monthKey)),
    [rows, monthKey],
  );
  const byDay = useMemo(() => {
    const next = {};
    monthRows.forEach((row) => {
      next[Number(String(row.date).slice(8, 10))] = row;
    });
    return next;
  }, [monthRows]);
  const tally = tallyRows(monthRows);

  return (
    <>
      <div className="card filters">
        <Field label="Month">
          <select value={month} onChange={(event) => { setMonth(Number(event.target.value)); setPicked(null); }}>
            {months.map((label, index) => <option key={label} value={index + 1}><Tr>{label}</Tr></option>)}
          </select>
        </Field>
        <Field label="Year">
          <Input type="number" min="2020" max="2100" value={year} onChange={(event) => setYear(Number(event.target.value) || year)} />
        </Field>
      </div>
      <div className="kpis">
        <div className="kpi present"><span><Tr>Present</Tr></span><strong>{tally.present}</strong></div>
        <div className="kpi absent"><span><Tr>Absent</Tr></span><strong>{tally.absent}</strong></div>
        <div className="kpi late"><span><Tr>Late</Tr></span><strong>{tally.late}</strong></div>
        <div className="kpi leave"><span><Tr>Leave</Tr></span><strong>{tally.leave}</strong></div>
        <div className="kpi percent"><span><Tr>Attendance</Tr></span><strong>{tally.percent}%</strong></div>
      </div>
      <p className="legend"><span><Tr>✓ Present</Tr></span><span><Tr>✕ Absent</Tr></span><span><Tr>◷ Late</Tr></span><span><Tr>L Leave</Tr></span><span><Tr>– No class</Tr></span></p>
      {loading ? <Loader /> : (
        <div className="month-wrap person-month">
          <table className="month-grid">
            <thead>
              <tr>
                <th className="who"><Tr>{personLabel}</Tr></th>
                {Array.from({ length: dayCount }, (_, index) => <th key={index + 1}>{index + 1}</th>)}
                <th className="pct">%</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td className="who"><strong><Tr>{name || '—'}</Tr></strong>{code ? <div className="hint"><Tr>{code}</Tr></div> : null}</td>
                {Array.from({ length: dayCount }, (_, index) => {
                  const row = byDay[index + 1];
                  return (
                    <td key={index + 1}>
                      <button type="button" className={row ? `mark-cell ${row.status}` : 'mark-cell empty'} onClick={() => row && setPicked(row)}>{markSymbol(row?.status)}</button>
                    </td>
                  );
                })}
                <td className={`pct ${tally.percent >= 75 ? 'good' : 'low'}`}><span>{tally.percent}%</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      )}
      <Modal title={picked ? picked.date : ''} onClose={() => setPicked(null)}>
        {picked ? (
          <dl className="meta-list">
            <div><dt><Tr>Date</Tr></dt><dd>{picked.date}</dd></div>
            <div><dt><Tr>Status</Tr></dt><dd><Badge value={picked.status} /></dd></div>
            <div><dt><Tr>Check-in</Tr></dt><dd>{picked.check_in || '—'}</dd></div>
            <div><dt><Tr>Method</Tr></dt><dd><Tr>{picked.source || '—'}</Tr></dd></div>
            {picked.notes ? <div><dt><Tr>Notes</Tr></dt><dd>{picked.notes}</dd></div> : null}
          </dl>
        ) : null}
      </Modal>
    </>
  );
}

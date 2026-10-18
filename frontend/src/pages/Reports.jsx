import { useState } from 'react';
import { api, download, openPdf, withQuery } from '../api';
import {Input,  Tr, Field, Loader, Page } from '../ui';

const types = [
  ['students', 'Student list'],
  ['attendance', 'Attendance'],
  ['fees', 'Fee collection'],
  ['payments', 'Payment history'],
  ['defaulters', 'Defaulters'],
  ['exams', 'Exam schedule'],
  ['leaves', 'Leaves'],
];

export default function Reports() {
  const [type, setType] = useState('students');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);

  async function load(event) {
    event?.preventDefault();
    setLoading(true);
    const query = new URLSearchParams({ type });
    if (from) query.set('from', from);
    if (to) query.set('to', to);
    const data = await api(`/api/reports?${query}`);
    setRows(data.rows || []);
    setLoading(false);
  }

  const columns = rows[0] ? Object.keys(rows[0]) : [];
  return (
    <Page title="Reports" actions={<button className="btn" onClick={() => download(`/api/reports?type=${type}&format=csv${from ? `&from=${from}` : ''}${to ? `&to=${to}` : ''}`, `${type}-report.csv`)}><Tr>Excel</Tr></button>}>
      <form className="card filters" onSubmit={load}>
        <Field label="Report">
          <select value={type} onChange={(event) => setType(event.target.value)}>
            {types.map(([value, label]) => <option key={value} value={value}><Tr>{label}</Tr></option>)}
          </select>
        </Field>
        <Field label="From"><Input type="date" value={from} onChange={(event) => setFrom(event.target.value)} /></Field>
        <Field label="To"><Input type="date" value={to} onChange={(event) => setTo(event.target.value)} /></Field>
        <div className="toolbar">
          <button className="btn" type="submit"><Tr>Show</Tr></button>
          <button className="btn ghost" type="button" onClick={() => openPdf(withQuery('/api/reports', { type, from, to, format: 'pdf' }))}><Tr>Print PDF</Tr></button>
        </div>
      </form>
      <article className="card">
        <table>
          <thead><tr>{columns.map((column) => <th key={column}><Tr>{column}</Tr></th>)}</tr></thead>
          <tbody>{rows.slice(0, 100).map((row, index) => <tr key={index}>{columns.map((column) => <td key={column}>{typeof row[column] === 'string' ? <Tr>{row[column]}</Tr> : row[column]}</td>)}</tr>)}</tbody>
        </table>
        {loading ? <Loader /> : null}
        {!loading && rows.length === 0 ? <p><Tr>Choose a report and press Show.</Tr></p> : null}
      </article>
    </Page>
  );
}

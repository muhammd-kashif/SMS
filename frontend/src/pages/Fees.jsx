import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, download, errorText, exportCsv, openPdf, withQuery } from '../api';
import { useAuth } from '../auth';
import { useI18n } from '../i18n';
import { useList } from '../list';
import {Input,  Tr, Badge, DataTable, Field, money, Modal, Page, RowActions, StatusSwitch, Tabs, useFeedback } from '../ui';

const tabs = [
  { id: 'fees', label: 'Student fees' },
  { id: 'structure', label: 'Fee structure' },
  { id: 'collect', label: 'Collect fee' },
  { id: 'payments', label: 'Payment history' },
  { id: 'voucher', label: 'Fee voucher' },
  { id: 'receipts', label: 'Receipts' },
  { id: 'pending', label: 'Pending' },
  { id: 'defaulters', label: 'Defaulters' },
];

export default function Fees() {
  const { user } = useAuth();
  const { toast, confirm } = useFeedback();
  const [params, setParams] = useSearchParams();
  const tab = params.get('tab') || 'fees';
  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [methods, setMethods] = useState(['cash', 'bank', 'online', 'other']);
  const [settings, setSettings] = useState({});
  const [filters, setFilters] = useState({
    search: params.get('search') || '',
    class_id: '',
    section_id: '',
    status: '',
    from: '',
    to: '',
    pending: tab === 'pending' ? '1' : '',
  });
  const [payFilters, setPayFilters] = useState({ search: '', method: '', from: '', to: '' });
  const [defaulters, setDefaulters] = useState([]);
  const [editing, setEditing] = useState(null);
  const [voucher, setVoucher] = useState(null);
  const [composer, setComposer] = useState(null);
  const fees = useList('/api/fees', { ...filters, pending: tab === 'pending' ? '1' : filters.pending });
  const payments = useList('/api/payments', payFilters);
  const sections = classes.find((item) => String(item.id) === String(filters.class_id))?.sections || [];

  useEffect(() => {
    api('/api/structure').then((data) => setClasses(data.classes || [])).catch(() => {});
    api('/api/students?all=1').then((data) => setStudents(data.data || [])).catch(() => {});
    api('/api/settings').then((data) => {
      setSettings(data.settings || {});
      setMethods(data.settings?.payment_methods || ['cash', 'bank', 'online', 'other']);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (tab === 'defaulters') api('/api/fees/defaulters').then(setDefaulters).catch(() => setDefaulters([]));
  }, [tab]);

  async function createFee(event) {
    event.preventDefault();
    try {
      await api('/api/fees', { method: 'POST', body: Object.fromEntries(new FormData(event.target).entries()) });
      toast('Fee record created.');
      setComposer(null);
      fees.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function assignClass(event) {
    event.preventDefault();
    try {
      const data = await api('/api/fees/assign-class', { method: 'POST', body: Object.fromEntries(new FormData(event.target).entries()) });
      toast(`Fee assigned to ${data.created} students.`);
      setComposer(null);
      fees.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function pay(event) {
    event.preventDefault();
    try {
      const payment = await api('/api/payments', { method: 'POST', body: Object.fromEntries(new FormData(event.target).entries()) });
      toast(`Receipt ${payment.receipt_no} created.`);
      setComposer(null);
      fees.reload();
      payments.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function toggleFee(row) {
    const next = !row.is_active;
    const ok = await confirm({
      title: next ? 'Activate fee?' : 'Deactivate fee?',
      body: next ? 'This fee will appear in pending lists again.' : 'This fee will be kept, but hidden from collection until activated.',
      confirmLabel: next ? 'Activate' : 'Deactivate',
      danger: !next,
    });
    if (!ok) return;
    try {
      await api(`/api/fees/${row.id}`, { method: 'PUT', body: { is_active: next } });
      toast(next ? 'Fee activated.' : 'Fee deactivated.');
      fees.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  async function reverse(row) {
    const reason = window.prompt('Reason for reversing this payment');
    if (!reason) return;
    const ok = await confirm({
      title: 'Reverse payment?',
      body: 'This receipt will stay in history as reversed. The balance will be restored.',
      confirmLabel: 'Reverse',
      danger: true,
    });
    if (!ok) return;
    try {
      await api(`/api/payments/${row.id}/reverse`, { method: 'POST', body: { reason } });
      toast('Payment reversed.');
      payments.reload();
      fees.reload();
    } catch (err) { toast(errorText(err), 'err'); }
  }

  const feeColumns = [
    { key: 'student', label: 'Student', render: (row) => <Tr>{row.student?.user?.name}</Tr> },
    { key: 'code', label: 'ID', render: (row) => row.student?.student_code },
    { key: 'title', label: 'Description' },
    { key: 'amount', label: 'Amount', sort: true, render: (row) => money(row.amount) },
    { key: 'due_date', label: 'Due', sort: true, render: (row) => String(row.due_date).slice(0, 10) },
    { key: 'pending_amount', label: 'Pending', render: (row) => money(row.pending_amount) },
    { key: 'status', label: 'Status', sort: true, render: (row) => (
      <div className="status-cell">
        <Badge value={row.status} />
        <StatusSwitch active={row.is_active !== false} disabled={user?.role !== 'admin'} onChange={() => toggleFee(row)} />
      </div>
    ) },
    { key: 'actions', label: 'Actions', render: (row) => (
      <RowActions onView={() => setVoucher(row)} onEdit={() => setEditing(row)} />
    ) },
  ];

  return (
    <Page title="Fees" text="Structure, collection, vouchers, and receipts stay in separate screens." actions={
      <div className="toolbar">
        {tab === 'structure' ? <button className="btn" onClick={() => setComposer('class')}><Tr>Assign class fee</Tr></button> : null}
        {tab === 'structure' ? <button className="btn" onClick={() => setComposer('student')}><Tr>Add student fee</Tr></button> : null}
        {tab === 'collect' ? <button className="btn" onClick={() => setComposer('collect')}><Tr>Record payment</Tr></button> : null}
        <button className="btn ghost" onClick={() => exportCsv('fees.csv', fees.rows.map((row) => ({ Student: row.student?.user?.name, Title: row.title, Pending: row.pending_amount, Status: row.status })))}><Tr>Export Excel</Tr></button>
        <button className="btn ghost" onClick={() => {
          const path = tab === 'payments' || tab === 'receipts'
            ? withQuery('/api/payments', { ...payFilters, format: 'pdf' })
            : tab === 'defaulters'
              ? '/api/fees/defaulters?format=pdf'
              : withQuery('/api/fees', { ...filters, pending: tab === 'pending' ? '1' : filters.pending, format: 'pdf' });
          openPdf(path).catch(() => toast('Could not open the PDF.', 'err'));
        }}><Tr>Print PDF</Tr></button>
        <Link className="btn ghost" to="/reports"><Tr>Fee reports</Tr></Link>
      </div>
    }>
      <Tabs tabs={tabs} value={tab} onChange={(id) => setParams(id === 'fees' ? {} : { tab: id })} />
      {['fees', 'pending', 'voucher'].includes(tab) ? (
        <div className="card filters">
          <Field label="Search"><Input value={filters.search} placeholder="Name, ID, roll, receipt title" onChange={(event) => setFilters({ ...filters, search: event.target.value })} /></Field>
          <Field label="Class">
            <select value={filters.class_id} onChange={(event) => setFilters({ ...filters, class_id: event.target.value, section_id: '' })}>
              <option value=""><Tr>All</Tr></option>{classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
            </select>
          </Field>
          <Field label="Section">
            <select value={filters.section_id} onChange={(event) => setFilters({ ...filters, section_id: event.target.value })}>
              <option value=""><Tr>All</Tr></option>{sections.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}
            </select>
          </Field>
          <Field label="Payment status">
            <select value={filters.status} onChange={(event) => setFilters({ ...filters, status: event.target.value })}>
              <option value=""><Tr>All</Tr></option><option value="paid"><Tr>Paid</Tr></option><option value="partial"><Tr>Partial</Tr></option><option value="pending"><Tr>Pending</Tr></option><option value="overdue"><Tr>Overdue</Tr></option>
            </select>
          </Field>
          <Field label="From"><Input type="date" value={filters.from} onChange={(event) => setFilters({ ...filters, from: event.target.value })} /></Field>
          <Field label="To"><Input type="date" value={filters.to} onChange={(event) => setFilters({ ...filters, to: event.target.value })} /></Field>
        </div>
      ) : null}
      {tab === 'fees' || tab === 'pending' ? (
        <DataTable columns={feeColumns} rows={fees.rows} loading={fees.loading} sort={fees.sort} onSort={fees.toggleSort} emptyTitle="No fees found" emptyText="No fee records match these filters." page={fees.page} lastPage={fees.last} from={fees.from} to={fees.to} total={fees.total} noun="fees" onPage={fees.setPage} />
      ) : null}
      {tab === 'structure' ? (
        <DataTable columns={feeColumns} rows={fees.rows} loading={fees.loading} sort={fees.sort} onSort={fees.toggleSort} emptyTitle="No fee records" emptyText="Assign a class fee or add a fee for one student." page={fees.page} lastPage={fees.last} from={fees.from} to={fees.to} total={fees.total} noun="fees" onPage={fees.setPage} />
      ) : null}
      {tab === 'collect' ? (
        <DataTable columns={feeColumns} rows={fees.rows.filter((fee) => fee.status !== 'paid' && fee.is_active !== false)} loading={fees.loading} emptyTitle="Nothing to collect" emptyText="Unpaid fees appear here. Use Record payment to take a receipt." page={1} lastPage={1} from={fees.rows.length ? 1 : 0} to={fees.rows.length} total={fees.rows.length} noun="fees" onPage={() => {}} />
      ) : null}
      {tab === 'payments' || tab === 'receipts' ? (
        <>
          <div className="card filters">
            <Field label="Search"><Input value={payFilters.search} placeholder="Receipt, name, ID, roll" onChange={(event) => setPayFilters({ ...payFilters, search: event.target.value })} /></Field>
            <Field label="Method">
              <select value={payFilters.method} onChange={(event) => setPayFilters({ ...payFilters, method: event.target.value })}>
                <option value=""><Tr>All</Tr></option>{methods.map((method) => <option key={method} value={method}><Tr>{method}</Tr></option>)}
              </select>
            </Field>
            <Field label="From"><Input type="date" value={payFilters.from} onChange={(event) => setPayFilters({ ...payFilters, from: event.target.value })} /></Field>
            <Field label="To"><Input type="date" value={payFilters.to} onChange={(event) => setPayFilters({ ...payFilters, to: event.target.value })} /></Field>
          </div>
          <DataTable
            columns={[
              { key: 'receipt_no', label: 'Receipt', sort: true },
              { key: 'student', label: 'Student', render: (row) => <Tr>{row.student?.user?.name}</Tr> },
              { key: 'amount', label: 'Amount', sort: true, render: (row) => money(row.amount) },
              { key: 'method', label: 'Method' },
              { key: 'paid_at', label: 'Date', sort: true, render: (row) => String(row.paid_at).slice(0, 10) },
              { key: 'status', label: 'Status', render: (row) => <Badge value={row.status || 'posted'} /> },
              { key: 'actions', label: 'Actions', render: (row) => (
                <div className="toolbar">
                  <button className="btn ghost" onClick={() => download(`/api/payments/${row.id}/receipt`, `${row.receipt_no}.pdf`)}><Tr>PDF</Tr></button>
                  <button className="btn ghost" onClick={() => openPdf(`/api/payments/${row.id}/receipt`).catch(() => toast('Could not open the receipt.', 'err'))}><Tr>Print</Tr></button>
                  {row.status !== 'reversed' ? <button className="btn ghost" onClick={() => reverse(row)}><Tr>Reverse</Tr></button> : null}
                </div>
              ) },
            ]}
            rows={payments.rows}
            loading={payments.loading}
            sort={payments.sort}
            onSort={payments.toggleSort}
            emptyTitle="No payments"
            emptyText="Receipts appear after a fee is collected."
            page={payments.page}
            lastPage={payments.last}
            from={payments.from}
            to={payments.to}
            total={payments.total}
            noun="payments"
            onPage={payments.setPage}
          />
        </>
      ) : null}
      {tab === 'voucher' ? (
        <>
          <article className="card voucher-actions">
            <div>
              <h3><Tr>Fee vouchers</Tr></h3>
              <p className="hint"><Tr>Download every matching bill together, or open one row for a single student's voucher.</Tr></p>
            </div>
            <div className="toolbar">
              <button className="btn" onClick={() => download(withQuery('/api/fees/vouchers', filters), 'fee-vouchers.pdf').catch(() => toast('Could not download the vouchers.', 'err'))}><Tr>All students' vouchers</Tr></button>
              <button className="btn ghost" onClick={() => openPdf(withQuery('/api/fees/vouchers', filters)).catch(() => toast('Could not open the vouchers.', 'err'))}><Tr>Print all</Tr></button>
            </div>
          </article>
          <DataTable columns={feeColumns} rows={fees.rows} loading={fees.loading} emptyTitle="No vouchers" emptyText="Create a fee, then open it to download the voucher." page={fees.page} lastPage={fees.last} from={fees.from} to={fees.to} total={fees.total} noun="vouchers" onPage={fees.setPage} />
        </>
      ) : null}
      {tab === 'defaulters' ? (
        <article className="card">
          {defaulters.length === 0 ? <p><Tr>No defaulters.</Tr></p> : defaulters.map((fee) => (
            <p key={fee.id}><Tr>{fee.student?.user?.name}</Tr> · <Tr>{fee.student?.school_class?.name || fee.student?.schoolClass?.name}</Tr> · <Tr>{fee.title}</Tr> · {money(fee.pending_amount)} · <Tr>Due</Tr> {String(fee.due_date).slice(0, 10)}</p>
          ))}
        </article>
      ) : null}
      <Modal title={voucher ? 'Fee voucher' : ''} wide onClose={() => setVoucher(null)}>
        {voucher ? (
          <div className="voucher-modal">
            <FeeChallan fee={voucher} college={user?.college} settings={settings} />
            <div className="toolbar">
              <button className="btn" onClick={() => download(`/api/fees/${voucher.id}/voucher`, `voucher-${voucher.id}.pdf`).catch(() => toast('Could not download the voucher.', 'err'))}><Tr>This student's PDF</Tr></button>
              <button className="btn ghost" onClick={() => openPdf(`/api/fees/${voucher.id}/voucher`).catch(() => toast('Could not open the voucher.', 'err'))}><Tr>Print this voucher</Tr></button>
              <button className="btn ghost" onClick={() => navigator.share?.({ title: 'Fee voucher', text: `${voucher.title} ${money(voucher.pending_amount)}` }).catch(() => toast('Sharing is not available on this device.', 'err'))}><Tr>Share</Tr></button>
            </div>
          </div>
        ) : null}
      </Modal>
      <Modal title={composer === 'class' ? 'Assign a class fee' : composer === 'student' ? 'Add one student fee' : composer === 'collect' ? 'Record payment' : ''} onClose={() => setComposer(null)}>
        {composer === 'class' ? (
          <form className="form-grid" onSubmit={assignClass}>
            <Field label="Class"><select name="class_id" required>{classes.map((item) => <option key={item.id} value={item.id}><Tr>{item.name}</Tr></option>)}</select></Field>
            <Field label="Type"><select name="fee_type"><option value="monthly"><Tr>Monthly</Tr></option><option value="admission"><Tr>Admission</Tr></option><option value="examination"><Tr>Examination</Tr></option><option value="other"><Tr>Other</Tr></option></select></Field>
            <Field label="Title"><Input name="title" required /></Field>
            <Field label="Amount"><Input name="amount" type="number" min="0" required /></Field>
            <Field label="Due date"><Input name="due_date" type="date" required /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
        {composer === 'student' ? (
          <form className="form-grid" onSubmit={createFee}>
            <Field label="Student" wide><select name="student_id" required><option value=""><Tr>Select</Tr></option>{students.map((student) => <option key={student.id} value={student.id}><Tr>{student.name}</Tr></option>)}</select></Field>
            <Field label="Type"><select name="fee_type"><option value="monthly"><Tr>Monthly</Tr></option><option value="admission"><Tr>Admission</Tr></option><option value="examination"><Tr>Examination</Tr></option><option value="other"><Tr>Other</Tr></option></select></Field>
            <Field label="Title"><Input name="title" required /></Field>
            <Field label="Amount"><Input name="amount" type="number" min="0" required /></Field>
            <Field label="Due date"><Input name="due_date" type="date" required /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
        {composer === 'collect' ? (
          <form className="form-grid" onSubmit={pay}>
            <Field label="Fee" wide>
              <select name="fee_item_id" required>
                <option value=""><Tr>Select</Tr></option>
                {fees.rows.filter((fee) => fee.status !== 'paid' && fee.is_active !== false).map((fee) => <option key={fee.id} value={fee.id}><Tr>{`${fee.student?.user?.name || ''} · ${fee.title || ''}`}</Tr> · {money(fee.pending_amount)}</option>)}
              </select>
            </Field>
            <Field label="Amount"><Input name="amount" type="number" min="1" required /></Field>
            <Field label="Method"><select name="method">{methods.map((method) => <option key={method} value={method}><Tr>{method}</Tr></option>)}</select></Field>
            <Field label="Date"><Input name="paid_at" type="date" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      <Modal title={editing ? 'Edit fee' : ''} onClose={() => setEditing(null)}>
        {editing ? (
          <form className="form-grid" onSubmit={async (event) => {
            event.preventDefault();
            try {
              await api(`/api/fees/${editing.id}`, { method: 'PUT', body: Object.fromEntries(new FormData(event.target).entries()) });
              toast('Fee updated.');
              setEditing(null);
              fees.reload();
            } catch (err) { toast(errorText(err), 'err'); }
          }}>
            <Field label="Title"><Input name="title" defaultValue={editing.title} required /></Field>
            <Field label="Amount"><Input name="amount" type="number" min="0" defaultValue={editing.amount} required /></Field>
            <Field label="Due date"><Input name="due_date" type="date" defaultValue={String(editing.due_date).slice(0, 10)} required /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}

const ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

function words(number) {
  let value = Math.floor(Math.abs(number));
  if (value === 0) return 'zero';
  const parts = [];
  [[10000000, 'crore'], [100000, 'lakh'], [1000, 'thousand'], [100, 'hundred']].forEach(([scale, label]) => {
    if (value >= scale) {
      parts.push(`${words(Math.floor(value / scale))} ${label}`);
      value %= scale;
    }
  });
  if (value >= 20) {
    const rest = value % 10;
    parts.push(rest ? `${tens[Math.floor(value / 10)]}-${ones[rest]}` : tens[Math.floor(value / 10)]);
  } else if (value > 0) parts.push(ones[value]);
  return parts.join(' ');
}

function rupeeWords(amount) {
  const rupees = Math.floor(Number(amount) + 0.00001);
  const text = `${words(rupees)} rupee${rupees === 1 ? '' : 's'} only`;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function formatDay(value) {
  if (!value) return '';
  const date = new Date(`${String(value).slice(0, 10)}T00:00:00`);
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 10);
  return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

function addDays(value, days) {
  const date = new Date(`${String(value).slice(0, 10)}T00:00:00`);
  date.setDate(date.getDate() + days);
  return date;
}

function FeeChallan({ fee, college, settings }) {
  const { locale, tx } = useI18n();
  const amount = Number(fee.amount || 0);
  const paid = Number(fee.paid_amount || 0);
  const penalty = Number(fee.late_fee) > 0 ? Number(fee.late_fee) : Number(settings.late_fee_amount || 0);
  const within = Math.max(0, Math.round((amount - paid) * 100) / 100);
  const after = Math.max(0, Math.round((amount + penalty - paid) * 100) / 100);
  const grace = Number(fee.grace_days || 0);
  const due = fee.due_date ? String(fee.due_date).slice(0, 10) : '';
  const graceEnd = due ? addDays(due, grace) : null;
  const afterStart = due ? addDays(due, grace + 1) : null;
  const className = [fee.student?.school_class?.name || fee.student?.schoolClass?.name, fee.student?.section?.name].filter(Boolean).join(' ');
  const period = due ? new Date(`${due}T00:00:00`).toLocaleDateString(locale === 'ur' ? 'ur-PK' : 'en-GB', { month: 'long', year: 'numeric' }) : '';
  const copies = ['Fee Bill', 'Student Copy', 'Bank Copy'];
  const logo = college?.logo_url || '/logo.png';
  const name = college?.name || settings.college_name || 'Smart College';

  return (
    <div className="challan-wrap">
      <div className="challan-sheet">
        {copies.map((copy) => (
          <article className="challan" key={copy}>
            <header className="challan-head">
              <img src={logo} alt="" />
              <div>
                <strong>{tx(name)}</strong>
                <span>{tx(college?.address || settings.college_address || '')}</span>
              </div>
              <div className="challan-copy"><Tr>Fee Bill</Tr><strong><Tr>{copy}</Tr></strong></div>
            </header>
            <table className="meta">
              <tbody>
                <tr><td><Tr>Invoice no.</Tr></td><td>{String(fee.id).padStart(12, '0')}</td></tr>
                <tr><td><Tr>Due date</Tr></td><td>{formatDay(due)}</td></tr>
                <tr><td><Tr>Student</Tr></td><td><strong><Tr>{fee.student?.user?.name}</Tr></strong></td></tr>
                <tr><td><Tr>Student ID</Tr></td><td>{fee.student?.student_code}</td></tr>
                <tr><td><Tr>Father name</Tr></td><td><Tr>{fee.student?.father_name || '—'}</Tr></td></tr>
                <tr><td><Tr>Class</Tr></td><td>{tx(className) || '—'}</td></tr>
                <tr><td><Tr>Roll number</Tr></td><td>{fee.student?.roll_number || '—'}</td></tr>
              </tbody>
            </table>
            <div className="period">{tx(fee.title)} · {period}</div>
            <table className="lines">
              <thead><tr><th><Tr>Description</Tr></th><th><Tr>Amount (Rs.)</Tr></th></tr></thead>
              <tbody>
                <tr><td>{tx(fee.title)}</td><td>{amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
                {paid > 0 ? <tr><td><Tr>Already paid</Tr></td><td>{paid.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr> : null}
              </tbody>
            </table>
            <table className="due-table">
              <tbody>
                <tr><td><Tr>Payable within due date</Tr></td><td>{within.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
              </tbody>
            </table>
            <p className="words">{locale === 'ur' ? `لفظوں میں: ${within.toLocaleString('en-PK')} روپے صرف` : `In words: ${rupeeWords(within)}`}</p>
            <table className="slab">
              <tbody>
                <tr><td colSpan="2"><strong><Tr>Payable after due date</Tr></strong></td></tr>
                {grace > 0 ? (
                  <>
                    <tr><td>Between {formatDay(addDays(due, 1))} and {formatDay(graceEnd)}</td><td>{within.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
                    <tr><td>{formatDay(afterStart)} onwards</td><td>{after.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
                  </>
                ) : (
                  <tr><td>From {formatDay(addDays(due, 1))} onwards</td><td>{after.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
                )}
              </tbody>
            </table>
            <div className="pay-box">
              <img src={logo} alt="" />
              <div>
                <strong><Tr>Payment information</Tr></strong>
                <p>
                  {settings.bank_name
                    ? (locale === 'ur'
                      ? `${settings.bank_name} کے ذریعے ادا کریں${settings.bank_account ? `۔ اکاؤنٹ نمبر ${settings.bank_account}` : ''}۔`
                      : `Payable through ${settings.bank_name}${settings.bank_account ? `. Account no. ${settings.bank_account}` : ''}.`)
                    : (locale === 'ur' ? `${tx(name)} کے اکاؤنٹس دفتر میں ادا کریں۔` : `Payable at the ${name} accounts office.`)}
                </p>
                <span>{college?.phone || settings.college_phone || ''} {college?.email || settings.college_email || ''}</span>
              </div>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}

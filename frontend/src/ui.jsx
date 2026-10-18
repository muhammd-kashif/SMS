import { createContext, forwardRef, useContext, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { useI18n } from './i18n';

const FeedbackContext = createContext(null);

export function Tr({ children }) {
  const { tx } = useI18n();
  if (typeof children === 'string' || typeof children === 'number') return tx(children);
  return children ?? null;
}

export function FeedbackProvider({ children }) {
  const { tx, t } = useI18n();
  const [toasts, setToasts] = useState([]);
  const [ask, setAsk] = useState(null);
  const resolver = useRef(null);

  function toast(message, tone = 'ok') {
    const id = `${Date.now()}-${Math.random()}`;
    setToasts((list) => [...list, { id, message: tx(message), tone }]);
    setTimeout(() => setToasts((list) => list.filter((item) => item.id !== id)), 3400);
  }

  function confirm(options) {
    return new Promise((resolve) => {
      resolver.current = resolve;
      setAsk(options);
    });
  }

  function close(value) {
    resolver.current?.(value);
    resolver.current = null;
    setAsk(null);
  }

  return (
    <FeedbackContext.Provider value={{ toast, confirm }}>
      {children}
      <div className="toasts">
        {toasts.map((item) => <div key={item.id} className={`toast ${item.tone}`}>{item.message}</div>)}
      </div>
      {ask ? (
        <div className="modal-back">
          <div className="modal confirm-box" role="dialog" aria-modal="true">
            <h2>{tx(ask.title)}</h2>
            <p>{typeof ask.body === 'string' ? tx(ask.body) : ask.body}</p>
            <div className="toolbar end">
              <button className="btn ghost" onClick={() => close(false)}>{tx(ask.cancelLabel || t('cancel'))}</button>
              <button className={ask.danger ? 'btn danger' : 'btn'} onClick={() => close(true)}>{tx(ask.confirmLabel || t('confirm'))}</button>
            </div>
          </div>
        </div>
      ) : null}
    </FeedbackContext.Provider>
  );
}

export function useFeedback() {
  return useContext(FeedbackContext);
}

export function Page({ title, text, actions, children }) {
  const { tx } = useI18n();
  return (
    <section className="content">
      <div className="page-head">
        <div>
          <h1>{typeof title === 'string' ? tx(title) : title}</h1>
          {text ? <p>{typeof text === 'string' ? tx(text) : text}</p> : null}
        </div>
        {actions ? <div className="top-actions">{actions}</div> : null}
      </div>
      {children}
    </section>
  );
}

export function Field({ label, error, hint, wide, children }) {
  const { tx } = useI18n();
  return (
    <label className={wide ? 'wide' : ''}>
      <span>{tx(label)}</span>
      {children}
      {error ? <small className="error">{tx(Array.isArray(error) ? error[0] : error)}</small> : null}
      {hint && !error ? <small className="hint">{tx(hint)}</small> : null}
    </label>
  );
}

export function Badge({ value }) {
  const { tx } = useI18n();
  const key = String(value || '').toLowerCase().replace(/\s+/g, '-');
  return <span className={`pill ${key}`}>{tx(value)}</span>;
}

export function StatusSwitch({ active, onChange, disabled, onLabel = 'Active', offLabel = 'Inactive' }) {
  const { tx } = useI18n();
  onLabel = tx(onLabel);
  offLabel = tx(offLabel);
  return (
    <button
      type="button"
      className={active ? 'switch on' : 'switch'}
      role="switch"
      aria-checked={Boolean(active)}
      aria-label={active ? onLabel : offLabel}
      disabled={disabled}
      onClick={() => onChange?.(!active)}
    >
      <span className="switch-track" aria-hidden="true"><span className="switch-knob" /></span>
      <span className="switch-label">{active ? onLabel : offLabel}</span>
    </button>
  );
}

export function Modal({ title, children, onClose, wide }) {
  const { t, tx } = useI18n();
  if (!title) return null;
  return (
    <div className="modal-back" onClick={onClose}>
      <div className={wide ? 'modal modal-wide' : 'modal'} onClick={(event) => event.stopPropagation()} role="dialog" aria-modal="true">
        <div className="modal-head">
          <h2>{tx(title)}</h2>
          <button type="button" className="icon-btn" aria-label={t('cancel')} onClick={onClose}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg>
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Tabs({ tabs, value, onChange }) {
  const { tx } = useI18n();
  return (
    <div className="tabs" role="tablist">
      {tabs.map((tab) => (
        <button key={tab.id} type="button" className={value === tab.id ? 'tab active' : 'tab'} onClick={() => onChange(tab.id)}>{tx(tab.label)}</button>
      ))}
    </div>
  );
}

export function EmptyState({ title, text, action }) {
  const { tx } = useI18n();
  return (
    <div className="empty">
      <strong>{tx(title)}</strong>
      {text ? <p>{tx(text)}</p> : null}
      {action || null}
    </div>
  );
}

export function Loader({ full = false, label = 'Loading' }) {
  const { tx } = useI18n();
  label = tx(label);
  return (
    <div className={full ? 'loader full' : 'loader'} role="status" aria-label={label}>
      <div className="loader-ring">
        <img src="/logo.png" alt="" />
      </div>
    </div>
  );
}

export function Skeleton({ rows = 5 }) {
  return (
    <div className="skeleton" aria-busy="true">
      {Array.from({ length: rows }, (_, index) => <div key={index} className="skeleton-row" />)}
    </div>
  );
}

export function Pager({ page, lastPage, from, to, total, noun, onPage }) {
  const { tx } = useI18n();
  if (!total) return null;
  const start = Math.max(1, Math.min(page - 2, lastPage - 4));
  const end = Math.min(lastPage, start + 4);
  const pages = [];
  for (let number = Math.max(1, start); number <= end; number += 1) pages.push(number);
  return (
    <div className="pager">
      <span>{tx('Showing')} {from}–{to} {tx('of')} {total} {tx(noun)}</span>
      <div className="pager-btns">
        <button type="button" className="btn ghost" disabled={page <= 1} onClick={() => onPage(page - 1)}>{tx('Previous')}</button>
        {pages.map((number) => (
          <button type="button" key={number} className={number === page ? 'btn page-num' : 'btn ghost page-num'} onClick={() => onPage(number)}>{number}</button>
        ))}
        <button type="button" className="btn ghost" disabled={page >= lastPage} onClick={() => onPage(page + 1)}>{tx('Next')}</button>
      </div>
    </div>
  );
}

function cellText(value) {
  if (typeof value === 'string' || typeof value === 'number') return <Tr>{value}</Tr>;
  return value ?? '';
}

export function DataTable({ columns, rows, loading, sort, onSort, emptyTitle, emptyText, emptyAction, page, lastPage, from, to, total, noun, onPage }) {
  const { tx } = useI18n();
  return (
    <article className="card table-card">
      {loading ? <Loader /> : (
        <>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  {columns.map((column) => (
                    <th key={column.key}>
                      {column.sort ? (
                        <button type="button" className="sort-btn" onClick={() => onSort?.(column.key)}>
                          {tx(column.label)} {sort?.key === column.key ? (sort.dir === 'asc' ? '↑' : '↓') : ''}
                        </button>
                      ) : tx(column.label)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => (
                  <tr key={row.id ?? index}>
                    {columns.map((column) => <td key={column.key}>{column.render ? column.render(row) : cellText(row[column.key])}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {rows.length === 0 ? <EmptyState title={emptyTitle} text={emptyText} action={emptyAction} /> : null}
          <Pager page={page} lastPage={lastPage} from={from} to={to} total={total} noun={noun} onPage={onPage} />
        </>
      )}
    </article>
  );
}

function Eye() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></svg>;
}
function Pen() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h4l10-10-4-4L4 16v4z" /><path d="M13 7l4 4" /></svg>;
}
function Bin() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16" /><path d="M9 7V5h6v2" /><path d="M7 7l1 12h8l1-12" /></svg>;
}

export function ActionMenu({ items }) {
  const { tx } = useI18n();
  const [open, setOpen] = useState(false);
  const [box, setBox] = useState(null);
  const ref = useRef(null);
  const visible = (items || []).filter((item) => item && item.show !== false);

  useEffect(() => {
    function close(event) {
      if (!ref.current?.contains(event.target)) setOpen(false);
    }
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, []);

  if (!visible.length) return null;
  return (
    <div className="action-menu" ref={ref}>
      <button
        type="button"
        className="icon-act"
        aria-label={tx('Actions')}
        aria-expanded={open}
        onClick={(event) => {
          const rect = event.currentTarget.getBoundingClientRect();
          setBox({ top: rect.bottom + 6, left: Math.max(8, rect.right - 180) });
          setOpen((value) => !value);
        }}
      >
        ⋮
      </button>
      {open && box ? (
        <div className="action-pop" style={{ top: box.top, left: box.left }}>
          {visible.map((item) => (
            <button key={item.label} type="button" className={item.danger ? 'danger' : ''} onClick={() => { setOpen(false); item.onClick?.(); }}>
              {tx(item.label)}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function RowActions({ onView, onEdit, onDelete }) {
  const { tx } = useI18n();
  return (
    <div className="row-actions">
      {onView ? <button type="button" className="icon-act" aria-label={tx('View')} title={tx('View')} onClick={onView}><Eye /></button> : null}
      {onEdit ? <button type="button" className="icon-act" aria-label={tx('Edit')} title={tx('Edit')} onClick={onEdit}><Pen /></button> : null}
      {onDelete ? <button type="button" className="icon-act danger" aria-label={tx('Delete')} title={tx('Delete')} onClick={onDelete}><Bin /></button> : null}
    </div>
  );
}

export const Camera = forwardRef(function Camera({ guide = false, hint = 'Keep your face inside the oval' }, ref) {
  const { tx } = useI18n();
  const videoRef = useRef(null);
  const [error, setError] = useState('');
  useImperativeHandle(ref, () => ({
    capture: () => captureFrame(videoRef.current),
  }));
  useEffect(() => {
    let stream;
    navigator.mediaDevices?.getUserMedia({ video: { facingMode: 'user' }, audio: false })
      .then(async (media) => {
        stream = media;
        if (!videoRef.current) return;
        videoRef.current.srcObject = media;
        await videoRef.current.play();
      })
      .catch(() => setError(tx('Allow camera access to register or scan a face.')));
    return () => stream?.getTracks().forEach((track) => track.stop());
  }, []);
  return (
    <div className="camera-frame">
      <video ref={videoRef} muted playsInline />
      {guide ? <div className="face-oval" aria-hidden="true"><span>{tx(hint)}</span></div> : null}
      {error ? <p className="error">{error}</p> : null}
    </div>
  );
});

export function captureFrame(video) {
  if (!video || !video.videoWidth) return null;
  const canvas = document.createElement('canvas');
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  canvas.getContext('2d').drawImage(video, 0, 0);
  return canvas.toDataURL('image/jpeg', 0.9);
}

export function FilePick({ name, accept }) {
  const { tx } = useI18n();
  const input = useRef(null);
  const [fileName, setFileName] = useState('');
  return (
    <div className="file-pick">
      <input ref={input} name={name} type="file" accept={accept} onChange={(event) => setFileName(event.target.files?.[0]?.name || '')} />
      <button type="button" className="btn ghost" onClick={() => input.current?.click()}>{tx('Choose file')}</button>
      <span>{fileName || tx('No file chosen')}</span>
    </div>
  );
}

export function Input({ placeholder, ...props }) {
  const { tx } = useI18n();
  return <input {...props} placeholder={placeholder ? tx(placeholder) : placeholder} />;
}

export function Textarea({ placeholder, ...props }) {
  const { tx } = useI18n();
  return <textarea {...props} placeholder={placeholder ? tx(placeholder) : placeholder} />;
}

export function money(value, locale = (typeof document !== 'undefined' && document.documentElement.lang === 'ur' ? 'ur' : 'en')) {
  const amount = Number(value || 0).toLocaleString('en-PK', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
  return locale === 'ur' ? `روپے ${amount}` : `PKR ${amount}`;
}

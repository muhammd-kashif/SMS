const API = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

export function errorText(error) {
  const errors = error?.data?.errors;
  if (errors) return Object.values(errors).flat().join(' ');
  return error?.message || 'Something went wrong.';
}

async function request(path, { method = 'GET', body, form } = {}) {
  const headers = { Accept: 'application/json' };
  const token = localStorage.getItem('sms_token');
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (form) {
    payload = form;
  } else if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  let response;
  try {
    response = await fetch(`${API}${path}`, { method, headers, body: payload });
  } catch {
    const error = new Error('Network unavailable.');
    error.offline = true;
    throw error;
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data.message || 'Request failed.');
    error.status = response.status;
    error.data = data;
    error.offline = response.status === 503;
    throw error;
  }
  return data;
}

export const api = (path, options) => request(path, options);

export function apiForm(path, form, method = 'POST') {
  return request(path, { method, form });
}

export function fieldErrors(error) {
  return error?.data?.errors || {};
}

export function exportCsv(filename, rows) {
  if (!rows?.length) return;
  const keys = Object.keys(rows[0]);
  const lines = [
    keys.join(','),
    ...rows.map((row) => keys.map((key) => `"${String(row[key] ?? '').replaceAll('"', '""')}"`).join(',')),
  ];
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function withQuery(path, filters) {
  const query = new URLSearchParams();
  Object.entries(filters || {}).forEach(([key, value]) => {
    if (value !== '' && value != null) query.set(key, String(value));
  });
  const text = query.toString();
  return text ? `${path}?${text}` : path;
}

export async function openPdf(path) {
  const headers = {};
  const token = localStorage.getItem('sms_token');
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${API}${path}`, { headers });
  if (!response.ok) throw new Error('Download failed.');
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  window.open(url, '_blank', 'noopener');
}

export async function download(path, filename) {
  const headers = {};
  const token = localStorage.getItem('sms_token');
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${API}${path}`, { headers });
  if (!response.ok) throw new Error('Download failed.');
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

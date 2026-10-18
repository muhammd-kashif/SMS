import { useEffect, useState } from 'react';
import { api } from './api';

export function useList(path, filters) {
  const [page, setPage] = useState(1);
  const [sort, setSort] = useState({ key: '', dir: 'asc' });
  const [pack, setPack] = useState({ rows: [], last: 1, total: 0, from: 0, to: 0 });
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);
  const filterKey = JSON.stringify(filters);

  useEffect(() => {
    setPage(1);
  }, [filterKey]);

  useEffect(() => {
    const query = new URLSearchParams();
    Object.entries(filters || {}).forEach(([key, value]) => {
      if (value !== '' && value != null) query.set(key, String(value));
    });
    query.set('page', String(page));
    if (sort.key) {
      query.set('sort', sort.key);
      query.set('direction', sort.dir);
    }
    let ignore = false;
    setLoading(true);
    api(`${path}?${query}`)
      .then((data) => {
        if (ignore) return;
        const rows = data.data || [];
        setPack({
          rows,
          last: data.last_page || 1,
          total: data.total ?? rows.length,
          from: data.from || (rows.length ? 1 : 0),
          to: data.to || rows.length,
          summary: data.summary || null,
        });
      })
      .catch(() => {
        if (!ignore) setPack({ rows: [], last: 1, total: 0, from: 0, to: 0, summary: null });
      })
      .finally(() => {
        if (!ignore) setLoading(false);
      });
    return () => {
      ignore = true;
    };
  }, [path, filterKey, page, sort.key, sort.dir, tick]);

  function toggleSort(key) {
    setSort((current) => (
      current.key === key
        ? { key, dir: current.dir === 'asc' ? 'desc' : 'asc' }
        : { key, dir: 'asc' }
    ));
  }

  return {
    ...pack,
    loading,
    page,
    setPage,
    sort,
    toggleSort,
    reload: () => setTick((value) => value + 1),
  };
}

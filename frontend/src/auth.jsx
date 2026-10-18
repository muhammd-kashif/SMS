import { createContext, useContext, useEffect, useState } from 'react';
import { api } from './api';
import { applyTheme } from './theme';

const AuthContext = createContext(null);

export function useAuth() {
  return useContext(AuthContext);
}

export function can(user, module) {
  return Boolean(user?.permissions?.includes('*') || user?.permissions?.includes(module));
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('sms_token');
    if (!token) {
      setReady(true);
      return;
    }
    api('/api/me')
      .then((profile) => {
        setUser(profile);
        applyTheme(profile.college);
      })
      .catch(() => localStorage.removeItem('sms_token'))
      .finally(() => setReady(true));
  }, []);

  async function login(email, password) {
    const data = await api('/api/login', { method: 'POST', body: { email, password } });
    localStorage.setItem('sms_token', data.token);
    setUser(data.user);
    applyTheme(data.user?.college);
  }

  async function logout() {
    await api('/api/logout', { method: 'POST' }).catch(() => {});
    localStorage.removeItem('sms_token');
    setUser(null);
  }

  function updateUser(next) {
    setUser(next);
    if (next?.college) applyTheme(next.college);
  }

  return <AuthContext.Provider value={{ user, ready, login, logout, updateUser }}>{children}</AuthContext.Provider>;
}

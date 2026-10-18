import {Input,  Tr } from '../ui';
import { useEffect, useState } from 'react';
import { api, errorText } from '../api';
import { useAuth } from '../auth';
import { useI18n } from '../i18n';
import { applyTheme } from '../theme';

export default function Login() {
  const { login } = useAuth();
  const { t } = useI18n();
  const [email, setEmail] = useState('admin@smartcollege.test');
  const [password, setPassword] = useState('College@123');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [brand, setBrand] = useState(null);

  useEffect(() => {
    api('/api/branding').then((data) => {
      setBrand(data);
      applyTheme(data);
    }).catch(() => {});
  }, []);

  async function submit(event) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      await login(email, password);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-screen">
      <section className="login-brand">
        <img className="login-logo" src={brand?.logo_url || '/logo.png'} alt={brand?.name || 'Smart College'} />
        <div className="login-copy">
          <p className="eyebrow"><Tr>College management</Tr></p>
          <h1><Tr>{brand?.name || 'Smart College'}</Tr></h1>
          <p><Tr>Attendance, fees, exams, and daily college work in one place.</Tr></p>
          <ul className="login-points">
            <li><Tr>Attendance is marked only after a live face match</Tr></li>
            <li><Tr>Fees, vouchers, and receipts stay in one ledger</Tr></li>
            <li><Tr>Exams, leaves, and announcements for every role</Tr></li>
          </ul>
        </div>
      </section>
      <section className="login-panel">
        <form className="login-card" onSubmit={submit}>
          <img className="login-card-logo" src={brand?.logo_url || '/logo.png'} alt={brand?.name || 'Smart College'} />
          <h2>{t('signIn')}</h2>
          <div className="form-grid">
            <label className="wide">{t('email')}<Input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required /></label>
            <label className="wide">{t('password')}<Input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required /></label>
          </div>
          {error ? <p className="error">{error}</p> : null}
          <button className="btn" disabled={busy} type="submit">{busy ? t('loading') : t('signIn')}</button>
          <div className="demo">
            <Tr>Demo password for every account: College@123</Tr><br />
            admin@smartcollege.test · teacher@smartcollege.test · accountant@smartcollege.test<br />
            student@smartcollege.test · parent@smartcollege.test
          </div>
        </form>
      </section>
    </div>
  );
}

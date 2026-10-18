import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, apiForm, errorText, fieldErrors } from '../api';
import { useAuth } from '../auth';
import {Input, FilePick, Tr, Badge, Field, Modal, Page, useFeedback } from '../ui';

export default function Profile() {
  const { user, updateUser, logout } = useAuth();
  const { toast } = useFeedback();
  const [params, setParams] = useSearchParams();
  const [panel, setPanel] = useState(null);
  const [form, setForm] = useState({ name: user?.name || '', phone: user?.phone || '' });
  const [errors, setErrors] = useState({});
  const [password, setPassword] = useState({ current_password: '', password: '', password_confirmation: '' });
  const portrait = user?.face_photo_url || user?.photo_url;

  useEffect(() => {
    const tab = params.get('tab');
    if (tab === 'edit' || tab === 'password') setPanel(tab);
  }, [params]);

  function closePanel() {
    setPanel(null);
    if (params.get('tab')) setParams({});
  }

  async function saveProfile(event) {
    event.preventDefault();
    const data = new FormData(event.target);
    try {
      const profile = await apiForm('/api/me', data, 'POST');
      updateUser(profile);
      setForm({ name: profile.name || '', phone: profile.phone || '' });
      setErrors({});
      toast('Profile updated successfully.');
      closePanel();
    } catch (err) {
      setErrors(fieldErrors(err));
      toast(errorText(err), 'err');
    }
  }

  async function savePassword(event) {
    event.preventDefault();
    if (password.password !== password.password_confirmation) {
      setErrors({ password_confirmation: 'Passwords do not match.' });
      return;
    }
    try {
      await api('/api/me/password', { method: 'PUT', body: password });
      setPassword({ current_password: '', password: '', password_confirmation: '' });
      setErrors({});
      toast('Password updated successfully.');
      closePanel();
    } catch (err) {
      setErrors(fieldErrors(err));
      toast(errorText(err), 'err');
    }
  }

  return (
    <Page title="Profile" text="Your account details, photo, and password.">
      <article className="card profile-card">
        <div className="profile-portrait">
          {portrait ? <img src={portrait} alt="" /> : <div className="avatar">{user?.name?.slice(0, 1)}</div>}
        </div>
        <div className="profile-copy">
          <div className="profile-title">
            <h2><Tr>{user?.name}</Tr></h2>
            <Badge value={user?.role} />
            <Badge value={user?.is_active ? 'active' : 'inactive'} />
            {user?.role === 'teacher' || user?.role === 'student' ? <Badge value={user?.face_registered ? 'registered' : 'not registered'} /> : null}
          </div>
          <dl className="meta-list">
            <div><dt><Tr>Email</Tr></dt><dd>{user?.email}</dd></div>
            <div><dt><Tr>Phone</Tr></dt><dd>{user?.phone || '—'}</dd></div>
            <div><dt><Tr>Username</Tr></dt><dd><Tr>{user?.username}</Tr></dd></div>
            {user?.employee_code ? <div><dt><Tr>Employee ID</Tr></dt><dd>{user.employee_code}</dd></div> : null}
            {user?.designation ? <div><dt><Tr>Designation</Tr></dt><dd><Tr>{user.designation}</Tr></dd></div> : null}
            <div><dt><Tr>Face</Tr></dt><dd>{user?.face_registered ? <Tr>Saved</Tr> : <Tr>Not registered</Tr>}</dd></div>
          </dl>
          <div className="toolbar">
            <button className="btn" onClick={() => setPanel('edit')}><Tr>Edit profile</Tr></button>
            <button className="btn ghost" onClick={() => setPanel('password')}><Tr>Change password</Tr></button>
            <button className="btn ghost" onClick={logout}><Tr>Logout</Tr></button>
          </div>
        </div>
      </article>
      <Modal title={panel === 'edit' ? 'Edit profile' : ''} onClose={closePanel}>
        {panel === 'edit' ? (
          <form className="form-grid" onSubmit={saveProfile}>
            <Field label="Name" error={errors.name}><Input name="name" value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} required /></Field>
            <Field label="Email"><Input value={user?.email || ''} disabled /></Field>
            <Field label="Phone" error={errors.phone}><Input name="phone" value={form.phone || ''} onChange={(event) => setForm({ ...form, phone: event.target.value })} placeholder="03001234567" /></Field>
            <Field label="Username"><Input value={user?.username || ''} disabled /></Field>
            <Field label="Profile photo" error={errors.photo} hint="JPG or PNG, up to 4 MB. A saved face is shown when no photo is uploaded."><FilePick name="photo" accept="image/png,image/jpeg,image/webp" /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
      <Modal title={panel === 'password' ? 'Change password' : ''} onClose={closePanel}>
        {panel === 'password' ? (
          <form className="form-grid" onSubmit={savePassword}>
            <Field label="Current password" error={errors.current_password} wide><Input type="password" value={password.current_password} onChange={(event) => setPassword({ ...password, current_password: event.target.value })} required /></Field>
            <Field label="New password" error={errors.password}><Input type="password" value={password.password} onChange={(event) => setPassword({ ...password, password: event.target.value })} required minLength={8} /></Field>
            <Field label="Confirm password" error={errors.password_confirmation}><Input type="password" value={password.password_confirmation} onChange={(event) => setPassword({ ...password, password_confirmation: event.target.value })} required /></Field>
            <button className="btn" type="submit"><Tr>Save</Tr></button>
          </form>
        ) : null}
      </Modal>
    </Page>
  );
}
